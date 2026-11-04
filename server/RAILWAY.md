# Deploying the backend on Railway

One Railway service built from `server/Dockerfile`, with a volume for the
SQLite database, uploaded X-rays and the model files. `railway.json` sets
the Dockerfile builder, the health check and the restart policy.

## One-time setup

1. **New project → Deploy from GitHub repo** → pick this repo and branch.
2. Service **Settings → Source → Root Directory**: `server`
   (so Railway finds `railway.json` and the `Dockerfile`).
3. **Add a volume** to the service, mount path `/data`.
4. **Variables** (service → Variables):

   | Variable | Value |
   |---|---|
   | `LUNGCXR_SECRET_KEY` | long random string, e.g. `python3 -c "import secrets;print(secrets.token_urlsafe(48))"`. **Required**: the container refuses to start without it. Changing it signs everyone out. |
   | `LUNGCXR_ADMIN_EMAIL` | the first admin's email |
   | `LUNGCXR_ADMIN_PASSWORD` | the first admin's password (8+ chars). Used only to create the account if it doesn't exist; change it in the app afterwards and you can delete this variable. |
   | `LUNGCXR_SEGMENTER_URL` | direct download URL of `cxr_lung_segment_including_heart_512.pt` |
   | `LUNGCXR_CLASSIFIER_URL` | direct download URL of `tb_classifier.pth` |
   | `LUNGCXR_SEGMENTER_SHA256`, `LUNGCXR_CLASSIFIER_SHA256` | optional; `sha256sum models/*` locally. A mismatching download is discarded. |
   | `LUNGCXR_CORS_ORIGINS` | the Flutter web app's origin, e.g. `https://lungcxr.example.org` (default `*`) |
   | `LUNGCXR_ADMIN_NAME` | optional display name for that admin |
   | `GUNICORN_THREADS` | optional, default 4 |

   The model URLs must download the raw file with no login page in between
   (a pre-signed S3/R2 link, a Hugging Face `resolve/main/...` link with a
   token in the URL, etc.). Files already on the volume are never
   downloaded again; delete them from the volume to force a refresh.

5. **Settings → Networking → Generate Domain.** The API is then at
   `https://<domain>/api/v1` (Swagger UI at `/api/v1/`).

## What happens on each boot (`start.sh`)

`init-db` (create missing tables; `_ensure_schema` adds new columns) →
`ensure-admin` → `fetch-models` (only missing files) → `worker --once`
(reads cases queued while the model was missing) → `gunicorn` on `$PORT`
with **one** worker process and a few threads. Keep it at one replica:
SQLite and the volume belong to a single instance, and model runs are
serialised in-process.

Uploads are read inline (about 7 s on 4 vCPUs), so the service needs
roughly 1.5–2 GB of RAM. Without model files the API still works and cases
show "Awaiting model" until the next boot finds them.

## Pointing the Flutter app at it

```bash
flutter build web --dart-define=API_BASE_URL=https://<domain>/api/v1
```

## Useful one-offs

With the Railway CLI linked to the service (`railway link`):

```bash
railway ssh -- flask create-user doctor@hospital.org "Dr Name" --role doctor
railway ssh -- flask requeue          # retry failed readings, then:
railway ssh -- flask worker --once
```

`/data/lungcxr.db` is the whole database; back it up by copying it off the
volume (e.g. `railway ssh -- cat /data/lungcxr.db > backup.db`).
