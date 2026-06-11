"""Adapter input: DB models -> canonical contracts. Fail-closed on corruption."""
import dataclasses
import pytest

from app.extensions import db as _db
from app.models import Tournament, TournamentParticipant, TournamentRound, TournamentMatch
from app.services.tournament_scoring.adapters import adapt_tournament_to_engine_input
from app.services.tournament_scoring.exceptions import InvalidTournamentScoringData


def _mk_tournament(scoring_mode='points', **kw):
    t = Tournament(name='T', format='americano', scoring_mode=scoring_mode,
                   num_courts=kw.pop('num_courts', 1),
                   court_bonus_round=kw.pop('court_bonus_round', 0),
                   win_points=kw.pop('win_points', 3),
                   draw_points=kw.pop('draw_points', 1),
                   sort_by_wins=kw.pop('sort_by_wins', False),
                   h2h_tiebreaker=kw.pop('h2h_tiebreaker', False))
    _db.session.add(t)
    _db.session.flush()
    return t


def _mk_participants(t, names, seeds=None):
    ps = []
    for i, n in enumerate(names):
        p = TournamentParticipant(tournament_id=t.id, name=n,
                                  seed=(seeds[i] if seeds else i + 1))
        _db.session.add(p)
        ps.append(p)
    _db.session.flush()
    return ps


def _mk_match(t, rnd, ps, sets_json, status='completed', court=1):
    m = TournamentMatch(tournament_id=t.id, round_id=rnd.id, court=court,
                        team1_p1_id=ps[0].id, team1_p2_id=ps[1].id,
                        team2_p1_id=ps[2].id, team2_p2_id=ps[3].id,
                        sets_json=sets_json, status=status)
    _db.session.add(m)
    _db.session.flush()
    return m


def _mk_round(t, number=1):
    r = TournamentRound(tournament_id=t.id, round_number=number)
    _db.session.add(r)
    _db.session.flush()
    return r


def test_participant_order_follows_seed(app, db):
    t = _mk_tournament()
    # insert out of order; seeds 3,1,2,4
    ps = _mk_participants(t, ['C', 'A', 'B', 'D'], seeds=[3, 1, 2, 4])
    inp = adapt_tournament_to_engine_input(t)
    ordered_ids = [p.id for p in inp.players]
    assert ordered_ids == [ps[1].id, ps[2].id, ps[0].id, ps[3].id]  # A,B,C,D
    assert [p.source_order for p in inp.players] == [0, 1, 2, 3]


def test_completed_included_pending_ignored(app, db):
    t = _mk_tournament()
    ps = _mk_participants(t, ['A', 'B', 'C', 'D'])
    r1 = _mk_round(t, 1)
    _mk_match(t, r1, ps, '[[21, 15]]', status='completed')
    _mk_match(t, r1, ps, '[[5, 5]]', status='pending')      # ignored
    _mk_match(t, r1, ps, '[]', status='pending')             # placeholder, ignored
    _mk_match(t, r1, ps, '[[9, 9]]', status='canceled')      # ignored
    inp = adapt_tournament_to_engine_input(t)
    assert len(inp.games) == 1
    assert inp.games[0].points_team_1 == 21 and inp.games[0].points_team_2 == 15


def test_completed_missing_player_rejected(app, db):
    t = _mk_tournament()
    ps = _mk_participants(t, ['A', 'B', 'C', 'D'])
    r1 = _mk_round(t, 1)
    m = _mk_match(t, r1, ps, '[[21, 15]]')
    m.team2_p2_id = None
    _db.session.flush()
    with pytest.raises(InvalidTournamentScoringData):
        adapt_tournament_to_engine_input(t)


@pytest.mark.parametrize('bad_json', [
    'not-json', '{"a":1}', '[[1]]', '[[1,2,3]]', '[["x","y"]]', '[[-1, 5]]', '[]',
])
def test_completed_malformed_sets_json_rejected(app, db, bad_json):
    t = _mk_tournament()
    ps = _mk_participants(t, ['A', 'B', 'C', 'D'])
    r1 = _mk_round(t, 1)
    _mk_match(t, r1, ps, bad_json, status='completed')
    with pytest.raises(InvalidTournamentScoringData):
        adapt_tournament_to_engine_input(t)


def test_points_mode_mapping(app, db):
    t = _mk_tournament(scoring_mode='points')
    ps = _mk_participants(t, ['A', 'B', 'C', 'D'])
    r1 = _mk_round(t, 1)
    _mk_match(t, r1, ps, '[[21, 15]]', court=2)
    inp = adapt_tournament_to_engine_input(t)
    g = inp.games[0]
    assert g.points_team_1 == 21 and g.points_team_2 == 15
    assert g.sets == ()
    assert g.court.number == 2
    assert g.round_number == 1
    assert g.team_1.player_ids == (ps[0].id, ps[1].id)
    assert g.team_2.player_ids == (ps[2].id, ps[3].id)


def test_sets_mode_mapping(app, db):
    t = _mk_tournament(scoring_mode='sets')
    ps = _mk_participants(t, ['A', 'B', 'C', 'D'])
    r1 = _mk_round(t, 1)
    _mk_match(t, r1, ps, '[[6, 4], [6, 3]]')
    inp = adapt_tournament_to_engine_input(t)
    g = inp.games[0]
    assert g.sets == ((6, 4), (6, 3))
    assert g.points_team_1 is None and g.points_team_2 is None
    assert inp.config.scoring_mode == 'sets'


def test_config_mapping(app, db):
    t = _mk_tournament(scoring_mode='points', num_courts=3, court_bonus_round=2,
                       win_points=5, draw_points=2, sort_by_wins=True,
                       h2h_tiebreaker=True)
    _mk_participants(t, ['A', 'B', 'C', 'D'])
    cfg = adapt_tournament_to_engine_input(t).config
    assert cfg.scoring_mode == 'points'
    assert cfg.court_count == 3
    assert cfg.extra_points_from_round == 2     # from court_bonus_round
    assert cfg.points_for_won_game == 5
    assert cfg.points_for_even_game == 2
    assert cfg.sort_by_wins is True and cfg.sort_head2head is True


def test_court_bonus_values_default_zero(app, db):
    """Schema gap: no per-court extra_points column exists yet, so courts map
    to extra_points=0 (mechanism wired, values empty). Documented in adapter."""
    t = _mk_tournament(court_bonus_round=1)
    ps = _mk_participants(t, ['A', 'B', 'C', 'D'])
    r1 = _mk_round(t, 1)
    _mk_match(t, r1, ps, '[[10, 8]]')
    inp = adapt_tournament_to_engine_input(t)
    assert inp.config.extra_points_from_round == 1
    assert inp.games[0].court.extra_points == 0


def test_canonical_input_is_immutable(app, db):
    t = _mk_tournament()
    ps = _mk_participants(t, ['A', 'B', 'C', 'D'])
    r1 = _mk_round(t, 1)
    _mk_match(t, r1, ps, '[[21, 15]]')
    inp = adapt_tournament_to_engine_input(t)
    with pytest.raises(dataclasses.FrozenInstanceError):
        inp.players = ()
    with pytest.raises(dataclasses.FrozenInstanceError):
        inp.games[0].points_team_1 = 99
