"""Logged-in user endpoints: profile + membership. Mirrors the web routes."""
from flask import request
from flask_jwt_extended import jwt_required
from app.extensions import db
from app.utils.referral import (
    use_code, MEMBERSHIP_PRICE_WITHOUT_CODE, MEMBERSHIP_PRICE_WITH_CODE,
)
from app.utils.wallet import deposit
from . import api_bp
from .helpers import ok, err, current_api_user
from .serializers import user_full, membership_status


@api_bp.route('/me', methods=['GET'])
@jwt_required()
def get_me():
    user = current_api_user()
    if user is None:
        return err('UNAUTHORIZED', 'Akun tidak ditemukan', 401)
    return ok(user_full(user))


@api_bp.route('/me', methods=['PATCH'])
@jwt_required()
def update_me():
    user = current_api_user()
    if user is None:
        return err('UNAUTHORIZED', 'Akun tidak ditemukan', 401)
    data = request.get_json(silent=True) or {}
    # Only these fields are user-editable.
    for field in ('nickname', 'bio', 'avatar_url'):
        if field in data:
            setattr(user, field, (data[field] or '')[:300])
    db.session.commit()
    return ok(user_full(user))


@api_bp.route('/membership', methods=['GET'])
@jwt_required()
def get_membership():
    user = current_api_user()
    if user is None:
        return err('UNAUTHORIZED', 'Akun tidak ditemukan', 401)
    return ok(membership_status(user))


@api_bp.route('/membership/upgrade', methods=['POST'])
@jwt_required()
def upgrade_membership():
    user = current_api_user()
    if user is None:
        return err('UNAUTHORIZED', 'Akun tidak ditemukan', 401)
    if user.membership_paid:
        return err('ALREADY_MEMBER', 'Kamu sudah jadi member', 409)

    data = request.get_json(silent=True) or {}
    ref_code = (data.get('referral_code') or '').strip().upper()
    if ref_code and not user.referred_by:
        use_code(ref_code, user)

    has_referral = user.referred_by is not None
    price = MEMBERSHIP_PRICE_WITH_CODE if has_referral else MEMBERSHIP_PRICE_WITHOUT_CODE

    # Non-referral path records a forfeitable wallet deposit (mirrors web flow).
    if not has_referral:
        deposit(user, price, source='membership')

    user.membership_paid = True
    user.membership_amount_paid = price
    user.membership = 'member'
    user.check_auto_upgrade()
    db.session.commit()

    return ok({
        'membership': membership_status(user),
        'price': price,
        'via_referral': has_referral,
    })
