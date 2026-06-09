"""Standard JSON response helpers + auth guards for the /api/v1 layer.

Every API response follows one shape:
    success → {"ok": true,  "data": <...>}
    error   → {"ok": false, "error": {"code": "...", "message": "..."}}
"""
from functools import wraps
from flask import jsonify
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request
from app.models import User


def ok(data=None, status=200):
    return jsonify({'ok': True, 'data': data}), status


def err(code, message, status=400):
    return jsonify({'ok': False, 'error': {'code': code, 'message': message}}), status


def current_api_user():
    """Resolve the User from the JWT identity, or None."""
    uid = get_jwt_identity()
    if uid is None:
        return None
    return User.query.get(int(uid))


def member_required(fn):
    """Require a valid JWT AND a paid membership (admin/treasurer exempt)."""
    @wraps(fn)
    def wrapper(*args, **kwargs):
        verify_jwt_in_request()
        user = current_api_user()
        if user is None:
            return err('UNAUTHORIZED', 'Sesi tidak valid, login ulang', 401)
        if not user.membership_paid and user.role not in ('admin', 'treasurer'):
            return err('MEMBERSHIP_REQUIRED', 'Upgrade membership untuk fitur ini', 403)
        return fn(*args, **kwargs)
    return wrapper
