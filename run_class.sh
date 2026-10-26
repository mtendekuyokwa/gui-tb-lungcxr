#!/usr/bin/env bash
# Class demo: backend API + model worker together.
# Uploads only get a reading when BOTH are running (upload queues, worker answers).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER="$ROOT/server"
PORT="${PORT:-5000}"
WORKER_LOG="/tmp/lungcxr-worker.log"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--port N] [--once] [--no-worker] [--help]

  (no args)   start API + worker together, Ctrl+C stops both
  --once      drain the queued predictions once and exit (no servers)
  --no-worker start the API only (uploads will stay 'queued')
  --help      this message

Env: PORT (default 5000)
EOF
}

MODE="both"
for arg in "$@"; do
  case "$arg" in
    --once) MODE="once" ;;
    --no-worker) MODE="api" ;;
    -h|--help) usage; exit 0 ;;
    --port) echo "Use PORT=N env instead." >&2; exit 1 ;;
    --port=*) PORT="${arg#--port=}" ;;
    *) echo "Unknown arg: $arg" >&2; usage; exit 1 ;;
  esac
done

cd "$SERVER"

# 1. venv ---------------------------------------------------------------
if [[ ! -x .venv/bin/flask ]]; then
  echo "Creating .venv and installing requirements..."
  python3 -m venv .venv
  .venv/bin/pip install -r requirements.txt
  echo "CPU torch (needed for the worker):"
  echo "  .venv/bin/pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu"
fi

# 2. model files ---------------------------------------------------------
if [[ ! -f models/cxr_lung_segment_including_heart_512.pt || ! -f models/tb_classifier.pth ]]; then
  echo "WARNING: models/ is missing weights; the worker will exit." >&2
  echo "  Need: models/cxr_lung_segment_including_heart_512.pt + models/tb_classifier.pth" >&2
fi

# 3. dev users (idempotent: skips existing) -------------------------------
.venv/bin/flask --app wsgi seed

echo
echo "Passwords for a fresh seed are in server/instance/dev-credentials.txt"
echo

if [[ "$MODE" == "once" ]]; then
  .venv/bin/flask --app wsgi worker --once
  exit 0
fi

# 4. worker in background -------------------------------------------------
WORKER_PID=""
if [[ "$MODE" == "both" ]]; then
  echo "Starting worker (log: $WORKER_LOG)..."
  .venv/bin/flask --app wsgi worker >"$WORKER_LOG" 2>&1 &
  WORKER_PID="$!"
  cleanup() { kill "$WORKER_PID" 2>/dev/null || true; }
  trap cleanup INT TERM EXIT
  sleep 3
  if ! kill -0 "$WORKER_PID" 2>/dev/null; then
    echo "Worker failed to start. Tail of $WORKER_LOG:" >&2
    tail -n 20 "$WORKER_LOG" >&2
    exit 1
  fi
  echo "Worker running (pid $WORKER_PID)."
fi

# 5. API in foreground -----------------------------------------------------
echo
echo "API:      http://127.0.0.1:$PORT/api/v1"
echo "Flutter:  flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:$PORT/api/v1"
echo "Upload flow: admin uploads -> model runs inline -> doctor sees the reading (~7s)."
echo "Worker also runs as fallback for backlog or missing models."
echo "Ctrl+C stops everything."
echo
exec .venv/bin/flask --app wsgi run --host 127.0.0.1 --port "$PORT"
