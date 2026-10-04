#!/bin/bash
#SBATCH --job-name=SEGMENTATION-POSITIVES
#SBATCH --output=segmentation-positives-result_%j.out
#SBATCH --error=segmentation-positives-result_%j.err
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

python -m segment_lung_cxr.data_preparation.prepare_ls1_csv ../TB_positives_extracted --output_csv tb_positive_files.csv

python3 -m segment_lung_cxr.inference.inference_lung_segment tb_positive_files.csv segment_lung_cxr/data/weights/cxr_lung_segment_including_heart_512.pt --dataset TB_Positive --img_size 512 512 --patch_size 512 512 --post_process True
