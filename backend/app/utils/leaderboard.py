"""Global leaderboard utilities.

Rank is computed across ALL tournaments (aggregate game points).
Cached in User.leaderboard_rank nightly — not real-time.
Top 50 unlock: 50% merch discount + access to limited items.
"""
from app.extensions import db


RANK_GOLD_CUTOFF = 50      # Top 50 → 50% discount + limited access
RANK_SILVER_CUTOFF = 100   # 51-100 → 20% discount


def get_global_leaderboard():
    """Return users ordered by total tournament points, all-time."""
    from app.models import User, TournamentParticipant, TournamentMatch, TournamentRound
    from collections import defaultdict

    # Sum game points per user across all tournaments
    scores = defaultdict(int)
    matches = TournamentMatch.query.filter_by(status='completed').all()
    for m in matches:
        for pid, is_t1 in [
            (m.team1_p1_id, True), (m.team1_p2_id, True),
            (m.team2_p1_id, False), (m.team2_p2_id, False)
        ]:
            if not pid:
                continue
            p = TournamentParticipant.query.get(pid)
            if p and p.user_id:
                scores[p.user_id] += m.score_team1 if is_t1 else m.score_team2

    ranked = sorted(scores.items(), key=lambda x: -x[1])
    return [{'user_id': uid, 'points': pts, 'rank': i + 1}
            for i, (uid, pts) in enumerate(ranked)]


def update_cached_ranks():
    """Update User.leaderboard_rank for all users. Call nightly."""
    from app.models import User
    lb = get_global_leaderboard()
    ranked_ids = {entry['user_id']: entry['rank'] for entry in lb}
    for user in User.query.all():
        user.leaderboard_rank = ranked_ids.get(user.id)
    db.session.commit()


def get_user_rank(user_id: int) -> int | None:
    """Return cached rank or None."""
    from app.models import User
    u = User.query.get(user_id)
    return u.leaderboard_rank if u else None


def shop_discount_for_rank(rank: int | None) -> int:
    """Return discount percentage (0, 20, or 50) based on rank."""
    if rank is None:
        return 0
    if rank <= RANK_GOLD_CUTOFF:
        return 50
    if rank <= RANK_SILVER_CUTOFF:
        return 20
    return 0


def is_top50(user_id: int) -> bool:
    rank = get_user_rank(user_id)
    return rank is not None and rank <= RANK_GOLD_CUTOFF
