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
    assert all('raw_score' in r and 'even_points' in r and 'bonus_points' in r
               for r in rows)


@pytest.mark.parametrize('bad', ['engine_v2_test', '', None, 'LEGACY_FLASK_V1'])
def test_unknown_version_fails_closed(bad):
    with pytest.raises(UnsupportedScoringEngineVersion):
        disp.calculate_tournament_standings(_Stub(bad), legacy_calculator=lambda t: [])


def test_rotation_dispatch_not_wired_yet():
    with pytest.raises(NotImplementedError):
        disp.generate_tournament_rotation(_Stub('americano_reference_v1'), [])


def test_routes_do_not_import_dispatcher():
    """Step 4a guarantee: no route module references the dispatcher yet."""
    import inspect
    import app.api.tournaments as api_t
    import app.routes.tournament as web_t
    for mod in (api_t, web_t):
        assert 'dispatcher' not in inspect.getsource(mod), mod.__name__
