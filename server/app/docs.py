"""Swagger OpenAPI specification and Swagger UI served with flask-restx.

The ``Resource`` classes below exist only to generate the spec and the
interactive docs at ``GET /api/v1/`` (plus ``swagger.json`` and ``/docs``).
The real request handling lives in ``auth.py``, ``cases.py`` and ``admin.py``;
these stubs must never shadow those views, so the ``docs`` blueprint has to
stay registered *after* them in ``app/__init__.py``.
"""

from flask import Blueprint, redirect, url_for
from flask_restx import Api, Resource, fields
from werkzeug.datastructures import FileStorage

bp = Blueprint("docs", __name__)

api = Api(
    bp,
    version="1.0.0",
    title="LungCXR Tuberculosis Detection & Review API",
    description="Comprehensive API documentation for the LungCXR Flask backend supporting tuberculosis chest X-ray reading, admin management, and doctor reviews.",
    doc="/",
    authorizations={
        "BearerAuth": {
            "type": "apiKey",
            "in": "header",
            "name": "Authorization",
            "description": "Type in the *'Value'* input box below: **'Bearer <JWT>'**, where JWT is the token from POST /auth/login.",
        }
    },
    security="BearerAuth",
)


# --- Sub-models ---

prediction_sub_model = api.model("PredictionSub", {
    "id": fields.Integer(description="Prediction ID"),
    "state": fields.String(description="Prediction state"),
    "model_version": fields.String(description="Model version"),
    "label": fields.String(description="Predicted label"),
    "tb_probability": fields.Float(description="TB probability score"),
    "has_overlay": fields.Boolean(description="Whether overlay exists"),
    "has_mask": fields.Boolean(description="Whether lung mask exists")
})

doctor_sub_model = api.model("DoctorSub", {
    "id": fields.Integer(description="Doctor ID"),
    "email": fields.String(description="Doctor email"),
    "full_name": fields.String(description="Doctor full name"),
    "role": fields.String(description="User role"),
    "active": fields.Boolean(description="Active status"),
})

patient_sub_model = api.model("PatientSub", {
    "id": fields.Integer(description="Patient ID"),
    "hospital_number": fields.String(description="Hospital record number, nullable"),
    "name": fields.String(description="Patient name"),
    "sex": fields.String(description="Patient sex, nullable"),
    "birth_year": fields.Integer(description="Patient birth year, nullable")
})

mark_sub_model = api.model("MarkSub", {
    "finding": fields.String(description="Finding code, null while unlabelled"),
    "note": fields.String(description="Doctor's comment describing the finding"),
    "points": fields.List(fields.List(fields.Float()), description="Image-relative [x, y] pairs, each 0..1")
})

mask_edit_sub_model = api.model("MaskEditSub", {
    "kind": fields.String(description="Edit kind: add or erase"),
    "tool": fields.String(description="Tool used: brush or pen"),
    "width": fields.Float(description="Stroke width as a fraction of image width"),
    "points": fields.List(fields.List(fields.Float()), description="Image-relative [x, y] pairs, each 0..1")
})

disease_tag_sub_model = api.model("DiseaseTagSub", {
    "code": fields.String(description="Disease code"),
    "free_text": fields.String(description="Optional free text")
})

model_feedback_sub_model = api.model("ModelFeedbackSub", {
    "kind": fields.String(description="Feedback kind"),
    "note": fields.String(description="Feedback note"),
    "derived": fields.Boolean(description="Whether derived automatically")
})

further_testing_sub_model = api.model("FurtherTestingSub", {
    "tests": fields.List(fields.String(), description="List of test codes"),
    "urgency": fields.String(description="Urgency level"),
    "free_text": fields.String(description="Free text note")
})

audit_sub_model = api.model("AuditSub", {
    "action": fields.String(description="Action name"),
    "note": fields.String(description="Audit note"),
    "at": fields.String(description="ISO timestamp"),
    "user": fields.String(description="User who performed action")
})

review_nested_model = api.model("ReviewNested", {
    "id": fields.Integer(description="Review ID"),
    "doctor": fields.Nested(doctor_sub_model, description="Doctor who wrote the review"),
    "state": fields.String(description="Review state"),
    "verdict": fields.String(description="Diagnostic verdict"),
    "note": fields.String(description="Review notes"),
    "submitted_at": fields.String(description="ISO submission timestamp, nullable"),
    "updated_at": fields.String(description="ISO update timestamp"),
    "marks": fields.List(fields.Nested(mark_sub_model), description="Lesion marks"),
    "mask_edits": fields.List(fields.Nested(mask_edit_sub_model), description="Lung mask correction strokes"),
    "disease_tags": fields.List(fields.Nested(disease_tag_sub_model), description="Disease tags"),
    "model_feedback": fields.Nested(model_feedback_sub_model, description="Model feedback"),
    "further_testing": fields.Nested(further_testing_sub_model, description="Further testing requests")
})

