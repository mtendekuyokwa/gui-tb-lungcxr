import hashlib
import pathlib

from app.models import User

API = "/api/v1"


def test_health_needs_no_token(client):
    assert client.get(f"{API}/health").json == {"status": "ok"}


def test_ensure_admin_creates_once(app, monkeypatch):
    runner = app.test_cli_runner()
    assert "skipping" in runner.invoke(args=["ensure-admin"]).output

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
