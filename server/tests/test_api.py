import csv
import io

from app.extensions import db
from app.models import DONE, Case, Prediction

from conftest import PASSWORD, assign, login, png_bytes, upload, user_id

API = "/api/v1"
REVIEW = {
    "verdict": "tb_suspected",
    "note": "Right upper zone cavity.",
    "marks": [{"finding": "cavity", "note": "Cavity, right upper zone.", "points": [[0.62, 0.21], [0.64, 0.23]]}],
    "model_feedback": {"kind": "wrong_region", "note": "Heatmap on the heart."},
    "further_testing": {"tests": ["genexpert", "culture"], "urgency": "urgent"},
}


def set_prediction(case_id, label, probability):
    prediction = db.session.get(Case, case_id).prediction
    prediction.state = DONE
    prediction.label = label
    prediction.tb_probability = probability
    prediction.model_version = "test"
    db.session.commit()


# --- cases --------------------------------------------------------------------


def test_doctor_uploads_and_owns_the_case(client, doc1):
    """The doctor's own upload is assigned to them and open for review."""
    data = {"image": (png_bytes(), "cxr.png"), "patient_name": "Self Upload"}
    response = client.post(f"{API}/cases", headers=doc1, data=data, content_type="multipart/form-data")
    assert response.status_code == 201, response.json
    case = response.json
    assert case["status"] == "assigned"
    assert case["prediction"]["state"] == "queued"  # tests run no model inline
    assert case["review"] is None
    # Saved as one of the doctor's cases.
    mine = client.get(f"{API}/cases", headers=doc1).json
    assert any(row["id"] == case["id"] for row in mine)
    assert mine[0]["assigned_to"] is not None


def test_doctor_uploads_need_a_token_and_a_name(client, doc1):
    response = client.post(
        f"{API}/cases", headers=doc1,
        data={"image": (png_bytes(), "cxr.png")},
        content_type="multipart/form-data")
    assert response.status_code == 422 and "patient_name" in response.json["error"]
    unauthorized = client.post(
        f"{API}/cases",
        data={"image": (png_bytes(), "cxr.png"), "patient_name": "Anon"},
        content_type="multipart/form-data")
    assert unauthorized.status_code == 401


def test_admin_upload_still_creates_unassigned(client, admin):
    data = {"image": (png_bytes(), "cxr.png"), "patient_name": "Admin Upload"}
    response = client.post(f"{API}/admin/cases", headers=admin, data=data, content_type="multipart/form-data")
    assert response.status_code == 201 and response.json["status"] == "unassigned"


def test_patient_search_reuses_records(client, admin):
    """Typing a returning patient reuses their row instead of retyping them."""
    case1 = upload(client, admin, name="Alice Banda", hospital_number="HU-42")
    case2 = upload(client, admin, name="Alice Banda", hospital_number="HU-42")
    upload(client, admin, name="Zola Moyo")

    # Same hospital number reuses the same patient row across cases.
    detail1 = client.get(f"{API}/admin/cases/{case1}", headers=admin).json
    detail2 = client.get(f"{API}/admin/cases/{case2}", headers=admin).json
    assert detail1["patient"] == detail2["patient"]

    # Matches by name...
    by_name = client.get(f"{API}/patients?q=banda", headers=admin).json
    assert [row["name"] for row in by_name] == ["Alice Banda"]
    # ...and by hospital number. Zola has no number and does not match.
    by_number = client.get(f"{API}/patients?q=hu-4", headers=admin).json
    assert by_number == by_name
    assert by_number[0]["hospital_number"] == "HU-42"

    assert client.get(f"{API}/patients", headers=admin).json == []  # no query
    too_short = client.get(f"{API}/patients?q=a", headers=admin).json
    assert too_short == []
    assert client.get(f"{API}/patients?q=al").status_code == 401


# --- auth ---------------------------------------------------------------------


def test_login_rejects_wrong_password(client):
    response = client.post(f"{API}/auth/login", json={"email": "doc1@test", "password": "nope"})
    assert response.status_code == 401


