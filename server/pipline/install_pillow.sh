#!/bin/bash
#SBATCH --job-name=checking-cpu-test
#SBATCH --output=install-pillow-result_%j.out
#SBATCH --error=install-pillow-result_%j.err
#SBATCH -p cpu-nodes
#SBATCH -N 1
#SBATCH -n 2
#SBATCH --mem=4G
#SBATCH --time=0:10:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=mkuyokwa@mlw.mw

set -euo pipefail
module purge
module load Python/3.12.3-GCCcore-13.3.0
source /head/NFS/mkuyokwa/lungcxr/lung_cxr_segmentation/venv/bin/activate


python3 << 'PYEOF'
print('hello')
PYEOF
