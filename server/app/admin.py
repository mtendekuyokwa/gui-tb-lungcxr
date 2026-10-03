"""Admin routes: users, uploading and assigning cases, closing reviews, exports."""

import csv
import io
import json
import pathlib
from datetime import datetime, timezone

from flask import Blueprint, Response, current_app, g, jsonify, request
from PIL import Image, UnidentifiedImageError
from sqlalchemy import func

from .cases import reopen
from .errors import ApiError
from .extensions import db
from .models import (
    ACCEPTED,
    ASSIGNED,
    CASE_STATUSES,
    DONE,
    OPEN_STATUSES,
    QUEUED,
    RETURNED,
    ROLE_ADMIN,
    ROLE_DOCTOR,
    SUBMITTED,
    UNASSIGNED,
    Case,
    ModelFeedback,
    Patient,
    Prediction,
    Review,
    TestRequest,
    User,
    iso,
    now,
)
from .security import audit, json_body, login_required

bp = Blueprint("admin", __name__)

MIN_PASSWORD = 8
UPLOAD_FORMATS = {"PNG", "JPEG"}


# --- users -----------------------------------------------------------------


def _password(value):
    if not isinstance(value, str) or len(value) < MIN_PASSWORD:
        raise ApiError(422, f"Password must be at least {MIN_PASSWORD} characters.")
    return value


def _name(value):
    if not isinstance(value, str) or not value.strip():
        raise ApiError(422, "'full_name' is required.")
    return value.strip()


@bp.get("/users")
@login_required(ROLE_ADMIN)
def list_users():
    return jsonify([u.to_dict() for u in User.query.order_by(User.full_name)])


@bp.post("/users")
@login_required(ROLE_ADMIN)
def create_user():
    data = json_body()
    email = str(data.get("email", "")).strip().lower()
    if "@" not in email:
        raise ApiError(422, "A valid 'email' is required.")
    role = data.get("role", ROLE_DOCTOR)
    if role not in (ROLE_ADMIN, ROLE_DOCTOR):
        raise ApiError(422, "'role' must be 'admin' or 'doctor'.")
    if User.query.filter_by(email=email).first():
        raise ApiError(409, "A user with this email already exists.")
    user = User(email=email, full_name=_name(data.get("full_name")), role=role)
    user.set_password(_password(data.get("password")))
    db.session.add(user)
    db.session.commit()
    return jsonify(user.to_dict()), 201


@bp.patch("/users/<int:user_id>")
@login_required(ROLE_ADMIN)
def update_user(user_id):
    user = db.session.get(User, user_id)
    if user is None:
        raise ApiError(404, "User not found.")
    data = json_body()
    if "active" in data:
        if not isinstance(data["active"], bool):
            raise ApiError(422, "'active' must be true or false.")
        if user.id == g.user.id and not data["active"]:
            raise ApiError(409, "You cannot deactivate your own account.")
        user.active = data["active"]
    if "full_name" in data:
        user.full_name = _name(data["full_name"])
    if "password" in data:
        user.set_password(_password(data["password"]))
    db.session.commit()
    return jsonify(user.to_dict())


# --- cases -----------------------------------------------------------------


def _case_or_404(case_id):
    case = db.session.get(Case, case_id)
    if case is None:
        raise ApiError(404, "Case not found.")
    return case


def _summary(case):
    review = case.current_review
    return {
        **case.to_dict(),
        "verdict": review.verdict if review else None,
        "model_wrong": bool(review and review.feedback),
        "needs_testing": bool(review and review.test_requests),
    }


def _read_image(upload):
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


def _save_png(image, case_id):
    relative = f"images/{case_id}.png"
    path = pathlib.Path(current_app.config["STORAGE_DIR"]) / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG")
    return relative


@bp.post("/cases")
@login_required(ROLE_ADMIN)
def create_case():
    upload = request.files.get("image")
    if upload is None:
        raise ApiError(422, "An 'image' file is required.")
    # Validated before any row is created, so a bad file leaves nothing behind.
    image = _read_image(upload)
    form = request.form
    hospital_number = form.get("hospital_number", "").strip() or None
    patient = (
        Patient.query.filter_by(hospital_number=hospital_number).first()
        if hospital_number
        else None
    )
    if patient is None:
        name = form.get("patient_name", "").strip()
        if not name:
            raise ApiError(422, "'patient_name' is required for a new patient.")
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

    case = Case(patient=patient)
    db.session.add(case)
    db.session.flush()  # assigns case.id, which names the stored file
    case.image_path = _save_png(image, case.id)
    # The model worker (not built yet) picks up queued predictions.
    case.predictions.append(Prediction(state=QUEUED))
    audit(case, "created")
    db.session.commit()
    return jsonify(_summary(case)), 201


