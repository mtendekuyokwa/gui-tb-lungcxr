#!/bin/bash
#SBATCH --job-name=TRAIN-CLASSIFIER-SEG
#SBATCH --output=train-classifier-seg-result_%j.out
#SBATCH --error=train-classifier-seg-result_%j.err
#SBATCH -p gpu-nodes
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=20G
#SBATCH --time=10:00:00
#SBATCH --gres=gpu:1
#SBATCH --mail-type=ALL
#SBATCH --mail-user=mkuyokwa@mlw.mw

set -euo pipefail
module purge
module load Python/3.12.3-GCCcore-13.3.0
source venv/bin/activate

mkdir -p results/classification

python -m classification.train classification_data_segmented results/classification/tb_classifier_segmented.pt --classes Normal Tuberculosis --ext png