def test_me_and_catalog_need_a_token(client, doc1):
    assert client.get(f"{API}/auth/me").status_code == 401
    assert client.get(f"{API}/auth/me", headers={"Authorization": "Bearer junk"}).status_code == 401
    assert client.get(f"{API}/auth/me", headers=doc1).json["role"] == "doctor"
    catalog = client.get(f"{API}/catalog", headers=doc1).json
    assert {f["code"] for f in catalog["findings"]} >= {"cavity", "pleuralThickening"}
    assert len(catalog["findings"]) == 12


def test_doctor_cannot_use_admin_routes(client, doc1):
    assert client.get(f"{API}/admin/users", headers=doc1).status_code == 403
    assert client.get(f"{API}/admin/cases", headers=doc1).status_code == 403
    assert client.get(f"{API}/admin/export", headers=doc1).status_code == 403


def test_deactivated_user_token_stops_working(client, admin, doc1):
    uid = user_id(client, admin, "doc1@test")
    assert client.patch(f"{API}/admin/users/{uid}", headers=admin, json={"active": False}).status_code == 200
    assert client.get(f"{API}/auth/me", headers=doc1).status_code == 401
    response = client.post(f"{API}/auth/login", json={"email": "doc1@test", "password": PASSWORD})
    assert response.status_code == 401


def test_admin_creates_user_and_cannot_deactivate_self(client, admin):
    body = {"email": "New@Test", "full_name": "New Doc", "password": "long-enough"}
    created = client.post(f"{API}/admin/users", headers=admin, json=body)
    assert created.status_code == 201 and created.json["role"] == "doctor"
    assert client.post(f"{API}/admin/users", headers=admin, json=body).status_code == 409
    short = {**body, "email": "x@test", "password": "short"}
    assert client.post(f"{API}/admin/users", headers=admin, json=short).status_code == 422
    me = user_id(client, admin, "admin@test")
    assert client.patch(f"{API}/admin/users/{me}", headers=admin, json={"active": False}).status_code == 409


# --- cases and assignment -------------------------------------------------------


def test_upload_creates_case_with_queued_prediction(client, admin):
    cid = upload(client, admin, hospital_number="H-1")
    case = client.get(f"{API}/admin/cases/{cid}", headers=admin).json
    assert case["status"] == "unassigned"
    assert case["prediction"]["state"] == "queued"
    assert [a["action"] for a in case["audit"]] == ["created"]
    image = client.get(f"{API}/cases/{cid}/image", headers=admin)
    assert image.status_code == 200 and image.data[:8] == b"\x89PNG\r\n\x1a\n"
    # Same hospital number reuses the patient.
    second = upload(client, admin, name="", hospital_number="H-1")
    other = client.get(f"{API}/admin/cases/{second}", headers=admin).json
    assert other["patient"]["id"] == case["patient"]["id"]


def test_upload_rejects_non_images_and_converts_jpeg(client, admin):
    bad = {"image": (io.BytesIO(b"not an image"), "x.png"), "patient_name": "A"}
    response = client.post(f"{API}/admin/cases", headers=admin, data=bad, content_type="multipart/form-data")
    assert response.status_code == 422
    assert client.get(f"{API}/admin/cases", headers=admin).json == []
    jpeg = {"image": (png_bytes("JPEG"), "x.jpg"), "patient_name": "A"}
    response = client.post(f"{API}/admin/cases", headers=admin, data=jpeg, content_type="multipart/form-data")
    assert response.status_code == 201
    image = client.get(f"{API}/cases/{response.json['id']}/image", headers=admin)
    assert image.data[:4] == b"\x89PNG"


def test_doctor_sees_only_assigned_cases(client, admin, doc1, doc2, case_id):
    unassigned = upload(client, admin)
    assert [c["id"] for c in client.get(f"{API}/cases", headers=doc1).json] == [case_id]
    assert client.get(f"{API}/cases", headers=doc2).json == []
    for path in ("", "/image", "/overlay"):
        assert client.get(f"{API}/cases/{case_id}{path}", headers=doc2).status_code == 404
    assert client.get(f"{API}/cases/{unassigned}", headers=doc1).status_code == 404
    assert client.put(f"{API}/cases/{case_id}/review", headers=doc2, json=REVIEW).status_code == 404
    assert client.get(f"{API}/cases/{case_id}/image", headers=doc1).status_code == 200
    # No overlay until the model runs.
    assert client.get(f"{API}/cases/{case_id}/overlay", headers=doc1).status_code == 404


