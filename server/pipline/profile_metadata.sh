#!/bin/bash
#SBATCH --job-name=PROFILE-METADATA
#SBATCH --output=profile-metadata-result_%j.out
#SBATCH --error=profile-metadata-result_%j.err
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
import glob

# ---- Step 1: Add patient_id / study_uid / series_uid to both manifests ----
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
tb_df.to_csv('tb_positive_files_with_ids.csv', index=False)
print(f"Saved tb_positive_files_with_ids.csv ({len(tb_df)} rows)")

unused_df = pd.read_csv('tb_positive_unused.csv')
unused_df = pd.concat([unused_df, unused_df['cxr_file'].apply(extract_ids)], axis=1)
unused_df.to_csv('tb_positive_unused_with_ids.csv', index=False)
print(f"Saved tb_positive_unused_with_ids.csv ({len(unused_df)} rows)")

# ---- Step 2: Locate the metadata file automatically ----
search_patterns = [
    '../niad-tb-positives/*.csv',
    '../niad-tb-positives/*.tsv',
    '../**/metadata*.csv',
    '../**/metadata*.tsv',
    '../**/*portal*.csv',
]
candidates = []
for pattern in search_patterns:
    candidates.extend(glob.glob(pattern, recursive=True))
candidates = sorted(set(candidates))

print(f"\nCandidate metadata files found: {candidates}")

if not candidates:
    print("ERROR: No metadata file found automatically. Edit META_PATH manually below and rerun.")
    raise SystemExit(1)

# Use the largest candidate found (most likely to be the full metadata dump)
META_PATH = max(candidates, key=lambda p: pathlib.Path(p).stat().st_size)
print(f"Using metadata file: {META_PATH} ({pathlib.Path(META_PATH).stat().st_size / 1e6:.1f} MB)")

# ---- Step 3: Load metadata (try comma, fall back to tab) ----
try:
    meta = pd.read_csv(META_PATH)
    if meta.shape[1] == 1:  # likely wrong delimiter
        raise ValueError("Only 1 column parsed, retrying with tab delimiter")
except Exception:
    meta = pd.read_csv(META_PATH, sep='\t')

print(f"Metadata loaded: {len(meta)} rows, columns: {list(meta.columns)}")

# ---- Step 4: Join on patient_id ----
merged = tb_df.merge(meta, on='patient_id', how='left', suffixes=('', '_meta'))
matched = merged['country'].notna().sum() if 'country' in merged.columns else merged.iloc[:, -1].notna().sum()
print(f"\nMatched {matched} / {len(tb_df)} rows to metadata via patient_id")

# ---- Step 5: Reproduce the exact 3,500-image training sample ----
sample = merged.sample(n=3500, random_state=42)
sample.to_csv('tb_training_sample_with_metadata.csv', index=False)
print(f"Saved tb_training_sample_with_metadata.csv ({len(sample)} rows)")

# ---- Step 6: Print composition stats ----
print("\n" + "="*60)
print("TRAINING SAMPLE (3,500 images) — COMPOSITION")
print("="*60)

for col in ['country', 'type_of_resistance', 'case_definition', 'sex', 'outcome', 'cxr_outlier']:
    if col in sample.columns:
        print(f"\n--- {col} ---")
        print(sample[col].value_counts())
    else:
        print(f"\n--- {col} --- (column not found in metadata)")

if 'patient_id' in sample.columns:
    print(f"\nUnique patients in training sample: {sample['patient_id'].nunique()} / {len(sample)} images")

if 'age_of_onset' in sample.columns:
    print(f"\nAge of onset — mean: {sample['age_of_onset'].mean():.1f}, "
          f"min: {sample['age_of_onset'].min()}, max: {sample['age_of_onset'].max()}")

# ---- Step 7: Full-pool patient/leakage stats (no metadata needed) ----
print("\n" + "="*60)
print("FULL POOL — PATIENT-LEVEL STRUCTURE (6,623 images)")
print("="*60)
print(f"Unique patients (full pool): {tb_df['patient_id'].nunique()}")
print(f"Unique studies (full pool): {tb_df['study_uid'].nunique()}")

train_patients = set(sample['patient_id'])
heldout_patients = set(unused_df['patient_id'])
overlap = train_patients & heldout_patients
print(f"\nPatients in training sample: {len(train_patients)}")
print(f"Patients in held-out pool: {len(heldout_patients)}")
print(f"Patients in BOTH (leakage risk): {len(overlap)} ({len(overlap)/len(train_patients):.1%} of training patients)")

print("\nDone.")
PYEOF
