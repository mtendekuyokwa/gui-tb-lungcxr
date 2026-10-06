import os
import pathlib

from flask import Flask, jsonify
from flask_cors import CORS
from werkzeug.exceptions import HTTPException

from .errors import ApiError
from .extensions import db

SERVER_DIR = pathlib.Path(__file__).resolve().parent.parent
DEV_SECRET = "dev-only-secret-change-me-before-deploying"


def create_app(config=None):
    app = Flask(__name__, instance_path=str(SERVER_DIR / "instance"))
    app.config.update(
        SECRET_KEY=os.environ.get("LUNGCXR_SECRET_KEY", DEV_SECRET),
        SQLALCHEMY_DATABASE_URI=os.environ.get(
            "LUNGCXR_DATABASE_URI", f"sqlite:///{SERVER_DIR / 'instance' / 'lungcxr.db'}"
        ),
        STORAGE_DIR=os.environ.get("LUNGCXR_STORAGE_DIR", str(SERVER_DIR / "storage")),
        MODELS_DIR=os.environ.get("LUNGCXR_MODELS_DIR", str(SERVER_DIR / "models")),
        MODEL_VERSION="tb-resnet18-seg512-v1",
        TOKEN_HOURS=8,
        MAX_CONTENT_LENGTH=50 * 1024 * 1024,
        CORS_ORIGINS=os.environ.get("LUNGCXR_CORS_ORIGINS", "*"),
    )
    if config:
        app.config.update(config)

    if app.config["SECRET_KEY"] == DEV_SECRET and not (app.debug or app.testing):
        app.logger.warning("LUNGCXR_SECRET_KEY is not set; using the development secret.")

    pathlib.Path(app.instance_path).mkdir(parents=True, exist_ok=True)
    pathlib.Path(app.config["STORAGE_DIR"]).mkdir(parents=True, exist_ok=True)

    db.init_app(app)
    CORS(app, resources={r"/api/*": {"origins": app.config["CORS_ORIGINS"]}})

    from . import admin, auth, cases, cli

    app.register_blueprint(auth.bp, url_prefix="/api/v1")
    app.register_blueprint(cases.bp, url_prefix="/api/v1")
    app.register_blueprint(admin.bp, url_prefix="/api/v1/admin")
    cli.register(app)

    @app.errorhandler(ApiError)
    def handle_api_error(err):
        db.session.rollback()
        return jsonify(error=err.message), err.status

    @app.errorhandler(HTTPException)
    def handle_http_error(err):
        return jsonify(error=err.description), err.code

    return app