def test_opening_a_case_moves_it_to_in_review(client, admin, doc1, case_id):
    assert client.get(f"{API}/cases", headers=doc1).json[0]["status"] == "assigned"
    assert client.get(f"{API}/cases/{case_id}", headers=doc1).json["status"] == "in_review"


def _write_mask(app, case_id, value=255):
    from pathlib import Path

    from PIL import Image as PilImage

    path = Path(app.config["STORAGE_DIR"]) / f"masks/{case_id}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    PilImage.new("L", (16, 16), value).save(path, format="PNG")
    case = db.session.get(Case, case_id)
    case.prediction.state = DONE
    case.prediction.mask_path = f"masks/{case_id}.png"
    db.session.commit()


def test_mask_endpoint_serves_worker_mask(app, client, admin, doc1, doc2, case_id):
    assert client.get(f"{API}/cases/{case_id}/mask", headers=doc1).status_code == 404
    assert client.get(f"{API}/cases/{case_id}", headers=doc1).json["prediction"]["has_mask"] is False

    _write_mask(app, case_id)
    image = client.get(f"{API}/cases/{case_id}/mask", headers=doc1)
    assert image.status_code == 200 and image.data[:8] == b"\x89PNG\r\n\x1a\n"
    assert client.get(f"{API}/cases/{case_id}", headers=doc1).json["prediction"]["has_mask"] is True
    # The admin views through the same endpoint; another doctor cannot probe it.
    assert client.get(f"{API}/cases/{case_id}/mask", headers=admin).status_code == 200
    assert client.get(f"{API}/cases/{case_id}/mask", headers=doc2).status_code == 404


MASK_EDITS = [
    {"kind": "add", "tool": "brush", "width": 0.03, "points": [[0.4, 0.4], [0.45, 0.5]]},
    {"kind": "erase", "tool": "pen", "width": 0.008, "points": [[0.6, 0.6]]},
]


def test_mask_edits_round_trip_and_replace(client, doc1, case_id):
    saved = client.put(f"{API}/cases/{case_id}/review", headers=doc1, json={"mask_edits": MASK_EDITS})
    assert saved.status_code == 200
    assert saved.json["review"]["mask_edits"] == MASK_EDITS

    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json={"verdict": "no_tb"})
    review = client.get(f"{API}/cases/{case_id}", headers=doc1).json["review"]
    assert review["mask_edits"] == []

    # Explicit null clears, like omitting the key.
    cleared = client.put(
        f"{API}/cases/{case_id}/review", headers=doc1, json={"mask_edits": MASK_EDITS})
    assert cleared.status_code == 200
    nulled = client.put(
        f"{API}/cases/{case_id}/review", headers=doc1, json={"mask_edits": None})
    assert nulled.status_code == 200
    assert nulled.json["review"]["mask_edits"] == []


def test_mask_edits_validation(client, doc1, case_id):
    good = {"kind": "add", "tool": "brush", "width": 0.03, "points": [[0.1, 0.2]]}
    bad_bodies = [
        {"mask_edits": [{"kind": "fill", **{k: v for k, v in good.items() if k != "kind"}}]},
        {"mask_edits": [{"tool": "spray", **{k: v for k, v in good.items() if k != "tool"}}]},
        {"mask_edits": [{**good, "width": 0.0005}]},
        {"mask_edits": [{**good, "width": 0.5}]},
        {"mask_edits": [{**good, "width": True}]},
        {"mask_edits": [{**good, "points": []}]},
        {"mask_edits": [{**good, "points": [[1.5, 0.2]]}]},
        {"mask_edits": [{**good, "points": "nope"}]},
        {"mask_edits": ["nope"]},
        {"mask_edits": {}},
    ]
    for body in bad_bodies:
        response = client.put(f"{API}/cases/{case_id}/review", headers=doc1, json=body)
        assert response.status_code == 422, body


