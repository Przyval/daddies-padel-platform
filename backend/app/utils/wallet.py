"""Wallet utilities for Daddies Padel.

Rules (from brainstorm):
- Rp 400K deposit (no referral) → wallet, expires in 1 year, non-refundable (hangus)
- Rp 200K payment (with referral) → direct payment, no wallet entry needed
- Wallet balance can be spent on chips, merch, events
- If expires_at passes → wallet_hangus = True, balance = 0
"""
from datetime import datetime, timedelta


WALLET_EXPIRY_DAYS = 365  # 1 year


def deposit(user, amount: int, source: str = 'membership') -> None:
    """Record a wallet deposit (Rp 400K non-referral flow)."""
    from app.extensions import db
    user.wallet_balance += amount
    user.wallet_expires_at = datetime.utcnow() + timedelta(days=WALLET_EXPIRY_DAYS)
    user.wallet_hangus = False
    db.session.flush()


def debit(user, amount: int, description: str = '') -> bool:
    """Deduct from wallet. Returns True if successful."""
    from app.extensions import db
    check_expiry(user)
    if user.wallet_hangus or user.wallet_balance < amount:
        return False
    user.wallet_balance -= amount
    db.session.flush()
    return True


def check_expiry(user) -> bool:
    """Mark wallet as hangus if expired. Returns True if hangus."""
    from app.extensions import db
    if not user.wallet_hangus and user.wallet_expires_at:
        if datetime.utcnow() > user.wallet_expires_at:
            user.wallet_hangus = True
            user.wallet_balance = 0
            db.session.flush()
            return True
    return user.wallet_hangus


def wallet_status(user) -> dict:
    """Return wallet status summary for display."""
    check_expiry(user)
    expires = user.wallet_expires_at
    days_left = None
    if expires and not user.wallet_hangus:
        days_left = max(0, (expires - datetime.utcnow()).days)
    return {
        'balance': user.wallet_balance,
        'balance_display': f'Rp {user.wallet_balance:,}',
        'hangus': user.wallet_hangus,
        'expires_at': expires,
        'days_left': days_left,
        'warning': days_left is not None and days_left <= 30,
    }