@bp.get("/cases")
@login_required(ROLE_ADMIN)
def list_cases():
    query = Case.query
    status = request.args.get("status")
    if status:
        if status not in CASE_STATUSES:
            raise ApiError(400, "Unknown status.")
        query = query.filter(Case.status == status)
    doctor = request.args.get("doctor")
    if doctor:
        if not doctor.isdigit():
            raise ApiError(400, "'doctor' must be a user id.")
        query = query.filter(Case.assigned_to == int(doctor))
    flag = request.args.get("flag")
    if flag:
        flagged = {"model_wrong": ModelFeedback, "needs_testing": TestRequest}.get(flag)
        if flagged is None:
            raise ApiError(400, "'flag' must be 'model_wrong' or 'needs_testing'.")
        # Only the current assignee's review counts, not an earlier doctor's draft.
        query = query.filter(
            Review.query.join(flagged, flagged.review_id == Review.id)
            .filter(Review.case_id == Case.id, Review.doctor_id == Case.assigned_to)
            .exists()
        )
    return jsonify([_summary(c) for c in query.order_by(Case.id.desc())])


@bp.get("/cases/<int:case_id>")
@login_required(ROLE_ADMIN)
def get_case(case_id):
    case = _case_or_404(case_id)
    review = case.current_review
    return jsonify(
        {
            **_summary(case),
            "review": review.to_dict() if review else None,
            "audit": [entry.to_dict() for entry in case.audit],
        }
    )


def _parse_due(value):
    if value is None:
        return None
    try:
        due = datetime.fromisoformat(str(value))
    except ValueError:
        raise ApiError(422, "'due_at' must be an ISO 8601 date-time.")
    return due if due.tzinfo else due.replace(tzinfo=timezone.utc)


@bp.post("/cases/assign")
@login_required(ROLE_ADMIN)
def assign_cases():
    data = json_body()
    case_ids = data.get("case_ids")
    if (
        not isinstance(case_ids, list)
        or not case_ids
        or not all(isinstance(i, int) and not isinstance(i, bool) for i in case_ids)
    ):
        raise ApiError(422, "'case_ids' must be a non-empty list of case ids.")
    doctor_id = data.get("doctor_id")
    doctor = db.session.get(User, doctor_id) if isinstance(doctor_id, int) else None
    if doctor is None or doctor.role != ROLE_DOCTOR or not doctor.active:
        raise ApiError(422, "'doctor_id' must be an active doctor.")
    due_at = _parse_due(data.get("due_at"))

    cases = Case.query.filter(Case.id.in_(set(case_ids))).all()
    if len(cases) != len(set(case_ids)):
        raise ApiError(404, "One or more cases were not found.")
    # Checked up front so a bulk assignment is all or nothing.
    locked = [c.id for c in cases if c.status not in (UNASSIGNED, *OPEN_STATUSES)]
    if locked:
        raise ApiError(409, f"Cases already submitted or accepted cannot be reassigned: {locked}.")

    for case in cases:
        if case.assigned_to == doctor.id:
            if due_at is not None:
                case.due_at = due_at
            continue
        action = "assigned" if case.assigned_to is None else "reassigned"
        case.assigned_to = doctor.id
        case.assigned_by = g.user.id
        case.assigned_at = now()
        case.due_at = due_at
        case.status = ASSIGNED
        audit(case, action, f"to {doctor.full_name}")
    db.session.commit()
    return jsonify([_summary(c) for c in cases])


@bp.post("/cases/<int:case_id>/accept")
@login_required(ROLE_ADMIN)
def accept_case(case_id):
    case = _case_or_404(case_id)
    if case.status != SUBMITTED:
        raise ApiError(409, "Only a submitted case can be accepted.")
    case.status = ACCEPTED
    audit(case, "accepted")
    db.session.commit()
    return jsonify(_summary(case))


