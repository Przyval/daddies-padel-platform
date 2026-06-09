"""Community endpoints: leaderboard, members, notifications. JSON mirrors
the web routes in routes/main.py + utils/leaderboard.py.
"""
from flask import request
from flask_jwt_extended import jwt_required
from app.extensions import db
from app.models import User, Notification
from app.utils.leaderboard import get_global_leaderboard, shop_discount_for_rank
from . import api_bp
from .helpers import ok, err, current_api_user
from .serializers import user_public, member_profile, notification_public


# ── Leaderboard ────────────────────────────────────────────────────────────

@api_bp.route('/leaderboard', methods=['GET'])
@jwt_required()
def leaderboard():
    """tab = chips | streak | loyalty | global (tournament points)."""
    tab = request.args.get('tab', 'chips')

    if tab == 'global':
        lb = get_global_leaderboard()
        users = {u.id: u for u in User.query.all()}
        rows = [{'rank': e['rank'], 'value': e['points'], 'metric': 'points',
                 'user': user_public(users.get(e['user_id']))}
                for e in lb if e['user_id'] in users]
        return ok(rows)

    users = User.query.all()
    if tab == 'streak':
        keyed = [(u.streak_data['current'], u) for u in users]
        metric = 'streak_weeks'
    elif tab == 'loyalty':
        keyed = [(u.sessions_played, u) for u in users]
        metric = 'sessions'
    else:  # chips (default)
        keyed = [(u.chips_balance, u) for u in users]
        metric = 'chips'

    keyed.sort(key=lambda x: x[0], reverse=True)
    rows = [{'rank': i + 1, 'value': val, 'metric': metric, 'user': user_public(u)}
            for i, (val, u) in enumerate(keyed)]
    return ok(rows)


# ── Members ────────────────────────────────────────────────────────────────

@api_bp.route('/members', methods=['GET'])
@jwt_required()
def members():
    q = (request.args.get('q') or '').strip()
    query = User.query.order_by(User.username)
    if q:
        like = f'%{q}%'
        query = query.filter(db.or_(User.username.ilike(like),
                                    User.nickname.ilike(like)))
    return ok([user_public(u) for u in query.all()])


@api_bp.route('/members/<int:user_id>', methods=['GET'])
@jwt_required()
def member_detail(user_id):
    u = User.query.get(user_id)
    if u is None:
        return err('NOT_FOUND', 'Anggota tidak ditemukan', 404)
    return ok(member_profile(u))


# ── Notifications ──────────────────────────────────────────────────────────

@api_bp.route('/notifications', methods=['GET'])
@jwt_required()
def notifications():
    user = current_api_user()
    rows = (Notification.query.filter_by(user_id=user.id)
            .order_by(Notification.created_at.desc()).all())
    unread = sum(1 for n in rows if not n.is_read)
    return ok({'unread_count': unread,
               'notifications': [notification_public(n) for n in rows]})


@api_bp.route('/notifications/read-all', methods=['POST'])
@jwt_required()
def mark_all_read():
    user = current_api_user()
    Notification.query.filter_by(user_id=user.id, is_read=False)\
        .update({'is_read': True})
    db.session.commit()
    return ok({'message': 'Semua notifikasi ditandai dibaca'})


@api_bp.route('/notifications/<int:notif_id>/read', methods=['POST'])
@jwt_required()
def mark_one_read(notif_id):
    user = current_api_user()
    n = Notification.query.filter_by(id=notif_id, user_id=user.id).first()
    if n is None:
        return err('NOT_FOUND', 'Notifikasi tidak ditemukan', 404)
    n.is_read = True
    db.session.commit()
    return ok(notification_public(n))
