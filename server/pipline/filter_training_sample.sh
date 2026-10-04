#!/bin/bash
#SBATCH --job-name=FILTER-TRAINING-SAMPLE
#SBATCH --output=filter-training-sample-result_%j.out
#SBATCH --error=filter-training-sample-result_%j.err
#SBATCH -p cpu-nodes
#SBATCH -N 1
#SBATCH -n 2
#SBATCH --mem=8G
#SBATCH --time=0:15:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=mkuyokwa@mlw.mw

set -euo pipefail
module purge
module load Python/3.12.3-GCCcore-13.3.0
source venv/bin/activate

python3 << 'PYEOF'
import pandas as pd

full_pool = pd.read_csv('tb_full_pool_with_metadata_FIXED.csv')
print(f"Full pool loaded: {len(full_pool)} rows")

# Reproduce the EXACT same 3,500-image sample used in training
# (must match tb_df.sample(n=3500, random_state=42) from convert_dicom.sh / mask_images.sh)
sample = full_pool.sample(n=3500, random_state=42)
sample.to_csv('tb_training_sample_3500_with_metadata.csv', index=False)
print(f"Saved tb_training_sample_3500_with_metadata.csv ({len(sample)} rows)")

print("\n" + "="*60)
print("TRAINING SAMPLE (3,500 images) — COMPOSITION")
print("="*60)

for col in ['country', 'type_of_resistance', 'case_definition', 'sex', 'outcome', 'cxr_outlier', 'diagnosis_code']:
    if col in sample.columns:
        print(f"\n--- {col} ---")
        print(sample[col].value_counts())
        print(f"(missing/unmatched: {sample[col].isna().sum()})")

print(f"\nUnique patients in training sample: {sample['patient_id'].nunique()} / {len(sample)} images")
print(f"Unique studies in training sample: {sample['study_uid'].nunique()}")

if 'age_of_onset' in sample.columns:
    print(f"\nAge of onset — mean: {sample['age_of_onset'].mean():.1f}, "
          f"min: {sample['age_of_onset'].min()}, max: {sample['age_of_onset'].max()}")

if 'country' in sample.columns:
    print("\n--- Country breakdown (% of training sample) ---")
    print((sample['country'].value_counts(normalize=True, dropna=True) * 100).round(2))

print("\nDone.")
PYEOF
