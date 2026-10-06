# Lung Segmentation on HTCp

## 1. Create input CSV

```bash
source venv/bin/activate
python3 -c "
import pandas as pd, pathlib
files = sorted(pathlib.Path('/path/to/Normal/').expanduser().glob('*.png'))
df = pd.DataFrame({'cxr_file': [str(f.resolve()) for f in files]})
df.to_csv('normal_files.csv', index=False)
print(f'Saved {len(df)} files')
"
```

## 2. Run segmentation

```bash
python -m segment_lung_cxr.inference.inference_lung_segment \
    normal_files.csv \
    segment_lung_cxr/data/weights/cxr_lung_segment_including_heart_512.pt \
    --dataset Normal \
    --img_size 512 512 --patch_size 512 512 --post_process True
```

Output: `.nrrd` masks in `results/segments/Normal/`
