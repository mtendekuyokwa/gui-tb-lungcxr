#!/bin/sh
# Container entrypoint: prepare the volume, then serve with gunicorn.
set -eu

: "${LUNGCXR_SECRET_KEY:?Set LUNGCXR_SECRET_KEY (a long random string) in the Railway variables.}"

DATA="${LUNGCXR_DATA_DIR:-/data}"
export LUNGCXR_DATABASE_URI="${LUNGCXR_DATABASE_URI:-sqlite:///$DATA/lungcxr.db}"
export LUNGCXR_STORAGE_DIR="${LUNGCXR_STORAGE_DIR:-$DATA/storage}"
export LUNGCXR_MODELS_DIR="${LUNGCXR_MODELS_DIR:-$DATA/models}"
export FLASK_APP=wsgi
mkdir -p "$DATA" "$LUNGCXR_STORAGE_DIR" "$LUNGCXR_MODELS_DIR"

flask init-db
flask ensure-admin
# A failed download must not stop the API; cases then wait for the model.
flask fetch-models || echo "fetch-models failed; starting without the model."
# Read anything queued while the model was missing (e.g. a previous boot).
flask worker --once || echo "worker --once failed; queued cases stay queued."

# One worker process: SQLite on one volume, and one copy of the models in
# memory. Threads serve concurrent requests; model runs are serialised.
exec gunicorn wsgi:app \
    --bind "0.0.0.0:${PORT:-8000}" \
    --workers 1 \
    --threads "${GUNICORN_THREADS:-4}" \
    --timeout 180 \
    --access-logfile -
