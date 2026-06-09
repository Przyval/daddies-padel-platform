"""JWT auth endpoints for the native app — mirrors routes/auth.py but JSON."""
from flask import request
from flask_jwt_extended import (
    create_access_token, create_refresh_token,
    jwt_required, get_jwt_identity,
)
from app.extensions import db, limiter
from app.models import User
from app.utils.referral import use_code, ensure_code, validate_code
from . import api_bp
from .helpers import ok, err, current_api_user
from .serializers import user_full


def _tokens_for(user):
    identity = str(user.id)
    return {
        'access_token': create_access_token(identity=identity),
        'refresh_token': create_refresh_token(identity=identity),
        'user': user_full(user),
    }


@api_bp.route('/auth/register', methods=['POST'])
@limiter.limit('5 per minute')
def register():
    data = request.get_json(silent=True) or {}
    username = (data.get('username') or '').strip()
    email = (data.get('email') or '').strip().lower()
    phone = (data.get('phone') or '').strip()
    password = data.get('password') or ''
    referral = (data.get('referral_code') or '').strip().upper()

    if not all([username, email, phone, password]):
        return err('VALIDATION', 'username, email, phone, password wajib diisi', 422)
    if len(password) < 6:
        return err('VALIDATION', 'Password minimal 6 karakter', 422)
    if User.query.filter_by(email=email).first():
        return err('EMAIL_TAKEN', 'Email sudah terdaftar', 409)
    if User.query.filter_by(phone=phone).first():
        return err('PHONE_TAKEN', 'Nomor HP sudah terdaftar', 409)

    user = User(username=username, email=email, phone=phone, role='member')
    user.set_password(password)
    db.session.add(user)
    db.session.flush()
    ensure_code(user)
    if referral:
        use_code(referral, user)
    db.session.commit()

    return ok(_tokens_for(user), 201)


@api_bp.route('/auth/login', methods=['POST'])
@limiter.limit('10 per minute')
def login():
    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''

    user = User.query.filter_by(email=email).first()
    if user is None or not user.check_password(password):
        return err('INVALID_CREDENTIALS', 'Email atau password salah', 401)

    return ok(_tokens_for(user))


@api_bp.route('/auth/refresh', methods=['POST'])
@jwt_required(refresh=True)
def refresh():
    identity = get_jwt_identity()
    user = User.query.get(int(identity))
    if user is None:
        return err('UNAUTHORIZED', 'Akun tidak ditemukan', 401)
    return ok({'access_token': create_access_token(identity=identity)})


@api_bp.route('/auth/logout', methods=['POST'])
@jwt_required()
def logout():
    # Stateless JWT: client discards tokens. (Token blocklist = future hardening.)
    return ok({'message': 'Logged out'})


@api_bp.route('/auth/validate-referral', methods=['GET'])
def validate_referral():
    code = (request.args.get('code') or '').strip().upper()
    owner = validate_code(code)
    if owner:
        return ok({
            'valid': True,
            'price': 200000,
            'price_display': 'Rp 200.000',
            'message': f'Kode valid! Diundang oleh {owner.first_name}',
        })
    return ok({
        'valid': False,
        'price': 400000,
        'price_display': 'Rp 400.000',
        'message': 'Kode tidak valid atau sudah penuh',
    })