catalog_item_model = api.model("CatalogItem", {
    "code": fields.String(description="Code"),
    "label": fields.String(description="Label")
})

finding_item_model = api.model("FindingItem", {
    "code": fields.String(description="Code"),
    "group": fields.String(description="Group"),
    "label": fields.String(description="Label")
})

doctor_workload_model = api.model("DoctorWorkload", {
    "doctor": fields.Nested(doctor_sub_model, description="Doctor profile"),
    "open": fields.Integer(description="Open cases count"),
    "submitted": fields.Integer(description="Submitted cases count"),
    "accepted": fields.Integer(description="Accepted cases count")
})

model_agreement_model = api.model("ModelAgreement", {
    "compared": fields.Integer(description="Number of comparisons"),
    "agreed": fields.Integer(description="Number of agreements"),
    "rate": fields.Float(description="Agreement rate (0 to 1)")
})

user_item_model = api.model("UserItem", {
    "id": fields.Integer(description="User ID"),
    "email": fields.String(description="User email"),
    "full_name": fields.String(description="User full name"),
    "role": fields.String(description="User role"),
    "active": fields.Boolean(description="Active status"),
})

# Reused user shapes (flask-restx Nested requires a registered model,
# not an inline dict).
user_ref_model = api.model("UserRef", {
    "id": fields.Integer(description="User ID"),
    "email": fields.String(description="User email"),
    "full_name": fields.String(description="User full name"),
    "role": fields.String(description="User role"),
    "active": fields.Boolean(description="Active status"),
})

user_profile_model = api.model("UserProfile", {
    "id": fields.Integer(description="User ID"),
    "email": fields.String(description="User email"),
    "full_name": fields.String(description="User full name"),
    "role": fields.String(description="User role"),
    "active": fields.Boolean(description="Active status"),
})

login_response_model = api.model("LoginResponse", {
    "token": fields.String(description="JWT bearer token"),
    "user": fields.Nested(user_ref_model, description="Authenticated user"),
})

user_created_model = api.model("UserCreated", {
    "id": fields.Integer(description="User ID"),
    "email": fields.String(description="User email"),
    "full_name": fields.String(description="User full name"),
    "role": fields.String(description="User role"),
    "active": fields.Boolean(description="Active status"),
})

user_updated_model = api.model("UserUpdated", {
    "id": fields.Integer(description="User ID"),
    "email": fields.String(description="User email"),
    "full_name": fields.String(description="User full name"),
    "role": fields.String(description="User role"),
    "active": fields.Boolean(description="Active status"),
})

# PATCH /admin/users/<id>: all fields optional.
user_update_model = api.model("UserUpdate", {
    "full_name": fields.String(description="New full name"),
    "password": fields.String(description="New password (min 8 characters)"),
    "active": fields.Boolean(description="Activate or deactivate the account"),
})

return_case_model = api.model("ReturnCase", {
    "note": fields.String(required=True, description="Note explaining the return"),
})

system_stats_model = api.model("SystemStats", {
    "by_status": fields.Raw(description="Case counts by status"),
    "doctors": fields.List(fields.Nested(doctor_workload_model)),
    "model_agreement": fields.Nested(model_agreement_model),
})

# Multipart parser for the admin case-upload endpoint. Documented as form
# params so Swagger UI shows a file picker instead of a JSON body.
upload_parser = api.parser()
upload_parser.add_argument("image", location="files", type=FileStorage,
                           required=True, help="X-ray image file (PNG or JPEG)")
upload_parser.add_argument(
    "hospital_number", location="form", help="Patient hospital number, optional")
upload_parser.add_argument("patient_name", location="form",
                           required=True, help="Patient name (required for a new patient)")
upload_parser.add_argument("sex", location="form",
                           help="Patient sex, optional")
upload_parser.add_argument(
    "birth_year", location="form", help="Patient birth year, optional")


# --- Request bodies (mirror cases.py validation) ---

