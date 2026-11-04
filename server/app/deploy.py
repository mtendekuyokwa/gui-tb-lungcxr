"""Boot steps shared by every way the backend is hosted.

Railway runs them through ``start.sh`` (the ``flask`` commands in ``cli.py``);
hosts that only run ``gunicorn main:app`` from the repo root (e.g. Pella)
run them from ``main.py``. Everything here is idempotent: safe on every boot.
"""

import hashlib
import os
import pathlib
import secrets
import shutil
import tempfile
import urllib.request

SERVER_DIR = pathlib.Path(__file__).resolve().parent.parent
MIN_ADMIN_PASSWORD = 8


def _instance_dir():
    """Where the generated secret and first-admin note live: the
    ``LUNGCXR_INSTANCE_DIR`` variable, else ``server/instance``."""
    return pathlib.Path(os.environ.get("LUNGCXR_INSTANCE_DIR", SERVER_DIR / "instance"))


def _log(message):
    # Flushed at once: hosts show stdout live, and a buffered line from
    # gunicorn's master process may never appear at all.
    print(message, flush=True)


def ensure_secret():
    """Makes sure ``LUNGCXR_SECRET_KEY`` is set before the app is created.

    When the host gives no way to set it, a random key is generated once and
    kept in ``LUNGCXR_SECRET_FILE`` (default ``<instance dir>/secret_key``),
    so tokens stay valid across restarts. Returns where the key came from.
    """
    if os.environ.get("LUNGCXR_SECRET_KEY"):
        return "environment"
    path = pathlib.Path(
        os.environ.get("LUNGCXR_SECRET_FILE", _instance_dir() / "secret_key"))
    if path.is_file() and path.read_text().strip():
        key = path.read_text().strip()
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        key = secrets.token_urlsafe(48)
        path.write_text(key)
        path.chmod(0o600)
    os.environ["LUNGCXR_SECRET_KEY"] = key
    return str(path)


def ensure_admin(app, log=_log):
    """Creates the first admin.

    With ``LUNGCXR_ADMIN_EMAIL`` / ``LUNGCXR_ADMIN_PASSWORD`` set, that account
    is created if missing (an existing one is never changed). With neither set
    and no users at all, ``admin@lungcxr.local`` is created with a random
    password written to ``<instance dir>/initial-admin.txt`` (not the log).
    """
    from .cli import _add_user
    from .extensions import db
    from .models import ROLE_ADMIN, User

    email = os.environ.get("LUNGCXR_ADMIN_EMAIL", "").strip().lower()
    password = os.environ.get("LUNGCXR_ADMIN_PASSWORD", "")
    name = os.environ.get("LUNGCXR_ADMIN_NAME", "").strip() or "Hospital Admin"
    with app.app_context():
        if email and password:
            if User.query.filter_by(email=email).first():
                log(f"ensure-admin: {email} already exists.")
                return
            if len(password) < MIN_ADMIN_PASSWORD:
                raise ValueError(
                    f"LUNGCXR_ADMIN_PASSWORD must be at least {MIN_ADMIN_PASSWORD} characters.")
            _add_user(email, name, ROLE_ADMIN, password)
            db.session.commit()
            log(f"ensure-admin: created admin {email}")
            return
        if User.query.first() is not None:
            log("ensure-admin: users exist; nothing to do.")
            return
        email = "admin@lungcxr.local"
        password = secrets.token_urlsafe(12)
        _add_user(email, name, ROLE_ADMIN, password)
        db.session.commit()
        note = _instance_dir() / "initial-admin.txt"
        note.parent.mkdir(parents=True, exist_ok=True)
        note.write_text(f"{email}\n{password}\n")
        note.chmod(0o600)
        log(f"ensure-admin: created {email}; its password is in {note}. "
            "Sign in, change it, then delete that file.")


def fetch_models(models_dir, log=_log):
    """Downloads missing model files from ``LUNGCXR_SEGMENTER_URL`` /
    ``LUNGCXR_CLASSIFIER_URL`` (checked against the optional ``*_SHA256``).
    Files already present are kept. Raises on a checksum mismatch."""
    from .ml.files import CLASSIFIER_FILE, SEGMENTER_FILE

    models = pathlib.Path(models_dir)
    models.mkdir(parents=True, exist_ok=True)
    for name, prefix in ((SEGMENTER_FILE, "SEGMENTER"), (CLASSIFIER_FILE, "CLASSIFIER")):
        target = models / name
        if target.is_file():
            log(f"fetch-models: {name} present.")
            continue
        url = os.environ.get(f"LUNGCXR_{prefix}_URL", "").strip()
        if not url:
            log(f"fetch-models: {name} missing and LUNGCXR_{prefix}_URL unset; "
                "cases will wait for the model.")
            continue
        log(f"fetch-models: downloading {name} ...")
        digest = hashlib.sha256()
        # Download beside the target, then rename, so a cut-off download never
        # leaves a half file that looks present on the next boot.
        with tempfile.NamedTemporaryFile(dir=models, delete=False) as part:
            with urllib.request.urlopen(url, timeout=60) as response:
                while chunk := response.read(1 << 20):
                    part.write(chunk)
                    digest.update(chunk)
        expected = os.environ.get(f"LUNGCXR_{prefix}_SHA256", "").strip().lower()
        if expected and digest.hexdigest() != expected:
            os.unlink(part.name)
            raise ValueError(f"{name}: checksum mismatch, download discarded.")
        shutil.move(part.name, target)
        log(f"fetch-models: saved {name} ({target.stat().st_size // 1_000_000} MB).")


def prepare(app, log=_log):
    """Every boot step after the app exists: tables, first admin, models.
    A failed model download is logged, not fatal: the API still serves."""
    from .extensions import db

    with app.app_context():
        db.create_all()
    log(f"Database ready: {app.config['SQLALCHEMY_DATABASE_URI']}")
    ensure_admin(app, log)
    try:
        fetch_models(app.config["MODELS_DIR"], log)
    except Exception as error:  # noqa: BLE001 - keep serving without the model
        log(f"fetch-models failed ({error}); starting without the model.")


def create_ready_app(log=_log):
    """The app with every boot step done: what `gunicorn main:app` serves,
    from the repo root (main.py) or from server/ (server/main.py)."""
    ensure_secret()  # before create_app, which reads LUNGCXR_SECRET_KEY
    from . import create_app

    app = create_app()
    prepare(app, log)
    return app
