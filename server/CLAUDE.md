# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`server/` is the Python side of the LungCXR Flutter GUI (see `../CLAUDE.md`; full design in `../DOCUMENTATION.md`). Two things live here:

- `app/` — the **Flask backend**: login, admin→doctor case assignment, doctor reviews (marks, verdict, model-was-wrong flag, further-testing flag), exports. `FEATURES.md` is the ordered build list; tick items there as they land. Phases 1–5 are done except the numeric check against the cluster's predictions (feature 22, blocked on missing original images).
- `pipline/` (sic) — a snapshot from the HPC cluster of the **TB vs Normal classification pipeline** that the worker will eventually serve. The rest of this file from "Pipeline commands" down is about it.

## Backend

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/flask --app wsgi seed          # creates tables + dev admin/2 doctors, prints random passwords
.venv/bin/flask --app wsgi run --debug   # http://127.0.0.1:5000/api/v1
.venv/bin/flask --app wsgi worker         # model worker; needs models/ (see below). --once drains the queue and exits
.venv/bin/flask --app wsgi requeue        # queue failed cases again (--all for every case)
.venv/bin/python -m pytest -q
LUNGCXR_TEST_CXR=/path/to/real_cxr.png .venv/bin/python -m pytest -q   # also runs the real models on that image
.venv/bin/python -m pytest -q -k test_reassign_hides_previous_draft   # single test
```

Config is environment only: `LUNGCXR_SECRET_KEY`, `LUNGCXR_DATABASE_URI` (default SQLite at `instance/lungcxr.db`), `LUNGCXR_STORAGE_DIR` (default `storage/`), `LUNGCXR_CORS_ORIGINS`. There are no migrations yet: tables come from `db.create_all()`, so a model change means deleting the dev database.

- **Blueprints**: `auth.py` (login, `/auth/me`, `/catalog`), `cases.py` (doctor routes + review validation), `admin.py` (users, upload, assign, accept/return, export, stats). All under `/api/v1`; admin under `/api/v1/admin`.
- **Access**: `security.login_required(*roles)` loads the user from the DB on every request (so deactivation is immediate) and sets `g.user`. Doctor routes go through `cases._my_case`, which returns 404 — not 403 — for cases assigned to someone else.
- **Lifecycle** (constants in `models.py`): `unassigned → assigned → in_review → submitted → accepted`, with `submitted → returned → in_review`. A doctor may edit only in `OPEN_STATUSES`. Every transition calls `security.audit`.
- **Reviews** are one per (case, doctor). `PUT /cases/{id}/review` replaces the whole review. After a reassignment the earlier doctor's review stays in the table but `Case.current_review` only returns the current assignee's.
- **Errors**: raise `ApiError(status, message)`; the handler rolls back the session and returns `{"error": ...}`. Validate input before adding rows.
- **Catalog** (`catalog.py`): codes for verdicts, findings, diseases, tests. Finding codes equal the Dart `LesionType` enum names in `lib/feature_home/models/lesion.dart`; keep them in sync.
- **Model serving** (`app/ml/`, imported only by the worker so the web app and most tests don't need PyTorch): `Pipeline.read(path)` runs `Segmenter` (the NIH TorchScript model; output channel 1, threshold 0.5, two largest regions, holes filled) → `preprocess.classifier_arrays` (must match `pipline/training/train_classifier.py` exactly) → `Classifier.predict`, which also computes Grad-CAM on `layer4[-1]`. The overlay is a 512×512 RGBA heatmap whose alpha follows the activation inside the lung mask; the Flutter app draws it over the X-ray. Images where the mask covers under 2% raise `ModelError` and the prediction becomes `failed`. The segmenter is a re-implementation of the MONAI/SimpleITK inference script with torch + scipy, so masks are close to but not bit-identical with the cluster's.
- **`models/`** (not in git) must hold `cxr_lung_segment_including_heart_512.pt` (from `pipline/segment_lung_cxr.zip`, `data/nih-weights/`) and `tb_classifier.pth` (a copy of `pipline/training/best_model.pth`). Torch is the CPU build: `pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu`. About 7 s per image on 4 CPU cores.
- **Worker** (`app/worker.py`): polls for `queued` predictions, oldest first; writes `storage/masks/{case}.png` and `storage/overlays/{case}-{prediction}.png`. A failure marks that prediction `failed` and moves on. `requeue` adds a new prediction row rather than overwriting, so earlier readings stay as history.
- **Images** are stored as `storage/images/{case_id}.png` and served only through `/cases/{id}/image`.

## Pipeline

Nothing in `pipline/` was written to run on this machine. The scripts ran under Slurm on the cluster at `/head/NFS/mkuyokwa/lungcxr/`, and **every path inside the CSVs is an absolute cluster path** (`cxr_file`, `pred_mask_file`, `gradcam_path`, …). The images and `.nrrd` masks those paths point at are not present locally, so training/inference cannot be re-run here as-is — only `evaluate_predictions.py` works on the bundled data.

## Pipeline commands

No tests, linter config or packaging. Scripts are standalone argparse CLIs, run by path (not `-m`); run from `pipline/`.

```bash
# 1. Manifest: merge segmentation eval CSVs into one row per image with a quality tier
python data/data-preparation/build_master_manifest.py \
    --normal-eval <overlap.csv> --normal-eval-surface <surface.csv> \
    --tb-eval <overlap.csv> --tb-eval-surface <surface.csv> \
    --normal-cxr-dir … --normal-pred-dir … --normal-ref-dir … \
    --tb-cxr-dir … --tb-pred-dir … --tb-ref-dir … --output all_files_manifest.csv

