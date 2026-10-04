#!/usr/bin/env python3
"""
Build master classification manifest CSV from evaluation results.

This script creates a single source-of-truth CSV containing:
- Original CXR image paths
- Predicted mask paths  
- Reference (ground truth) mask paths
- Evaluation metrics (Dice, Hausdorff, etc.)
- Quality categorization (excellent / good / bad)
- TB label (has_tb: 0=normal, 1=tb)

Usage:
    python build_master_manifest.py \
        --normal-eval normal-results/evaluation/normal_full/overlap_results.csv \
        --normal-eval-surface normal-results/evaluation/normal_full/surface_distance_results.csv \
        --tb-eval tb-inference-results/evaluation/tb_full/overlap_results.csv \
        --tb-eval-surface tb-inference-results/evaluation/tb_full/surface_distance_results.csv \
        --normal-cxr-dir normal_dataset/img \
        --normal-pred-dir normal-results/segments/normal_full \
        --normal-ref-dir normal-results/segments/normal_ref_fixed \
        --tb-cxr-dir TB_Positive \
        --tb-pred-dir tb-inference-results/segments/tb_full \
        --tb-ref-dir TB_annotations \
        --output classification/all_files_manifest.csv
"""

import pandas as pd
import numpy as np
import argparse
import pathlib
from collections import defaultdict


def categorize_quality(dice, hausdorff, mean_surface,
                       dice_excellent=0.93, hd_excellent=50, ms_excellent=8,
                       dice_good=0.80, hd_good=200, ms_good=25):
    """
    Three-tier quality categorization.

    EXCELLENT: high dice AND low hausdorff AND low mean surface
    GOOD:      moderate dice AND moderate hausdorff AND moderate mean surface  
    BAD:       low dice OR very high hausdorff OR very high mean surface
    """
    if pd.isna(dice) or pd.isna(hausdorff) or pd.isna(mean_surface):
        return "bad"

    # Excellent: ALL three metrics must be excellent
    if dice >= dice_excellent and hausdorff <= hd_excellent and mean_surface <= ms_excellent:
        return "excellent"
    # Bad: ANY metric is bad
    elif dice < dice_good or hausdorff > hd_good or mean_surface > ms_good:
        return "bad"
    # Good: everything else
    else:
        return "good"


def resolve_cxr_path(mask_path, cxr_dir, dataset_type="normal"):
    """
    Infer CXR image path from mask/evaluation path.
    Customize this based on your actual naming conventions.
    """
    mask_name = pathlib.Path(mask_path).stem
    cxr_dir = pathlib.Path(cxr_dir)

    # Try common naming patterns
    # Pattern 1: mask_001.nrrd -> 001.png
    # Pattern 2: pred_001.nrrd -> 001.png
    # Pattern 3: same basename, different extension

    candidates = []

    # Strip common prefixes
    base_name = mask_name
    for prefix in ["mask_", "pred_", "segment_", "seg_"]:
        if base_name.startswith(prefix):
            base_name = base_name[len(prefix):]

    # Try various extensions
    for ext in [".png", ".jpg", ".jpeg", ".dcm"]:
        candidates.append(cxr_dir / (base_name + ext))
        # Also try with the full mask name
        candidates.append(cxr_dir / (mask_name + ext))

    # For DICOM TB data, the structure might be different
    if dataset_type == "tb":
        # TB DICOMs might be in nested folders
        # Try to find by patient ID or study ID
        pass

    for cand in candidates:
        if cand.exists():
            return str(cand)

    # Return best guess even if not found (will flag later)
    return str(cxr_dir / (base_name + ".png"))


def resolve_pred_mask_path(eval_row, pred_dir):
    """Resolve predicted mask path from evaluation CSV row."""
    pred_dir = pathlib.Path(pred_dir)

    # Try the pred_seg_file column directly
    if "pred_seg_file" in eval_row and pd.notna(eval_row["pred_seg_file"]):
        p = pathlib.Path(eval_row["pred_seg_file"])
        if p.exists():
            return str(p)
        # Try relative to pred_dir
        alt = pred_dir / p.name
        if alt.exists():
            return str(alt)

    # Try ref_seg_file with common replacements
    if "ref_seg_file" in eval_row and pd.notna(eval_row["ref_seg_file"]):
        ref_name = pathlib.Path(eval_row["ref_seg_file"]).stem
        for prefix in ["", "pred_", "mask_"]:
            for ext in [".nrrd", ".nii.gz", ".nii"]:
                cand = pred_dir / (prefix + ref_name + ext)
                if cand.exists():
                    return str(cand)

    return None


