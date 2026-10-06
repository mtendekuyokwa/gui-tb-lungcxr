"""Doctor-facing routes: my cases, the image, and my review."""

import pathlib

from flask import Blueprint, current_app, g, jsonify, request, send_file

from . import catalog
from .errors import ApiError
from .extensions import db
from .models import (
    ASSIGNED,
    CASE_STATUSES,
    DONE,
    DRAFT,
    IN_REVIEW,
    OPEN_STATUSES,
    ROLE_ADMIN,
    ROLE_DOCTOR,
    SUBMITTED,
    Case,
    DiseaseTag,
    Mark,
    ModelFeedback,
    Review,
    TestRequest,
    now,
)
from .security import audit, json_body, login_required

bp = Blueprint("cases", __name__)


def _my_case(case_id):
    """The case if it is assigned to the signed-in doctor, else 404 so IDs can't be probed."""
    case = db.session.get(Case, case_id)
    if case is None or case.assigned_to != g.user.id:
        raise ApiError(404, "Case not found.")
    return case


def _viewable_case(case_id):
    case = db.session.get(Case, case_id)
    if case is None or (g.user.role != ROLE_ADMIN and case.assigned_to != g.user.id):
        raise ApiError(404, "Case not found.")
    return case


def _detail(case):
    review = case.review_by(g.user.id)
    # The admin's reason for the latest return, so the doctor knows what to fix.
    returns = [entry.note for entry in case.audit if entry.action == "returned"]
    return {
        **case.to_dict(),
        "review": review.to_dict() if review else None,
        "return_note": returns[-1] if returns and case.status != SUBMITTED else None,
    }


def _send_stored(relative_path):
    if not relative_path:
        raise ApiError(404, "File not available.")
    path = pathlib.Path(current_app.config["STORAGE_DIR"]) / relative_path
    if not path.is_file():
        raise ApiError(404, "File not available.")
    return send_file(path, mimetype="image/png", max_age=0)


@bp.get("/cases")
@login_required(ROLE_DOCTOR)
def list_cases():
    query = Case.query.filter_by(assigned_to=g.user.id)
    status = request.args.get("status")
    if status:
        if status not in CASE_STATUSES:
            raise ApiError(400, "Unknown status.")
        query = query.filter_by(status=status)
    return jsonify([c.to_dict() for c in query.order_by(Case.id.desc())])


@bp.get("/cases/<int:case_id>")
@login_required(ROLE_DOCTOR)
def get_case(case_id):
    case = _my_case(case_id)
    if case.status == ASSIGNED:
        case.status = IN_REVIEW
        audit(case, "opened")
        db.session.commit()
    return jsonify(_detail(case))


@bp.get("/cases/<int:case_id>/image")
@login_required()
def get_image(case_id):
    return _send_stored(_viewable_case(case_id).image_path)


@bp.get("/cases/<int:case_id>/overlay")
@login_required()
def get_overlay(case_id):
    prediction = _viewable_case(case_id).prediction
    return _send_stored(prediction.overlay_path if prediction else None)


def _text(value, field, limit=4000):
    if value is None:
        return ""
    if not isinstance(value, str) or len(value) > limit:
        raise ApiError(422, f"'{field}' must be text of at most {limit} characters.")
    return value.strip()


def _code(value, allowed, field):
    if not isinstance(value, str) or value not in allowed:
        raise ApiError(422, f"Unknown {field}: {value!r}.")
    return value


def _parse_marks(raw):
    if not isinstance(raw, list):
        raise ApiError(422, "'marks' must be a list.")
    marks = []
    for item in raw:
        if not isinstance(item, dict):
            raise ApiError(422, "Each mark must be an object.")
        finding = item.get("finding")
        if finding is not None:
            _code(finding, catalog.FINDINGS, "finding")
        points = item.get("points")
        if not isinstance(points, list) or not points:
            raise ApiError(422, "Each mark needs a non-empty 'points' list.")
        clean = []
        for point in points:
            ok = (
                isinstance(point, list)
                and len(point) == 2
                and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in point)
                and all(0 <= v <= 1 for v in point)
            )
            if not ok:
                raise ApiError(422, "Mark points must be [x, y] pairs between 0 and 1.")
            clean.append([float(point[0]), float(point[1])])
        marks.append(Mark(points=clean, finding_code=finding))
    return marks


