from datetime import datetime, timezone

from werkzeug.security import check_password_hash, generate_password_hash

from .extensions import db

ROLE_ADMIN = "admin"
ROLE_DOCTOR = "doctor"

# Case lifecycle: see "Roles and workflow" in DOCUMENTATION.md.
UNASSIGNED = "unassigned"
ASSIGNED = "assigned"
IN_REVIEW = "in_review"
SUBMITTED = "submitted"
RETURNED = "returned"
ACCEPTED = "accepted"
CASE_STATUSES = (UNASSIGNED, ASSIGNED, IN_REVIEW, SUBMITTED, RETURNED, ACCEPTED)
# Statuses in which the assigned doctor may edit the review, and the admin may reassign.
OPEN_STATUSES = (ASSIGNED, IN_REVIEW, RETURNED)

DRAFT = "draft"
QUEUED = "queued"
DONE = "done"
FAILED = "failed"


def now():
    return datetime.now(timezone.utc)


def iso(value):
    if value is None:
        return None
    # SQLite drops the offset; everything is stored as UTC.
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.isoformat()


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(255), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    full_name = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), nullable=False)
    active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime(timezone=True), nullable=False, default=now)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def to_dict(self):
        return {
            "id": self.id,
            "email": self.email,
            "full_name": self.full_name,
            "role": self.role,
            "active": self.active,
        }


class Patient(db.Model):
    __tablename__ = "patients"

    id = db.Column(db.Integer, primary_key=True)
    hospital_number = db.Column(db.String(64), unique=True)
    name = db.Column(db.String(255), nullable=False)
    sex = db.Column(db.String(16))
    birth_year = db.Column(db.Integer)

    def to_dict(self):
        return {
            "id": self.id,
            "hospital_number": self.hospital_number,
            "name": self.name,
            "sex": self.sex,
            "birth_year": self.birth_year,
        }


class Case(db.Model):
    __tablename__ = "cases"

    id = db.Column(db.Integer, primary_key=True)
    patient_id = db.Column(db.Integer, db.ForeignKey("patients.id"), nullable=False)
    image_path = db.Column(db.String(512))
    status = db.Column(db.String(20), nullable=False, default=UNASSIGNED, index=True)
    assigned_to = db.Column(db.Integer, db.ForeignKey("users.id"), index=True)
    assigned_by = db.Column(db.Integer, db.ForeignKey("users.id"))
    assigned_at = db.Column(db.DateTime(timezone=True))
    due_at = db.Column(db.DateTime(timezone=True))
    created_at = db.Column(db.DateTime(timezone=True), nullable=False, default=now)

    patient = db.relationship("Patient")
    doctor = db.relationship("User", foreign_keys=[assigned_to])
    predictions = db.relationship(
        "Prediction", order_by="Prediction.id", cascade="all, delete-orphan"
    )
    reviews = db.relationship("Review", back_populates="case", cascade="all, delete-orphan")
    audit = db.relationship("AuditLog", order_by="AuditLog.id", cascade="all, delete-orphan")

    @property
    def prediction(self):
        """The newest prediction; older model versions are kept as history."""
        return self.predictions[-1] if self.predictions else None

    def review_by(self, doctor_id):
        return next((r for r in self.reviews if r.doctor_id == doctor_id), None)

    @property
    def current_review(self):
        return self.review_by(self.assigned_to) if self.assigned_to else None

    def to_dict(self):
        prediction = self.prediction
        return {
            "id": self.id,
            "status": self.status,
            "patient": self.patient.to_dict(),
            "assigned_to": self.doctor.to_dict() if self.doctor else None,
            "assigned_at": iso(self.assigned_at),
            "due_at": iso(self.due_at),
            "created_at": iso(self.created_at),
            "prediction": prediction.to_dict() if prediction else None,
        }


class Prediction(db.Model):
    __tablename__ = "predictions"

    id = db.Column(db.Integer, primary_key=True)
    case_id = db.Column(db.Integer, db.ForeignKey("cases.id"), nullable=False, index=True)
    model_version = db.Column(db.String(64))
    label = db.Column(db.String(20))
    tb_probability = db.Column(db.Float)
    mask_path = db.Column(db.String(512))
    overlay_path = db.Column(db.String(512))
    state = db.Column(db.String(20), nullable=False, default=QUEUED, index=True)
    created_at = db.Column(db.DateTime(timezone=True), nullable=False, default=now)

    def to_dict(self):
        return {
            "id": self.id,
            "state": self.state,
            "model_version": self.model_version,
            "label": self.label,
            "tb_probability": self.tb_probability,
            "has_overlay": bool(self.overlay_path),
        }


