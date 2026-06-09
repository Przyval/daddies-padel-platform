"""Model → JSON serializers. Keep all API shaping in one place so the
native app sees a stable contract regardless of internal model changes.
"""


def user_public(u):
    """Minimal shape for member lists / leaderboards / opponents."""
    if u is None:
        return None
    return {
        'id': u.id,
        'name': u.display_name,
        'nickname': u.nickname,
        'initials': u.initials,
        'avatar_url': u.avatar_url,
        'membership': u.membership,
        'membership_label': u.membership_label,
        'member_tier_label': u.member_tier_label,
        'kta_tier': u.kta_tier,
    }


def user_full(u):
    """Full shape for /me — the logged-in user's own profile."""
    if u is None:
        return None
    streak = u.streak_data
    return {
        **user_public(u),
        'username': u.username,
        'email': u.email,
        'phone': u.phone,
        'bio': u.bio,
        'role': u.role,
        'kta_number': u.kta_number,
        'membership_paid': u.membership_paid,
        'membership_amount_paid': u.membership_amount_paid,
        'chips_balance': u.chips_balance,
        'wallet_balance': u.wallet_balance,
        'referral_code': u.referral_code,
        'can_unlock_kta': u.can_unlock_kta,
        'stats': {
            'sessions_played': u.sessions_played,
            'tournaments_played': u.tournaments_played,
            'total_games': u.total_games,
            'total_points': u.total_points,
        },
        'streak': {
            'current': streak.get('current'),
            'longest': streak.get('longest'),
            'total_weeks': streak.get('total_weeks'),
            'at_risk': streak.get('at_risk'),
            'tier': streak.get('tier'),
        },
    }


def membership_status(u):
    """Shape for the membership screen — status + progress toward next tier."""
    if u is None:
        return None
    return {
        'membership': u.membership,
        'membership_label': u.membership_label,
        'member_tier_label': u.member_tier_label,
        'kta_number': u.kta_number,
        'kta_tier': u.kta_tier,
        'membership_paid': u.membership_paid,
        'progress': {
            'games_played': u.total_games,
            'games_required': 5,
            'chips_balance': u.chips_balance,
            'chips_required_elite': 10000,
            'games_required_elite': 20,
        },
    }