def _parse_disease_tags(raw):
    if not isinstance(raw, list):
        raise ApiError(422, "'disease_tags' must be a list.")
    tags = []
    for item in raw:
        if isinstance(item, str):
            item = {"code": item}
        if not isinstance(item, dict):
            raise ApiError(422, "Each disease tag must be a code or an object.")
        tags.append(
            DiseaseTag(
                disease_code=_code(item.get("code"), catalog.DISEASES, "disease"),
                free_text=_text(item.get("free_text"), "free_text", 255),
            )
        )
    return tags


def _parse_tests(raw):
    if raw is None:
        return []
    if not isinstance(raw, dict):
        raise ApiError(422, "'further_testing' must be an object or null.")
    tests = raw.get("tests")
    if not isinstance(tests, list) or not tests:
        raise ApiError(422, "'further_testing.tests' must list at least one test.")
    urgency = _code(raw.get("urgency", "routine"), catalog.URGENCIES, "urgency")
    free_text = _text(raw.get("free_text"), "free_text", 255)
    return [
        TestRequest(test_code=_code(t, catalog.TESTS, "test"), urgency=urgency, free_text=free_text)
        for t in dict.fromkeys(tests)
    ]


def _apply_feedback(review, raw, prediction):
    if raw is None:
        review.feedback = None
        return
    if not isinstance(raw, dict):
        raise ApiError(422, "'model_feedback' must be an object or null.")
    kind = _code(raw.get("kind"), catalog.FEEDBACK_KINDS, "feedback kind")
    note = _text(raw.get("note"), "model_feedback.note")
    # Updated in place: review_id is unique, so replacing the row could collide on flush.
    feedback = review.feedback or ModelFeedback()
    feedback.kind = kind
    feedback.note = note
    feedback.derived = False
    feedback.prediction_id = prediction.id if prediction else None
    review.feedback = feedback


def _derive_feedback(review, prediction):
    """On submit, record a model error the doctor implied but did not flag."""
    if review.feedback is not None and not review.feedback.derived:
        return
    kind = None
    if prediction is not None and prediction.state == DONE:
        if prediction.label == catalog.LABEL_TB and review.verdict == "no_tb":
            kind = "false_positive"
        elif prediction.label == catalog.LABEL_NORMAL and review.verdict == "tb_suspected":
            kind = "false_negative"
    if kind is None:
        review.feedback = None
        return
    feedback = review.feedback or ModelFeedback()
    feedback.kind = kind
    feedback.note = ""
    feedback.derived = True
    feedback.prediction_id = prediction.id
    review.feedback = feedback


@bp.put("/cases/<int:case_id>/review")
@login_required(ROLE_DOCTOR)
def save_review(case_id):
    case = _my_case(case_id)
    if case.status not in OPEN_STATUSES:
        raise ApiError(409, "This case is not open for editing.")
    data = json_body()

    verdict = data.get("verdict")
    if verdict is not None:
        _code(verdict, catalog.VERDICTS, "verdict")
    note = _text(data.get("note"), "note")
    marks = _parse_marks(data.get("marks", []))
    tags = _parse_disease_tags(data.get("disease_tags", []))
    tests = _parse_tests(data.get("further_testing"))

    review = case.review_by(g.user.id)
    if review is None:
        review = Review(case=case, doctor_id=g.user.id)
        db.session.add(review)
    review.verdict = verdict
    review.note = note
    review.marks = marks
    review.disease_tags = tags
    review.test_requests = tests
    review.updated_at = now()
    _apply_feedback(review, data.get("model_feedback"), case.prediction)

    if case.status != IN_REVIEW:
        case.status = IN_REVIEW
        audit(case, "review_started")
    db.session.commit()
    return jsonify(_detail(case))


@bp.post("/cases/<int:case_id>/review/submit")
@login_required(ROLE_DOCTOR)
def submit_review(case_id):
    case = _my_case(case_id)
    if case.status not in OPEN_STATUSES:
        raise ApiError(409, "This case is not open for editing.")
    review = case.review_by(g.user.id)
    if review is None or review.verdict is None:
        raise ApiError(422, "A verdict is required before submitting.")
    if review.verdict == "other_disease" and not review.disease_tags:
        raise ApiError(422, "Tag at least one disease for 'Other disease suspected'.")

    _derive_feedback(review, case.prediction)
    review.state = SUBMITTED
    review.submitted_at = now()
    case.status = SUBMITTED
    audit(case, "submitted")
    db.session.commit()
    return jsonify(_detail(case))


def reopen(review):
    """Used when the admin returns a case."""
    review.state = DRAFT
    review.submitted_at = None
