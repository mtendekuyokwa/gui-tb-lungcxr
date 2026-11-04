"""Backend entry point for hosts that run `gunicorn main:app` from the repo
root (e.g. Pella). The Flask app lives in server/; see server/DEPLOY.md for
the Docker-based deployment."""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent / "server"))

from app import deploy  # noqa: E402

deploy.ensure_secret()  # before create_app, which reads LUNGCXR_SECRET_KEY

from app import create_app  # noqa: E402

app = create_app()
deploy.prepare(app)
