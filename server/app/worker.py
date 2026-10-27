"""Background worker: turns `queued` predictions into model readings."""

import pathlib
import time

from flask import current_app

from .extensions import db
from .models import DONE, FAILED, QUEUED, Case, Prediction


def process_queued(pipeline, limit=None, case_id=None):
    """Run the pipeline on queued predictions, oldest first. Returns how many were handled.

    With ``case_id`` the call is scoped to that case's queued prediction, so the
    inline run after an upload always answers the fresh case instead of an
    older backlog entry.
    """
    storage = pathlib.Path(current_app.config["STORAGE_DIR"])
    handled = 0
    targeted = case_id is not None
    while limit is None or handled < limit:
        if targeted:
            # Only this case: skip, not fall back to the backlog.
            prediction = Prediction.query.filter_by(
                state=QUEUED, case_id=case_id).order_by(Prediction.id).first()
        else:
            prediction = Prediction.query.filter_by(
                state=QUEUED).order_by(Prediction.id).first()
        if prediction is None:
            break
        case = db.session.get(Case, prediction.case_id)
        assert case is not None
        try:
            reading = pipeline.read(storage / case.image_path)
            mask_path = f"masks/{case.id}.png"
            overlay_path = f"overlays/{case.id}-{prediction.id}.png"
            for relative, image in ((mask_path, reading.mask), (overlay_path, reading.overlay)):
                (storage / relative).parent.mkdir(parents=True, exist_ok=True)
                image.save(storage / relative, format="PNG")
            prediction.label = reading.label
            prediction.tb_probability = reading.tb_probability
            prediction.mask_path = mask_path
            prediction.overlay_path = overlay_path
            prediction.state = DONE
        except Exception as error:  # one bad image must not stop the queue
            current_app.logger.warning(
                "Prediction %s failed: %s", prediction.id, error)
            prediction.state = FAILED
        prediction.model_version = current_app.config["MODEL_VERSION"]
        db.session.commit()
        handled += 1
    return handled


def run_forever(pipeline, poll_seconds=2.0):
    while True:
        if process_queued(pipeline) == 0:
            db.session.rollback()  # end the read transaction so new rows are seen
            time.sleep(poll_seconds)


_pipeline = None
_pipeline_dir = None


def run_model_inline(case_id, limit=1):
    """Run the model inside a request (headless, no worker step).

    The doctor then sees a finished reading instead of "Awaiting model".
    Scoped to one case, so an older backlog cannot steal the turn.
    Skipped in tests and when the model files are missing — the background
    worker picks those queued predictions up. Returns how many were handled.
    """
    if current_app.testing:
        return 0
    try:
        from .ml.pipeline import Pipeline
    except Exception:
        return 0  # torch not installed here; the worker handles it
    models_dir = current_app.config["MODELS_DIR"]
    global _pipeline, _pipeline_dir
    if _pipeline is None or _pipeline_dir != models_dir:
        try:
            _pipeline = Pipeline(models_dir)
        except Exception:
            _pipeline = None
            _pipeline_dir = None
            return 0  # no model files here; the worker handles it
        _pipeline_dir = models_dir
    try:
        return process_queued(_pipeline, limit=limit, case_id=case_id)
    except Exception:
        current_app.logger.warning("Inline model run failed.", exc_info=True)
        return 0
