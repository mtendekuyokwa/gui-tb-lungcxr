"""Case creation from an uploaded image, shared by admin and doctor routes.

Both roles upload through this module: an admin creates an unassigned case;
a doctor creates one that is assigned to them from the start.
"""

import pathlib

from flask import current_app
from PIL import Image, UnidentifiedImageError

from .errors import ApiError
from .extensions import db
from .models import ASSIGNED, Case, Hospital, Patient, Prediction, QUEUED, now
from .security import audit

UPLOAD_FORMATS = {"PNG", "JPEG"}


def read_image(upload):
    try:
        image = Image.open(upload.stream)
        if image.format not in UPLOAD_FORMATS:
            raise ApiError(422, "Image must be PNG or JPEG.")
        image.load()
    except (UnidentifiedImageError, OSError):
        raise ApiError(422, "Image must be PNG or JPEG.")
    if image.mode not in ("L", "RGB", "RGBA", "I", "I;16"):
        image = image.convert("RGB")
    return image


def save_png(image, case_id):
    relative = f"images/{case_id}.png"
    path = pathlib.Path(current_app.config["STORAGE_DIR"]) / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG")
    return relative


def read_hospital(form):
    """The optional ``hospital_id`` form field as a Hospital, or None."""
    raw = form.get("hospital_id", "").strip()
    if not raw:
        return None
    hospital = db.session.get(Hospital, int(raw)) if raw.isdigit() else None
    if hospital is None:
        raise ApiError(422, "'hospital_id' must be an existing hospital.")
    return hospital


def create_case(upload, form, assigned_to=None, assigned_by=None, note=None):
    """Validates and stores the upload, creates the patient and case, and —
    outside tests and with the model files present — runs the model inline.
    ``assigned_to`` makes it the receiver's case from creation on."""
    # Validated before any row is created, so a bad file leaves nothing behind.
    image = read_image(upload)
    hospital = read_hospital(form)
    hospital_number = form.get("hospital_number", "").strip() or None
    patient = (
        Patient.query.filter_by(hospital_number=hospital_number).first()
        if hospital_number
        else None
    )
    if patient is None:
        name = form.get("patient_name", "").strip()
        if not name:
            raise ApiError(
                422, "'patient_name' is required for a new patient.")
        birth_year = form.get("birth_year", "").strip()
        if birth_year and not birth_year.isdigit():
            raise ApiError(422, "'birth_year' must be a number.")
        patient = Patient(
            hospital_number=hospital_number,
            name=name,
            sex=form.get("sex", "").strip() or None,
            birth_year=int(birth_year) if birth_year else None,
        )
        db.session.add(patient)

    case = Case(patient=patient, hospital=hospital)
    if assigned_to is not None:
        case.assigned_to = assigned_to
        case.assigned_by = assigned_by
        case.assigned_at = now()
        case.status = ASSIGNED
    db.session.add(case)
    db.session.flush()  # assigns case.id, which names the stored file
    case.image_path = save_png(image, case.id)
    # Headless: run the model in this request so the doctor already sees
    # the reading. Falls back to queued when models are missing (tests,
    # or the worker drains it later).
    case.predictions.append(Prediction(state=QUEUED))
    audit(case, "created", note)
    db.session.commit()
    from .worker import run_model_inline

    run_model_inline(case.id)
    return db.session.get(Case, case.id)
