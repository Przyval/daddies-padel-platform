"""JSON API package (/api/v1). All responses follow the {ok, data|error} shape.

The blueprint is defined here; route modules import it and attach endpoints.
Importing them at the bottom registers the routes when the package loads.
"""
from flask import Blueprint, jsonify
from app.extensions import jwt

api_bp = Blueprint('api', __name__)


# --- JWT errors as JSON (not HTML redirects) ------------------------------
def _jwt_error(code, message, status):
    return jsonify({'ok': False, 'error': {'code': code, 'message': message}}), status


@jwt.unauthorized_loader
def _missing_token(reason):
    return _jwt_error('NO_TOKEN', 'Token tidak ada, login dulu', 401)


@jwt.invalid_token_loader
def _invalid_token(reason):
    return _jwt_error('INVALID_TOKEN', 'Token tidak valid', 401)


@jwt.expired_token_loader
def _expired_token(header, payload):
    return _jwt_error('TOKEN_EXPIRED', 'Token kedaluwarsa, refresh dulu', 401)


# --- Health check ----------------------------------------------------------
@api_bp.route('/health', methods=['GET'])
def health():
    return jsonify({'ok': True, 'data': {'status': 'up', 'version': 'v1'}})


# Attach route modules (must come after api_bp is defined).
from . import auth, me, sessions  # noqa: E402,F401