def resolve_ref_mask_path(eval_row, ref_dir):
    """Resolve reference mask path from evaluation CSV row."""
    ref_dir = pathlib.Path(ref_dir)

    if "ref_seg_file" in eval_row and pd.notna(eval_row["ref_seg_file"]):
        p = pathlib.Path(eval_row["ref_seg_file"])
        if p.exists():
            return str(p)
        alt = ref_dir / p.name
        if alt.exists():
            return str(alt)

    return None


def build_manifest(args):
    records = []

    # Process Normal dataset
    if args.normal_eval:
        print("Processing Normal dataset...")
        normal_overlap = pd.read_csv(str(args.normal_eval))
        normal_surface = pd.read_csv(str(args.normal_eval_surface)) if args.normal_eval_surface else None

        if normal_surface is not None:
            # Merge overlap and surface metrics
            normal_df = pd.merge(
                normal_overlap, normal_surface,
                on=["ref_seg_file", "pred_seg_file"],
                how="outer"
            )
        else:
            normal_df = normal_overlap

        for idx, row in normal_df.iterrows():
            pred_mask = resolve_pred_mask_path(row, args.normal_pred_dir)
            ref_mask = resolve_ref_mask_path(row, args.normal_ref_dir)
            cxr = resolve_cxr_path(row.get("pred_seg_file", row.get("ref_seg_file", "")), 
                                   args.normal_cxr_dir, "normal")

            dice = row.get("dice", np.nan)
            hausdorff = row.get("hausdorff_distance", np.nan)
            mean_surface = row.get("mean_surface_distance", np.nan)
            volume_sim = row.get("volume_similarity", np.nan)
            fn = row.get("false_negative", np.nan)
            fp = row.get("false_positive", np.nan)
            jaccard = row.get("jaccard", np.nan)

            quality = categorize_quality(dice, hausdorff, mean_surface,
                                         args.dice_excellent, args.hd_excellent, args.ms_excellent,
                                         args.dice_good, args.hd_good, args.ms_good)

            records.append({
                "cxr_file": cxr,
                "pred_mask_file": pred_mask,
                "ref_mask_file": ref_mask,
                "dataset": "normal",
                "has_tb": 0,
                "dice": dice,
                "jaccard": jaccard,
                "hausdorff": hausdorff,
                "mean_surface_distance": mean_surface,
                "volume_similarity": volume_sim,
                "false_negative": fn,
                "false_positive": fp,
                "quality": quality,
            })

        print(f"  Added {len(normal_df)} normal cases")

    # Process TB dataset
    if args.tb_eval:
        print("Processing TB dataset...")
        tb_overlap = pd.read_csv(str(args.tb_eval))
        tb_surface = pd.read_csv(str(args.tb_eval_surface)) if args.tb_eval_surface else None

        if tb_surface is not None:
            tb_df = pd.merge(
                tb_overlap, tb_surface,
                on=["ref_seg_file", "pred_seg_file"],
                how="outer"
            )
        else:
            tb_df = tb_overlap

        for idx, row in tb_df.iterrows():
            pred_mask = resolve_pred_mask_path(row, args.tb_pred_dir)
            ref_mask = resolve_ref_mask_path(row, args.tb_ref_dir)
            cxr = resolve_cxr_path(row.get("pred_seg_file", row.get("ref_seg_file", "")),
                                   args.tb_cxr_dir, "tb")

            dice = row.get("dice", np.nan)
            hausdorff = row.get("hausdorff_distance", np.nan)
            mean_surface = row.get("mean_surface_distance", np.nan)
            volume_sim = row.get("volume_similarity", np.nan)
            fn = row.get("false_negative", np.nan)
            fp = row.get("false_positive", np.nan)
            jaccard = row.get("jaccard", np.nan)

            quality = categorize_quality(dice, hausdorff, mean_surface,
                                         args.dice_excellent, args.hd_excellent, args.ms_excellent,
                                         args.dice_good, args.hd_good, args.ms_good)

            records.append({
                "cxr_file": cxr,
                "pred_mask_file": pred_mask,
                "ref_mask_file": ref_mask,
                "dataset": "tb",
                "has_tb": 1,
                "dice": dice,
                "jaccard": jaccard,
                "hausdorff": hausdorff,
                "mean_surface_distance": mean_surface,
                "volume_similarity": volume_sim,
                "false_negative": fn,
                "false_positive": fp,
                "quality": quality,
            })

        print(f"  Added {len(tb_df)} TB cases")

    # Build DataFrame
    master_df = pd.DataFrame(records)

    # Summary
    print("\n" + "=" * 70)
    print("MASTER MANIFEST SUMMARY")
    print("=" * 70)
    print(f"Total records: {len(master_df)}")
    print(f"\nBy dataset:")
    print(master_df["dataset"].value_counts())
    print(f"\nBy quality:")
    print(master_df["quality"].value_counts())
    print(f"\nBy dataset × quality:")
    print(pd.crosstab(master_df["dataset"], master_df["quality"]))

    # Check for missing files
    missing_cxr = master_df[~master_df["cxr_file"].apply(lambda x: pathlib.Path(str(x)).exists() if pd.notna(x) and str(x) else False)]
    missing_pred = master_df[~master_df["pred_mask_file"].apply(lambda x: pathlib.Path(str(x)).exists() if pd.notna(x) and str(x) else False)]
    missing_ref = master_df[~master_df["ref_mask_file"].apply(lambda x: pathlib.Path(str(x)).exists() if pd.notna(x) and str(x) else False)]

    if len(missing_cxr) > 0:
        print(f"\nWARNING: {len(missing_cxr)} CXR files not found")
    if len(missing_pred) > 0:
        print(f"WARNING: {len(missing_pred)} predicted mask files not found")
    if len(missing_ref) > 0:
        print(f"WARNING: {len(missing_ref)} reference mask files not found")

    # Quality distribution stats
    print("\n" + "=" * 70)
    print("QUALITY DISTRIBUTION STATS")
    print("=" * 70)
    for quality in ["excellent", "good", "bad"]:
        subset = master_df[master_df["quality"] == quality]
        if len(subset) == 0:
            continue
        print(f"\n{quality.upper()} (n={len(subset)}):")
        print(f"  Dice: {subset['dice'].mean():.3f} ± {subset['dice'].std():.3f}")
        print(f"  Hausdorff: {subset['hausdorff'].mean():.1f} ± {subset['hausdorff'].std():.1f}")
        print(f"  Mean Surface: {subset['mean_surface_distance'].mean():.1f} ± {subset['mean_surface_distance'].std():.1f}")

    # Save
    output_path = pathlib.Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    master_df.to_csv(str(output_path), index=False)
    print(f"\nSaved master manifest to: {output_path}")

    return master_df


