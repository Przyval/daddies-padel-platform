"""Step 4c — rotation cutover: reference americano tournaments use the
pre-computed reference tables; everything else falls back to legacy generators.
"""
import pytest

from app.extensions import db as _db
from app.models import (
    Tournament, TournamentParticipant, User,
    SCORING_ENGINE_LEGACY,
)
from app.services.tournament_scoring import dispatcher as disp
from app.services.tournament_scoring.exceptions import UnsupportedScoringEngineVersion


def _token(client):
    u = User(username='Owner', email='o@t.com', phone='081x', role='member',
             membership='member', membership_paid=True)
    u.set_password('rahasia123')
    _db.session.add(u)
    _db.session.commit()
    return client.post('/api/v1/auth/login',
                       json={'email': 'o@t.com', 'password': 'rahasia123'}
                       ).get_json()['data']['access_token']


def _create(client, token, n_players, num_courts, fmt='americano'):
    r = client.post('/api/v1/tournaments',
                    headers={'Authorization': f'Bearer {token}'},
                    json={'name': 'T', 'format': fmt, 'num_courts': num_courts,
                          'participants': [{'name': f'P{i}'} for i in range(1, n_players + 1)]})
    assert r.status_code == 201, r.get_json()
    return r.get_json()['data']


def test_reference_americano_8p_uses_table(app, db, client):
    """8 players / 2 courts (natural) -> the reference table: 7 rounds, every
    pair partners EXACTLY once — the optimality property circle-method lacks."""
    d = _create(client, _token(client), 8, 2)
    rounds = d['rounds']
    assert len(rounds) == 7
    partner_pairs = set()
    for rnd in rounds:
        assert len(rnd['matches']) == 2
        seen = []
        for m in rnd['matches']:
            t1 = [p['id'] for p in m['team1']]
            t2 = [p['id'] for p in m['team2']]
            seen += t1 + t2
            for pair in (tuple(sorted(t1)), tuple(sorted(t2))):
                assert pair not in partner_pairs, f'pair {pair} partnered twice'
                partner_pairs.add(pair)
        assert len(seen) == len(set(seen)) == 8  # all 8 play once per round
    assert len(partner_pairs) == 28              # C(8,2): everyone with everyone


def test_legacy_pinned_tournament_never_touches_table(app, db, monkeypatch):
    import app.services.tournament_scoring.rotations as rot
    calls = {'n': 0}
    real = rot.apply_table

    def spy(players):
        calls['n'] += 1
        return real(players)

    monkeypatch.setattr(rot, 'apply_table', spy)

    t = Tournament(name='L', format='americano', num_courts=2,
                   scoring_engine_version=SCORING_ENGINE_LEGACY)
    _db.session.add(t)
    _db.session.flush()
    for i in range(8):
        _db.session.add(TournamentParticipant(tournament_id=t.id, name=f'P{i}', seed=i + 1))
    _db.session.flush()

    from app.routes.tournament import _generate_all_rounds
    _generate_all_rounds(t)
    _db.session.commit()
    assert calls['n'] == 0                 # legacy generator owned rotation
    assert t.rounds.count() >= 1


def test_reference_non_table_count_falls_back(app, db, client):
    """5 players: no reference table -> legacy generator, creation still works."""
    d = _create(client, _token(client), 5, 1)
    assert len(d['rounds']) >= 1


def test_reference_non_natural_courts_falls_back(app, db, client):
    """8 players on 1 court (!= natural 2): reference randomizes that
    redistribution, so we use the legacy generator. Max 1 match per round."""
    d = _create(client, _token(client), 8, 1)
    assert all(len(r['matches']) <= 1 for r in d['rounds'])


def test_rotation_unknown_version_fails_closed(app, db):
    class _Stub:
        scoring_engine_version = 'engine_v2_test'
        format = 'americano'
        num_courts = 2

    with pytest.raises(UnsupportedScoringEngineVersion):
        disp.generate_tournament_rotation(_Stub(), [])
