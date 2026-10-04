#!/bin/bash
#SBATCH --job-name=PROFILE-FULL-POOL-FIXED
#SBATCH --output=profile-full-pool-fixed-result_%j.out
#SBATCH --error=profile-full-pool-fixed-result_%j.err
#SBATCH -p cpu-nodes
#SBATCH -N 1
#SBATCH -n 2
#SBATCH --mem=8G
#SBATCH --time=0:30:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=mkuyokwa@mlw.mw

set -euo pipefail
module purge
module load Python/3.12.3-GCCcore-13.3.0
source venv/bin/activate

python3 << 'PYEOF'
import pandas as pd
import pathlib
import subprocess

def extract_ids(path):
    parts = path.split('/')
    idx = parts.index('TB_positives_extracted')
    return pd.Series({
        'patient_id': parts[idx+1],
        'study_uid': parts[idx+2],
        'series_uid': parts[idx+3],
    })

tb_df = pd.read_csv('tb_positive_files.csv')
tb_df = pd.concat([tb_df, tb_df['cxr_file'].apply(extract_ids)], axis=1)
# Build the exact same path format as series_instance_content_url:
# patient_id/study_uid/series_uid/instance.dcm
tb_df['dicom_path'] = tb_df['cxr_file'].apply(lambda x: x.split('TB_positives_extracted/')[-1])
print(f"Full available TB pool: {len(tb_df)} images")

result = subprocess.run(["find", "..", "-iname", "*TB_Portals_CXRs_March_2025*.csv"],
                         capture_output=True, text=True)
candidates = [l for l in result.stdout.splitlines() if l.strip()]
META_PATH = candidates[0]
print(f"Using metadata file: {META_PATH}")

meta = pd.read_csv(META_PATH)
if meta.shape[1] == 1:
    meta = pd.read_csv(META_PATH, sep='\t')
print(f"Metadata loaded: {len(meta)} rows")

# Deduplicate metadata on the join key first, as a safety net against any
# genuine duplicate metadata rows (shouldn't happen, but verify)
dupe_check = meta['series_instance_content_url'].duplicated().sum()
print(f"Duplicate series_instance_content_url values in metadata: {dupe_check}")

# ---- CORRECT JOIN: on the full unique path, not patient_id ----
merged = tb_df.merge(
    meta, left_on='dicom_path', right_on='series_instance_content_url',
    how='left', suffixes=('', '_meta')
)
print(f"\nRow count after join: {len(merged)} (should equal {len(tb_df)})")
assert len(merged) == len(tb_df), "ROW EXPLOSION STILL PRESENT — investigate duplicate keys"

matched = merged['country'].notna().sum()
print(f"Matched {matched} / {len(tb_df)} rows to metadata")

merged.to_csv('tb_full_pool_with_metadata_FIXED.csv', index=False)
print(f"Saved tb_full_pool_with_metadata_FIXED.csv ({len(merged)} rows)")

print("\n" + "="*60)
print("FULL AVAILABLE POOL — CORRECTED COMPOSITION")
print("="*60)

for col in ['country', 'type_of_resistance', 'case_definition', 'sex', 'outcome', 'cxr_outlier', 'diagnosis_code']:
    if col in merged.columns:
        print(f"\n--- {col} ---")
        print(merged[col].value_counts())
        print(f"(missing/unmatched: {merged[col].isna().sum()})")

print(f"\nUnique patients: {merged['patient_id'].nunique()} / {len(merged)} images")
print(f"Unique studies: {merged['study_uid'].nunique()}")

if 'age_of_onset' in merged.columns:
    print(f"\nAge of onset — mean: {merged['age_of_onset'].mean():.1f}, "
          f"min: {merged['age_of_onset'].min()}, max: {merged['age_of_onset'].max()}")

if 'country' in merged.columns:
    print("\n--- Country breakdown (% of matched images) ---")
    print((merged['country'].value_counts(normalize=True, dropna=True) * 100).round(2))

print("\nDone.")
PYEOF
