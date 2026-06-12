"""Dispatcher: explicit per-version dispatch, fail-closed on unknown."""
import pytest

from app.services.tournament_scoring import dispatcher as disp
from app.services.tournament_scoring.exceptions import UnsupportedScoringEngineVersion


class _Stub:
    def __init__(self, version):
        self.scoring_engine_version = version


def test_legacy_version_calls_only_legacy_callable(monkeypatch):
    calls = {'legacy': 0, 'canonical': 0}
    monkeypatch.setattr(disp, 'calculate_standings',
                        lambda **k: calls.__setitem__('canonical', calls['canonical'] + 1))

    def legacy(t):
        calls['legacy'] += 1
        return ['legacy-rows']

    out = disp.calculate_tournament_standings(_Stub('legacy_flask_v1'),
                                              legacy_calculator=legacy)
    assert out == ['legacy-rows']
    assert calls == {'legacy': 1, 'canonical': 0}


def test_reference_version_calls_only_canonical(app, db, monkeypatch):
    from app.models import Tournament, TournamentParticipant
    from app.extensions import db as _db

    t = Tournament(name='Ref', format='americano', scoring_mode='points',
                   sort_by_wins=False)
    _db.session.add(t)
    _db.session.flush()
    for i, n in enumerate(['A', 'B', 'C', 'D']):
        _db.session.add(TournamentParticipant(tournament_id=t.id, name=n, seed=i + 1))
    _db.session.commit()
    assert t.scoring_engine_version == 'americano_reference_v1'

    legacy_calls = {'n': 0}

    def legacy(_):
        legacy_calls['n'] += 1
        return []

    rows = disp.calculate_tournament_standings(t, legacy_calculator=legacy)
    assert legacy_calls['n'] == 0
    assert len(rows) == 4                      # canonical produced rows
    assert {r['rank'] for r in rows} == {1, 2, 3, 4}
    # legacy-shaped keys for template/serializer compat + canonical extras
    for r in rows:
        for key in ('participant', 'points', 'wins', 'losses', 'ties',
                    'matches_played', 'games_won', 'games_lost', 'diff_pts',
                    'even_pts', 'teammates', 'h2h',
                    'raw_score', 'bonus_points'):
            assert key in r, key


@pytest.mark.parametrize('bad', ['engine_v2_test', '', None, 'LEGACY_FLASK_V1'])
def test_unknown_version_fails_closed(bad):
    with pytest.raises(UnsupportedScoringEngineVersion):
        disp.calculate_tournament_standings(_Stub(bad), legacy_calculator=lambda t: [])


def test_rotation_dispatch_legacy_returns_none():
    """Legacy tournaments own their rotation via the in-route generators."""
    assert disp.generate_tournament_rotation(_Stub('legacy_flask_v1'), []) is None


def test_rotation_dispatch_unknown_fails_closed():
    with pytest.raises(UnsupportedScoringEngineVersion):
        disp.generate_tournament_rotation(_Stub('engine_v2_test'), [])


def test_routes_use_dispatcher_and_legacy_algorithm_extracted():
    """Step 4b cutover: every standings read goes through the dispatcher, and
    the legacy algorithm body no longer lives inside route modules (it was
    moved mechanically to tournament_legacy_scoring)."""
    import inspect
    import app.api.tournaments as api_t
    import app.routes.tournament as web_t
    import app.services.tournament_legacy_scoring as legacy_mod

    for mod in (api_t, web_t):
        src = inspect.getsource(mod)
        assert 'calculate_tournament_standings' in src, mod.__name__
        assert 'def calculate_leaderboard' not in src, mod.__name__

    # the extracted legacy function still exists, importable from both places
    from app.routes.tournament import calculate_leaderboard as reexported
    assert reexported is legacy_mod.calculate_leaderboard
