#!/bin/bash
#SBATCH --job-name=PROFILE-FULL-POOL
#SBATCH --output=profile-full-pool-result_%j.out
#SBATCH --error=profile-full-pool-result_%j.err
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

# ---- Step 1: Add patient_id / study_uid / series_uid to the full manifest ----
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
print(f"Full available TB pool: {len(tb_df)} images")

# ---- Step 2: Locate the metadata file by exact known filename ----
# Filename has spaces/parentheses, so search by fixed substring rather than shell glob
target_substring = "TB_Portals_CXRs_March_2025"
result = subprocess.run(
    ["find", "..", "-iname", f"*{target_substring}*.csv"],
    capture_output=True, text=True
)
candidates = [line for line in result.stdout.splitlines() if line.strip()]
print(f"\nCandidate metadata files found: {candidates}")

if not candidates:
    # Broaden search to the whole home dir in case it's elsewhere
    result = subprocess.run(
        ["find", "/head/NFS/mkuyokwa", "-iname", f"*{target_substring}*.csv"],
        capture_output=True, text=True
    )
    candidates = [line for line in result.stdout.splitlines() if line.strip()]
    print(f"Broadened search found: {candidates}")

if not candidates:
    print("ERROR: metadata file still not found. Set META_PATH manually below and rerun.")
    raise SystemExit(1)

META_PATH = candidates[0]
print(f"Using metadata file: {META_PATH} ({pathlib.Path(META_PATH).stat().st_size / 1e6:.1f} MB)")

try:
    meta = pd.read_csv(META_PATH)
    if meta.shape[1] == 1:
        raise ValueError("wrong delimiter")
except Exception:
    meta = pd.read_csv(META_PATH, sep='\t')

print(f"Metadata loaded: {len(meta)} rows, columns: {list(meta.columns)}")

# ---- Step 3: Join FULL pool (all 6,623 images) on patient_id ----
merged = tb_df.merge(meta, on='patient_id', how='left', suffixes=('', '_meta'))
matched = merged['country'].notna().sum() if 'country' in merged.columns else 0
print(f"\nMatched {matched} / {len(tb_df)} rows to metadata via patient_id")

merged.to_csv('tb_full_pool_with_metadata.csv', index=False)
print(f"Saved tb_full_pool_with_metadata.csv ({len(merged)} rows)")

# ---- Step 4: Composition of the FULL available pool ----
print("\n" + "="*60)
print("FULL AVAILABLE POOL (all extracted images) — COMPOSITION")
print("="*60)

for col in ['country', 'type_of_resistance', 'case_definition', 'sex', 'outcome', 'cxr_outlier', 'diagnosis_code']:
    if col in merged.columns:
        print(f"\n--- {col} ---")
        print(merged[col].value_counts())
        print(f"(missing/unmatched: {merged[col].isna().sum()})")
    else:
        print(f"\n--- {col} --- (column not found in metadata)")

print(f"\nUnique patients in full pool: {merged['patient_id'].nunique()} / {len(merged)} images")
print(f"Unique studies in full pool: {merged['study_uid'].nunique()}")

if 'age_of_onset' in merged.columns:
    print(f"\nAge of onset — mean: {merged['age_of_onset'].mean():.1f}, "
          f"min: {merged['age_of_onset'].min()}, max: {merged['age_of_onset'].max()}")

# ---- Step 5: Country breakdown as % (useful for "locations") ----
if 'country' in merged.columns:
    print("\n--- Country breakdown (% of matched images) ---")
    country_pct = merged['country'].value_counts(normalize=True, dropna=True) * 100
    print(country_pct.round(2))

# ---- Step 6: Images per patient distribution ----
print("\n--- Images-per-patient distribution (full pool) ---")
print(merged['patient_id'].value_counts().describe())

print("\nDone.")
PYEOF
