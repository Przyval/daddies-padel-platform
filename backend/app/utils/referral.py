"""Referral code utilities for Daddies Padel.

Rules (from brainstorm transcript):
- Every member gets 3 uses/month
- Using a code → Rp 200.000 membership price
- No code     → Rp 400.000 (full price, goes to wallet, non-refundable)
- Monthly reset: uses_this_month resets on the 1st of each month
- Code is 6-char alphanumeric, auto-generated on user creation
"""
import random
import string
from datetime import date


MEMBERSHIP_PRICE_WITH_CODE = 200_000   # Rp 200.000
MEMBERSHIP_PRICE_WITHOUT_CODE = 400_000  # Rp 400.000
MAX_USES_PER_MONTH = 3


def generate_code() -> str:
    """Generate a unique 6-char alphanumeric referral code."""
    from app.models import User
    chars = string.ascii_uppercase + string.digits
    chars = chars.replace('O', '').replace('0', '').replace('I', '').replace('1', '')
    while True:
        code = ''.join(random.choices(chars, k=6))
        if not User.query.filter_by(referral_code=code).first():
            return code


def ensure_code(user) -> str:
    """Generate and assign a referral code if user doesn't have one yet."""
    from app.extensions import db
    if not user.referral_code:
        user.referral_code = generate_code()
        db.session.flush()
    return user.referral_code


def _reset_if_new_month(user):
    """Reset monthly use counter if we're in a new month."""
    from app.extensions import db
    today = date.today()
    if user.referral_reset_date is None or user.referral_reset_date.month != today.month or user.referral_reset_date.year != today.year:
        user.referral_uses_this_month = 0
        user.referral_reset_date = today
        db.session.flush()


def validate_code(code: str):
    """Return the User who owns this code, or None if invalid."""
    from app.models import User
    if not code:
        return None
    owner = User.query.filter_by(referral_code=code.upper()).first()
    if not owner or not owner.membership_paid:
        return None
    _reset_if_new_month(owner)
    if owner.referral_uses_this_month >= MAX_USES_PER_MONTH:
        return None
    return owner


def use_code(code: str, new_user) -> tuple[bool, str]:
    """Apply a referral code for new_user. Returns (success, message).

    Prior art: approval-race-condition-toctou pitfall — use a flush-before-check
    pattern to minimise TOCTOU on referral_uses_this_month.
    """
    from app.extensions import db
    owner = validate_code(code)
    if not owner:
        return False, 'Kode referral tidak valid atau sudah penuh (maks 3/bulan)'

    new_user.referred_by = owner.id
    new_user.membership_amount_paid = MEMBERSHIP_PRICE_WITH_CODE
    owner.referral_uses_this_month += 1
    db.session.flush()
    return True, f'Kode valid! Harga membership: Rp {MEMBERSHIP_PRICE_WITH_CODE:,}'


def membership_price_for(code: str) -> int:
    """Return the membership price given an optional referral code."""
    owner = validate_code(code)
    return MEMBERSHIP_PRICE_WITH_CODE if owner else MEMBERSHIP_PRICE_WITHOUT_CODE


def referral_stats(user) -> dict:
    """Return referral stats for a user's dashboard."""
    from app.models import User
    _reset_if_new_month(user)
    total_referred = User.query.filter_by(referred_by=user.id).count()
    paid_referred = User.query.filter_by(
        referred_by=user.id, membership_paid=True
    ).count()
    return {
        'code': ensure_code(user),
        'uses_this_month': user.referral_uses_this_month,
        'remaining_this_month': MAX_USES_PER_MONTH - user.referral_uses_this_month,
        'total_referred': total_referred,
        'paid_referred': paid_referred,
    }