@bp.post("/cases/<int:case_id>/return")
@login_required(ROLE_ADMIN)
def return_case(case_id):
    case = _case_or_404(case_id)
    if case.status != SUBMITTED:
        raise ApiError(409, "Only a submitted case can be returned.")
    note = json_body().get("note")
    if not isinstance(note, str) or not note.strip():
        raise ApiError(422, "A 'note' explaining the return is required.")
    case.status = RETURNED
    reopen(case.current_review)
    audit(case, "returned", note.strip())
    db.session.commit()
    return jsonify(_summary(case))


# --- export and stats --------------------------------------------------------


def _cell(value):
    """Stop spreadsheet apps from running free text as a formula."""
    if isinstance(value, str) and value[:1] in ("=", "+", "-", "@"):
        return "'" + value
    return value


def _csv_response(name, header, rows):
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(header)
    for row in rows:
        writer.writerow([_cell(v) for v in row])
    return Response(
        buffer.getvalue(),
        mimetype="text/csv",
        headers={"Content-Disposition": f"attachment; filename={name}.csv"},
    )


def _submitted_reviews():
    return Review.query.filter_by(state=SUBMITTED).order_by(Review.case_id)


@bp.get("/export")
@login_required(ROLE_ADMIN)
def export():
    """CSV exports. Patient name and hospital number are deliberately left out."""
    kind = request.args.get("kind", "reviews")
    if kind == "reviews":
        header = [
            "case_id", "doctor_id", "case_status", "verdict", "note", "marks", "findings",
            "disease_tags", "model_label", "tb_probability", "feedback_kind", "tests",
            "urgency", "submitted_at",
        ]
        rows = []
        for r in _submitted_reviews():
            p = r.case.prediction
            rows.append([
                r.case_id, r.doctor_id, r.case.status, r.verdict, r.note, len(r.marks),
                ";".join(sorted({m.finding_code for m in r.marks if m.finding_code})),
                ";".join(t.disease_code for t in r.disease_tags),
                p.label if p else None, p.tb_probability if p else None,
                r.feedback.kind if r.feedback else None,
                ";".join(t.test_code for t in r.test_requests),
                r.test_requests[0].urgency if r.test_requests else None,
                iso(r.submitted_at),
            ])
        return _csv_response("reviews", header, rows)
    if kind == "model_feedback":
        header = [
            "case_id", "doctor_id", "prediction_id", "model_version", "model_label",
            "tb_probability", "feedback_kind", "derived", "feedback_note", "verdict", "marks",
        ]
        rows = []
        for r in _submitted_reviews().join(ModelFeedback):
            p = r.feedback.prediction
            rows.append([
                r.case_id, r.doctor_id, r.feedback.prediction_id,
                p.model_version if p else None, p.label if p else None,
                p.tb_probability if p else None, r.feedback.kind, r.feedback.derived,
                r.feedback.note, r.verdict,
                json.dumps([{"finding": m.finding_code, "points": m.points} for m in r.marks]),
            ])
        return _csv_response("model_feedback", header, rows)
    raise ApiError(400, "'kind' must be 'reviews' or 'model_feedback'.")


@bp.get("/stats")
@login_required(ROLE_ADMIN)
def stats():
    counts = dict(db.session.query(Case.status, func.count()).group_by(Case.status).all())
    by_status = {status: counts.get(status, 0) for status in CASE_STATUSES}

    workload = {}
    rows = (
        db.session.query(Case.assigned_to, Case.status, func.count())
        .filter(Case.assigned_to.isnot(None))
        .group_by(Case.assigned_to, Case.status)
    )
    for doctor_id, status, count in rows:
        entry = workload.setdefault(doctor_id, {"open": 0, "submitted": 0, "accepted": 0})
        entry["open" if status in OPEN_STATUSES else status] += count
    doctors = [
        {"doctor": u.to_dict(), **workload.get(u.id, {"open": 0, "submitted": 0, "accepted": 0})}
        for u in User.query.filter_by(role=ROLE_DOCTOR).order_by(User.full_name)
    ]

    # Agreement only where both sides gave a TB / not-TB answer.
    compared = agreed = 0
    for review in _submitted_reviews():
        prediction = review.case.prediction
        if prediction is None or prediction.state != DONE:
            continue
        if review.verdict not in ("tb_suspected", "no_tb"):
            continue
        compared += 1
        agreed += (prediction.label == "tb") == (review.verdict == "tb_suspected")
    return jsonify(
        by_status=by_status,
        doctors=doctors,
        model_agreement={
            "compared": compared,
            "agreed": agreed,
            "rate": agreed / compared if compared else None,
        },
    )
