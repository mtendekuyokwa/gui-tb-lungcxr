import os
import pathlib

import numpy as np
import pytest
from PIL import Image

from app import worker
from app.extensions import db
from app.models import Case

from conftest import assign, upload

API = "/api/v1"
MODELS_DIR = pathlib.Path(__file__).resolve().parent.parent / "models"


class FakeReading:
    label = "tb"
    tb_probability = 0.91
    mask = Image.new("L", (32, 32), 255)
    overlay = Image.new("RGBA", (512, 512), (255, 0, 0, 128))


class FakePipeline:
    def __init__(self, fail_on=()):
        self.fail_on = set(fail_on)
        self.seen = []
        self.masks = []

    def read(self, image_path, mask_path=None):
        case_id = int(pathlib.Path(image_path).stem)
        self.seen.append(case_id)
        self.masks.append(mask_path)
        if case_id in self.fail_on:
            raise ValueError("unreadable")
        return FakeReading()


def test_worker_stores_reading_and_serves_overlay(app, client, admin, doc1):
    first = upload(client, admin)
    second = upload(client, admin, name="Other")
    assign(client, admin, [first], "doc1@test")
    pipeline = FakePipeline()
    assert worker.process_queued(pipeline) == 2
    assert pipeline.seen == [first, second]  # oldest first
    assert worker.process_queued(pipeline) == 0  # nothing left queued

    case = client.get(f"{API}/cases/{first}", headers=doc1).json
    assert case["prediction"] == {
        "id": case["prediction"]["id"],
        "state": "done",
        "model_version": app.config["MODEL_VERSION"],
        "label": "tb",
        "tb_probability": 0.91,
        "has_overlay": True,
        "has_mask": True,
        "edited_mask": False,
    }
    overlay = client.get(f"{API}/cases/{first}/overlay", headers=doc1)
    assert overlay.status_code == 200 and overlay.data[:4] == b"\x89PNG"
    mask = client.get(f"{API}/cases/{first}/mask", headers=doc1)
    assert mask.status_code == 200 and mask.data[:4] == b"\x89PNG"
    storage = pathlib.Path(app.config["STORAGE_DIR"])
    assert (storage / f"masks/{first}.png").is_file()

    # The stored reading now drives derived feedback and the agreement rate.
    client.put(f"{API}/cases/{first}/review", headers=doc1, json={"verdict": "no_tb"})
    review = client.post(f"{API}/cases/{first}/review/submit", headers=doc1).json["review"]
    assert review["model_feedback"]["kind"] == "false_positive"
    stats = client.get(f"{API}/admin/stats", headers=admin).json
    assert stats["model_agreement"] == {"compared": 1, "agreed": 0, "rate": 0.0}


def test_one_failed_image_does_not_stop_the_queue(app, client, admin):
    bad = upload(client, admin)
    good = upload(client, admin, name="Other")
    assert worker.process_queued(FakePipeline(fail_on=[bad])) == 2
    assert db.session.get(Case, bad).prediction.state == "failed"
    assert db.session.get(Case, bad).prediction.overlay_path is None
    assert db.session.get(Case, good).prediction.state == "done"
    assert client.get(f"{API}/cases/{bad}/overlay", headers=admin).status_code == 404


def test_requeue_adds_a_new_prediction_and_keeps_history(app, client, admin):
    cid = upload(client, admin)
    worker.process_queued(FakePipeline(fail_on=[cid]))
    runner = app.test_cli_runner()
    assert "Queued 1" in runner.invoke(args=["requeue"]).output
    assert "Queued 0" in runner.invoke(args=["requeue"]).output  # already queued
    worker.process_queued(FakePipeline())
    case = db.session.get(Case, cid)
    assert [p.state for p in case.predictions] == ["failed", "done"]
    assert case.prediction.overlay_path == f"overlays/{cid}-{case.prediction.id}.png"


needs_models = pytest.mark.skipif(
    not (MODELS_DIR / "tb_classifier.pth").is_file(), reason="model files not in server/models"
)


@pytest.fixture(scope="module")
def pipeline():
    from app.ml.pipeline import Pipeline

    return Pipeline(MODELS_DIR)


