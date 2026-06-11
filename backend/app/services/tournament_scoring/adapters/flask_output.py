"""Canonical standings -> route-compatible rows.

Builds the participant map ONCE (no per-row queries / N+1). Keeps the
raw/even/bonus breakdown visible instead of collapsing into a single score.
"""
from __future__ import annotations


def adapt_canonical_standings_to_legacy_rows(standings, participants):
    """Canonical standings -> rows in the LEGACY calculate_leaderboard shape,
    so existing templates/serializers (s['points'], s['wins'], s['teammates'],
    ...) work unchanged regardless of which engine produced the rows.
    Participant map built once — no N+1."""
    by_id = {p.id: p for p in participants}

    def first_name(pid):
        p = by_id.get(pid)
        return p.first_name if p is not None else f'#{pid}'

    rows = []
    for s in standings:
        rows.append({
            'participant': by_id.get(s.player_id),
            'wins': s.wins,
            'losses': s.losses,
            'ties': s.draws,
            'matches_played': s.games_played,
            'sets_won': s.sets_for,
            'sets_lost': s.sets_against,
            'games_won': s.games_for,
            'games_lost': s.games_against,
            'points': s.total_points,
            'diff_pts': s.diff_pts,
            'even_pts': s.even_points,
            'h2h_total': s.h2h_total,
            'teammates': sorted(
                [(first_name(tid), cnt) for tid, cnt in s.teammates.items()],
                key=lambda x: -x[1]),
            'h2h': sorted(
                [(first_name(oid), delta) for oid, delta in s.h2h.items()],
                key=lambda x: -x[1]),
            # canonical extras (additive — legacy rows simply lack these)
            'rank': s.rank,
            'raw_score': s.raw_points,
            'bonus_points': s.bonus_points,
        })
    return rows


def adapt_canonical_standings_to_rows(standings, participants):
    """standings: list[PlayerStanding] (canonical). participants: iterable of
    TournamentParticipant models. Returns list[dict] in rank order."""
    by_id = {p.id: p for p in participants}
    rows = []
    for s in standings:
        p = by_id.get(s.player_id)
        rows.append({
            'participant': p,
            'participant_id': s.player_id,
            'user_id': p.user_id if p is not None else None,
            'rank': s.rank,
            'score': s.total_points,
            'raw_score': s.raw_points,
            'even_points': s.even_points,
            'bonus_points': s.bonus_points,
            'wins': s.wins,
            'draws': s.draws,
            'losses': s.losses,
            'games_played': s.games_played,
            'diff_pts': s.diff_pts,
            'game_diff': s.game_diff,
            'set_diff': s.set_diff,
            'h2h_total': s.h2h_total,
        })
    return rows