def main(argv=None):
    parser = argparse.ArgumentParser(description="Build master classification manifest")

    # Normal dataset inputs
    parser.add_argument("--normal-eval", type=pathlib.Path, default=None,
                        help="Normal overlap evaluation CSV")
    parser.add_argument("--normal-eval-surface", type=pathlib.Path, default=None,
                        help="Normal surface distance evaluation CSV")
    parser.add_argument("--normal-cxr-dir", type=pathlib.Path, default="normal_dataset/img",
                        help="Directory containing normal CXR images")
    parser.add_argument("--normal-pred-dir", type=pathlib.Path, default="normal-results/segments/normal_full",
                        help="Directory containing normal predicted masks")
    parser.add_argument("--normal-ref-dir", type=pathlib.Path, default="normal-results/segments/normal_ref_fixed",
                        help="Directory containing normal reference masks")

    # TB dataset inputs
    parser.add_argument("--tb-eval", type=pathlib.Path, default=None,
                        help="TB overlap evaluation CSV")
    parser.add_argument("--tb-eval-surface", type=pathlib.Path, default=None,
                        help="TB surface distance evaluation CSV")
    parser.add_argument("--tb-cxr-dir", type=pathlib.Path, default="TB_Positive",
                        help="Directory containing TB CXR images")
    parser.add_argument("--tb-pred-dir", type=pathlib.Path, default="tb-inference-results/segments/tb_full",
                        help="Directory containing TB predicted masks")
    parser.add_argument("--tb-ref-dir", type=pathlib.Path, default="TB_annotations",
                        help="Directory containing TB reference masks")

    # Quality thresholds
    parser.add_argument("--dice-excellent", type=float, default=0.93)
    parser.add_argument("--hd-excellent", type=float, default=50)
    parser.add_argument("--ms-excellent", type=float, default=8)
    parser.add_argument("--dice-good", type=float, default=0.80)
    parser.add_argument("--hd-good", type=float, default=200)
    parser.add_argument("--ms-good", type=float, default=25)

    # Output
    parser.add_argument("--output", type=pathlib.Path, default="classification/all_files_manifest.csv",
                        help="Output master manifest CSV path")

    args = parser.parse_args(argv)

    if not args.normal_eval and not args.tb_eval:
        parser.error("At least one of --normal-eval or --tb-eval must be provided")

    build_manifest(args)


if __name__ == "__main__":
    main()
