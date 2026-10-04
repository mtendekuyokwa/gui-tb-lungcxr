#!/bin/bash
#SBATCH --job-name=PREDICT-BACTERIAL
#SBATCH --output=predict-bacterial-result_%j.out
#SBATCH --error=predict-bacterial-result_%j.err
#SBATCH -p cpu-nodes
#SBATCH -N 1
#SBATCH -n 4
#SBATCH --mem=10G
#SBATCH --time=1:00:00
#SBATCH --gres=gpu:1
#SBATCH --mail-type=ALL
#SBATCH --mail-user=mkuyokwa@mlw.mw

set -euo pipefail
module purge
module load Python/3.12.3-GCCcore-13.3.0
source venv/bin/activate

python3 << 'PYEOF'
import pathlib
import csv
import torch
import torch.nn as nn
import numpy as np
from PIL import Image
from monai.transforms import (
    Compose, LoadImaged, EnsureChannelFirstd, Resized,
    ScaleIntensityd, NormalizeIntensityd,
)
from pytorch_grad_cam import GradCAM
from pytorch_grad_cam.utils.image import show_cam_on_image


def _build_model(num_classes=2):
    model = torch.hub.load("pytorch/vision:v0.19.0", "resnet18", weights=None)
    in_features = model.fc.in_features
    model.fc = nn.Sequential(nn.Dropout(0.3), nn.Linear(in_features, num_classes))
    return model


def preprocess(image_path, img_size):
    transforms = Compose([
        LoadImaged(keys=["img"]),
        EnsureChannelFirstd(keys=["img"]),
        Resized(keys=["img"], spatial_size=img_size, mode="bilinear"),
        ScaleIntensityd(keys=["img"]),
        NormalizeIntensityd(
            keys=["img"], subtrahend=[0.485, 0.456, 0.406],
            divisor=[0.229, 0.224, 0.225], channel_wise=True,
        ),
    ])
    return transforms({"img": str(image_path)})["img"]


def load_rgb_for_overlay(image_path, img_size):
    img = Image.open(image_path).convert("RGB").resize((img_size[1], img_size[0]))
    return np.array(img).astype(np.float32) / 255.0


classes = ["Normal", "Tuberculosis"]
img_size = [512, 512]

input_dir = pathlib.Path("../negative-testing/NORMAL")
image_files = sorted(list(input_dir.glob("*.png")) + list(input_dir.glob("*.jpg")) + list(input_dir.glob("*.jpeg")))

if not image_files:
    print(f"No images found in {input_dir}/ — add PNG/JPG files and resubmit.")
    raise SystemExit(0)

print(f"Found {len(image_files)} bacterial-infection images to test")

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")

results = {}
for model_name, model_path, out_subdir in [
    ("raw", "results/classification/tb_classifier.pt", "results/gradcam_bacterial_raw"),
    ("segmented", "results/classification/tb_classifier_segmented.pt", "results/gradcam_bacterial_segmented"),
]:
    model_path = pathlib.Path(model_path)
    if not model_path.exists():
        print(f"Skipping {model_name} model — {model_path} not found")
        continue

    output_dir = pathlib.Path(out_subdir)
    output_dir.mkdir(parents=True, exist_ok=True)

    model = _build_model(num_classes=2)
    model.load_state_dict(torch.load(model_path, map_location=device))
    model.to(device)
    model.eval()

    target_layers = [model.layer4[-1]]
    cam = GradCAM(model=model, target_layers=target_layers)

    rows = []
    tb_flagged = 0
    for img_path in image_files:
        input_tensor = preprocess(img_path, img_size).unsqueeze(0).to(device)

        with torch.no_grad():
            outputs = model(input_tensor)
            probs = torch.softmax(outputs, dim=1)
            pred_class = probs.argmax(dim=1).item()
            confidence = probs[0, pred_class].item()

        if classes[pred_class] == "Tuberculosis":
            tb_flagged += 1

        grayscale_cam = cam(input_tensor=input_tensor)[0]
        rgb_img = load_rgb_for_overlay(img_path, img_size)
        overlay = show_cam_on_image(rgb_img, grayscale_cam, use_rgb=True)
        overlay_path = output_dir / f"{img_path.stem}_gradcam.png"
        Image.fromarray(overlay).save(overlay_path)

        rows.append({
            "image": img_path.name,
            "predicted": classes[pred_class],
            "confidence": f"{confidence:.4f}",
            "gradcam_path": str(overlay_path),
        })

    with open(output_dir / "summary.csv", "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    false_positive_rate = tb_flagged / len(image_files)
    print(f"\n[{model_name.upper()} model] Flagged as Tuberculosis: {tb_flagged}/{len(image_files)} ({false_positive_rate:.2%})")
    print(f"[{model_name.upper()} model] Summary saved to {output_dir}/summary.csv")
    results[model_name] = false_positive_rate

print("\n=== Summary ===")
for name, fpr in results.items():
    print(f"{name}: {fpr:.2%} of bacterial-infection images incorrectly flagged as Tuberculosis")
PYEOF
