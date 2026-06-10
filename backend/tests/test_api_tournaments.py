"""Tests for the /api/v1/tournaments endpoints."""
import pytest
from app.extensions import db as _db
from app.models import User


def _mk_user(email, role='member', paid=True):
    u = User(username=email.split('@')[0], email=email, phone='08' + email[:6],
             role=role, membership='member', membership_paid=paid)
    u.set_password('rahasia123')
    _db.session.add(u)
    _db.session.commit()
    return u


def _token(client, email):
    return client.post('/api/v1/auth/login',
                       json={'email': email, 'password': 'rahasia123'}
                       ).get_json()['data']['access_token']


def _auth(token):
    return {'Authorization': f'Bearer {token}'}


@pytest.fixture
def owner(app, db):
    return _mk_user('owner@test.com')


@pytest.fixture
def other(app, db):
    return _mk_user('other@test.com')


def _create_t(client, token, fmt='americano'):
    return client.post('/api/v1/tournaments', headers=_auth(token), json={
        'name': 'Turnamen Test', 'format': fmt, 'num_courts': 1,
        'scoring_mode': 'points', 'points_per_game': 21,
        'participants': [{'name': n} for n in ['Adi', 'Budi', 'Citra', 'Dani']],
    })


def test_create_requires_4_players(client, owner):
    t = _token(client, 'owner@test.com')
    r = client.post('/api/v1/tournaments', headers=_auth(t),
                    json={'name': 'X', 'participants': [{'name': 'A'}]})
    assert r.status_code == 422


def test_create_generates_rounds(client, owner):
    t = _token(client, 'owner@test.com')
    r = _create_t(client, t)
    assert r.status_code == 201
    d = r.get_json()['data']
    assert d['status'] == 'playing'
    assert len(d['participants']) == 4
    assert len(d['rounds']) == 3            # 4-player round robin
    assert d['rounds'][0]['matches'][0]['status'] == 'pending'
    assert 'standings' in d


def test_list_tournaments(client, owner):
    t = _token(client, 'owner@test.com')
    _create_t(client, t)
    r = client.get('/api/v1/tournaments', headers=_auth(t))
    assert r.status_code == 200
    assert len(r.get_json()['data']) == 1


def test_score_match_updates_standings(client, owner):
    t = _token(client, 'owner@test.com')
    tid = _create_t(client, t).get_json()['data']['id']
    detail = client.get(f'/api/v1/tournaments/{tid}', headers=_auth(t)).get_json()['data']
    m = detail['rounds'][0]['matches'][0]

    r = client.post(f'/api/v1/tournaments/{tid}/score/{m["id"]}', headers=_auth(t),
                    json={'points_t1': 14, 'points_t2': 10})
    assert r.status_code == 200
    scored = r.get_json()['data']
    assert scored['status'] == 'completed'
    assert scored['score_team1'] == 14 and scored['score_team2'] == 10

    standings = client.get(f'/api/v1/tournaments/{tid}/standings',
                           headers=_auth(t)).get_json()['data']
    top = standings[0]
    assert top['rank'] == 1
    assert top['points'] == 14


def test_score_points_clamped_to_max(client, owner):
    t = _token(client, 'owner@test.com')
    tid = _create_t(client, t).get_json()['data']['id']
    m = client.get(f'/api/v1/tournaments/{tid}',
                   headers=_auth(t)).get_json()['data']['rounds'][0]['matches'][0]
    r = client.post(f'/api/v1/tournaments/{tid}/score/{m["id"]}', headers=_auth(t),
                    json={'points_t1': 999, 'points_t2': 0})
    assert r.get_json()['data']['score_team1'] == 21   # clamped to points_per_game


def test_score_cross_tournament_blocked(client, owner):
    t = _token(client, 'owner@test.com')
    tid1 = _create_t(client, t).get_json()['data']['id']
    tid2 = _create_t(client, t).get_json()['data']['id']
    m = client.get(f'/api/v1/tournaments/{tid2}',
                   headers=_auth(t)).get_json()['data']['rounds'][0]['matches'][0]
    # score tid2's match via tid1 → 403 (IDOR guard)
    r = client.post(f'/api/v1/tournaments/{tid1}/score/{m["id"]}', headers=_auth(t),
                    json={'points_t1': 5, 'points_t2': 5})
    assert r.status_code == 403


def test_next_round_blocked_until_complete(client, owner):
    t = _token(client, 'owner@test.com')
    tid = _create_t(client, t).get_json()['data']['id']
    # americano: rounds pre-generated; advancing pointer is allowed only when
    # current round done. Round 1 has a pending match → blocked.
    r = client.post(f'/api/v1/tournaments/{tid}/next_round', headers=_auth(t))
    assert r.status_code == 409


