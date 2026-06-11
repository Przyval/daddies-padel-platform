"""Americano rotation — deterministic pre-computed table core.

Port of AmericanoRotation._fromTable (Dart). Given players in a FIXED order,
applies the optimal table for that count and returns rounds at the natural
court count (N/4). This is the deterministic core that must match the golden
byte-for-byte.

Out of scope here (the reference randomizes them — validate by invariant, not
golden equality):
  - player shuffle before applying the table (an input permutation; the caller
    decides ordering — pass players in the order you want)
  - CourtDistributor redistribution when requested courts != N/4
  - the general constraint-satisfaction fallback for non-table player counts
"""
from __future__ import annotations

from typing import Sequence

from .types import Player, RotationMatch, RotationRound
from .rotations_tables import TABLES, courts_for_player_count


def has_table(player_count: int) -> bool:
    return player_count in TABLES


def apply_table(players: Sequence[Player]) -> tuple[RotationRound, ...] | None:
    """Apply the pre-computed table to `players` in their given order.

    Returns None if no table exists for this count (caller falls back). Pure:
    does not mutate or shuffle — ordering is the caller's responsibility.
    """
    n = len(players)
    table = TABLES.get(n)
    if table is None:
        return None
    courts_per = courts_for_player_count(n)
    ids = [p.id for p in players]

    rounds: list[RotationRound] = []
    for r, indices in enumerate(table):
        matches: list[RotationMatch] = []
        for c in range(courts_per):
            base = c * 4
            matches.append(RotationMatch(
                court=c + 1,
                team1=(ids[indices[base] - 1], ids[indices[base + 1] - 1]),
                team2=(ids[indices[base + 2] - 1], ids[indices[base + 3] - 1]),
            ))
        rounds.append(RotationRound(number=r + 1, matches=tuple(matches)))
    return tuple(rounds)
