import hashlib
import os
import pathlib
import secrets
import shutil
import tempfile
import urllib.request

import click

from .extensions import db
from .models import FAILED, QUEUED, ROLE_ADMIN, ROLE_DOCTOR, Case, Prediction, User


def _add_user(email, full_name, role, password):
    user = User(email=email.lower(), full_name=full_name, role=role)
    user.set_password(password)
    db.session.add(user)
    return user


def register(app):
    @app.cli.command("init-db")
    def init_db():
        """Create the database tables if they do not exist."""
        db.create_all()
        click.echo(f"Database ready: {app.config['SQLALCHEMY_DATABASE_URI']}")

    @app.cli.command("create-user")
    @click.argument("email")
    @click.argument("full_name")
    @click.option("--role", type=click.Choice([ROLE_ADMIN, ROLE_DOCTOR]), default=ROLE_DOCTOR)
    @click.password_option()
    def create_user(email, full_name, role, password):
        """Create one user, prompting for the password."""
        if User.query.filter_by(email=email.lower()).first():
            raise click.ClickException("A user with this email already exists.")
        _add_user(email, full_name, role, password)
        db.session.commit()
        click.echo(f"Created {role} {email}")

    @app.cli.command("seed")
    def seed():
        """Development only: one admin and two doctors with random passwords."""
        db.create_all()
        accounts = [
            ("admin@lungcxr.local", "Hospital Admin", ROLE_ADMIN),
            ("doctor1@lungcxr.local", "Doctor One", ROLE_DOCTOR),
            ("doctor2@lungcxr.local", "Doctor Two", ROLE_DOCTOR),
        ]
        for email, full_name, role in accounts:
            if User.query.filter_by(email=email).first():
                click.echo(f"exists   {email}")
                continue
            password = secrets.token_urlsafe(9)
            _add_user(email, full_name, role, password)
            click.echo(f"created  {email}  password: {password}")
        db.session.commit()

    @app.cli.command("worker")
    @click.option("--once", is_flag=True, help="Process the queue and exit.")
    def worker(once):
        """Run the model worker: lung mask, TB reading and XAI heatmap per case."""
        from . import worker as queue
        from .ml.pipeline import Pipeline

        click.echo(f"Loading models from {app.config['MODELS_DIR']} ...")
        pipeline = Pipeline(app.config["MODELS_DIR"])
        if once:
            click.echo(f"Processed {queue.process_queued(pipeline)} prediction(s).")
        else:
            click.echo("Worker running. Ctrl+C to stop.")
            queue.run_forever(pipeline)

    @app.cli.command("requeue")
    @click.option("--all", "everything", is_flag=True, help="Every case, not only failed ones.")
    def requeue(everything):
        """Queue a fresh prediction for failed cases (or all), keeping the old rows."""
        count = 0
        for case in Case.query:
            latest = case.prediction
            if latest is not None and latest.state == QUEUED:
                continue
            if everything or latest is None or latest.state == FAILED:
                case.predictions.append(Prediction(state=QUEUED))
                count += 1
        db.session.commit()
        click.echo(f"Queued {count} prediction(s).")

    @app.cli.command("ensure-admin")
    def ensure_admin():
        """Deployment bootstrap: creates the admin named by LUNGCXR_ADMIN_EMAIL /
        LUNGCXR_ADMIN_PASSWORD (optional LUNGCXR_ADMIN_NAME) if no user has that
        email yet. Does nothing when either variable is unset, and never changes
        an existing account, so the password can be rotated in the app."""
        email = os.environ.get("LUNGCXR_ADMIN_EMAIL", "").strip().lower()
        password = os.environ.get("LUNGCXR_ADMIN_PASSWORD", "")
        if not email or not password:
            click.echo("ensure-admin: LUNGCXR_ADMIN_EMAIL/PASSWORD not set, skipping.")
            return
        if User.query.filter_by(email=email).first():
            click.echo(f"ensure-admin: {email} already exists.")
            return
        if len(password) < 8:
            raise click.ClickException("LUNGCXR_ADMIN_PASSWORD must be at least 8 characters.")
        name = os.environ.get("LUNGCXR_ADMIN_NAME", "Hospital Admin").strip() or "Hospital Admin"
        _add_user(email, name, ROLE_ADMIN, password)
        db.session.commit()
        click.echo(f"ensure-admin: created admin {email}")

    @app.cli.command("fetch-models")
    def fetch_models():
        """Downloads missing model files into MODELS_DIR from the URLs in
        LUNGCXR_SEGMENTER_URL and LUNGCXR_CLASSIFIER_URL (optionally checked
        against LUNGCXR_SEGMENTER_SHA256 / LUNGCXR_CLASSIFIER_SHA256). Files
        already present are kept, so a volume only downloads once."""
        from .ml.pipeline import CLASSIFIER_FILE, SEGMENTER_FILE

        models = pathlib.Path(app.config["MODELS_DIR"])
        models.mkdir(parents=True, exist_ok=True)
        for name, prefix in ((SEGMENTER_FILE, "SEGMENTER"), (CLASSIFIER_FILE, "CLASSIFIER")):
            target = models / name
            if target.is_file():
                click.echo(f"fetch-models: {name} present.")
                continue
            url = os.environ.get(f"LUNGCXR_{prefix}_URL", "").strip()
            if not url:
                click.echo(f"fetch-models: {name} missing and LUNGCXR_{prefix}_URL unset; "
                           "cases will wait for the model.")
                continue
            click.echo(f"fetch-models: downloading {name} ...")
            digest = hashlib.sha256()
            # Download beside the target, then rename, so a cut-off download
            # never leaves a half file that looks present next boot.
            with tempfile.NamedTemporaryFile(dir=models, delete=False) as part:
                with urllib.request.urlopen(url, timeout=60) as response:
                    while chunk := response.read(1 << 20):
                        part.write(chunk)
                        digest.update(chunk)
            expected = os.environ.get(f"LUNGCXR_{prefix}_SHA256", "").strip().lower()
            if expected and digest.hexdigest() != expected:
                os.unlink(part.name)
                raise click.ClickException(f"{name}: checksum mismatch, download discarded.")
            shutil.move(part.name, target)
            click.echo(f"fetch-models: saved {name} ({target.stat().st_size // 1_000_000} MB).")