def test_assign_validates_and_is_all_or_nothing(client, admin, doc1, case_id):
    admin_id = user_id(client, admin, "admin@test")
    body = {"case_ids": [case_id], "doctor_id": admin_id}
    assert client.post(f"{API}/admin/cases/assign", headers=admin, json=body).status_code == 422
    assert assign(client, admin, [case_id, 999], "doc2@test").status_code == 404

    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json=REVIEW)
    client.post(f"{API}/cases/{case_id}/review/submit", headers=doc1)
    fresh = upload(client, admin)
    assert assign(client, admin, [fresh, case_id], "doc2@test").status_code == 409
    assert client.get(f"{API}/admin/cases/{fresh}", headers=admin).json["status"] == "unassigned"


def test_reassign_hides_previous_draft(client, admin, doc1, doc2, case_id):
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json=REVIEW)
    assert assign(client, admin, [case_id], "doc2@test").status_code == 200
    assert client.get(f"{API}/cases/{case_id}", headers=doc1).status_code == 404
    case = client.get(f"{API}/cases/{case_id}", headers=doc2).json
    assert case["review"] is None
    detail = client.get(f"{API}/admin/cases/{case_id}", headers=admin).json
    assert detail["review"] is None and detail["model_wrong"] is False
    assert [a["action"] for a in detail["audit"]] == [
        "created", "assigned", "review_started", "reassigned", "opened",
    ]


# --- reviews --------------------------------------------------------------------


def test_review_draft_round_trip_and_replace(client, doc1, case_id):
    saved = client.put(f"{API}/cases/{case_id}/review", headers=doc1, json=REVIEW)
    assert saved.status_code == 200
    review = saved.json["review"]
    assert saved.json["status"] == "in_review" and review["state"] == "draft"
    assert review["marks"] == REVIEW["marks"]
    assert review["model_feedback"] == {"kind": "wrong_region", "note": "Heatmap on the heart.", "derived": False}
    assert review["further_testing"]["tests"] == ["genexpert", "culture"]
    assert review["further_testing"]["urgency"] == "urgent"

    # Each save replaces the whole review.
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json={"verdict": "no_tb"})
    review = client.get(f"{API}/cases/{case_id}", headers=doc1).json["review"]
    assert review["verdict"] == "no_tb" and review["marks"] == []
    assert review["model_feedback"] is None and review["further_testing"] is None


def test_review_validation(client, doc1, case_id):
    bad_bodies = [
        {"verdict": "maybe"},
        {"marks": [{"finding": "cavity", "points": [[1.5, 0.2]]}]},
        {"marks": [{"finding": "cavity", "points": []}]},
        {"marks": [{"finding": "bogus", "points": [[0.1, 0.2]]}]},
        {"marks": [{"finding": "cavity", "note": "x" * 2001, "points": [[0.1, 0.2]]}]},
        {"marks": [{"finding": "cavity", "note": 5, "points": [[0.1, 0.2]]}]},
        {"disease_tags": ["flu"]},
        {"model_feedback": {"kind": "meh"}},
        {"further_testing": {"tests": []}},
        {"further_testing": {"tests": ["genexpert"], "urgency": "now"}},
    ]
    for body in bad_bodies:
        response = client.put(f"{API}/cases/{case_id}/review", headers=doc1, json=body)
        assert response.status_code == 422, body
    # An unlabelled mark is a valid draft.
    ok = client.put(
        f"{API}/cases/{case_id}/review", headers=doc1, json={"marks": [{"finding": None, "points": [[0, 1]]}]}
    )
    assert ok.status_code == 200
    # A mark comment round-trips and is stripped like other free text.
    noted = client.put(
        f"{API}/cases/{case_id}/review",
        headers=doc1,
        json={"marks": [{"finding": "cavity", "note": "  RUL cavity  ", "points": [[0.1, 0.2]]}]},
    )
    assert noted.status_code == 200
    assert noted.json["review"]["marks"] == [
        {"finding": "cavity", "note": "RUL cavity", "points": [[0.1, 0.2]]}
    ]