mark_input_model = api.model("MarkInput", {
    "finding": fields.String(description="Finding code, or null for an unlabelled mark"),
    "note": fields.String(description="Comment describing the finding, at most 2000 characters"),
    "points": fields.List(fields.List(fields.Float()), required=True, description="Non-empty list of [x, y] pairs, each 0..1"),
})

mask_edit_input_model = api.model("MaskEditInput", {
    "kind": fields.String(required=True, description="Edit kind: add or erase"),
    "tool": fields.String(required=True, description="Tool used: brush or pen"),
    "width": fields.Float(required=True, description="Stroke width as a fraction of image width, 0.002 to 0.2"),
    "points": fields.List(fields.List(fields.Float()), required=True, description="Non-empty list of [x, y] pairs, each 0..1"),
})

disease_tag_input_model = api.model("DiseaseTagInput", {
    "code": fields.String(required=True, description="Disease code"),
    "free_text": fields.String(description="Optional free text"),
})

model_feedback_input_model = api.model("ModelFeedbackInput", {
    "kind": fields.String(required=True, description="Feedback kind"),
    "note": fields.String(description="Feedback note"),
})

further_testing_input_model = api.model("FurtherTestingInput", {
    "tests": fields.List(fields.String(), required=True, description="At least one test code"),
    "urgency": fields.String(description="Urgency level (default routine)"),
    "free_text": fields.String(description="Free text note"),
})


# --- Models ---

login_model = api.model("LoginRequest", {
    "email": fields.String(required=True, description="User email", example="doctor@example.com"),
    "password": fields.String(required=True, description="User password", example="secret123")
})

review_model = api.model("ReviewDraft", {
    "verdict": fields.String(description="Diagnostic verdict (tb_suspected, no_tb, other_disease, unreadable)"),
    "note": fields.String(description="Review notes, at most 4000 characters"),
    "marks": fields.List(fields.Nested(mark_input_model), description="Lesion marks; each needs a non-empty points list"),
    "mask_edits": fields.List(fields.Nested(mask_edit_input_model), description="Lung mask correction strokes; replaced whole on each save"),
    "disease_tags": fields.List(fields.Raw(), description="Disease codes or {code, free_text} objects"),
    "model_feedback": fields.Nested(model_feedback_input_model, description="Feedback on the model prediction, or null to clear"),
    "further_testing": fields.Nested(further_testing_input_model, description="Further testing request, or null for none"),
})

assign_model = api.model("AssignRequest", {
    "case_ids": fields.List(fields.Integer(), required=True, description="Non-empty list of case IDs"),
    "doctor_id": fields.Integer(required=True, description="Target active doctor user ID"),
    "due_at": fields.String(description="Due date ISO 8601 datetime, optional")
})

user_create_model = api.model("UserCreate", {
    "email": fields.String(required=True, description="User email"),
    "password": fields.String(required=True, description="User password (min 8 characters)"),
    "full_name": fields.String(required=True, description="Doctor or admin full name"),
    "role": fields.String(enum=["admin", "doctor"], description="User role (default doctor)"),
})

# Mirrors Case.to_dict(): the shape every case endpoint returns.
case_summary_model = api.model("CaseSummary", {
    "id": fields.Integer(description="Case ID"),
    "status": fields.String(description="Case status"),
    "patient": fields.Nested(patient_sub_model, description="Patient information"),
    "assigned_to": fields.Nested(doctor_sub_model, allow_null=True, description="Assigned doctor, null while unassigned"),
    "assigned_at": fields.String(description="ISO assignment timestamp, nullable"),
    "due_at": fields.String(description="ISO due timestamp, nullable"),
    "created_at": fields.String(description="ISO creation timestamp"),
    "prediction": fields.Nested(prediction_sub_model, allow_null=True, description="Newest model prediction"),
})

# Doctor view: Case.to_dict() plus the doctor's own review draft.
case_detail_model = api.model("CaseDetail", {
    "id": fields.Integer(description="Case ID"),
    "status": fields.String(description="Case status"),
    "patient": fields.Nested(patient_sub_model, description="Patient information"),
    "assigned_to": fields.Nested(doctor_sub_model, allow_null=True, description="Assigned doctor"),
    "assigned_at": fields.String(description="ISO assignment timestamp, nullable"),
    "due_at": fields.String(description="ISO due timestamp, nullable"),
    "created_at": fields.String(description="ISO creation timestamp"),
    "prediction": fields.Nested(prediction_sub_model, allow_null=True, description="Newest model prediction, may be null"),
    "review": fields.Nested(review_nested_model, allow_null=True, description="Doctor's review draft, may be null"),
    "return_note": fields.String(description="Latest return note from admin, null unless returned"),
})

