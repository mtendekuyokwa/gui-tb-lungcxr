from datetime import timedelta
from functools import wraps

import jwt
from flask import current_app, g, request

from .errors import ApiError
from .extensions import db
from .models import AuditLog, User, now


def create_token(user):
    payload = {
        "sub": str(user.id),
        "role": user.role,
        "exp": now() + timedelta(hours=current_app.config["TOKEN_HOURS"]),
    }
    return jwt.encode(payload, current_app.config["SECRET_KEY"], algorithm="HS256")


def _current_user():
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        raise ApiError(401, "Missing bearer token.")
    try:
        payload = jwt.decode(
            header[len("Bearer "):], current_app.config["SECRET_KEY"], algorithms=["HS256"]
        )
        user = db.session.get(User, int(payload["sub"]))
    except (jwt.PyJWTError, KeyError, ValueError):
        raise ApiError(401, "Invalid or expired token.")
    # Looked up on every request so deactivating a user takes effect at once.
    if user is None or not user.active:
        raise ApiError(401, "Invalid or expired token.")
    return user


def login_required(*roles):
    """Require a valid token, and one of `roles` if any are given."""

    def decorator(view):
        @wraps(view)
        def wrapped(*args, **kwargs):
            g.user = _current_user()
            if roles and g.user.role not in roles:
                raise ApiError(403, "Not allowed for this role.")
            return view(*args, **kwargs)

        return wrapped

    return decorator


def audit(case, action, note=""):
    db.session.add(AuditLog(case_id=case.id, user_id=g.user.id, action=action, note=note))


def json_body():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        raise ApiError(400, "Request body must be a JSON object.")
    return data
