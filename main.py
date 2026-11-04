"""Backend entry point for hosts that run `gunicorn main:app` from the repo
root (e.g. Pella). The Flask app lives in server/; see server/DEPLOY.md."""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent / "server"))

from app.deploy import create_ready_app  # noqa: E402

app = create_ready_app()