# Admin view: case summary plus triage flags, the current review and history.
admin_case_detail_model = api.model("AdminCaseDetail", {
    "id": fields.Integer(description="Case ID"),
    "status": fields.String(description="Case status"),
    "patient": fields.Nested(patient_sub_model, description="Patient information"),
    "assigned_to": fields.Nested(doctor_sub_model, allow_null=True, description="Assigned doctor"),
    "assigned_at": fields.String(description="ISO assignment timestamp, nullable"),
    "due_at": fields.String(description="ISO due timestamp, nullable"),
    "created_at": fields.String(description="ISO creation timestamp"),
    "prediction": fields.Nested(prediction_sub_model, allow_null=True, description="Newest model prediction, may be null"),
    "verdict": fields.String(description="Current review verdict, nullable"),
    "model_wrong": fields.Boolean(description="Whether the current review flags a model error"),
    "needs_testing": fields.Boolean(description="Whether the current review requests further testing"),
    "review": fields.Nested(review_nested_model, allow_null=True, description="Current assignee's review, may be null"),
    "audit": fields.List(fields.Nested(audit_sub_model), description="Audit log entries"),
})

catalog_model = api.model("Catalog", {
    "verdicts": fields.List(fields.Nested(catalog_item_model)),
    "findings": fields.List(fields.Nested(finding_item_model)),
    "diseases": fields.List(fields.Nested(catalog_item_model)),
    "tests": fields.List(fields.Nested(catalog_item_model)),
    "urgencies": fields.List(fields.Nested(catalog_item_model)),
    "feedback_kinds": fields.List(fields.Nested(catalog_item_model))
})

error_model = api.model("ErrorResponse", {
    "error": fields.String(description="Error message from the API")
})

# --- Routes ---


@api.route("/auth/login")
class AuthLogin(Resource):
    @api.doc(security=[], description="Authenticate doctor or admin with email and password to receive a JWT bearer token.")
    @api.expect(login_model)
    @api.response(200, "Success", login_response_model)
    @api.response(401, "Authentication failed", error_model)
    def post(self):
        """Authenticate user"""


@api.route("/auth/me")
class AuthMe(Resource):
    @api.doc(description="Returns profile information of currently authenticated user.")
    @api.response(200, "User profile", user_profile_model)
    @api.response(401, "Missing or invalid token", error_model)
    def get(self):
        """Get current user profile"""


@api.route("/catalog")
class Catalog(Resource):
    @api.doc(description="Returns choices for verdicts, lesion findings, diseases, and further tests.")
    @api.response(200, "Catalog of options", catalog_model)
    @api.response(401, "Not authenticated", error_model)
    def get(self):
        """Get application catalog"""


@api.route("/cases")
class CasesList(Resource):
    @api.doc(description="Returns cases assigned to the signed-in doctor.", params={"status": "Filter by case status"})
    @api.response(200, "List of case summaries", [case_summary_model])
    @api.response(400, "Unknown status", error_model)
    @api.response(401, "Not authenticated", error_model)
    @api.param("status", "Filter cases by status (unassigned, assigned, in_review, submitted, returned, accepted)")
    def get(self):
        """List assigned cases (Doctor)"""

    @api.doc(description="The doctor uploads a chest X-ray image and creates a case that is assigned to them from the start.")
    @api.expect(upload_parser)
    @api.response(201, "Case created", admin_case_detail_model)
    @api.response(401, "Not authenticated", error_model)
    @api.response(403, "Not allowed for this role", error_model)
    @api.response(422, "Missing image, bad image format, or missing patient name", error_model)
    def post(self):
        """Upload own case (Doctor)"""


@api.route("/cases/<int:case_id>")
class CaseDetail(Resource):
    @api.doc(description="Returns detailed case information including patient info, AI prediction, review draft, and marks.", params={"case_id": "Case unique identifier"})
    @api.response(200, "Case detail", case_detail_model)
    @api.response(404, "Case not found or not assigned to user", error_model)
    @api.param("case_id", "Case unique identifier")
    def get(self, case_id):
        """Get case detail (Doctor)"""


