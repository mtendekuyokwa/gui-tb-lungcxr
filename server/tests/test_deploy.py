import hashlib
import pathlib

from app.models import User

API = "/api/v1"


def test_health_needs_no_token(client):
    assert client.get(f"{API}/health").json == {"status": "ok"}


def test_ensure_admin_creates_once(app, monkeypatch):
    runner = app.test_cli_runner()
    # Users exist (the fixture's), so without variables nothing happens.
    assert "nothing to do" in runner.invoke(args=["ensure-admin"]).output

    monkeypatch.setenv("LUNGCXR_ADMIN_EMAIL", "Boss@Hospital.org")
    monkeypatch.setenv("LUNGCXR_ADMIN_PASSWORD", "long-enough-pw")
    assert "created admin boss@hospital.org" in runner.invoke(args=["ensure-admin"]).output
    user = User.query.filter_by(email="boss@hospital.org").one()
    assert user.role == "admin" and user.check_password("long-enough-pw")

    # A second boot never touches the existing account.
    monkeypatch.setenv("LUNGCXR_ADMIN_PASSWORD", "another-password")
    assert "already exists" in runner.invoke(args=["ensure-admin"]).output
    assert user.check_password("long-enough-pw")


def test_fetch_models_downloads_missing_files_once(app, tmp_path, monkeypatch):
    models = tmp_path / "models"
    app.config["MODELS_DIR"] = str(models)
    source = tmp_path / "weights.bin"
    source.write_bytes(b"weights" * 1000)
    monkeypatch.setenv("LUNGCXR_SEGMENTER_URL", source.as_uri())
    monkeypatch.setenv("LUNGCXR_CLASSIFIER_URL", source.as_uri())
    monkeypatch.setenv("LUNGCXR_CLASSIFIER_SHA256", hashlib.sha256(source.read_bytes()).hexdigest())

    runner = app.test_cli_runner()
    result = runner.invoke(args=["fetch-models"])
    assert result.exit_code == 0, result.output
    assert sorted(p.name for p in models.iterdir()) == [
        "cxr_lung_segment_including_heart_512.pt", "tb_classifier.pth"]
    assert "present" in runner.invoke(args=["fetch-models"]).output


def test_fetch_models_rejects_a_bad_checksum(app, tmp_path, monkeypatch):
    models = tmp_path / "models"
    app.config["MODELS_DIR"] = str(models)
    source = tmp_path / "weights.bin"
    source.write_bytes(b"tampered")
    monkeypatch.setenv("LUNGCXR_SEGMENTER_URL", source.as_uri())
    monkeypatch.setenv("LUNGCXR_SEGMENTER_SHA256", "0" * 64)
    result = app.test_cli_runner().invoke(args=["fetch-models"])
    assert result.exit_code != 0 and "checksum mismatch" in result.output
    assert not any(pathlib.Path(models).iterdir())  # no half file left behind


def test_first_boot_without_variables_creates_a_random_admin(app, tmp_path, monkeypatch):
    from app import deploy
    from app.extensions import db

    with app.app_context():
        User.query.delete()
        db.session.commit()
    monkeypatch.setenv("LUNGCXR_INSTANCE_DIR", str(tmp_path))
    deploy.ensure_admin(app, log=lambda _: None)
    email, password = (tmp_path / "initial-admin.txt").read_text().split()
    with app.app_context():
        assert User.query.filter_by(email=email).one().check_password(password)


def test_secret_is_generated_once_and_reused(tmp_path, monkeypatch):
    from app import deploy

    secret_file = tmp_path / "secret_key"
    monkeypatch.delenv("LUNGCXR_SECRET_KEY", raising=False)
    monkeypatch.setenv("LUNGCXR_SECRET_FILE", str(secret_file))
    deploy.ensure_secret()
    first = secret_file.read_text()
    monkeypatch.delenv("LUNGCXR_SECRET_KEY")
    deploy.ensure_secret()
    assert len(first) > 40 and secret_file.read_text() == first
    import os
    assert os.environ["LUNGCXR_SECRET_KEY"] == first
