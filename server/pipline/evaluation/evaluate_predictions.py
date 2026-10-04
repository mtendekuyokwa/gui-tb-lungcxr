import argparse
import pathlib
import sys
import pandas as pd
import numpy as np
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    confusion_matrix, roc_auc_score
)
import json


def evaluate(args):
    # --- Load & validate -------------------------------------------------
    df = pd.read_csv(str(args.predictions))
    required = {"tb_probability", "predicted_label", "true_label", "category"}
    missing = required - set(df.columns)
    if missing:
        print(f"ERROR: Missing columns in predictions CSV: {missing}", file=sys.stderr)
        sys.exit(1)

    print(f"Loaded predictions: {len(df)} samples\n")

    all_probs = df["tb_probability"].values
    all_preds = df["predicted_label"].values
    all_labels = df["true_label"].values
    all_qualities = df["category"].values

    # --- Overall metrics --------------------------------------------------
    overall_acc = accuracy_score(all_labels, all_preds)
    overall_f1 = f1_score(all_labels, all_preds, pos_label=1, zero_division=0)
    overall_auc = (
        roc_auc_score(all_labels, all_probs)
        if len(np.unique(all_labels)) > 1 else float("nan")
    )

    print("=" * 70)
    print(f"OVERALL RESULTS (n={len(all_labels)})")
    print("=" * 70)
    print(f"Accuracy:     {overall_acc:.4f}")
    print(f"F1 (TB):      {overall_f1:.4f}")
    print(f"AUC:          {overall_auc:.4f}")
    print()

    # --- Per-category metrics ----------------------------------------------
    print("=" * 70)
    print("PER-category RESULTS")
    print("=" * 70)

    results = {
        "overall": {
            "n": int(len(all_labels)),
            "accuracy": float(overall_acc),
            "f1_tb": float(overall_f1),
            "auc": float(overall_auc),
        },
        "per_quality": {},
    }

    for quality in ["excellent", "good", "bad"]:
        mask = all_qualities == quality
        n = int(mask.sum())
        if n == 0:
            continue

        q_probs = all_probs[mask]
        q_preds = all_preds[mask]
        q_labels = all_labels[mask]

        acc = accuracy_score(q_labels, q_preds)
        # Use binary metrics (positive class = TB) instead of weighted
        prec = precision_score(q_labels, q_preds, pos_label=1, zero_division=0)
        rec = recall_score(q_labels, q_preds, pos_label=1, zero_division=0)
        f1 = f1_score(q_labels, q_preds, pos_label=1, zero_division=0)
        cm = confusion_matrix(q_labels, q_preds, labels=[0, 1])

        try:
            auc = roc_auc_score(q_labels, q_probs) if len(np.unique(q_labels)) > 1 else float("nan")
        except Exception:
            auc = float("nan")

        # Sensitivity & Specificity from CM (rows=true, cols=pred)
        tn, fp, fn, tp = cm.ravel()
        sensitivity = tp / (tp + fn) if (tp + fn) > 0 else float("nan")
        specificity = tn / (tn + fp) if (tn + fp) > 0 else float("nan")

        results["per_quality"][quality] = {
            "n": n,
            "accuracy": float(acc),
            "precision": float(prec),
            "recall_sensitivity": float(rec),
            "f1": float(f1),
            "auc": float(auc),
            "specificity": float(specificity),
            "confusion_matrix": cm.tolist(),
        }

        print(f"\n{quality.upper()} (n={n}):")
        print(f"  Accuracy:     {acc:.4f}")
        print(f"  Precision:    {prec:.4f}")
        print(f"  Sensitivity:  {sensitivity:.4f}")
        print(f"  Specificity:  {specificity:.4f}")
        print(f"  F1 (TB):      {f1:.4f}")
        print(f"  AUC:          {auc:.4f}")
        print(f"  CM [[TN FP]   {cm.tolist()}")
        print(f"      [FN TP]]")

    # --- Per-quality per-class breakdown ----------------------------------
    print("\n" + "=" * 70)
    print("PER-QUALITY PER-CLASS BREAKDOWN")
    print("=" * 70)

    for quality in ["excellent", "good", "bad"]:
        q_mask = all_qualities == quality
        if q_mask.sum() == 0:
            continue

        print(f"\n{quality.upper()}:")
        for cls, cls_name in [(0, "Normal"), (1, "TB")]:
            c_mask = (all_labels == cls) & q_mask
            if c_mask.sum() == 0:
                continue
            c_preds = all_preds[c_mask]
            c_labels = all_labels[c_mask]
            c_acc = accuracy_score(c_labels, c_preds)
            print(f"  {cls_name}: n={c_mask.sum()}, accuracy={c_acc:.4f}")

    # --- Save outputs -----------------------------------------------------
    output_dir = pathlib.Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    with open(output_dir / "evaluation_results.json", "w") as f:
        json.dump(results, f, indent=2)

    df["correct"] = df["true_label"] == df["predicted_label"]
    df.to_csv(output_dir / "predictions_with_metrics.csv", index=False)

    print(f"\nSaved to {output_dir}")
    print(f"  evaluation_results.json")
    print(f"  predictions_with_metrics.csv")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Evaluate predictions by quality tier")
    parser.add_argument(
        "--predictions", type=pathlib.Path, required=True,
        help="Path to predictions.csv from run_inference.py"
    )
    parser.add_argument(
        "--output-dir", type=pathlib.Path, default="classification-pipeline/evaluation"
    )
    args = parser.parse_args(argv)
    evaluate(args)


if __name__ == "__main__":
    main()
