#!/bin/bash
#SBATCH --job-name=TEST-UNSEEN-TB-SEG
#SBATCH --output=test-unseen-seg-result_%j.out
#SBATCH --error=test-unseen-seg-result_%j.err
#SBATCH -p gpu-nodes
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

echo "=== Step 1: Create masked versions of the same 100 held-out images ==="
python3 << 'PYEOF'
import pandas as pd
import pathlib
import numpy as np
import SimpleITK as sitk
from PIL import Image

def mask_and_save(cxr_path, seg_path, out_path):
    if str(cxr_path).endswith('.dcm'):
        img_sitk = sitk.ReadImage(str(cxr_path))
        img_arr = sitk.GetArrayFromImage(img_sitk).squeeze().astype(np.float32)
        img_arr = img_arr - img_arr.min()
        if img_arr.max() > 0:
            img_arr = img_arr / img_arr.max()
        img_arr = (img_arr * 255).astype(np.uint8)
    else:
        img_arr = np.array(Image.open(cxr_path).convert('L'))

    mask_sitk = sitk.ReadImage(str(seg_path))
    mask_arr = sitk.GetArrayFromImage(mask_sitk).squeeze()

    if mask_arr.shape != img_arr.shape:
        mask_img = Image.fromarray((mask_arr > 0).astype(np.uint8) * 255).resize(
            (img_arr.shape[1], img_arr.shape[0]), Image.NEAREST
        )
        mask_arr = np.array(mask_img) > 0
    else:
        mask_arr = mask_arr > 0

    masked = img_arr.copy()
    masked[~mask_arr] = 0
    Image.fromarray(masked).convert('RGB').save(out_path)


unused_df = pd.read_csv('tb_positive_unused.csv')
sample = unused_df.sample(n=100, random_state=7)  # SAME sample as raw test set

dest = pathlib.Path('test_images_unseen_segmented')
dest.mkdir(parents=True, exist_ok=True)

converted, failed = 0, 0
for i, row in enumerate(sample.itertuples()):
    cxr_path = pathlib.Path(row.cxr_file)
    seg_path = pathlib.Path(row.pred_seg_file)
    out_path = dest / f"tb_unseen_{i:04d}.png"
    if out_path.exists():
        continue
    try:
        mask_and_save(cxr_path, seg_path, out_path)
        converted += 1
    except Exception as e:
        print(f"Failed: {cxr_path} — {e}")
        failed += 1
print(f"Masked {converted} held-out TB images, {failed} failed")
PYEOF

echo ""
echo "=== Step 2: Run predictions + Grad-CAM using SEGMENTED model ==="
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
model_path = "results/classification/tb_classifier_segmented.pt"
input_dir = pathlib.Path("test_images_unseen_segmented")
output_dir = pathlib.Path("results/gradcam_unseen_segmented")
output_dir.mkdir(parents=True, exist_ok=True)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")

model = _build_model(num_classes=2)
model.load_state_dict(torch.load(model_path, map_location=device))
model.to(device)
model.eval()

target_layers = [model.layer4[-1]]
cam = GradCAM(model=model, target_layers=target_layers)

results = []
image_files = sorted(input_dir.glob("*.png"))
print(f"Running predictions on {len(image_files)} held-out (segmented) TB-positive images...")

correct = 0
for img_path in image_files:
    input_tensor = preprocess(img_path, img_size).unsqueeze(0).to(device)

    with torch.no_grad():
        outputs = model(input_tensor)
        probs = torch.softmax(outputs, dim=1)
        pred_class = probs.argmax(dim=1).item()
        confidence = probs[0, pred_class].item()

    is_correct = (classes[pred_class] == "Tuberculosis")
    if is_correct:
        correct += 1

    grayscale_cam = cam(input_tensor=input_tensor)[0]
    rgb_img = load_rgb_for_overlay(img_path, img_size)
    overlay = show_cam_on_image(rgb_img, grayscale_cam, use_rgb=True)
    overlay_path = output_dir / f"{img_path.stem}_gradcam.png"
    Image.fromarray(overlay).save(overlay_path)

    results.append({
        "image": img_path.name,
        "true_label": "Tuberculosis",
        "predicted": classes[pred_class],
        "confidence": f"{confidence:.4f}",
        "correct": is_correct,
        "gradcam_path": str(overlay_path),
    })

with open("results/gradcam_unseen_segmented/summary.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=results[0].keys())
    writer.writeheader()
    writer.writerows(results)

accuracy = correct / len(image_files) if image_files else 0
print(f"\nAccuracy (segmented model) on held-out TB-positive set: {correct}/{len(image_files)} ({accuracy:.2%})")
print("Summary saved to results/gradcam_unseen_segmented/summary.csv")
PYEOF
