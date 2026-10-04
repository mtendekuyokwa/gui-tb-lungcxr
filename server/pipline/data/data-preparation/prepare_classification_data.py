#!/usr/bin/env python3
"""
Stratified data preparation for classification experiment.
Ensures equal representation of TB/Normal and Excellent/Good/Bad.
"""

import pandas as pd
import numpy as np
import argparse
import pathlib
import json


def prepare_data(args):
    df = pd.read_csv(str(args.manifest))
    print(f"Loaded manifest: {len(df)} total records")
    print()

    required = ["cxr_file", "pred_mask_file", "has_tb", "quality", "dataset"]
    for col in required:
        if col not in df.columns:
            raise ValueError(f"Missing required column: {col}")

    df = df.dropna(subset=["cxr_file", "pred_mask_file", "has_tb", "quality"])
    print(f"After dropping missing values: {len(df)} records")

    valid_qualities = ["excellent", "good", "bad"]
    df = df[df["quality"].isin(valid_qualities)]
    print(f"After quality filter: {len(df)} records")
    print()

    print("Raw distribution (has_tb x quality):")
    print(pd.crosstab(df["has_tb"], df["quality"], margins=True))
    print()

    # Determine samples per stratum
    strata = []
    for tb_val in [0, 1]:
        for quality in valid_qualities:
            subset = df[(df["has_tb"] == tb_val) & (df["quality"] == quality)]
            strata.append({
                "has_tb": tb_val,
                "quality": quality,
                "available": len(subset),
                "tb_label": "TB" if tb_val == 1 else "Normal",
            })

    strata_df = pd.DataFrame(strata)
    print("Samples available per stratum:")
    print(strata_df.to_string(index=False))
    print()

    min_available = int(strata_df["available"].min())
    print(f"Minimum available per stratum: {min_available}")

    if args.samples_per_stratum:
        n_per_stratum = args.samples_per_stratum
        if n_per_stratum > min_available:
            print(f"WARNING: Requested {n_per_stratum} but only {min_available} available. Using {min_available}.")
            n_per_stratum = min_available
    else:
        n_per_stratum = min_available
        print(f"Using all available: {n_per_stratum} per stratum")

    print(f"\nFinal sample size per stratum: {n_per_stratum}")
    print(f"Total dataset size: {n_per_stratum * 6}")
    print()

    # Stratified sampling
    np.random.seed(args.seed)
    sampled_records = []

    for tb_val in [0, 1]:
        for quality in valid_qualities:
            subset = df[(df["has_tb"] == tb_val) & (df["quality"] == quality)]
            if len(subset) < n_per_stratum:
                if args.allow_undersample:
                    sampled = subset.sample(n=n_per_stratum, replace=True, random_state=args.seed)
                else:
                    sampled = subset
                    print(f"  WARNING: Only {len(subset)} samples for ({tb_val}, {quality}), using all")
            else:
                sampled = subset.sample(n=n_per_stratum, replace=False, random_state=args.seed)

            sampled_records.append(sampled)

    balanced_df = pd.concat(sampled_records, ignore_index=True)
    balanced_df = balanced_df.sample(frac=1, random_state=args.seed).reset_index(drop=True)

    print("Balanced distribution after sampling:")
    print(pd.crosstab(balanced_df["has_tb"], balanced_df["quality"], margins=True))
    print()

    # Create train/val/test splits WITHIN each stratum
    train_records = []
    val_records = []
    test_records = []

    total_ratio = args.train_ratio + args.val_ratio + args.test_ratio
    train_frac = args.train_ratio / total_ratio
    val_frac = args.val_ratio / total_ratio

    for tb_val in [0, 1]:
        for quality in valid_qualities:
            subset = balanced_df[(balanced_df["has_tb"] == tb_val) & (balanced_df["quality"] == quality)]
            n = len(subset)

            n_train = int(n * train_frac)
            n_val = int(n * val_frac)
            n_test = n - n_train - n_val

            subset = subset.sample(frac=1, random_state=args.seed).reset_index(drop=True)

            train_records.append(subset.iloc[:n_train])
            val_records.append(subset.iloc[n_train:n_train + n_val])
            test_records.append(subset.iloc[n_train + n_val:])

    train_df = pd.concat(train_records, ignore_index=True)
    val_df = pd.concat(val_records, ignore_index=True)
    test_df = pd.concat(test_records, ignore_index=True)

    train_df["split"] = "train"
    val_df["split"] = "val"
    test_df["split"] = "test"

    final_df = pd.concat([train_df, val_df, test_df], ignore_index=True)

    print("=" * 70)
    print("FINAL SPLIT DISTRIBUTION")
    print("=" * 70)
    print(f"Train: {len(train_df)} | Val: {len(val_df)} | Test: {len(test_df)}")
    print()
    print("Train distribution:")
    print(pd.crosstab(train_df["has_tb"], train_df["quality"], margins=True))
    print()
    print("Val distribution:")
    print(pd.crosstab(val_df["has_tb"], val_df["quality"], margins=True))
    print()
    print("Test distribution:")
    print(pd.crosstab(test_df["has_tb"], test_df["quality"], margins=True))
    print()

    # Save outputs
    output_dir = pathlib.Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    final_df.to_csv(output_dir / "balanced_manifest.csv", index=False)
    train_df.to_csv(output_dir / "train.csv", index=False)
    val_df.to_csv(output_dir / "val.csv", index=False)
    test_df.to_csv(output_dir / "test.csv", index=False)

    # Build metadata with Python-native types
    stratum_dist = {}
    for tb in [0, 1]:
        for q in valid_qualities:
            mask = (final_df["has_tb"] == tb) & (final_df["quality"] == q)
            count = int(mask.sum())
            stratum_dist[f"tb={tb}_quality={q}"] = count

    metadata = {
        "seed": int(args.seed),
        "samples_per_stratum": int(n_per_stratum),
        "total_samples": int(len(final_df)),
        "train_size": int(len(train_df)),
        "val_size": int(len(val_df)),
        "test_size": int(len(test_df)),
        "stratum_distribution": stratum_dist,
    }

    with open(output_dir / "split_metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)

    print("=" * 70)
    print("FILES SAVED")
    print("=" * 70)
    print(f"  {output_dir}/balanced_manifest.csv")
    print(f"  {output_dir}/train.csv")
    print(f"  {output_dir}/val.csv")
    print(f"  {output_dir}/test.csv")
    print(f"  {output_dir}/split_metadata.json")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Prepare stratified classification dataset")
    parser.add_argument("--manifest", type=pathlib.Path, required=True)
    parser.add_argument("--output-dir", type=pathlib.Path, default="classification-pipeline/data")
    parser.add_argument("--train-ratio", type=float, default=0.70)
    parser.add_argument("--val-ratio", type=float, default=0.15)
    parser.add_argument("--test-ratio", type=float, default=0.15)
    parser.add_argument("--samples-per-stratum", type=int, default=None)
    parser.add_argument("--allow-undersample", action="store_true")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args(argv)
    prepare_data(args)


if __name__ == "__main__":
    main()
