#!/bin/bash
#SBATCH --job-name=CSV-PREP
#SBATCH --output=csv-prep-result_%j.out
#SBATCH --error=csv-prep-result_%j.err
#SBATCH -p cpu-nodes
#SBATCH -N 1
#SBATCH -n 4
#SBATCH --mem=10G
#SBATCH --time=1:00:00

set -euo pipefail

module purge
module load Python/3.12.3-GCCcore-13.3.0
source venv/bin/activate

python -m segment_lung_cxr.data_preparation.prepare_ls1_csv ../TB_positives_extracted --output_csv tb_positive_files.csv
