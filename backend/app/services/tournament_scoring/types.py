"""Neutral data contracts for the canonical Americano scoring engine.

Pure data — NO Flask, NO SQLAlchemy, NO database. Mirrors the reference engine
(americano_padel/ Dart) field-for-field so behaviour can be ported with parity.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal, Optional

ScoringMode = Literal["points", "sets"]


@dataclass(frozen=True)
class Player:
    id: int
    source_order: int  # original input order — decides ties under non-transitive h2h


@dataclass(frozen=True)
class Team:
    player_ids: tuple[int, ...]  # 2 ids (or 1 for odd edge cases)


@dataclass(frozen=True)
class Court:
    number: int
    extra_points: int = 0


@dataclass(frozen=True)
class GameResult:
    round_number: int
    court: Court
    team_1: Team
    team_2: Team
    points_team_1: Optional[int] = None
    points_team_2: Optional[int] = None
    sets: tuple[tuple[int, int], ...] = ()

    # ── reference Game helpers (Dart Game.*) ────────────────────────────────
    @property
    def has_results(self) -> bool:
        p = (self.points_team_1 or 0) + (self.points_team_2 or 0)
        return p > 0 or len(self.sets) > 0

    @property
    def set_winner(self) -> int:
        """1=team1, 2=team2, 0=tie/unplayed."""
        if not self.sets:
            return 0
        t1 = sum(1 for a, b in self.sets if a > b)
        t2 = sum(1 for a, b in self.sets if b > a)
        if t1 > t2:
            return 1
        if t2 > t1:
            return 2
        return 0

    def games_for(self, team: int) -> int:
        return sum((a if team == 1 else b) for a, b in self.sets)

    def games_diff(self, team: int) -> int:
        return sum(((a - b) if team == 1 else (b - a)) for a, b in self.sets)

    def set_diff(self, team: int) -> int:
        t1 = sum(1 for a, b in self.sets if a > b)
        t2 = sum(1 for a, b in self.sets if b > a)
        return (t1 - t2) if team == 1 else (t2 - t1)


@dataclass(frozen=True)
class RotationMatch:
    court: int
    team1: tuple[int, int]  # player ids
    team2: tuple[int, int]


@dataclass(frozen=True)
class RotationRound:
    number: int
    matches: tuple[RotationMatch, ...]


@dataclass(frozen=True)
class EngineConfig:
    scoring_mode: ScoringMode
    court_count: int
    extra_points_from_round: int = 0
    points_for_won_game: int = 3   # sets mode; -3 = games-as-points
    points_for_even_game: int = 1  # sets mode draw
    sort_by_wins: bool = False
    sort_head2head: bool = False


@dataclass(frozen=True)
class PlayerStanding:
    """Output row — carries every intermediate (raw/even/bonus kept separate)."""
    rank: int
    player_id: int
    source_order: int
    # score breakdown
    raw_points: int
    even_points: int
    bonus_points: int   # court bonus (extraPoints)
    total_points: int   # raw + even + bonus  (Dart PlayerStanding.score)
    # record
    wins: int
    draws: int          # Dart "ties"
    losses: int
    games_played: int   # Dart "games"
    attended_games: int
    # diffs (tracked; NOTE game_diff/set_diff are NOT used in tie-break)
    diff_pts: int
    game_diff: int
    set_diff: int
    # head-to-head
    h2h_total: int
    h2h: dict[int, int] = field(default_factory=dict)
