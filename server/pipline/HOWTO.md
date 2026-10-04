# How to Add a New Dataset & Run the Full Pipeline

## Overview

This project supports two operations you can run on any CXR dataset:

1. **Segmentation** — generate lung masks (.nrrd) from any CXR image
2. **Classification** — train/evaluate a TB vs Normal classifier

You can add your own dataset and run either or both. Below are worked examples for every supported image format.

To quickly check what's already in the project, see [README.md](README.md#datasets).

---

## Table of Contents

- [1. Adding a New Dataset](#1-adding-a-new-dataset)
- [2. Workspace & Results](#2-workspace--results)
- [3. Segmentation Pipeline](#3-segmentation-pipeline-any-image-format)
- [4. Classification Pipeline](#4-classification-pipeline)
- [5. Full End-to-End Example](#5-full-end-to-end-example)
- [6. Common Issues](#6-common-issues)
- [7. Customizing for Your Use Case](#7-customizing-for-your-use-case)

---

## 1. Adding a New Dataset

### Directory structure

```
raw_data/
├── LS1/                   # Example 1: DICOM studies
│   └── dataset_config.yaml
├── LS2/                   # Example 2: PNG classification dataset
│   └── dataset_config.yaml
└── YOUR_DATASET/          # Your new dataset goes here
    └── dataset_config.yaml
```

Create `raw_data/YOUR_DATASET/dataset_config.yaml`:

```yaml
name: YOUR_DATASET
description: "Describe your dataset here"
image_format: "dcm"    # dcm, png, jpg, nii.gz, etc.
```

Also register it in `configs/datasets.yaml`:

```yaml
datasets:
  YOUR_DATASET:
    config: "raw_data/YOUR_DATASET/dataset_config.yaml"
    purpose: "segmentation_inference"   # or "segmentation_inference + classification_training"
```

---

## 2. Workspace & Results

Once processed, everything lives under:

```
results/segments/YOUR_DATASET/    ← .nrrd lung masks (one per input image)
results/evaluation/               ← metric CSVs
results/classification/           ← model weights + evaluation plots
```

These are ignored by git (`.gitignore` has `results/`).

---

## 3. Segmentation Pipeline (any image format)

### DICOM images (.dcm)

Images in a flat folder or nested study/series structure:

```bash
# Generate CSV listing all DICOM files
python -m segment_lung_cxr.data_preparation.prepare_ls1_csv /path/to/your/dicoms --output_csv /tmp/my_dicoms.csv

# Or manually point the existing helper at your folder:
python -m segment_lung_cxr.data_preparation.prepare_ls1_csv /path/to/your/dicoms
```

### PNG / JPEG images

```bash
python -c "
import pathlib, pandas as pd
files = sorted(pathlib.Path('/path/to/images').glob('*.png'))  # or *.jpg
df = pd.DataFrame({'cxr_file': [str(f) for f in files]})
df.to_csv('segment_lung_cxr/data/input_csv_files/MY_DATASET/all_files.csv', index=False)
print(f'Found {len(files)} images')
"
```

### NIfTI images (.nii.gz)

Same as PNG — just change the glob pattern to `*.nii.gz`.

### Mix of formats

The inference script reads via SimpleITK (with pydicom fallback), so it handles DICOM, NIfTI, NRRD, PNG, JPEG, BMP, MHA, and many more automatically. Just point the CSV at them.

### Run segmentation inference

```bash
python -m segment_lung_cxr.inference.inference_lung_segment \
    segment_lung_cxr/data/input_csv_files/MY_DATASET/all_files.csv \
    segment_lung_cxr/data/weights/cxr_lung_segment_including_heart_512.pt \
    --dataset MY_DATASET \
    --img_size 512 512 --patch_size 512 512 \
    --post_process True
```

| Argument | What it does |
|---|---|
| `--dataset MY_DATASET` | Sets output dir to `results/segments/MY_DATASET/` |
| `--img_size 512 512` | Resamples CXR to 512×512 before model inference |
| `--patch_size 512 512` | Sliding window patch size (use same as img_size for full-image) |
| `--post_process True` | Keeps 2 largest connected components (left + right lung), fills holes |
| `--threshold 0.5` | Binarization threshold (default 0.5, adjust if too aggressive) |

### Model weights available

| Weight file | Input size | Heart |
|---|---|---|
| `cxr_lung_segment_including_heart_512.pt` | 512×512 | Included |
| `cxr_lung_segment_including_heart_224.pt` | 224×224 | Included |
| `cxr_lung_segment_excluding_heart_224.pt` | 224×224 | Excluded |

### Ensemble inference (use both models)

```bash
python -m segment_lung_cxr.inference.ensemble_inference_lung_segment \
    segment_lung_cxr/data/input_csv_files/MY_DATASET/all_files.csv \
    segment_lung_cxr/data/weights/cxr_lung_segment_including_heart_224.pt \
    segment_lung_cxr/data/weights/cxr_lung_segment_including_heart_512.pt \
    --dataset MY_DATASET \
    --img_sizes 224 224 512 512 \
    --patch_sizes 224 224 512 512 \
    --post_process True
```

---

## 4. Classification Pipeline

Trains a binary classifier (ResNet18) on two classes of CXR images.

### Folder structure expected by the trainer

```
/path/to/data/
├── Normal/             ← class 0 (folder name configurable)
│   ├── image001.png
│   └── ...
└── Tuberculosis/       ← class 1 (folder name configurable)
    ├── image100.png
    └── ...
```

### Train a classifier

#### Default usage (LS2 — Normal / Tuberculosis, PNG files)

```bash
python -m classification.train \
    ~/Downloads/TB_Chest_Radiography_Database \
    results/classification/tb_classifier.pt
```

The defaults are `--classes Normal Tuberculosis --ext png`, so LS2 works without any extra flags.

#### Custom class folder names

If your data has folders called `Healthy` and `Sick`:

```bash
python -m classification.train \
    /path/to/data \
    results/classification/my_classifier.pt \
    --classes Healthy Sick
```

#### Custom file extension (e.g., JPEG, DICOM)

```bash
python -m classification.train \
    /path/to/data \
    results/classification/my_classifier.pt \
    --classes Normal Disease \
    --ext jpg
```

#### All options

```bash
python -m classification.train \
    /path/to/data \
    results/classification/model.pt \
    --classes Class0 Class1 \       # folder names (default: Normal Tuberculosis)
    --ext png                       # file extension (default: png)
    --img_size 512 512              # resize to 512×512 (default)
    --batch_size 32                 # batch size (default: 32)
    --epochs 100                    # training epochs (default: 100)
    --lr 0.001                      # learning rate (default: 0.001)
```

### Prepare labeled CSV for inference

Use this to create a CSV that `classification.inference` can read:

```python
import pathlib, pandas as pd

class0_dir = pathlib.Path("/path/to/Class0")
class1_dir = pathlib.Path("/path/to/Class1")

rows = []
for f in sorted(class0_dir.glob("*")):
    rows.append({"cxr_file": str(f), "ref_label": 0})
for f in sorted(class1_dir.glob("*")):
    rows.append({"cxr_file": str(f), "ref_label": 1})

df = pd.DataFrame(rows)
df.to_csv("segment_lung_cxr/data/input_csv_files/MY_DATASET/labeled.csv", index=False)
```

### Evaluate

```bash
python -m classification.evaluate \
    predictions.csv \
    results/classification/ \
    --label_col ref_label --pred_col pred_class --prob_col prob_tb
```

Output: `confusion_matrix.png`, `roc_curve.png`, `metrics.csv`.

---

## 5. Full End-to-End Example

Say you have a new dataset at `/data/my_cxrs/` with 500 DICOMs:

```bash
# ---- Setup ----
source venv/bin/activate
cd ~/flocki/lung_cxr_segmentation

# ---- Step 1: Register dataset ----
mkdir raw_data/my_cxrs
cat > raw_data/my_cxrs/dataset_config.yaml <<EOF
name: my_cxrs
description: "My custom CXR dataset"
image_format: "dcm"
EOF

# ---- Step 2: Generate CSV ----
python -m segment_lung_cxr.data_preparation.prepare_ls1_csv /data/my_cxrs

# ---- Step 3: Segment ----
python -m segment_lung_cxr.inference.inference_lung_segment \
    segment_lung_cxr/data/input_csv_files/my_cxrs/all_files.csv \
    segment_lung_cxr/data/weights/cxr_lung_segment_including_heart_512.pt \
    --dataset my_cxrs --img_size 512 512 --patch_size 512 512 --post_process True

# ---- Step 4: View masks ----
ls results/segments/my_cxrs/
```

---

## 6. Common Issues

| Problem | Fix |
|---|---|
| `No module named 'torch'` | Run `source venv/bin/activate` first |
| Model weights are 133 bytes | `git lfs pull` — you have the pointer, not the real file |
| DICOM not found | Check the CSV paths are absolute or relative to the CSV location |
| CUDA out of memory | Add `--batch_size 1` or use `--img_size 224 224 --patch_size 224 224` |
| `.nrrd` files are all zeros | Lower threshold with `--threshold 0.3` |
| PyTorch deprecation warnings | Safe to ignore — MONAI will update for PyTorch 2.9+ |

---

## 7. Customizing for Your Use Case

- **Segmentation only**: Skip the classification steps entirely.
- **Classification only**: Skip segmentation, use raw images directly with `classification/train.py`.
- **Segmentation → Classification**: Segment first, then use lung masks as inputs to classifier (not yet implemented — segment pipeline stops at .nrrd).
- **3-channel vs grayscale**: All models expect 3-channel input. PNGs are loaded as RGB. DICOM grayscale images are internally converted to 3-channel.
