"""Engine purity invariants: no mutation, deterministic, incomplete games ignored."""
import copy

from app.services.tournament_scoring import (
    calculate_standings, Player, Team, Court, GameResult, EngineConfig,
)
from golden_loader import load, build_inputs, run_case


def _points_cfg(courts=1):
    return EngineConfig(scoring_mode='points', court_count=courts)


def test_input_not_mutated():
    case = load('scoring_points.json')[0]
    players, games, cfg = build_inputs(case)
    players_snap = copy.deepcopy(players)
    games_snap = copy.deepcopy(games)
    calculate_standings(players=players, games=games, config=cfg)
    assert players == players_snap
    assert games == games_snap


def test_repeated_calculation_identical():
    for case in load('scoring_tiebreak.json'):  # includes the h2h cycle
        a = run_case(case)
        b = run_case(case)
        assert a == b


def test_incomplete_games_ignored():
    players = [Player(id=i, source_order=i - 1) for i in range(1, 5)]
    court = Court(number=1)
    played = GameResult(1, court, Team((1, 2)), Team((3, 4)), points_team_1=21, points_team_2=15)
    # unplayed: 0-0 and no sets → has_results False → must not affect anything
    unplayed = GameResult(2, court, Team((1, 3)), Team((2, 4)), points_team_1=0, points_team_2=0)

    base = calculate_standings(players=players, games=[played], config=_points_cfg())
    withghost = calculate_standings(players=players, games=[played, unplayed], config=_points_cfg())
    assert base == withghost


def test_partial_placeholder_does_not_count():
    players = [Player(id=i, source_order=i - 1) for i in range(1, 5)]
    court = Court(number=1)
    ghost = GameResult(1, court, Team((1, 2)), Team((3, 4)))  # all None/empty
    res = calculate_standings(players=players, games=[ghost], config=_points_cfg())
    assert all(s.total_points == 0 and s.games_played == 0 and s.attended_games == 0 for s in res)
