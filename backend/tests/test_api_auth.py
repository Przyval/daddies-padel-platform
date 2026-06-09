"""Tests for the /api/v1 JWT auth + me + membership endpoints."""
import pytest
from app.extensions import db as _db
from app.models import User


@pytest.fixture
def member(app, db):
    """A paid member with a known password."""
    u = User(username='Test Member', email='member@test.com',
             phone='0811', role='member', membership='member',
             membership_paid=True, kta_number='DPC-9999')
    u.set_password('rahasia123')
    _db.session.add(u)
    _db.session.commit()
    return u


def _login(client, email, password):
    return client.post('/api/v1/auth/login', json={'email': email, 'password': password})


def test_health(client):
    r = client.get('/api/v1/health')
    assert r.status_code == 200
    assert r.get_json()['ok'] is True


def test_login_success_returns_tokens(client, member):
    r = _login(client, 'member@test.com', 'rahasia123')
    body = r.get_json()
    assert r.status_code == 200
    assert body['ok'] is True
    assert body['data']['access_token']
    assert body['data']['refresh_token']
    assert body['data']['user']['name'] == 'Test Member'


def test_login_wrong_password_401(client, member):
    r = _login(client, 'member@test.com', 'salah')
    assert r.status_code == 401
    assert r.get_json()['error']['code'] == 'INVALID_CREDENTIALS'


def test_me_requires_token(client):
    r = client.get('/api/v1/me')
    assert r.status_code == 401
    assert r.get_json()['ok'] is False  # JSON, not an HTML redirect


def test_me_with_token(client, member):
    token = _login(client, 'member@test.com', 'rahasia123').get_json()['data']['access_token']
    r = client.get('/api/v1/me', headers={'Authorization': f'Bearer {token}'})
    body = r.get_json()
    assert r.status_code == 200
    assert body['data']['kta_number'] == 'DPC-9999'
    assert 'stats' in body['data'] and 'streak' in body['data']


def test_membership_endpoint(client, member):
    token = _login(client, 'member@test.com', 'rahasia123').get_json()['data']['access_token']
    r = client.get('/api/v1/membership', headers={'Authorization': f'Bearer {token}'})
    body = r.get_json()
    assert r.status_code == 200
    assert body['data']['membership'] == 'member'
    assert body['data']['progress']['games_required'] == 5


def test_register_creates_user_and_tokens(client):
    r = client.post('/api/v1/auth/register', json={
        'username': 'Baru', 'email': 'baru@test.com',
        'phone': '0822', 'password': 'rahasia123',
    })
    body = r.get_json()
    assert r.status_code == 201
    assert body['data']['access_token']
    assert User.query.filter_by(email='baru@test.com').first() is not None


def test_register_duplicate_email_409(client, member):
    r = client.post('/api/v1/auth/register', json={
        'username': 'Dup', 'email': 'member@test.com',
        'phone': '0833', 'password': 'rahasia123',
    })
    assert r.status_code == 409
    assert r.get_json()['error']['code'] == 'EMAIL_TAKEN'


def test_register_short_password_422(client):
    r = client.post('/api/v1/auth/register', json={
        'username': 'X', 'email': 'x@test.com', 'phone': '0844', 'password': '123',
    })
    assert r.status_code == 422


def test_refresh_returns_new_access_token(client, member):
    refresh = _login(client, 'member@test.com', 'rahasia123').get_json()['data']['refresh_token']
    r = client.post('/api/v1/auth/refresh', headers={'Authorization': f'Bearer {refresh}'})
    assert r.status_code == 200
    assert r.get_json()['data']['access_token']
