import io

import pytest
from PIL import Image

from app import create_app
from app.extensions import db
from app.models import ROLE_ADMIN, ROLE_DOCTOR, User

PASSWORD = "correct-horse"


@pytest.fixture
def app(tmp_path):
    app = create_app(
        {
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": f"sqlite:///{tmp_path / 'test.db'}",
            "STORAGE_DIR": str(tmp_path / "storage"),
        }
    )
    with app.app_context():
        db.create_all()
        for email, name, role in [
            ("admin@test", "Admin", ROLE_ADMIN),
            ("doc1@test", "Doc One", ROLE_DOCTOR),
            ("doc2@test", "Doc Two", ROLE_DOCTOR),
        ]:
            user = User(email=email, full_name=name, role=role)
            user.set_password(PASSWORD)
            db.session.add(user)
        db.session.commit()
        yield app


@pytest.fixture
def client(app):
    return app.test_client()


def login(client, email):
    response = client.post("/api/v1/auth/login", json={"email": email, "password": PASSWORD})
    assert response.status_code == 200, response.json
    return {"Authorization": f"Bearer {response.json['token']}"}


@pytest.fixture
def admin(client):
    return login(client, "admin@test")


@pytest.fixture
def doc1(client):
    return login(client, "doc1@test")


@pytest.fixture
def doc2(client):
    return login(client, "doc2@test")


def png_bytes(fmt="PNG"):
    buffer = io.BytesIO()
    Image.new("L", (32, 32), 128).save(buffer, format=fmt)
    buffer.seek(0)
    return buffer


def user_id(client, admin, email):
    users = client.get("/api/v1/admin/users", headers=admin).json
    return next(u["id"] for u in users if u["email"] == email)


def upload(client, admin, name="Jane Banda", **fields):
    data = {"image": (png_bytes(), "cxr.png"), "patient_name": name, **fields}
    response = client.post(
        "/api/v1/admin/cases", headers=admin, data=data, content_type="multipart/form-data"
    )
    assert response.status_code == 201, response.json
    return response.json["id"]


def assign(client, admin, case_ids, email):
    return client.post(
        "/api/v1/admin/cases/assign",
        headers=admin,
        json={"case_ids": case_ids, "doctor_id": user_id(client, admin, email)},
    )


@pytest.fixture
def case_id(client, admin):
    """A case uploaded and assigned to doc1."""
    cid = upload(client, admin)
    assert assign(client, admin, [cid], "doc1@test").status_code == 200
    return cid
