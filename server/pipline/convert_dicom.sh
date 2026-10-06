#!/bin/bash
#SBATCH --job-name=DICOM-CONVERT
#SBATCH --output=dicom-convert-result_%j.out
#SBATCH --error=dicom-convert-result_%j.err
#SBATCH -p cpu-nodes
#SBATCH -N 1
#SBATCH -n 4
#SBATCH --mem=10G
#SBATCH --time=1:00:00

set -euo pipefail
module purge
module load Python/3.12.3-GCCcore-13.3.0
source venv/bin/activate

pip install pylibjpeg pylibjpeg-libjpeg

python3 << 'PYEOF'
import pandas as pd
import pathlib
import random
import pydicom
import numpy as np
from PIL import Image

random.seed(42)

tb_df = pd.read_csv('tb_positive_files.csv')
tb_sample = tb_df.sample(n=3500, random_state=42)
tb_dest = pathlib.Path('classification_data/Tuberculosis')
tb_dest.mkdir(parents=True, exist_ok=True)

converted, failed, skipped = 0, 0, 0
for i, f in enumerate(tb_sample['cxr_file']):
    src = pathlib.Path(f)
    dst = tb_dest / f"{i:05d}.png"
    if dst.exists():
        skipped += 1
        continue
    try:
        ds = pydicom.dcmread(src)
        arr = ds.pixel_array.astype(np.float32)
        arr = arr - arr.min()
        if arr.max() > 0:
            arr = arr / arr.max()
        arr = (arr * 255).astype(np.uint8)
        img = Image.fromarray(arr).convert('RGB')
        img.save(dst)
        converted += 1
    except Exception as e:
        print(f"Failed: {src} — {e}")
        failed += 1

print(f"Converted {converted} TB images, {failed} failed, {skipped} already done")
PYEOF