@needs_models
def test_real_models_reject_images_without_lungs(pipeline, tmp_path):
    from app.ml.pipeline import ModelError

    blank = tmp_path / "blank.png"
    Image.new("L", (64, 64), 0).save(blank)
    # Smooth blobs are not anatomy: the segmenter finds no lungs in them either.
    y, x = np.mgrid[0:300, 0:260]
    blobs = 90 + 130 * np.exp(-(((x - 130) / 150) ** 2 + ((y - 150) / 180) ** 2))
    drawn = tmp_path / "drawn.png"
    Image.fromarray(np.clip(blobs, 0, 255).astype(np.uint8)).save(drawn)
    for path in (blank, drawn):
        with pytest.raises(ModelError):
            pipeline.read(path)


@needs_models
@pytest.mark.skipif(
    "LUNGCXR_TEST_CXR" not in os.environ,
    reason="set LUNGCXR_TEST_CXR to a real chest X-ray file to run the models on it",
)
def test_real_models_read_a_chest_xray(pipeline):
    path = os.environ["LUNGCXR_TEST_CXR"]
    reading = pipeline.read(path)
    with Image.open(path) as image:
        size = image.size
    assert reading.label in ("tb", "normal")
    assert 0.0 <= reading.tb_probability <= 1.0
    assert (reading.label == "tb") == (reading.tb_probability > 0.5)
    assert reading.mask.size == size and reading.mask.mode == "L"
    lung_fraction = np.asarray(reading.mask).mean() / 255
    assert 0.15 < lung_fraction < 0.75
    assert reading.overlay.size == (512, 512) and reading.overlay.mode == "RGBA"
    assert np.asarray(reading.overlay)[..., 3].max() > 0
    again = pipeline.read(path)
    assert again.tb_probability == pytest.approx(reading.tb_probability, abs=1e-5)


def test_reevaluate_classifies_with_the_corrected_mask(app, client, admin, doc1):
    cid = upload(client, admin)
    assign(client, admin, [cid], "doc1@test")
    worker.process_queued(FakePipeline())
    url = f"{API}/cases/{cid}"
    # Nothing corrected yet.
    assert client.post(f"{url}/reevaluate", headers=doc1).status_code == 422

    # Erase the whole left half of the (all-lung) fake mask.
    erase = {"kind": "erase", "tool": "brush", "width": 0.2,
             "points": [[0.1, y / 10] for y in range(11)] + [[0.4, y / 10] for y in range(11)]}
    client.put(f"{url}/review", headers=doc1, json={"mask_edits": [erase]})
    case = client.post(f"{url}/reevaluate", headers=doc1).json
    assert case["prediction"]["state"] == "queued"
    assert case["prediction"]["edited_mask"] is True
    assert case["review"]["mask_edits"] == []  # baked into the new mask

    pipeline = FakePipeline()
    assert worker.process_queued(pipeline) == 1
    storage = pathlib.Path(app.config["STORAGE_DIR"])
    prediction = db.session.get(Case, cid).prediction
    assert pipeline.masks == [storage / prediction.input_mask_path]
    assert prediction.mask_path == prediction.input_mask_path
    assert (storage / f"masks/{cid}.png").is_file()  # the model mask is kept
    with Image.open(storage / prediction.mask_path) as baked:
        pixels = np.asarray(baked)
    assert pixels[16, 2] == 0 and pixels[16, 30] == 255
    assert [p.state for p in db.session.get(Case, cid).predictions] == ["done", "done"]
    assert client.get(f"{url}/mask", headers=doc1).status_code == 200


def test_reevaluate_needs_a_finished_mask(client, admin, doc1):
    cid = upload(client, admin)
    assign(client, admin, [cid], "doc1@test")
    edit = {"kind": "add", "tool": "pen", "width": 0.01, "points": [[0.5, 0.5]]}
    client.put(f"{API}/cases/{cid}/review", headers=doc1, json={"mask_edits": [edit]})
    assert client.post(f"{API}/cases/{cid}/reevaluate", headers=doc1).status_code == 409
