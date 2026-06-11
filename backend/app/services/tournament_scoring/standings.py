"""Accumulation core — port of ScoringEngine.calculateStandings (Dart), minus
the final sort (done in engine.py). Reproduces reference behaviour exactly,
including quirks (game_diff/set_diff tracked but unused in tie-break; court
bonus points-mode only; bonus to all four players in a court's game).
"""
from __future__ import annotations

from .types import EngineConfig, GameResult, Player


class _W:
    """Mutable working standing (Dart PlayerStanding before sort)."""
    __slots__ = (
        'player_id', 'source_order', 'raw_points', 'wins', 'losses', 'ties',
        'diff_pts', 'game_diff', 'set_diff', 'games', 'attended_games',
        'even_points', 'bonus_points', 'h2h',
        # additive output-compat fields — NOT part of reference scoring or any
        # tie-break; tracked only so adapters can emit legacy-shaped rows.
        'games_for', 'games_against', 'sets_for', 'sets_against', 'teammates',
    )

    def __init__(self, player_id: int, source_order: int):
        self.player_id = player_id
        self.source_order = source_order
        self.raw_points = 0
        self.wins = 0
        self.losses = 0
        self.ties = 0
        self.diff_pts = 0
        self.game_diff = 0
        self.set_diff = 0
        self.games = 0
        self.attended_games = 0
        self.even_points = 0
        self.bonus_points = 0
        self.h2h: dict[int, int] = {}
        self.games_for = 0
        self.games_against = 0
        self.sets_for = 0
        self.sets_against = 0
        self.teammates: dict[int, int] = {}

    @property
    def score(self) -> int:
        return self.raw_points + self.even_points + self.bonus_points


def _bonus_for(game: GameResult, cfg: EngineConfig) -> int:
    epfr = cfg.extra_points_from_round
    if epfr <= 0 or game.round_number < epfr:
        return 0
    return game.court.extra_points


def _apply_points(w: _W, game: GameResult, team: int, extra: int) -> None:
    my = (game.points_team_1 if team == 1 else game.points_team_2) or 0
    opp = (game.points_team_2 if team == 1 else game.points_team_1) or 0
    w.raw_points += my
    w.diff_pts += my - opp
    w.games_for += my          # output-compat (legacy games_won/games_lost)
    w.games_against += opp
    if my > opp:
        w.wins += 1
    elif my < opp:
        w.losses += 1
    if my + opp > 0:
        if my == opp:
            w.ties += 1
        w.games += 1
        w.bonus_points += extra


def _apply_sets(w: _W, game: GameResult, team: int, pfw: int, pfe: int) -> None:
    winner = game.set_winner
    is_winner = winner == team
    is_loser = winner != 0 and winner != team
    is_tie = winner == 0 and bool(game.sets)

    if pfw == -3:                       # games-as-points mode
        points = game.games_for(team)
    else:
        points = pfw if is_winner else (pfe if is_tie else 0)

    w.raw_points += points
    w.game_diff += game.games_diff(team)
    w.set_diff += game.set_diff(team)
    # output-compat tallies (legacy sets_won/sets_lost, games_won/games_lost)
    my_games = game.games_for(team)
    opp_games = game.games_for(2 if team == 1 else 1)
    w.games_for += my_games
    w.games_against += opp_games
    my_sets = sum(1 for a, b in game.sets if (a > b if team == 1 else b > a))
    opp_sets = sum(1 for a, b in game.sets if (b > a if team == 1 else a > b))
    w.sets_for += my_sets
    w.sets_against += opp_sets
    if is_winner:
        w.wins += 1
    elif is_loser:
        w.losses += 1
    if game.sets:
        w.games += 1
        if is_tie:
            w.ties += 1


def _record_h2h(game: GameResult, table: dict[int, _W], sets_mode: bool) -> None:
    if sets_mode:
        winner = game.set_winner
    else:
        p1 = game.points_team_1 or 0
        p2 = game.points_team_2 or 0
        winner = 1 if p1 > p2 else (2 if p2 > p1 else 0)
    if winner == 0:
        return
    for t1 in game.team_1.player_ids:
        for t2 in game.team_2.player_ids:
            w1, w2 = table.get(t1), table.get(t2)
            if w1 is None or w2 is None:
                continue
            d = 1 if winner == 1 else -1
            w1.h2h[t2] = w1.h2h.get(t2, 0) + d
            w2.h2h[t1] = w2.h2h.get(t1, 0) - d


def accumulate(players, games, cfg: EngineConfig):
    """Return (list[_W] in input/source order, counted_games)."""
    sets_mode = cfg.scoring_mode == "sets"
    table: dict[int, _W] = {}
    ordered: list[_W] = []
    for p in players:
        w = _W(p.id, p.source_order)
        table[p.id] = w
        ordered.append(w)

    counted = []
    for game in games:
        if not game.has_results:
            continue
        counted.append(game)
        extra = _bonus_for(game, cfg)
        for team, ids in ((1, game.team_1.player_ids), (2, game.team_2.player_ids)):
            for pid in ids:
                w = table.get(pid)
                if w is None:
                    continue
                w.attended_games += 1
                if sets_mode:
                    _apply_sets(w, game, team, cfg.points_for_won_game, cfg.points_for_even_game)
                else:
                    _apply_points(w, game, team, extra)
        _record_h2h(game, table, sets_mode)

        # output-compat: teammate counts (Dart playedWith, keyed by id here)
        for ids in (game.team_1.player_ids, game.team_2.player_ids):
            ids = list(ids)
            for i in range(len(ids)):
                for j in range(i + 1, len(ids)):
                    a, b = table.get(ids[i]), table.get(ids[j])
                    if a is not None and b is not None:
                        a.teammates[b.player_id] = a.teammates.get(b.player_id, 0) + 1
                        b.teammates[a.player_id] = b.teammates.get(a.player_id, 0) + 1

    return ordered, counted
