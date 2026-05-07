"""Auth decorators for Daddies Padel routes.

State machine:
  Not logged in  → login_required_json returns 401 JSON
  Guest user     → require_member redirects to /membership
  Member, non-owner → require_tournament_owner returns 403
  Member, owner / Admin → full access
"""
from functools import wraps
from flask import jsonify, redirect, url_for, abort, request
from flask_login import current_user


def login_required_json(f):
    """Block unauthenticated requests with JSON 401.
    Used on score/settings/rename routes so the JS fetch gets a clean error.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        if not current_user.is_authenticated:
            return jsonify({'ok': False, 'error': 'Login dulu untuk input skor'}), 401
        return f(*args, **kwargs)
    return decorated


def require_member(f):
    """Block non-paying members. Redirects GET, returns JSON 403 for POST/fetch."""
    @wraps(f)
    def decorated(*args, **kwargs):
        if not current_user.is_authenticated:
            if request.method == 'GET':
                return redirect(url_for('auth.login'))
            return jsonify({'ok': False, 'error': 'Login dulu'}), 401
        if not current_user.membership_paid and current_user.role not in ('admin', 'treasurer'):
            if request.method == 'GET':
                return redirect(url_for('main.membership'))
            return jsonify({'ok': False, 'error': 'Upgrade membership untuk fitur ini'}), 403
        return f(*args, **kwargs)
    return decorated


def require_tournament_owner(f):
    """Allow only the tournament creator (or admin) to call this route.
    GET requests redirect to login/standings; POST/fetch returns JSON 403.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        if not current_user.is_authenticated:
            if request.method == 'GET':
                return redirect(url_for('auth.login'))
            return jsonify({'ok': False, 'error': 'Login dulu'}), 401
        if current_user.role in ('admin', 'treasurer'):
            return f(*args, **kwargs)
        from app.models import Tournament
        # Check kwargs, then URL args, then form data
        tid = (kwargs.get('tournament_id') or
               request.args.get('tournament_id', type=int) or
               request.form.get('tournament_id', type=int))
        t = Tournament.query.get(tid) if tid else None
        if not t or t.created_by != current_user.id:
            if request.method == 'GET':
                return redirect(url_for('tournament.detail',
                                        tournament_id=tid or 0, tab='standing'))
            return jsonify({'ok': False, 'error': 'Hanya pembuat turnamen yang bisa melakukan ini'}), 403
        return f(*args, **kwargs)
    return decorated
