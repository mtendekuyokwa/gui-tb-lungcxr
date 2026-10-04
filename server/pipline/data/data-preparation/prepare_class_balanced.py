#!/usr/bin/env python3
"""
Class-balanced data preparation with natural quality distribution.

Ensures equal class representation (Normal vs TB) but lets quality
 distribute naturally within each class. Uses data augmentation during
training rather than duplicating rare strata.

Usage:
    python prepare_class_balanced.py \
        --manifest metadata/all_files_manifest.csv \
        --output-dir classification-pipeline/data_balanced \
        --target-per-class 3000 \
        --train-ratio 0.70 --val-ratio 0.15 --test-ratio 0.15 \
        --seed 42
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
    valid_qualities = ["excellent", "good", "bad"]
    df = df[df["quality"].isin(valid_qualities)]
    print(f"After cleaning: {len(df)} records")
    print()

    # Show natural distribution
    print("Natural quality distribution per class:")
    crosstab = pd.crosstab(df["has_tb"], df["quality"], margins=True)
    print(crosstab)
    print()

    # Sample target_per_class from each class (natural quality distribution)
    np.random.seed(args.seed)
    sampled_records = []

    for tb_val in [0, 1]:
        subset = df[df["has_tb"] == tb_val]
        label = "Normal" if tb_val == 0 else "TB"

        if len(subset) <= args.target_per_class:
            sampled = subset
            print(f"{label}: using all {len(subset)} available (less than target {args.target_per_class})")
        else:
            sampled = subset.sample(n=args.target_per_class, replace=False, random_state=args.seed)
            print(f"{label}: sampled {args.target_per_class} from {len(subset)} available")

        sampled_records.append(sampled)

    balanced_df = pd.concat(sampled_records, ignore_index=True)
    balanced_df = balanced_df.sample(frac=1, random_state=args.seed).reset_index(drop=True)

    print(f"\nTotal after class balancing: {len(balanced_df)}")
    print("Quality distribution in balanced dataset:")
    print(pd.crosstab(balanced_df["has_tb"], balanced_df["quality"], margins=True))
    print()

    # Stratified split: balance BOTH class and quality within each split
    train_records = []
    val_records = []
    test_records = []

    total_ratio = args.train_ratio + args.val_ratio + args.test_ratio
    train_frac = args.train_ratio / total_ratio
    val_frac = args.val_ratio / total_ratio

    for tb_val in [0, 1]:
        for quality in valid_qualities:
            subset = balanced_df[(balanced_df["has_tb"] == tb_val) & (balanced_df["quality"] == quality)]
            if len(subset) == 0:
                continue

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

    # Summary
    print("=" * 70)
    print("FINAL SPLIT DISTRIBUTION")
    print("=" * 70)
    print(f"Train: {len(train_df)} | Val: {len(val_df)} | Test: {len(test_df)}")
    print()

    for split_name, split_df in [("Train", train_df), ("Val", val_df), ("Test", test_df)]:
        print(f"{split_name} (n={len(split_df)}):")
        print(pd.crosstab(split_df["has_tb"], split_df["quality"], margins=True))
        print()

    # Save
    output_dir = pathlib.Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    final_df.to_csv(output_dir / "balanced_manifest.csv", index=False)
    train_df.to_csv(output_dir / "train.csv", index=False)
    val_df.to_csv(output_dir / "val.csv", index=False)
    test_df.to_csv(output_dir / "test.csv", index=False)

    # Metadata
    metadata = {
        "seed": int(args.seed),
        "target_per_class": int(args.target_per_class),
        "total_samples": int(len(final_df)),
        "train_size": int(len(train_df)),
        "val_size": int(len(val_df)),
        "test_size": int(len(test_df)),
        "normal_available": int(len(df[df["has_tb"] == 0])),
        "tb_available": int(len(df[df["has_tb"] == 1])),
        "quality_distribution": {
            "normal": {
                q: int(len(final_df[(final_df["has_tb"] == 0) & (final_df["quality"] == q)]))
                for q in valid_qualities
            },
            "tb": {
                q: int(len(final_df[(final_df["has_tb"] == 1) & (final_df["quality"] == q)]))
                for q in valid_qualities
            },
        },
    }

    with open(output_dir / "split_metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)

    print("=" * 70)
    print("FILES SAVED")
    print("=" * 70)
    for fname in ["balanced_manifest.csv", "train.csv", "val.csv", "test.csv", "split_metadata.json"]:
        print(f"  {output_dir}/{fname}")

    # Augmentation recommendation
    print()
    print("=" * 70)
    print("DATA AUGMENTATION RECOMMENDATION")
    print("=" * 70)
    print("""
Since Normal+Bad is small ({normal_bad} samples), use these transforms during training:

  transforms.Compose([
      transforms.RandomRotation(degrees=15),
      transforms.RandomHorizontalFlip(p=0.5),
      transforms.RandomResizedCrop(size=512, scale=(0.85, 1.0)),
      transforms.ColorJitter(brightness=0.1, contrast=0.1),
      transforms.Normalize(mean=[0.5]*3, std=[0.5]*3),
  ])

This gives ~5-10x effective sample expansion without duplicating exact images.
The quality label remains valid because the mask is applied BEFORE augmentation.
    """.format(
        normal_bad=int(len(df[(df["has_tb"] == 0) & (df["quality"] == "bad")]))
    ))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Class-balanced dataset preparation")
    parser.add_argument("--manifest", type=pathlib.Path, required=True)
    parser.add_argument("--output-dir", type=pathlib.Path, default="classification-pipeline/data_balanced")
    parser.add_argument("--target-per-class", type=int, default=3000,
                        help="Target samples per class (Normal and TB)")
    parser.add_argument("--train-ratio", type=float, default=0.70)
    parser.add_argument("--val-ratio", type=float, default=0.15)
    parser.add_argument("--test-ratio", type=float, default=0.15)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args(argv)
    prepare_data(args)


if __name__ == "__main__":
    main()
