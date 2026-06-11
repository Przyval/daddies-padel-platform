"""Load golden scoring fixtures into the engine's neutral contracts and run them.

Reconstructs Player/Court/GameResult/EngineConfig from a golden case's `input`,
runs `calculate_standings`, and re-emits rows in the golden's field names so a
parity test is a plain dict-equality per rank.
"""
import json
import os

from app.services.tournament_scoring import (
    calculate_standings, Player, Team, Court, GameResult, EngineConfig,
)

GOLDEN_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'golden')


def load(file_name):
    return json.load(open(os.path.join(GOLDEN_DIR, file_name)))['cases']


def _parse_sets(s):
    s = (s or '').strip()
    if not s:
        return ()
    out = []
    for part in s.split(','):
        a, b = part.strip().split('-')
        out.append((int(a), int(b)))
    return tuple(out)


def build_inputs(case):
    inp = case['input']
    n = inp['players']
    players = [Player(id=i, source_order=i - 1) for i in range(1, n + 1)]
    courts = [Court(number=c['number'], extra_points=c['extra_points']) for c in inp['courts']]

    games = []
    for rnd in inp['rounds']:
        for idx, g in enumerate(rnd['games']):
            court = courts[idx] if idx < len(courts) else Court(number=idx + 1, extra_points=0)
            games.append(GameResult(
                round_number=rnd['round'],
                court=court,
                team_1=Team(tuple(g['team1'])),
                team_2=Team(tuple(g['team2'])),
                points_team_1=g.get('team1_result'),
                points_team_2=g.get('team2_result'),
                sets=_parse_sets(g.get('sets', '')),
            ))

    cfg = EngineConfig(
        scoring_mode=inp['mode'],
        court_count=len(courts),
        extra_points_from_round=inp['extra_points_from_round'],
        points_for_won_game=inp['points_for_won_game'],
        points_for_even_game=inp['points_for_even_game'],
        sort_by_wins=inp['sort_by_wins'],
        sort_head2head=inp['sort_head2head'],
    )
    return players, games, cfg


def run_case(case):
    """Return engine output as golden-shaped dict rows (in rank order)."""
    players, games, cfg = build_inputs(case)
    standings = calculate_standings(players=players, games=games, config=cfg)
    rows = []
    for s in standings:
        rows.append({
            'rank': s.rank,
            'player_id': s.player_id,
            'score': s.total_points,
            'raw_points': s.raw_points,
            'even_points': s.even_points,
            'court_bonus': s.bonus_points,
            'wins': s.wins,
            'losses': s.losses,
            'ties': s.draws,
            'games': s.games_played,
            'attended_games': s.attended_games,
            'diff_pts': s.diff_pts,
            'game_diff': s.game_diff,
            'set_diff': s.set_diff,
            'h2h_total': s.h2h_total,
            'h2h': {str(k): v for k, v in s.h2h.items()},
        })
    return rows


def assert_case_parity(case):
    """Compare engine rows to golden expected_standings — order + every field."""
    expected = case['expected_standings']
    actual = run_case(case)
    assert len(actual) == len(expected), f"{case['id']}: row count differs"
    fields = ['rank', 'player_id', 'score', 'raw_points', 'even_points',
              'court_bonus', 'wins', 'losses', 'ties', 'games', 'attended_games',
              'diff_pts', 'game_diff', 'set_diff', 'h2h_total', 'h2h']
    for i, (e, a) in enumerate(zip(expected, actual)):
        for f in fields:
            assert a[f] == e[f], (
                f"{case['id']} rank-pos {i+1} field '{f}': engine={a[f]} golden={e[f]}\n"
                f"  engine row: {a}\n  golden row: {e}"
            )
