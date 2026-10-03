"""Background worker: turns `queued` predictions into model readings."""

import pathlib
import time

from flask import current_app

from .extensions import db
from .models import DONE, FAILED, QUEUED, Case, Prediction


def process_queued(pipeline, limit=None):
    """Run the pipeline on queued predictions, oldest first. Returns how many were handled."""
    storage = pathlib.Path(current_app.config["STORAGE_DIR"])
    handled = 0
    while limit is None or handled < limit:
        prediction = Prediction.query.filter_by(state=QUEUED).order_by(Prediction.id).first()
        if prediction is None:
            break
        case = db.session.get(Case, prediction.case_id)
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
            current_app.logger.warning("Prediction %s failed: %s", prediction.id, error)
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
