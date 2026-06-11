"""Canonical Americano scoring facade.

Pure + deterministic + non-mutating. Same input → same output, repeatedly.
No Flask, no DB. A Flask adapter is built separately, only after parity is green.
"""
from __future__ import annotations

from typing import Sequence

from .types import EngineConfig, GameResult, Player, PlayerStanding
from .standings import accumulate
from .even_points import apply_even_points
from .tie_break import compare_by_score, make_compare_by_wins, dart_sort


def calculate_standings(
    *,
    players: Sequence[Player],
    games: Sequence[GameResult],
    config: EngineConfig,
) -> list[PlayerStanding]:
    working, counted = accumulate(players, games, config)

    apply_even_points(working, config.court_count, counted)

    if config.sort_by_wins:
        ordered = dart_sort(working, make_compare_by_wins(config.sort_head2head))
    else:
        ordered = dart_sort(working, compare_by_score)

    out: list[PlayerStanding] = []
    for i, w in enumerate(ordered):
        out.append(PlayerStanding(
            rank=i + 1,
            player_id=w.player_id,
            source_order=w.source_order,
            raw_points=w.raw_points,
            even_points=w.even_points,
            bonus_points=w.bonus_points,
            total_points=w.score,
            wins=w.wins,
            draws=w.ties,
            losses=w.losses,
            games_played=w.games,
            attended_games=w.attended_games,
            diff_pts=w.diff_pts,
            game_diff=w.game_diff,
            set_diff=w.set_diff,
            h2h_total=sum(w.h2h.values()),
            h2h=dict(w.h2h),
        ))
    return out