def test_next_round_advances_after_complete(client, owner):
    t = _token(client, 'owner@test.com')
    tid = _create_t(client, t).get_json()['data']['id']
    detail = client.get(f'/api/v1/tournaments/{tid}', headers=_auth(t)).get_json()['data']
    for m in detail['rounds'][0]['matches']:
        client.post(f'/api/v1/tournaments/{tid}/score/{m["id"]}', headers=_auth(t),
                    json={'points_t1': 11, 'points_t2': 9})
    r = client.post(f'/api/v1/tournaments/{tid}/next_round', headers=_auth(t))
    assert r.status_code == 200
    assert r.get_json()['data']['current_round'] == 2


def test_delete_requires_owner(client, owner, other):
    to = _token(client, 'owner@test.com')
    tid = _create_t(client, to).get_json()['data']['id']
    # other member cannot delete
    tx = _token(client, 'other@test.com')
    assert client.delete(f'/api/v1/tournaments/{tid}', headers=_auth(tx)).status_code == 403
    # owner can
    assert client.delete(f'/api/v1/tournaments/{tid}', headers=_auth(to)).status_code == 200


def test_settings_update(client, owner):
    t = _token(client, 'owner@test.com')
    tid = _create_t(client, t).get_json()['data']['id']
    r = client.patch(f'/api/v1/tournaments/{tid}/settings', headers=_auth(t),
                     json={'sort_by_wins': False, 'win_points': 5})
    assert r.status_code == 200
    s = r.get_json()['data']
    assert s['sort_by_wins'] is False and s['win_points'] == 5


def test_complete_runs_cascade(client, owner):
    t = _token(client, 'owner@test.com')
    tid = _create_t(client, t).get_json()['data']['id']
    detail = client.get(f'/api/v1/tournaments/{tid}', headers=_auth(t)).get_json()['data']
    for m in detail['rounds'][0]['matches']:
        client.post(f'/api/v1/tournaments/{tid}/score/{m["id"]}', headers=_auth(t),
                    json={'points_t1': 11, 'points_t2': 9})
    r = client.post(f'/api/v1/tournaments/{tid}/complete', headers=_auth(t))
    assert r.status_code == 200
    d = r.get_json()['data']
    assert d['tournament']['status'] == 'completed'
    assert 'standings' in d and 'events' in d


def test_complete_is_idempotent_no_double_chips(client, owner):
    """Completing twice must not re-run the cascade (would double chips)."""
    t = _token(client, 'owner@test.com')
    tid = _create_t(client, t).get_json()['data']['id']
    detail = client.get(f'/api/v1/tournaments/{tid}', headers=_auth(t)).get_json()['data']
    for m in detail['rounds'][0]['matches']:
        client.post(f'/api/v1/tournaments/{tid}/score/{m["id"]}', headers=_auth(t),
                    json={'points_t1': 11, 'points_t2': 9})
    assert client.post(f'/api/v1/tournaments/{tid}/complete', headers=_auth(t)).status_code == 200
    # second call blocked
    r2 = client.post(f'/api/v1/tournaments/{tid}/complete', headers=_auth(t))
    assert r2.status_code == 409
    assert r2.get_json()['error']['code'] == 'ALREADY_COMPLETED'


def test_generate_and_score_playoff(client, owner):
    t = _token(client, 'owner@test.com')
    tid = _create_t(client, t).get_json()['data']['id']
    # complete round 1 so standings exist
    detail = client.get(f'/api/v1/tournaments/{tid}', headers=_auth(t)).get_json()['data']
    for i, m in enumerate(detail['rounds'][0]['matches']):
        client.post(f'/api/v1/tournaments/{tid}/score/{m["id"]}', headers=_auth(t),
                    json={'points_t1': 11 + i, 'points_t2': 9})
    r = client.post(f'/api/v1/tournaments/{tid}/generate_playoff', headers=_auth(t),
                    json={'bracket_size': 4})
    assert r.status_code == 201
    bracket = r.get_json()['data']
    assert len(bracket) == 3   # 2 semis + 1 final
    semi = bracket[0]
    rs = client.post(f'/api/v1/tournaments/{tid}/playoff/{semi["id"]}/score',
                     headers=_auth(t), json={'sets': [[6, 4]]})
    assert rs.status_code == 200
    assert rs.get_json()['data']['status'] == 'completed'


def test_tournaments_require_auth(client):
    assert client.get('/api/v1/tournaments').status_code == 401
