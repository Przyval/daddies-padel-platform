"""Tests for /api/v1 leaderboard, members, notifications."""
import pytest
from app.extensions import db as _db
from app.models import User, Notification


def _mk(email, chips=0):
    u = User(username=email.split('@')[0], email=email, phone='08' + email[:6],
             role='member', membership='member', membership_paid=True,
             chips_balance=chips)
    u.set_password('rahasia123')
    _db.session.add(u)
    _db.session.commit()
    return u


def _token(client, email):
    return client.post('/api/v1/auth/login',
                       json={'email': email, 'password': 'rahasia123'}
                       ).get_json()['data']['access_token']


def _auth(tok):
    return {'Authorization': f'Bearer {tok}'}


@pytest.fixture
def users(app, db):
    a = _mk('alice@test.com', chips=5000)
    b = _mk('bob@test.com', chips=9000)
    c = _mk('carol@test.com', chips=1000)
    return a, b, c


def test_leaderboard_chips_sorted(client, users):
    t = _token(client, 'alice@test.com')
    r = client.get('/api/v1/leaderboard?tab=chips', headers=_auth(t))
    assert r.status_code == 200
    rows = r.get_json()['data']
    assert rows[0]['user']['name'] == 'bob'      # 9000 chips
    assert rows[0]['rank'] == 1 and rows[0]['metric'] == 'chips'
    assert rows[0]['value'] == 9000


def test_leaderboard_global_tab(client, users):
    t = _token(client, 'alice@test.com')
    r = client.get('/api/v1/leaderboard?tab=global', headers=_auth(t))
    assert r.status_code == 200  # empty (no tournaments) but valid shape
    assert isinstance(r.get_json()['data'], list)


def test_members_list_and_search(client, users):
    t = _token(client, 'alice@test.com')
    assert len(client.get('/api/v1/members', headers=_auth(t)).get_json()['data']) == 3
    r = client.get('/api/v1/members?q=bob', headers=_auth(t))
    data = r.get_json()['data']
    assert len(data) == 1 and data[0]['name'] == 'bob'


def test_member_detail(client, users):
    a, b, c = users
    t = _token(client, 'alice@test.com')
    r = client.get(f'/api/v1/members/{b.id}', headers=_auth(t))
    assert r.status_code == 200
    d = r.get_json()['data']
    assert d['name'] == 'bob'
    assert 'stats' in d and 'streak' in d
    assert 'email' not in d  # public profile hides email


def test_member_detail_404(client, users):
    t = _token(client, 'alice@test.com')
    assert client.get('/api/v1/members/9999', headers=_auth(t)).status_code == 404


def test_notifications_list_and_read(client, users):
    a, b, c = users
    _db.session.add_all([
        Notification(user_id=a.id, title='Halo', body='satu', is_read=False),
        Notification(user_id=a.id, title='Dua', body='dua', is_read=False),
    ])
    _db.session.commit()
    t = _token(client, 'alice@test.com')

    r = client.get('/api/v1/notifications', headers=_auth(t))
    body = r.get_json()['data']
    assert body['unread_count'] == 2
    assert len(body['notifications']) == 2

    # mark all read
    client.post('/api/v1/notifications/read-all', headers=_auth(t))
    body2 = client.get('/api/v1/notifications', headers=_auth(t)).get_json()['data']
    assert body2['unread_count'] == 0


def test_notifications_scoped_to_user(client, users):
    a, b, c = users
    _db.session.add(Notification(user_id=a.id, title='A only', body='x'))
    _db.session.commit()
    # bob should not see alice's notification
    tb = _token(client, 'bob@test.com')
    body = client.get('/api/v1/notifications', headers=_auth(tb)).get_json()['data']
    assert body['notifications'] == []


def test_mark_one_read(client, users):
    a, b, c = users
    n = Notification(user_id=a.id, title='X', body='y', is_read=False)
    _db.session.add(n)
    _db.session.commit()
    t = _token(client, 'alice@test.com')
    r = client.post(f'/api/v1/notifications/{n.id}/read', headers=_auth(t))
    assert r.status_code == 200 and r.get_json()['data']['is_read'] is True


def test_community_requires_auth(client):
    assert client.get('/api/v1/leaderboard').status_code == 401
    assert client.get('/api/v1/members').status_code == 401
    assert client.get('/api/v1/notifications').status_code == 401
