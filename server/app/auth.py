from flask import Blueprint, g, jsonify

from . import catalog
from .errors import ApiError
from .models import User
from .security import create_token, json_body, login_required

bp = Blueprint("auth", __name__)


@bp.post("/auth/login")
def login():
    data = json_body()
    email = str(data.get("email", "")).strip().lower()
    password = str(data.get("password", ""))
    user = User.query.filter_by(email=email).first()
    if user is None or not user.active or not user.check_password(password):
        raise ApiError(401, "Wrong email or password.")
    return jsonify(token=create_token(user), user=user.to_dict())


@bp.get("/auth/me")
@login_required()
def me():
    return jsonify(g.user.to_dict())


@bp.get("/catalog")
@login_required()
def get_catalog():
    return jsonify(catalog.as_dict())