@api.route("/cases/<int:case_id>/image")
class CaseImage(Resource):
    @api.doc(description="Returns the PNG image for the case.", params={"case_id": "Case unique identifier"})
    @api.produces(["image/png"])
    @api.response(200, "X-ray PNG image")
    @api.response(401, "Not authenticated", error_model)
    @api.response(404, "Case not found or file not available", error_model)
    @api.param("case_id", "Case unique identifier")
    def get(self, case_id):
        """Download case X-ray image"""


@api.route("/cases/<int:case_id>/overlay")
class CaseOverlay(Resource):
    @api.doc(description="Returns the model heatmap overlay PNG image for the case prediction.", params={"case_id": "Case unique identifier"})
    @api.produces(["image/png"])
    @api.response(200, "Grad-CAM overlay PNG image")
    @api.response(401, "Not authenticated", error_model)
    @api.response(404, "Case not found, no prediction, or file not available", error_model)
    @api.param("case_id", "Case unique identifier")
    def get(self, case_id):
        """Download AI Grad-CAM overlay"""


@api.route("/cases/<int:case_id>/mask")
class CaseMask(Resource):
    @api.doc(description="Returns the lung segmentation mask PNG image for the case prediction.", params={"case_id": "Case unique identifier"})
    @api.produces(["image/png"])
    @api.response(200, "Lung mask PNG image")
    @api.response(401, "Not authenticated", error_model)
    @api.response(404, "Case not found, no prediction, or file not available", error_model)
    @api.param("case_id", "Case unique identifier")
    def get(self, case_id):
        """Download lung segmentation mask"""


@api.route("/cases/<int:case_id>/review")
class CaseReview(Resource):
    @api.doc(description="Saves doctor review draft.", params={"case_id": "Case unique identifier"})
    @api.expect(review_model)
    @api.response(200, "Updated case detail with review", case_detail_model)
    @api.response(401, "Not authenticated", error_model)
    @api.response(404, "Case not found", error_model)
    @api.response(409, "Case is not open for editing", error_model)
    @api.response(422, "Invalid input data", error_model)
    @api.param("case_id", "Case unique identifier")
    def put(self, case_id):
        """Save review draft"""


@api.route("/cases/<int:case_id>/review/submit")
class CaseReviewSubmit(Resource):
    @api.doc(description="Submits doctor's review for administrative review.", params={"case_id": "Case unique identifier"})
    @api.response(200, "Updated case detail after submit", case_detail_model)
    @api.response(401, "Not authenticated", error_model)
    @api.response(404, "Case not found", error_model)
    @api.response(409, "Case is not open for editing", error_model)
    @api.response(422, "A verdict is required before submitting", error_model)
    @api.param("case_id", "Case unique identifier")
    def post(self, case_id):
        """Submit review"""


@api.route("/admin/users")
class AdminUsers(Resource):
    @api.doc(description="Returns list of all users in the system.")
    @api.response(200, "List of user summaries", [user_item_model])
    @api.response(401, "Not authenticated", error_model)
    @api.response(403, "Not allowed for this role", error_model)
    def get(self):
        """List all users (Admin)"""

    @api.doc(description="Creates a new doctor or admin user.")
    @api.expect(user_create_model)
    @api.response(201, "User created", user_created_model)
    @api.response(401, "Not authenticated", error_model)
    @api.response(403, "Not allowed for this role", error_model)
    @api.response(409, "A user with this email already exists", error_model)
    @api.response(422, "Invalid input data", error_model)
    def post(self):
        """Create user (Admin)"""


@api.route("/admin/users/<int:user_id>")
class AdminUserDetail(Resource):
    @api.doc(description="Updates user profile, role, active status, or password.", params={"user_id": "User unique identifier"})
    @api.expect(user_update_model)
    @api.response(200, "Updated user", user_updated_model)
    @api.response(401, "Not authenticated", error_model)
    @api.response(403, "Not allowed for this role", error_model)
    @api.response(404, "User not found", error_model)
    @api.response(409, "You cannot deactivate your own account", error_model)
    @api.response(422, "Invalid input data", error_model)
    @api.param("user_id", "User unique identifier")
    def patch(self, user_id):
        """Update user (Admin)"""


