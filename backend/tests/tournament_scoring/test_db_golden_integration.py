"""DB models -> adapter -> canonical engine must reproduce the Dart golden.

Pure-engine parity alone doesn't prove the DATABASE mapping is right; this
builds equivalent DB fixtures for one points case (p_normal) and one sets case
(s_2_0) and checks every intermediate field against the golden rows.
"""
import json

from app.extensions import db as _db
from app.models import Tournament, TournamentParticipant, TournamentRound, TournamentMatch
from app.services.tournament_scoring import calculate_standings
from app.services.tournament_scoring.adapters import adapt_tournament_to_engine_input
from golden_loader import load

CHECK_FIELDS = ['score', 'raw_points', 'even_points', 'court_bonus', 'wins',
                'losses', 'ties', 'games', 'attended_games', 'diff_pts',
                'game_diff', 'set_diff', 'h2h_total']


def _build_db_from_case(case):
    """Create a Tournament in the DB equivalent to a golden case input.
    Returns (tournament, golden_id -> participant_id mapping)."""
    inp = case['input']
    t = Tournament(
        name=case['id'], format='americano',
        scoring_mode=inp['mode'],
        num_courts=len(inp['courts']),
        court_bonus_round=inp['extra_points_from_round'],
        win_points=inp['points_for_won_game'],
        draw_points=inp['points_for_even_game'],
        sort_by_wins=inp['sort_by_wins'],
        h2h_tiebreaker=inp['sort_head2head'],
    )
    _db.session.add(t)
    _db.session.flush()

    id_map = {}
    for i in range(1, inp['players'] + 1):
        p = TournamentParticipant(tournament_id=t.id, name=f'P{i}', seed=i)
        _db.session.add(p)
        _db.session.flush()
        id_map[i] = p.id

    for rnd in inp['rounds']:
        r = TournamentRound(tournament_id=t.id, round_number=rnd['round'])
        _db.session.add(r)
        _db.session.flush()
        for gi, g in enumerate(rnd['games']):
            if inp['mode'] == 'points':
                sets_json = json.dumps([[g['team1_result'], g['team2_result']]])
            else:
                pairs = [[int(x) for x in part.strip().split('-')]
                         for part in g['sets'].split(',')]
                sets_json = json.dumps(pairs)
            _db.session.add(TournamentMatch(
                tournament_id=t.id, round_id=r.id, court=gi + 1,
                team1_p1_id=id_map[g['team1'][0]], team1_p2_id=id_map[g['team1'][1]],
                team2_p1_id=id_map[g['team2'][0]], team2_p2_id=id_map[g['team2'][1]],
                sets_json=sets_json, status='completed',
            ))
    _db.session.commit()
    return t, id_map


def _assert_db_matches_golden(case):
    t, id_map = _build_db_from_case(case)
    inp = adapt_tournament_to_engine_input(t)
    standings = calculate_standings(players=inp.players, games=inp.games,
                                    config=inp.config)
    expected = case['expected_standings']
    assert len(standings) == len(expected)
    for s, e in zip(standings, expected):
        assert s.player_id == id_map[e['player_id']], case['id']
        actual = {
            'score': s.total_points, 'raw_points': s.raw_points,
            'even_points': s.even_points, 'court_bonus': s.bonus_points,
            'wins': s.wins, 'losses': s.losses, 'ties': s.draws,
            'games': s.games_played, 'attended_games': s.attended_games,
            'diff_pts': s.diff_pts, 'game_diff': s.game_diff,
            'set_diff': s.set_diff, 'h2h_total': s.h2h_total,
        }
        for f in CHECK_FIELDS:
            assert actual[f] == e[f], f"{case['id']} {e['player_id']} {f}: {actual[f]} != {e[f]}"


def test_db_to_golden_points_case(app, db):
    case = next(c for c in load('scoring_points.json') if c['id'] == 'p_normal')
    _assert_db_matches_golden(case)


def test_db_to_golden_sets_case(app, db):
    case = next(c for c in load('scoring_sets.json') if c['id'] == 's_2_0')
    _assert_db_matches_golden(case)


def test_db_to_golden_even_points_case(app, db):
    """Sit-out compensation via real DB rows (5 players, P5 never plays)."""
    case = next(c for c in load('scoring_even_points.json') if c['id'] == 'even_sit_twice')
    _assert_db_matches_golden(case)
