"""Sit-out compensation — port of ScoringEngine._applyEvenPoints (Dart).

Awards players who played fewer games:
    even = (maxGames - gamesPlayed) * (avgScore // 2)
where avgScore = floor(sum(team1+team2 points over completed games) / gameCount).
All integer semantics (no float rounding). Points mode only in practice (sets
mode leaves points_team_* at 0 → avgScore 0 → no even points).
"""
from __future__ import annotations


def _can_show_even(court_count: int, player_count: int) -> bool:
    """Dart _canShowEven: False when every player plays every round."""
    ppc = player_count / 4.0
    if ppc == float(int(ppc)) and court_count == int(ppc):
        return False
    return True


def apply_even_points(standings, court_count, counted_games) -> None:
    """Mutates each working standing's `.even_points`."""
    if not standings or not counted_games:
        return
    if not _can_show_even(court_count, len(standings)):
        return

    max_games = max((s.games for s in standings), default=0)
    if max_games == 0:
        return

    total = 0
    count = 0
    for g in counted_games:
        total += (g.points_team_1 or 0) + (g.points_team_2 or 0)
        count += 1
    if count == 0:
        return

    avg_score = total // count          # floor(total / count)
    half = avg_score // 2               # Dart avgScore ~/ 2
    for s in standings:
        if s.games < max_games:
            s.even_points = (max_games - s.games) * half