def test_submit_requires_verdict_and_locks_review(client, doc1, case_id):
    submit = f"{API}/cases/{case_id}/review/submit"
    assert client.post(submit, headers=doc1).status_code == 422
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json={"marks": []})
    assert client.post(submit, headers=doc1).status_code == 422
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json={"verdict": "other_disease"})
    assert client.post(submit, headers=doc1).status_code == 422
    body = {"verdict": "other_disease", "disease_tags": ["pneumonia", {"code": "other", "free_text": "TBC"}]}
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json=body)
    done = client.post(submit, headers=doc1)
    assert done.status_code == 200 and done.json["status"] == "submitted"
    assert done.json["review"]["state"] == "submitted"
    assert client.put(f"{API}/cases/{case_id}/review", headers=doc1, json=REVIEW).status_code == 409
    assert client.post(submit, headers=doc1).status_code == 409


def test_feedback_is_derived_when_verdict_contradicts_model(client, doc1, case_id):
    set_prediction(case_id, "normal", 0.03)
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json={"verdict": "tb_suspected"})
    review = client.post(f"{API}/cases/{case_id}/review/submit", headers=doc1).json["review"]
    assert review["model_feedback"] == {"kind": "false_negative", "note": "", "derived": True}


def test_no_feedback_derived_when_doctor_agrees_or_model_pending(client, admin, doc1, case_id):
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json={"verdict": "tb_suspected"})
    review = client.post(f"{API}/cases/{case_id}/review/submit", headers=doc1).json["review"]
    assert review["model_feedback"] is None  # prediction still queued

    second = upload(client, admin)
    assign(client, admin, [second], "doc1@test")
    set_prediction(second, "tb", 0.97)
    client.put(f"{API}/cases/{second}/review", headers=doc1, json={"verdict": "tb_suspected"})
    review = client.post(f"{API}/cases/{second}/review/submit", headers=doc1).json["review"]
    assert review["model_feedback"] is None


# --- closing the loop -------------------------------------------------------------


def test_return_reopens_then_accept_closes(client, admin, doc1, case_id):
    assert client.post(f"{API}/admin/cases/{case_id}/accept", headers=admin).status_code == 409
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json=REVIEW)
    client.post(f"{API}/cases/{case_id}/review/submit", headers=doc1)

    back = f"{API}/admin/cases/{case_id}/return"
    assert client.post(back, headers=admin, json={"note": " "}).status_code == 422
    assert client.post(back, headers=admin, json={"note": "Label the mark."}).json["status"] == "returned"
    case = client.get(f"{API}/cases/{case_id}", headers=doc1).json
    assert case["status"] == "returned" and case["review"]["state"] == "draft"
    assert case["return_note"] == "Label the mark."
    assert case["review"]["marks"] == REVIEW["marks"]  # work is kept

    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json=REVIEW)
    client.post(f"{API}/cases/{case_id}/review/submit", headers=doc1)
    assert client.post(f"{API}/admin/cases/{case_id}/accept", headers=admin).json["status"] == "accepted"
    assert client.post(back, headers=admin, json={"note": "x"}).status_code == 409
    assert client.put(f"{API}/cases/{case_id}/review", headers=doc1, json=REVIEW).status_code == 409
    audit = client.get(f"{API}/admin/cases/{case_id}", headers=admin).json["audit"]
    assert [a["action"] for a in audit][-4:] == ["returned", "review_started", "submitted", "accepted"]
    assert audit[-4]["note"] == "Label the mark."


def test_admin_filters(client, admin, doc1, case_id):
    plain = upload(client, admin)
    assign(client, admin, [plain], "doc1@test")
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json=REVIEW)
    client.put(f"{API}/cases/{plain}/review", headers=doc1, json={"verdict": "no_tb"})

    def ids(query):
        return [c["id"] for c in client.get(f"{API}/admin/cases?{query}", headers=admin).json]

    assert ids("flag=model_wrong") == [case_id]
    assert ids("flag=needs_testing") == [case_id]
    assert ids("status=in_review") == [plain, case_id]
    assert ids("status=submitted") == []
    assert ids(f"doctor={user_id(client, admin, 'doc2@test')}") == []
    assert client.get(f"{API}/admin/cases?flag=nope", headers=admin).status_code == 400


