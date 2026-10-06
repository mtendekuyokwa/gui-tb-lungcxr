#!/bin/bash
#SBATCH --job-name=MASK-IMAGES
#SBATCH --output=mask-images-result_%j.out
#SBATCH --error=mask-images-result_%j.err
#SBATCH -p gpu-nodes
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=20G
#SBATCH --time=2:00:00
#SBATCH --gres=gpu:1
#SBATCH --mail-type=ALL
#SBATCH --mail-user=mkuyokwa@mlw.mw

set -euo pipefail
module purge
module load Python/3.12.3-GCCcore-13.3.0
source venv/bin/activate

python3 << 'PYEOF'
import pandas as pd
import pathlib
import numpy as np
import SimpleITK as sitk
from PIL import Image

def mask_and_save(cxr_path, seg_path, out_path):
    # Load raw image (could be PNG or DICOM)
    if str(cxr_path).endswith('.dcm'):
        img_sitk = sitk.ReadImage(str(cxr_path))
        img_arr = sitk.GetArrayFromImage(img_sitk).squeeze().astype(np.float32)
        img_arr = img_arr - img_arr.min()
        if img_arr.max() > 0:
            img_arr = img_arr / img_arr.max()
        img_arr = (img_arr * 255).astype(np.uint8)
    else:
        img_arr = np.array(Image.open(cxr_path).convert('L'))

    # Load segmentation mask
    mask_sitk = sitk.ReadImage(str(seg_path))
    mask_arr = sitk.GetArrayFromImage(mask_sitk).squeeze()

    # Resize mask to match image if needed
    if mask_arr.shape != img_arr.shape:
        mask_img = Image.fromarray((mask_arr > 0).astype(np.uint8) * 255).resize(
            (img_arr.shape[1], img_arr.shape[0]), Image.NEAREST
        )
        mask_arr = np.array(mask_img) > 0
    else:
        mask_arr = mask_arr > 0

    # Zero out background (outside lung mask)
    masked = img_arr.copy()
    masked[~mask_arr] = 0

    out_img = Image.fromarray(masked).convert('RGB')
    out_img.save(out_path)


# ---- Normal ----
normal_df = pd.read_csv('normal_files.csv')
normal_dest = pathlib.Path('classification_data_segmented/Normal')
normal_dest.mkdir(parents=True, exist_ok=True)

converted, failed = 0, 0
for _, row in normal_df.iterrows():
    cxr_path = pathlib.Path(row['cxr_file'])
    seg_path = pathlib.Path(row['pred_seg_file'])
    out_path = normal_dest / f"{cxr_path.stem}.png"
    if out_path.exists():
        continue
    try:
        mask_and_save(cxr_path, seg_path, out_path)
        converted += 1
    except Exception as e:
        print(f"Failed (Normal): {cxr_path} — {e}")
        failed += 1
print(f"Normal: masked {converted}, failed {failed}")

# ---- Tuberculosis (using the same 3500-image training sample) ----
tb_df = pd.read_csv('tb_positive_files.csv')
tb_sample = tb_df.sample(n=3500, random_state=42)  # same sample used in training
tb_dest = pathlib.Path('classification_data_segmented/Tuberculosis')
tb_dest.mkdir(parents=True, exist_ok=True)

converted, failed = 0, 0
for i, row in enumerate(tb_sample.itertuples()):
    cxr_path = pathlib.Path(row.cxr_file)
    seg_path = pathlib.Path(row.pred_seg_file)
    out_path = tb_dest / f"{i:05d}.png"
    if out_path.exists():
        continue
    try:
        mask_and_save(cxr_path, seg_path, out_path)
        converted += 1
    except Exception as e:
        print(f"Failed (TB): {cxr_path} — {e}")
        failed += 1
print(f"Tuberculosis: masked {converted}, failed {failed}")
PYEOF