# 2. Splits (the one actually used for the shipped model)
python data/data-preparation/prepare_class_balanced.py \
    --manifest all_files_manifest_filtered.csv --output-dir data_balanced \
    --target-per-class 3000 --seed 42

# 3. Train
python training/train_classifier.py \
    --train-csv data_balanced/train.csv --val-csv data_balanced/val.csv \
    --mode segmented --epochs 100 --batch-size 64 --lr 1e-4 --output-dir training

# 4. Inference on the test split -> inference/predictions.csv
python inference/run_inference.py \
    --test-csv data_balanced/test.csv --checkpoint training/best_model.pth \
    --mode segmented --output-dir inference

# 5. Metrics -> evaluation/evaluation_results.json (runs locally on bundled data)
python evaluation/evaluate_predictions.py \
    --predictions inference/predictions.csv --output-dir evaluation
```

Dependencies for the classifier scripts are `torch torchvision scikit-learn pandas pillow SimpleITK` (+ `grad-cam` for Grad-CAM); the cluster used Python 3.12. They are **not** in `requirements.txt` / `environment.yml` — those belong to the upstream segmentation repo. `pipline/.venv` is a stale moved virtualenv; ignore it and use `server/.venv`.

## Pipeline architecture

Pipeline stages, each reading the previous stage's CSV:

`segmentation eval CSVs → build_master_manifest.py → prepare_class_balanced.py → train_classifier.py → run_inference.py → evaluate_predictions.py` (+ Grad-CAM, see below).

- **Manifest schema** is the contract between stages: `cxr_file, pred_mask_file, ref_mask_file, dataset, has_tb, dice, jaccard, hausdorff, mean_surface_distance, …, quality, split`. `has_tb` (0 = Normal, 1 = TB) is the label. `quality` (`excellent` / `good` / `bad`) grades the *lung segmentation mask*, not the image: excellent needs all of dice ≥ 0.93, Hausdorff ≤ 50, mean surface ≤ 8; bad is any of dice < 0.80, Hausdorff > 200, mean surface > 25. Evaluation is reported per quality tier to show how mask quality affects classification.
- **Two split sets exist.** `data_balanced/` (3000 per class, natural quality distribution, 4198/897/905) is what `training/best_model.pth` was trained and evaluated on. `data/input_csv_files/` is an earlier, smaller experiment from `prepare_classification_data.py` (122 per class×quality stratum, 732 total). Don't mix them.
- **Model**: torchvision `resnet18` with `fc = Sequential(Dropout(0.3), Linear(512, 2))`. `best_model.pth` is a checkpoint dict (`model_state_dict`, `optimizer_state_dict`, `epoch`, `val_acc`); loaders accept either that or a bare state dict. Class index 1 = TB; `tb_probability` is `softmax[:, 1]`.
- **Preprocessing must match exactly** when serving the model: load as grayscale → resize 512×512 → scale to 0..1 → multiply by the binary lung mask (`.nrrd` via SimpleITK, resized to 512) → stack to 3 channels → `Normalize(mean=0.5, std=0.5)`. `--mode raw` skips the mask; the shipped checkpoint is `segmented`, so inference needs a lung mask from the segmentation model first. If mask loading fails the dataset silently falls back to the unmasked image.
- `MaskedCXRDataset` and `get_model` are **duplicated** in `training/train_classifier.py` and `inference/run_inference.py` (and again in the Grad-CAM job script); change them together.
- **Grad-CAM**: `gradcam/overlays/*_gradcam.png` (one per test image) and `gradcam/gradcam_summary.csv` were produced by `run_gradcam.sh`, which is only inside `sbatch-scripts.zip`, not unpacked. It targets `model.layer4[-1]` and also records left/right lung activation split (`left_activation_ratio`, `left_lung_bias`; "left" means image-left). This is the source for the GUI's XAI overlay.
- **Results**: test accuracy 0.990, AUC 1.0, zero false positives; all 9 errors are missed TB cases, 8 of them in the `excellent` tier. Treat the near-perfect score with suspicion — Normal and TB images come from different sources (public PNG sets vs. DICOM-derived TB portal images), so the model may be separating datasets rather than disease.

## What else is in `pipline/`

Most top-level files are leftovers from the older upstream **lung segmentation** repo (`niaid/lung_cxr_segmentation`) and an earlier classifier attempt, and reference modules that are not unpacked here:

- `README.md`, `HOWTO.md`, `Makefile`, `requirements.txt`, `environment.yml`, `normal_tb_htcp.md`, `model_info.json` describe `segment_lung_cxr.*` and `classification.train` / `classification.evaluate`. Those packages exist only inside `segment_lung_cxr.zip` / `classification.zip`; the `make` targets fail as-is.
- Top-level `*.sh` are Slurm `sbatch` scripts for that older flow (MONAI-based `tb_classifier.pt`, ImageNet mean/std normalisation — a different model from `training/best_model.pth`). The job scripts for the current pipeline are in `sbatch-scripts.zip`.
- `*-result_<jobid>.out/.err`, `train-classifier-<jobid>.*`, etc. are Slurm logs. `train-classifier-61394.out` is the training log for the shipped checkpoint (job hit the time limit at epoch 56/100; best model was already saved).
- Empty files `except`, `from`, `import`, `for`, `EOF` are shell-heredoc accidents.
- `all_tb_metadata.csv`, `images_metadata.csv`, `Normal.metadata.xlsx` hold per-patient clinical metadata (age, sex, country, outcome, resistance).

`pipline/` holds ~3.8 GB (a 1.9 GB `.rar`, several 200–350 MB zips, the 134 MB checkpoint) plus the patient metadata above. `server/.gitignore` excludes those; check `git status` before committing anything from `pipline/`.