def test_exports_leave_out_patient_identity(client, admin, doc1, case_id):
    set_prediction(case_id, "tb", 0.91)
    body = {"verdict": "no_tb", "note": "=HYPERLINK(1)", "marks": REVIEW["marks"]}
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json=body)
    client.post(f"{API}/cases/{case_id}/review/submit", headers=doc1)

    reviews = client.get(f"{API}/admin/export?kind=reviews", headers=admin)
    assert reviews.mimetype == "text/csv"
    assert "Jane Banda" not in reviews.text
    row = next(csv.DictReader(io.StringIO(reviews.text)))
    assert row["verdict"] == "no_tb" and row["feedback_kind"] == "false_positive"
    assert row["note"] == "'=HYPERLINK(1)"
    assert row["findings"] == "cavity" and row["model_label"] == "tb"

    feedback = client.get(f"{API}/admin/export?kind=model_feedback", headers=admin)
    row = next(csv.DictReader(io.StringIO(feedback.text)))
    assert row["feedback_kind"] == "false_positive" and row["derived"] == "True"
    assert row["tb_probability"] == "0.91" and "0.62" in row["marks"]
    assert client.get(f"{API}/admin/export?kind=x", headers=admin).status_code == 400


def test_stats(client, admin, doc1, case_id):
    upload(client, admin)
    set_prediction(case_id, "tb", 0.9)
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json={"verdict": "tb_suspected"})
    client.post(f"{API}/cases/{case_id}/review/submit", headers=doc1)
    stats = client.get(f"{API}/admin/stats", headers=admin).json
    assert stats["by_status"]["unassigned"] == 1 and stats["by_status"]["submitted"] == 1
    doc_one = next(d for d in stats["doctors"] if d["doctor"]["email"] == "doc1@test")
    assert (doc_one["open"], doc_one["submitted"], doc_one["accepted"]) == (0, 1, 0)
    assert stats["model_agreement"] == {"compared": 1, "agreed": 1, "rate": 1.0}
    assert stats["verdicts"] == {
        "tb_suspected": 1, "no_tb": 0, "other_disease": 0, "unreadable": 0}
    assert set(stats["model_feedback"]) == {
        "false_positive", "false_negative", "wrong_region", "cannot_judge"}
    assert sum(stats["model_feedback"].values()) == 0


def test_stats_count_model_feedback(client, admin, doc1, case_id):
    set_prediction(case_id, "normal", 0.1)
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json={"verdict": "tb_suspected"})
    # A draft is not counted until it is submitted.
    assert client.get(f"{API}/admin/stats", headers=admin).json["model_feedback"]["false_negative"] == 0
    client.post(f"{API}/cases/{case_id}/review/submit", headers=doc1)
    stats = client.get(f"{API}/admin/stats", headers=admin).json
    assert stats["model_feedback"]["false_negative"] == 1
    assert stats["model_agreement"] == {"compared": 1, "agreed": 0, "rate": 0.0}


def test_stats_queues_what_waits_for_the_admin(client, admin, doc1, case_id):
    waiting = upload(client, admin, name="Unassigned Patient")
    late = upload(client, admin, name="Late Patient")
    client.post(f"{API}/admin/cases/assign", headers=admin, json={
        "case_ids": [late], "doctor_id": user_id(client, admin, "doc1@test"),
        "due_at": "2020-01-01T00:00:00Z"})
    set_prediction(case_id, "tb", 0.9)
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json={"verdict": "tb_suspected"})
    client.post(f"{API}/cases/{case_id}/review/submit", headers=doc1)

    stats = client.get(f"{API}/admin/stats", headers=admin).json
    queues = stats["queues"]
    assert queues["sign_off"]["count"] == 1
    assert queues["sign_off"]["cases"][0]["id"] == case_id
    assert queues["sign_off"]["cases"][0]["waiting_since"] is not None
    assert [c["id"] for c in queues["overdue"]["cases"]] == [late]
    assert [c["id"] for c in queues["unassigned"]["cases"]] == [waiting]
    doc_one = next(d for d in stats["doctors"] if d["doctor"]["email"] == "doc1@test")
    assert doc_one["oldest_open_since"] is not None


