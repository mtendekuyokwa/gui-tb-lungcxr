#!/usr/bin/env python3
"""
Run inference on test set and save predictions to CSV.

Usage:
    python run_inference.py \
        --test-csv classification-pipeline/data_balanced/test.csv \
        --checkpoint classification-pipeline/training/best_model.pth \
        --output-dir classification-pipeline/inference \
        --mode segmented
"""

import argparse
import pathlib
import pandas as pd
import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms, models
from PIL import Image
import SimpleITK as sitk


class MaskedCXRDataset(Dataset):
    def __init__(self, df, mode="segmented", transform=None):
        self.df = df.reset_index(drop=True)
        self.mode = mode
        self.transform = transform

    def __len__(self):
        return len(self.df)

    def _load_image(self, path):
        img = Image.open(path).convert("L")
        img = img.resize((512, 512))
        arr = np.array(img, dtype=np.float32) / 255.0
        return arr

    def _load_mask(self, path):
        mask = sitk.ReadImage(path)
        marr = sitk.GetArrayFromImage(mask)
        if marr.ndim > 2:
            marr = marr[..., 0] if marr.shape[-1] > 1 else marr[0]
        marr = (marr > 0).astype(np.float32)
        mpil = Image.fromarray((marr * 255).astype(np.uint8))
        mpil = mpil.resize((512, 512))
        return np.array(mpil, dtype=np.float32) / 255.0

    def __getitem__(self, idx):
        row = self.df.iloc[idx]

        img_arr = self._load_image(row["cxr_file"])

        if self.mode == "segmented" and pd.notna(row.get("pred_mask_file")):
            try:
                mask_arr = self._load_mask(row["pred_mask_file"])
                img_arr = img_arr * mask_arr
            except Exception as e:
                print(f"Mask failed: {e}")

        img_rgb = np.stack([img_arr] * 3, axis=0)
        img_tensor = torch.from_numpy(img_rgb)

        if self.transform:
            img_tensor = self.transform(img_tensor)

        label = int(row["has_tb"])
        quality = row.get("quality", "unknown")

        return img_tensor, label, quality, row["cxr_file"]


def get_model(num_classes=2):
    model = models.resnet18(pretrained=False)
    model.fc = nn.Sequential(
        nn.Dropout(0.3),
        nn.Linear(model.fc.in_features, num_classes)
    )
    return model


def run_inference(args):
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Running inference on: {device}")

    test_df = pd.read_csv(str(args.test_csv))
    print(f"Test samples: {len(test_df)}")

    transform = transforms.Compose([
        transforms.Normalize(mean=[0.5]*3, std=[0.5]*3),
    ])

    dataset = MaskedCXRDataset(test_df, mode=args.mode, transform=transform)
    loader = DataLoader(dataset, batch_size=args.batch_size, shuffle=False, num_workers=4)

    model = get_model().to(device)
    checkpoint = torch.load(str(args.checkpoint), map_location=device)
    if "model_state_dict" in checkpoint:
        model.load_state_dict(checkpoint["model_state_dict"])
    else:
        model.load_state_dict(checkpoint)
    model.eval()

    all_probs = []
    all_preds = []
    all_labels = []
    all_qualities = []
    all_paths = []

    with torch.no_grad():
        for images, labels, qualities, paths in loader:
            images = images.to(device)
            outputs = model(images)
            probs = torch.softmax(outputs, dim=1)[:, 1]
            _, predicted = torch.max(outputs, 1)

            all_probs.extend(probs.cpu().numpy())
            all_preds.extend(predicted.cpu().numpy())
            all_labels.extend(labels.numpy())
            all_qualities.extend(qualities)
            all_paths.extend(paths)

    # Save predictions
    output_dir = pathlib.Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    predictions_df = pd.DataFrame({
        "cxr_file": all_paths,
        "true_label": all_labels,
        "predicted_label": all_preds,
        "tb_probability": all_probs,
        "category": all_qualities,
    })

    predictions_df.to_csv(output_dir / "predictions.csv", index=False)
    print(f"Predictions saved to: {output_dir}/predictions.csv")
    print(f"Total predictions: {len(predictions_df)}")

    return predictions_df


def main(argv=None):
    parser = argparse.ArgumentParser(description="Run inference on test set")
    parser.add_argument("--test-csv", type=pathlib.Path, required=True)
    parser.add_argument("--checkpoint", type=pathlib.Path, required=True)
    parser.add_argument("--mode", choices=["segmented", "raw"], default="segmented")
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--output-dir", type=pathlib.Path, default="classification-pipeline/inference")
    args = parser.parse_args(argv)
    run_inference(args)


if __name__ == "__main__":
    main()
