#!/usr/bin/env python3
"""
Train ResNet18 classifier on masked CXR images with augmentation.

Usage:
    python train_classifier.py \
        --train-csv classification-pipeline/data_balanced/train.csv \
        --val-csv classification-pipeline/data_balanced/val.csv \
        --output-dir classification-pipeline/training \
        --epochs 50 --batch-size 64 --lr 1e-4
"""

import argparse
import pathlib
import pandas as pd
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms, models
from PIL import Image
import SimpleITK as sitk
import json


class MaskedCXRDataset(Dataset):
    def __init__(self, df, mode="segmented", transform=None, augment=False):
        self.df = df.reset_index(drop=True)
        self.mode = mode
        self.transform = transform
        self.augment = augment

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

        return img_tensor, label


def get_model(num_classes=2):
    # Use weights parameter instead of deprecated pretrained
    try:
        from torchvision.models import ResNet18_Weights
        model = models.resnet18(weights=ResNet18_Weights.IMAGENET1K_V1)
    except ImportError:
        model = models.resnet18(pretrained=True)

    model.fc = nn.Sequential(
        nn.Dropout(0.3),
        nn.Linear(model.fc.in_features, num_classes)
    )
    return model


def train(args):
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Training on: {device}")

    train_df = pd.read_csv(str(args.train_csv))
    val_df = pd.read_csv(str(args.val_csv))

    print(f"Train: {len(train_df)} | Val: {len(val_df)}")
    print(f"Train class distribution: {train_df['has_tb'].value_counts().to_dict()}")
    print(f"Val class distribution: {val_df['has_tb'].value_counts().to_dict()}")

    # Augmentation for training
    train_transform = transforms.Compose([
        transforms.RandomRotation(degrees=15),
        transforms.RandomHorizontalFlip(p=0.5),
        transforms.RandomResizedCrop(size=512, scale=(0.85, 1.0)),
        transforms.ColorJitter(brightness=0.1, contrast=0.1),
        transforms.Normalize(mean=[0.5]*3, std=[0.5]*3),
    ])

    # No augmentation for validation
    val_transform = transforms.Compose([
        transforms.Normalize(mean=[0.5]*3, std=[0.5]*3),
    ])

    train_ds = MaskedCXRDataset(train_df, mode=args.mode, transform=train_transform, augment=True)
    val_ds = MaskedCXRDataset(val_df, mode=args.mode, transform=val_transform)

    # Use 1 worker to avoid DataLoader warning on HPC
    num_workers = 1
    train_loader = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True, num_workers=num_workers, pin_memory=True)
    val_loader = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False, num_workers=num_workers, pin_memory=True)

    model = get_model().to(device)

    # Class weights for imbalance (if any)
    class_counts = train_df["has_tb"].value_counts().sort_index().values
    class_weights = torch.tensor([1.0 / c for c in class_counts], dtype=torch.float32).to(device)
    class_weights = class_weights / class_weights.sum() * len(class_weights)

    criterion = nn.CrossEntropyLoss(weight=class_weights)
    optimizer = optim.Adam(model.parameters(), lr=args.lr)

    # Fix: Remove verbose=True for older PyTorch compatibility
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode="min", patience=5, factor=0.5)

    output_dir = pathlib.Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    best_val_acc = 0.0
    history = {"train_loss": [], "train_acc": [], "val_loss": [], "val_acc": []}

    for epoch in range(args.epochs):
        # Training
        model.train()
        train_loss = 0.0
        train_correct = 0
        train_total = 0

        for images, labels in train_loader:
            images, labels = images.to(device), labels.to(device)
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            train_loss += loss.item() * images.size(0)
            _, predicted = torch.max(outputs, 1)
            train_correct += (predicted == labels).sum().item()
            train_total += labels.size(0)

        train_loss /= train_total
        train_acc = train_correct / train_total

        # Validation
        model.eval()
        val_loss = 0.0
        val_correct = 0
        val_total = 0

        with torch.no_grad():
            for images, labels in val_loader:
                images, labels = images.to(device), labels.to(device)
                outputs = model(images)
                loss = criterion(outputs, labels)
                val_loss += loss.item() * images.size(0)
                _, predicted = torch.max(outputs, 1)
                val_correct += (predicted == labels).sum().item()
                val_total += labels.size(0)

        val_loss /= val_total
        val_acc = val_correct / val_total
        scheduler.step(val_loss)

        history["train_loss"].append(train_loss)
        history["train_acc"].append(train_acc)
        history["val_loss"].append(val_loss)
        history["val_acc"].append(val_acc)

        # Print LR change manually since verbose is removed
        current_lr = optimizer.param_groups[0]["lr"]
        print(f"Epoch {epoch+1}/{args.epochs}: "
              f"Train Loss={train_loss:.4f} Acc={train_acc:.4f} | "
              f"Val Loss={val_loss:.4f} Acc={val_acc:.4f} | LR={current_lr:.6f}")

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            torch.save({
                "epoch": epoch,
                "model_state_dict": model.state_dict(),
                "optimizer_state_dict": optimizer.state_dict(),
                "val_acc": val_acc,
            }, output_dir / "best_model.pth")
            print(f"  -> Saved best model (val_acc={val_acc:.4f})")

    # Save final model and history
    torch.save(model.state_dict(), output_dir / "final_model.pth")

    with open(output_dir / "training_history.json", "w") as f:
        json.dump(history, f, indent=2)

    print(f"\nTraining complete. Best val accuracy: {best_val_acc:.4f}")
    print(f"Models saved to: {output_dir}")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Train TB/Normal classifier")
    parser.add_argument("--train-csv", type=pathlib.Path, required=True)
    parser.add_argument("--val-csv", type=pathlib.Path, required=True)
    parser.add_argument("--mode", choices=["segmented", "raw"], default="segmented")
    parser.add_argument("--epochs", type=int, default=50)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--lr", type=float, default=1e-4)
    parser.add_argument("--output-dir", type=pathlib.Path, default="classification-pipeline/training")
    args = parser.parse_args(argv)
    train(args)


if __name__ == "__main__":
    main()