class Review(db.Model):
    __tablename__ = "reviews"
    __table_args__ = (db.UniqueConstraint("case_id", "doctor_id"),)

    id = db.Column(db.Integer, primary_key=True)
    case_id = db.Column(db.Integer, db.ForeignKey("cases.id"), nullable=False, index=True)
    doctor_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    verdict = db.Column(db.String(32))
    note = db.Column(db.Text, nullable=False, default="")
    state = db.Column(db.String(20), nullable=False, default=DRAFT)
    submitted_at = db.Column(db.DateTime(timezone=True))
    updated_at = db.Column(db.DateTime(timezone=True), nullable=False, default=now, onupdate=now)

    case = db.relationship("Case", back_populates="reviews")
    doctor = db.relationship("User")
    marks = db.relationship("Mark", order_by="Mark.id", cascade="all, delete-orphan")
    disease_tags = db.relationship("DiseaseTag", order_by="DiseaseTag.id", cascade="all, delete-orphan")
    feedback = db.relationship("ModelFeedback", uselist=False, cascade="all, delete-orphan")
    test_requests = db.relationship("TestRequest", order_by="TestRequest.id", cascade="all, delete-orphan")

    def to_dict(self):
        tests = self.test_requests
        return {
            "id": self.id,
            "doctor": self.doctor.to_dict(),
            "state": self.state,
            "verdict": self.verdict,
            "note": self.note,
            "submitted_at": iso(self.submitted_at),
            "updated_at": iso(self.updated_at),
            "marks": [{"finding": m.finding_code, "points": m.points} for m in self.marks],
            "disease_tags": [
                {"code": t.disease_code, "free_text": t.free_text} for t in self.disease_tags
            ],
            "model_feedback": (
                {"kind": self.feedback.kind, "note": self.feedback.note, "derived": self.feedback.derived}
                if self.feedback
                else None
            ),
            "further_testing": (
                {
                    "tests": [t.test_code for t in tests],
                    "urgency": tests[0].urgency,
                    "free_text": tests[0].free_text,
                }
                if tests
                else None
            ),
        }


class Mark(db.Model):
    __tablename__ = "marks"

    id = db.Column(db.Integer, primary_key=True)
    review_id = db.Column(db.Integer, db.ForeignKey("reviews.id"), nullable=False, index=True)
    # List of [x, y] pairs, each 0..1 relative to image width and height.
    points = db.Column(db.JSON, nullable=False)
    # Null while the mark is unlabelled.
    finding_code = db.Column(db.String(64))


class DiseaseTag(db.Model):
    __tablename__ = "disease_tags"

    id = db.Column(db.Integer, primary_key=True)
    review_id = db.Column(db.Integer, db.ForeignKey("reviews.id"), nullable=False, index=True)
    disease_code = db.Column(db.String(64), nullable=False)
    free_text = db.Column(db.String(255), nullable=False, default="")


class ModelFeedback(db.Model):
    __tablename__ = "model_feedback"

    id = db.Column(db.Integer, primary_key=True)
    review_id = db.Column(db.Integer, db.ForeignKey("reviews.id"), nullable=False, unique=True)
    # The exact prediction the doctor was looking at.
    prediction_id = db.Column(db.Integer, db.ForeignKey("predictions.id"))
    kind = db.Column(db.String(32), nullable=False)
    note = db.Column(db.Text, nullable=False, default="")
    # True when filled in by the server because the verdict contradicted the model.
    derived = db.Column(db.Boolean, nullable=False, default=False)

    prediction = db.relationship("Prediction")


class TestRequest(db.Model):
    __tablename__ = "test_requests"

    id = db.Column(db.Integer, primary_key=True)
    review_id = db.Column(db.Integer, db.ForeignKey("reviews.id"), nullable=False, index=True)
    test_code = db.Column(db.String(64), nullable=False)
    urgency = db.Column(db.String(16), nullable=False)
    free_text = db.Column(db.String(255), nullable=False, default="")


class AuditLog(db.Model):
    __tablename__ = "audit_log"

    id = db.Column(db.Integer, primary_key=True)
    case_id = db.Column(db.Integer, db.ForeignKey("cases.id"), nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"))
    action = db.Column(db.String(32), nullable=False)
    note = db.Column(db.Text, nullable=False, default="")
    at = db.Column(db.DateTime(timezone=True), nullable=False, default=now)

    user = db.relationship("User")

    def to_dict(self):
        return {
            "action": self.action,
            "note": self.note,
            "at": iso(self.at),
            "user": self.user.full_name if self.user else None,
        }
