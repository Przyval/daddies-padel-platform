"""Canonical standings -> route-compatible rows.

Builds the participant map ONCE (no per-row queries / N+1). Keeps the
raw/even/bonus breakdown visible instead of collapsing into a single score.
"""
from __future__ import annotations


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