def test_hospitals_lookup_create_and_upload(client, admin, doc1):
    created = client.post(f"{API}/hospitals", headers=doc1, json={"name": "  Kamuzu   Central "})
    assert created.status_code == 201 and created.json["name"] == "Kamuzu Central"
    again = client.post(f"{API}/hospitals", headers=admin, json={"name": "kamuzu central"})
    assert again.status_code == 200 and again.json["id"] == created.json["id"]
    assert client.post(f"{API}/hospitals", headers=admin, json={"name": " "}).status_code == 422
    client.post(f"{API}/hospitals", headers=admin, json={"name": "Queen Elizabeth"})

    found = client.get(f"{API}/hospitals", headers=doc1, query_string={"q": "queen"}).json
    assert [h["name"] for h in found] == ["Queen Elizabeth"]
    every = client.get(f"{API}/hospitals", headers=admin).json
    assert [h["name"] for h in every] == ["Kamuzu Central", "Queen Elizabeth"]

    hid = created.json["id"]
    cid = upload(client, admin, hospital_id=str(hid))
    assert client.get(f"{API}/admin/cases/{cid}", headers=admin).json["hospital"] == {
        "id": hid, "name": "Kamuzu Central"}
    data = {"image": (png_bytes(), "cxr.png"), "patient_name": "X", "hospital_id": "999"}
    bad = client.post(f"{API}/cases", headers=doc1, data=data, content_type="multipart/form-data")
    assert bad.status_code == 422


def test_doctor_hides_a_case_from_their_list(client, admin, doc1, case_id):
    def listed():
        return [c["id"] for c in client.get(f"{API}/cases", headers=doc1).json]

    assert client.post(f"{API}/cases/{case_id}/hide", headers=doc1).status_code == 204
    assert case_id not in listed()
    # The admin still sees it, untouched.
    assert client.get(f"{API}/admin/cases/{case_id}", headers=admin).json["status"] == "assigned"
    assert client.post(f"{API}/cases/{case_id}/unhide", headers=doc1).status_code == 200
    assert case_id in listed()

    # Coming back from the admin shows it again.
    client.post(f"{API}/cases/{case_id}/hide", headers=doc1)
    client.put(f"{API}/cases/{case_id}/review", headers=doc1, json={"verdict": "no_tb"})
    client.post(f"{API}/cases/{case_id}/review/submit", headers=doc1)
    client.post(f"{API}/admin/cases/{case_id}/return", headers=admin, json={"note": "Recheck"})
    assert case_id in listed()


def test_cannot_hide_someone_elses_case(client, doc2, case_id):
    assert client.post(f"{API}/cases/{case_id}/hide", headers=doc2).status_code == 404


def test_expired_token_is_rejected(app, client):
    app.config["TOKEN_HOURS"] = -1
    headers = login(client, "doc1@test")
    assert client.get(f"{API}/auth/me", headers=headers).status_code == 401

def test_swagger_endpoints(client):
    res_json = client.get(f"{API}/swagger.json")
    assert res_json.status_code == 200
    data = res_json.json
    assert data["swagger"] == "2.0"
    assert "/auth/login" in data["paths"]
    assert "/cases" in data["paths"]
    assert "/admin/cases" in data["paths"]

    for url in (f"{API}/", f"{API}"):
        res_ui = client.get(url, follow_redirects=True)
        assert res_ui.status_code == 200
        assert b"SwaggerUIBundle" in res_ui.data

    res_redirect = client.get(f"{API}/docs", follow_redirects=True)
    assert res_redirect.status_code == 200
    assert b"SwaggerUIBundle" in res_redirect.data


def test_swagger_covers_every_endpoint(client):
    """Every real API route+method must appear in swagger.json."""
    import re

    spec = client.get(f"{API}/swagger.json").json
    documented = {
        (path, method.upper())
        for path, ops in spec["paths"].items()
        for method in ops
        if method.lower() in ("get", "post", "put", "patch", "delete")
    }
    missing = []
    for rule in client.application.url_map.iter_rules():
        if rule.endpoint.startswith("docs.") or rule.endpoint == "docs.docs_redirect":
            continue  # the documentation machinery itself
        if not str(rule).startswith("/api/"):
            continue
        path = re.sub(r"<(?:[^:<>]+:)?([^<>]+)>", r"{\1}", str(rule))
        path = path.replace(API, "", 1) or "/"
        for method in sorted(rule.methods - {"HEAD", "OPTIONS"}):
            if (path, method) not in documented:
                missing.append(f"{method} {path}")
    assert missing == []