@api.route("/admin/cases")
class AdminCases(Resource):
    @api.doc(description="Returns list of all cases across the system.", params={"status": "Filter by case status", "doctor": "Filter by doctor ID", "flag": "Filter by review flag"})
    @api.response(200, "List of case summaries", [case_summary_model])
    @api.response(400, "Unknown status, doctor, or flag filter", error_model)
    @api.response(401, "Not authenticated", error_model)
    @api.response(403, "Not allowed for this role", error_model)
    @api.param("status", "Filter cases by status")
    @api.param("doctor", "Filter cases by doctor user ID")
    @api.param("flag", "Filter cases by review flag: model_wrong or needs_testing")
    def get(self):
        """List all cases (Admin)"""

    @api.doc(description="Uploads a chest X-ray image and creates a new case.")
    @api.expect(upload_parser)
    @api.response(201, "Case created", case_summary_model)
    @api.response(401, "Not authenticated", error_model)
    @api.response(403, "Not allowed for this role", error_model)
    @api.response(422, "Missing image, bad image format, or missing patient name", error_model)
    def post(self):
        """Upload new case (Admin)"""


@api.route("/admin/cases/<int:case_id>")
class AdminCaseDetail(Resource):
    @api.doc(description="Returns full details and review history for a case.", params={"case_id": "Case unique identifier"})
    @api.response(200, "Full case details", admin_case_detail_model)
    @api.response(401, "Not authenticated", error_model)
    @api.response(403, "Not allowed for this role", error_model)
    @api.response(404, "Case not found", error_model)
    @api.param("case_id", "Case unique identifier")
    def get(self, case_id):
        """Get full case details (Admin)"""


@api.route("/admin/cases/assign")
class AdminCasesAssign(Resource):
    @api.doc(description="Assigns one or more cases to a specific doctor. Reassignment is all or nothing.")
    @api.expect(assign_model)
    @api.response(200, "Updated case summaries", [case_summary_model])
    @api.response(401, "Not authenticated", error_model)
    @api.response(403, "Not allowed for this role", error_model)
    @api.response(404, "One or more cases were not found", error_model)
    @api.response(409, "Cases already submitted or accepted cannot be reassigned", error_model)
    @api.response(422, "Invalid case IDs, doctor, or due date", error_model)
    def post(self):
        """Assign cases to doctor (Admin)"""


@api.route("/admin/cases/<int:case_id>/accept")
class AdminCaseAccept(Resource):
    @api.doc(description="Accepts doctor's submitted review for a case.", params={"case_id": "Case unique identifier"})
    @api.response(200, "Updated case summary", case_summary_model)
    @api.response(401, "Not authenticated", error_model)
    @api.response(403, "Not allowed for this role", error_model)
    @api.response(404, "Case not found", error_model)
    @api.response(409, "Only a submitted case can be accepted", error_model)
    @api.param("case_id", "Case unique identifier")
    def post(self, case_id):
        """Accept case review (Admin)"""


@api.route("/admin/cases/<int:case_id>/return")
class AdminCaseReturn(Resource):
    @api.doc(description="Returns submitted case back to doctor for revision.", params={"case_id": "Case unique identifier"})
    @api.expect(return_case_model)
    @api.response(200, "Updated case summary", case_summary_model)
    @api.response(401, "Not authenticated", error_model)
    @api.response(403, "Not allowed for this role", error_model)
    @api.response(404, "Case not found", error_model)
    @api.response(409, "Only a submitted case can be returned", error_model)
    @api.response(422, "A note explaining the return is required", error_model)
    @api.param("case_id", "Case unique identifier")
    def post(self, case_id):
        """Return case review for revision (Admin)"""


@api.route("/admin/export")
class AdminExport(Resource):
    @api.doc(description="Exports submitted reviews or model feedback as a CSV file download. Patient identity is never included.", params={"kind": "Kind of export: 'reviews' or 'model_feedback'"})
    @api.produces(["text/csv"])
    @api.response(200, "CSV file download")
    @api.response(400, "Invalid kind parameter", error_model)
    @api.response(401, "Not authenticated", error_model)
    @api.response(403, "Not allowed for this role", error_model)
    @api.param("kind", "Kind of export: 'reviews' or 'model_feedback'")
    def get(self):
        """Export CSV data (Admin)"""


@api.route("/admin/stats")
class AdminStats(Resource):
    @api.doc(description="Returns aggregated statistics on cases, reviews, and model performance.")
    @api.response(200, "System statistics", system_stats_model)
    @api.response(401, "Not authenticated", error_model)
    @api.response(403, "Not allowed for this role", error_model)
    def get(self):
        """Get system statistics (Admin)"""


@bp.get("/docs")
def docs_redirect():
    return redirect(url_for("docs.root"))
