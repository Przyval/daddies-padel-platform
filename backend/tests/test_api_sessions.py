"""Tests for the /api/v1/sessions endpoints."""
import io
from datetime import datetime, timedelta
import pytest
from app.extensions import db as _db
from app.models import User, Match


def _mk_user(email, role='member', paid=True, membership='member'):
    u = User(username=email.split('@')[0], email=email, phone='08' + email[:6],
             role=role, membership=membership, membership_paid=paid)
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
def member(app, db):
    return _mk_user('member@test.com')


@pytest.fixture
def admin(app, db):
    return _mk_user('admin@test.com', role='admin')


@pytest.fixture
def guest(app, db):
    return _mk_user('guest@test.com', role='member', paid=False, membership='guest')


@pytest.fixture
def a_session(app, db):
    m = Match(title='Kamis Malam', date_time=datetime.utcnow() + timedelta(days=1),
              location='Daddies Court', price=50000, max_players=4, status='open')
    _db.session.add(m)
    _db.session.commit()
    return m


def test_list_sessions(client, member, a_session):
    t = _token(client, 'member@test.com')
    r = client.get('/api/v1/sessions', headers=_auth(t))
    assert r.status_code == 200
    data = r.get_json()['data']
    assert len(data) == 1
    assert data[0]['title'] == 'Kamis Malam'
    assert data[0]['my_status'] is None


def test_get_session_detail(client, member, a_session):
    t = _token(client, 'member@test.com')
    r = client.get(f'/api/v1/sessions/{a_session.id}', headers=_auth(t))
    assert r.status_code == 200
    d = r.get_json()['data']
    assert d['players'] == []
    assert d['my_booking'] is None


def test_get_session_404(client, member):
    t = _token(client, 'member@test.com')
    r = client.get('/api/v1/sessions/999', headers=_auth(t))
    assert r.status_code == 404


def test_create_session_admin_only(client, member, admin):
    payload = {'title': 'New', 'date_time': datetime.utcnow().isoformat(),
               'price': 40000, 'max_players': 4}
    # member forbidden
    tm = _token(client, 'member@test.com')
    assert client.post('/api/v1/sessions', json=payload, headers=_auth(tm)).status_code == 403
    # admin ok
    ta = _token(client, 'admin@test.com')
    r = client.post('/api/v1/sessions', json=payload, headers=_auth(ta))
    assert r.status_code == 201
    assert r.get_json()['data']['title'] == 'New'


def test_create_session_bad_date(client, admin):
    ta = _token(client, 'admin@test.com')
    r = client.post('/api/v1/sessions',
                    json={'title': 'X', 'date_time': 'bukan-tanggal'}, headers=_auth(ta))
    assert r.status_code == 422


def test_join_session(client, member, a_session):
    t = _token(client, 'member@test.com')
    r = client.post(f'/api/v1/sessions/{a_session.id}/join', headers=_auth(t))
    assert r.status_code == 201
    assert r.get_json()['data']['waitlisted'] is False
    # double join blocked
    r2 = client.post(f'/api/v1/sessions/{a_session.id}/join', headers=_auth(t))
    assert r2.status_code == 409


def test_join_requires_paid_membership(client, guest, a_session):
    t = _token(client, 'guest@test.com')
    r = client.post(f'/api/v1/sessions/{a_session.id}/join', headers=_auth(t))
    assert r.status_code == 403
    assert r.get_json()['error']['code'] == 'MEMBERSHIP_REQUIRED'


def test_join_full_session_waitlists(client, app, db, a_session):
    # Fill the 4 slots with confirmed bookings, then a 5th joins -> waitlist.
    from app.models import Booking
    for i in range(4):
        u = _mk_user(f'p{i}@test.com')
        _db.session.add(Booking(user_id=u.id, match_id=a_session.id, status='confirmed'))
    _db.session.commit()
    late = _mk_user('late@test.com')
    t = _token(client, 'late@test.com')
    r = client.post(f'/api/v1/sessions/{a_session.id}/join', headers=_auth(t))
    assert r.status_code == 201
    assert r.get_json()['data']['waitlisted'] is True


def test_payment_info(client, member, a_session):
    t = _token(client, 'member@test.com')
    client.post(f'/api/v1/sessions/{a_session.id}/join', headers=_auth(t))
    r = client.get(f'/api/v1/sessions/{a_session.id}/payment', headers=_auth(t))
    assert r.status_code == 200
    d = r.get_json()['data']
    assert d['payment_code'].startswith('DPC-')
    assert d['amount'] == 50000


def test_upload_payment_proof(client, member, a_session):
    t = _token(client, 'member@test.com')
    client.post(f'/api/v1/sessions/{a_session.id}/join', headers=_auth(t))
    data = {'payment_proof': (io.BytesIO(b'fake-image-bytes'), 'bukti.jpg')}
    r = client.post(f'/api/v1/sessions/{a_session.id}/payment/proof',
                    data=data, headers=_auth(t), content_type='multipart/form-data')
    assert r.status_code == 200
    assert r.get_json()['data']['booking']['status'] == 'paid'


def test_upload_payment_proof_bad_ext(client, member, a_session):
    t = _token(client, 'member@test.com')
    client.post(f'/api/v1/sessions/{a_session.id}/join', headers=_auth(t))
    data = {'payment_proof': (io.BytesIO(b'x'), 'virus.exe')}
    r = client.post(f'/api/v1/sessions/{a_session.id}/payment/proof',
                    data=data, headers=_auth(t), content_type='multipart/form-data')
    assert r.status_code == 422


def test_history(client, member, a_session):
    t = _token(client, 'member@test.com')
    client.post(f'/api/v1/sessions/{a_session.id}/join', headers=_auth(t))
    r = client.get('/api/v1/sessions/history', headers=_auth(t))
    assert r.status_code == 200
    hist = r.get_json()['data']
    assert len(hist) == 1
    assert hist[0]['session']['title'] == 'Kamis Malam'


def test_sessions_require_auth(client):
    assert client.get('/api/v1/sessions').status_code == 401
