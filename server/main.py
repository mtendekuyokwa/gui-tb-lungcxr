"""Backend entry point for hosts that run `gunicorn main:app` with server/
as the working directory. See DEPLOY.md."""

from app.deploy import create_ready_app

app = create_ready_app()
