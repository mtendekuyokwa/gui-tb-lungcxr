import csv
import io

from app.extensions import db
from app.models import DONE, Case, Prediction

from conftest import PASSWORD, assign, login, png_bytes, upload, user_id

API = "/api/v1"
REVIEW = {
    "verdict": "tb_suspected",
    "note": "Right upper zone cavity.",
    "marks": [{"finding": "cavity", "points": [[0.62, 0.21], [0.64, 0.23]]}],
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
    # No overlay until the model worker exists.
    assert client.get(f"{API}/cases/{case_id}/overlay", headers=doc1).status_code == 404


def test_opening_a_case_moves_it_to_in_review(client, admin, doc1, case_id):
    assert client.get(f"{API}/cases", headers=doc1).json[0]["status"] == "assigned"
    assert client.get(f"{API}/cases/{case_id}", headers=doc1).json["status"] == "in_review"


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


def test_expired_token_is_rejected(app, client):
    app.config["TOKEN_HOURS"] = -1
    headers = login(client, "doc1@test")
    assert client.get(f"{API}/auth/me", headers=headers).status_code == 401
