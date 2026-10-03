# Known issues

Open problems and unverified areas as of 2026-10-03. Feature work still to do
is tracked in `FEATURES.md` (frontend) and `server/FEATURES.md` (backend); this
file is for things that are wrong, risky or untested in what already exists.

Severity: **High** = can give a wrong clinical signal or leak data.
**Medium** = wrong or fragile behaviour. **Low** = rough edge or cleanup.

## Model

| # | Severity | Issue |
| --- | --- | --- |
| M1 | High | **The model's readings are not validated.** The worker's output has never been compared with the cluster's saved predictions (`server/pipline/inference/predictions.csv`), because the original X-rays are not on this machine. Backend feature 22 is blocked until about ten of those test images are copied over. |
| M2 | High | **The reported accuracy is probably not real.** Test accuracy 0.990 and AUC 1.0, with the best checkpoint saved at the second epoch (validation accuracy 0.9989). Normal images come from public PNG sets and TB images from a DICOM archive, so the classifier may be separating image sources, not disease. |
| M3 | High | **The heatmap points at lung edges, not lung fields.** On the one real X-ray tried, Grad-CAM lit up the mask boundary. That supports M2 and means the XAI overlay should not be read as "where the disease is". |
| M4 | Medium | **The lung segmenter is a re-implementation.** `server/app/ml/segmenter.py` reproduces the cluster's MONAI + SimpleITK inference with plain PyTorch and SciPy. Resampling back to the original size and colour-to-grey conversion differ slightly, so masks are close to but not identical with the ones the classifier was trained on. |
| M5 | Medium | **Only TB or Normal.** The model cannot name any other disease, and it gives a reading for any image in which it finds lung-like shapes. Images with no lungs found are marked `failed`, but there is no check that an upload is a frontal chest X-ray. |
| M6 | Medium | **A failed prediction stores no reason.** The cause is only in the worker's log. |
| M7 | Low | **About 7 seconds per image** on 4 CPU cores; there is no GPU on this machine. |
| M8 | Low | **`torch.jit.load` is deprecated on Python 3.14.** The segmentation model still loads, with a warning that is silenced in code. A future PyTorch may refuse it; the fix is to re-export the model or pin Python. |

## Backend

| # | Severity | Issue |
| --- | --- | --- |
| B1 | High | **Development settings are not safe to deploy.** The secret key falls back to a fixed development value if `LUNGCXR_SECRET_KEY` is unset, CORS allows every origin by default, and the server has only been run with Flask's development server over plain HTTP. |
| B2 | High | **No login rate limiting and no way to change a password.** Only an admin can reset one, through `PATCH /admin/users/{id}`. |
| B3 | Medium | **No schema migrations.** Tables come from `create_all()`, so any change to a table means deleting the database. |
| B4 | Medium | **Two workers would process the same case.** A prediction goes straight from `queued` to `done`; there is no "running" state or lock. Run one worker only. |
| B5 | Medium | **PNG and JPEG only.** DICOM upload, and stripping patient tags from it, is not built. |
| B6 | Medium | **Opening a case changes it.** `GET /cases/{id}` moves an assigned case to "in review" and writes an audit entry. A page that merely prefetches cases would mark them all as opened. |
| B7 | Low | **`GET /admin/cases` returns every case** with no paging, and builds each row with several queries. |
| B8 | Low | **Seeded passwords are written to a file** (`server/instance/dev-credentials.txt`, not tracked). Development convenience only. |

## Frontend

| # | Severity | Issue |
| --- | --- | --- |
| F1 | Medium | **A page reload signs the user out.** The token is kept in memory only. |
| F2 | Medium | **Opening a mark's label panel saves a draft.** Selecting a mark counts as a change, so a returned case moves to "In review" before anything was edited. |
| F3 | Medium | **The X-ray file picker has not been tested in a browser.** It opens a native dialog that automation cannot drive. Upload itself is covered by the live test. |
| F4 | Medium | **The model reading is shown before the doctor gives a verdict.** That is faster but biases the doctor, which weakens the "model was wrong" data. A product decision, not yet made. |
| F5 | Low | **The Assign button moves** up when the first case is ticked, because the hint text above it disappears. |
| F6 | Low | **Admin cannot yet** create or deactivate doctors, export CSV, see statistics, or filter by doctor or flag from the app. The backend supports all of these. |
| F7 | Low | **Segment tool and Assistant chat do nothing real.** Segment shows a toast; chat gives one canned reply. The lung mask the backend now stores is not shown anywhere. |
| F8 | Low | **Desktop-width layout only.** Nothing adapts to tablets or phones. |
| F9 | Low | **Leftovers from the demo:** `AppImages`, the portraits in `assets/images/patients/`, the `Example` widget in `main.dart`, and the unused `imosys_flutter_package` dependency. `README.md` is still the Flutter template. |

## Data and repository

| # | Severity | Issue |
| --- | --- | --- |
| D1 | High | **`server/pipline/` is not in git and must not be added as it is.** It holds about 3.8 GB of archives, and CSV and Excel files with per-patient clinical metadata from the training data. `server/.gitignore` excludes the archives, logs, weights and metadata, but not the split CSVs (which contain cluster file paths) or the 905 Grad-CAM images. |
| D2 | Medium | **Model files live outside git** in `server/models/`. A fresh checkout cannot run the worker until they are copied in by hand; see `server/CLAUDE.md`. |
| D3 | Medium | **The documentation inside `server/pipline/` describes code that is not there.** Its `README.md`, `HOWTO.md` and `Makefile` refer to packages that exist only inside the zip files. |
| D4 | Low | **The development database contains test data.** Cases 1 to 3 are heatmap renders, not X-rays, so their "Normal, 0%" readings mean nothing. Case 4 is a 1-pixel test image. Only case 5 is a real X-ray. |

## Clinical decisions still open

These were assumed in order to build, and need a clinician or the project owner
to confirm.

- **Verdict, disease and test lists** in `server/app/catalog.py` are a proposal, not clinical guidance.
- **One doctor per case.** Two independent readers per image would need an assignments table.
- **Only the admin uploads images.**
- **Wording.** The app says "model reading", never "diagnosis". Any export or report must keep that.

## Testing gaps

- The Flutter tests run against a fake backend. `test/live_backend_test.dart` drives the real one but is skipped unless its environment variables are set.
- The real models are only exercised by a test that is skipped unless `LUNGCXR_TEST_CXR` points at an X-ray file.
- In-browser checks were done once, by hand-driven headless Chromium. There is no automated browser test.
- "Further testing" was never clicked through on screen; it is covered by the live test only.
