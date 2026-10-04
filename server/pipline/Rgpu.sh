#!/bin/bash
#SBATCH --job-name=SEGMENTATION
#SBATCH --output=segmentation-python-result_%j.out
#SBATCH --error=segmentation-python-result_%j.err
#SBATCH -p gpu-nodes
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=20G
#SBATCH --time=1:00:00
#SBATCH --gres=gpu:1
#SBATCH --mail-type=ALL
#SBATCH --mail-user=mkuyokwa@mlw.mw

set -euo pipefail

module purge
module load Python/3.12.3-GCCcore-13.3.0
source venv/bin/activate
python3 -m pip install -r requirements.txt

python3 -c "
import pandas as pd, pathlib
files = sorted(pathlib.Path('../kaggle-negatives/Normal').expanduser().glob('*.png'))
df = pd.DataFrame({'cxr_file': [str(f.resolve()) for f in files]})
df.to_csv('normal_files.csv', index=False)
print(f'Saved {len(df)} files')
"

python3 -m segment_lung_cxr.inference.inference_lung_segment normal_files.csv segment_lung_cxr/data/weights/cxr_lung_segment_including_heart_512.pt --dataset Normal --img_size 512 512 --patch_size 512 512 --post_process True
