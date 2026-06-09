"""Model → JSON serializers. Keep all API shaping in one place so the
native app sees a stable contract regardless of internal model changes.
"""
from app.models import Booking


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


def _iso(dt):
    return dt.isoformat() if dt else None


def session_summary(m, my_status=None):
    """Match (play session) shape for lists."""
    if m is None:
        return None
    return {
        'id': m.id,
        'title': m.title,
        'date_time': _iso(m.date_time),
        'location': m.location,
        'price': m.price,
        'max_players': m.max_players,
        'status': m.status,
        'event_type': m.event_type,
        'confirmed_count': m.confirmed_count,
        'waitlist_count': m.waitlist_count,
        'is_full': m.confirmed_count >= m.max_players,
        'my_status': my_status,  # this user's booking status, or None
    }


def booking_public(b):
    if b is None:
        return None
    return {
        'id': b.id,
        'status': b.status,
        'player': user_public(b.player),
        'has_payment_proof': bool(b.payment_proof),
        'created_at': _iso(b.created_at),
    }


def session_detail(m, my_booking=None):
    """Match detail with players + the requesting user's booking."""
    if m is None:
        return None
    bookings = m.bookings.order_by(Booking.created_at).all()
    data = session_summary(m, my_status=my_booking.status if my_booking else None)
    data['notes'] = m.notes
    data['players'] = [booking_public(b) for b in bookings]
    data['my_booking'] = booking_public(my_booking)
    return data


# ── Tournament ─────────────────────────────────────────────────────────────

def participant_public(p):
    if p is None:
        return None
    return {
        'id': p.id,
        'name': p.name,
        'first_name': p.first_name,
        'initials': p.initials,
        'gender': p.gender,
        'seed': p.seed,
        'user_id': p.user_id,
        'sitting_out': p.sitting_out_permanent,
    }


def tmatch_public(m):
    if m is None:
        return None
    return {
        'id': m.id,
        'court': m.court,
        'status': m.status,
        'team1': [participant_public(m.team1_p1), participant_public(m.team1_p2)],
        'team2': [participant_public(m.team2_p1), participant_public(m.team2_p2)],
        'sets': m.sets,
        'score_team1': m.score_team1,
        'score_team2': m.score_team2,
        'score_display': m.score_display,
        'winner': m.winner,
    }


def tround_public(r):
    from app.models import TournamentMatch
    matches = r.matches.order_by(TournamentMatch.court).all()
    return {
        'round_number': r.round_number,
        'is_complete': r.is_complete,
        'total_matches': r.total_matches,
        'pending_count': r.pending_count,
        'matches': [tmatch_public(m) for m in matches],
    }


def playoff_public(p):
    if p is None:
        return None
    return {
        'id': p.id,
        'bracket_round': p.bracket_round,
        'match_index': p.match_index,
        'team1': [participant_public(p.team1_p1), participant_public(p.team1_p2)],
        'team2': [participant_public(p.team2_p1), participant_public(p.team2_p2)],
        'sets': p.sets,
        'score_display': p.score_display,
        'status': p.status,
        'winner': p.winner,
    }


def tournament_summary(t):
    if t is None:
        return None
    return {
        'id': t.id,
        'name': t.name,
        'date': _iso(t.date),
        'status': t.status,
        'format': t.format,
        'format_label': t.format_label,
        'format_icon': t.format_icon,
        'num_courts': t.num_courts,
        'scoring_mode': t.scoring_mode,
        'points_per_game': t.points_per_game,
        'current_round': t.current_round,
        'total_rounds': t.total_rounds,
        'completed_matches': t.completed_matches,
        'participant_count': t.participants.count(),
        'created_by': t.created_by,
    }


def standing_row(s, rank):
    """Serialize one row from routes.tournament.calculate_leaderboard()."""
    return {
        'rank': rank,
        'participant': participant_public(s['participant']),
        'points': s['points'],
        'wins': s['wins'],
        'losses': s['losses'],
        'ties': s['ties'],
        'matches_played': s['matches_played'],
        'games_won': s['games_won'],
        'games_lost': s['games_lost'],
        'diff': s.get('diff_pts', 0),
    }


def tournament_detail(t, standings_rows=None):
    from app.models import TournamentParticipant
    data = tournament_summary(t)
    data['settings'] = {
        'win_points': t.win_points,
        'draw_points': t.draw_points,
        'loss_points': t.loss_points,
        'sort_by_wins': t.sort_by_wins,
        'h2h_tiebreaker': t.h2h_tiebreaker,
        'court_bonus_round': t.court_bonus_round,
    }
    parts = t.participants.order_by(TournamentParticipant.seed).all()
    data['participants'] = [participant_public(p) for p in parts]
    data['rounds'] = [tround_public(r) for r in t.rounds.all()]
    if standings_rows is not None:
        data['standings'] = standings_rows
    return data


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
