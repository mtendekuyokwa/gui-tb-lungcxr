import secrets

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
