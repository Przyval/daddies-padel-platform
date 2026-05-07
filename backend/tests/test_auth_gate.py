"""Tests for Phase 1: Auth gate on tournament mutating routes.

State machine:
  Not logged in  → 401 JSON on all POST mutating routes
  Guest member   → 401/403 on POST routes
  Paying member  → allowed
  Admin          → always allowed
"""
import json
import pytest
from app import create_app
from app.extensions import db as _db
from app.models import (
    Tournament, TournamentParticipant, TournamentRound, TournamentMatch, User
)


@pytest.fixture
def app():
    app = create_app()
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite://'
    app.config['WTF_CSRF_ENABLED'] = False
    app.config['LOGIN_DISABLED'] = False
    with app.app_context():
        _db.create_all()
        yield app
        _db.session.remove()
        _db.drop_all()


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def tournament_with_match(app):
    """Tournament owned by user 1, with one pending match."""
    with app.app_context():
        owner = User(username='Owner', email='owner@test.com', phone='001',
                     membership='member', membership_paid=True, role='member')
        owner.set_password('pw')
        _db.session.add(owner)
        _db.session.flush()

        t = Tournament(name='T', format='americano', status='playing',
                       num_courts=1, scoring_mode='points', points_per_game=21,
                       current_round=1, created_by=owner.id)
        _db.session.add(t)
        _db.session.flush()

        p1 = TournamentParticipant(tournament_id=t.id, name='A', seed=1)
        p2 = TournamentParticipant(tournament_id=t.id, name='B', seed=2)
        p3 = TournamentParticipant(tournament_id=t.id, name='C', seed=3)
        p4 = TournamentParticipant(tournament_id=t.id, name='D', seed=4)
        _db.session.add_all([p1, p2, p3, p4])
        _db.session.flush()

        rnd = TournamentRound(tournament_id=t.id, round_number=1)
        _db.session.add(rnd)
        _db.session.flush()

        m = TournamentMatch(
            tournament_id=t.id, round_id=rnd.id, court=1,
            team1_p1_id=p1.id, team1_p2_id=p2.id,
            team2_p1_id=p3.id, team2_p2_id=p4.id,
            status='pending'
        )
        _db.session.add(m)
        _db.session.commit()
        return t.id, m.id, owner.id


class TestUnauthenticatedBlocked:
    """Not logged in → 401 on all mutating routes."""

    def test_score_blocked_unauthenticated(self, client, tournament_with_match):
        t_id, m_id, _ = tournament_with_match
        resp = client.post(f'/tournament/{t_id}/score/{m_id}',
                           data={'points_t1': '15', 'points_t2': '9'})
        assert resp.status_code == 401
        data = json.loads(resp.data)
        assert data['ok'] == False
        assert 'Login' in data['error']

    def test_complete_blocked_unauthenticated(self, client, tournament_with_match):
        t_id, _, _ = tournament_with_match
        resp = client.post(f'/tournament/{t_id}/complete')
        assert resp.status_code == 401

    def test_settings_post_blocked_unauthenticated(self, client, tournament_with_match):
        t_id, _, _ = tournament_with_match
        resp = client.post(f'/tournament/{t_id}/settings',
                           data={'name': 'Hacked'},
                           headers={'X-Requested-With': 'fetch'})
        assert resp.status_code == 401


class TestGuestMemberBlocked:
    """Logged in but membership_paid=False → blocked on mutating routes."""

    def _login_as_guest(self, client, app):
        with app.app_context():
            guest = User(username='Guest', email='guest@test.com', phone='002',
                         membership='guest', membership_paid=False, role='member')
            guest.set_password('pw')
            _db.session.add(guest)
            _db.session.commit()
            guest_id = guest.id

        with client.session_transaction() as sess:
            sess['_user_id'] = str(guest_id)
            sess['_fresh'] = True
        return guest_id

    def test_score_allowed_for_any_logged_in(self, client, app, tournament_with_match):
        """Score input only requires login, not paid membership."""
        t_id, m_id, _ = tournament_with_match
        self._login_as_guest(client, app)
        resp = client.post(f'/tournament/{t_id}/score/{m_id}',
                           data={'points_t1': '15', 'points_t2': '9'})
        # Should succeed (logged in = can score)
        assert resp.status_code in (200, 302)


class TestOwnerCanModify:
    """Tournament creator can complete and change settings."""

    def _login_as_owner(self, client, owner_id):
        with client.session_transaction() as sess:
            sess['_user_id'] = str(owner_id)
            sess['_fresh'] = True

    def test_owner_can_access_settings(self, client, app, tournament_with_match):
        t_id, _, owner_id = tournament_with_match
        self._login_as_owner(client, owner_id)
        resp = client.post(f'/tournament/{t_id}/settings',
                           data={'name': 'New Name'},
                           headers={'X-Requested-With': 'fetch'})
        assert resp.status_code == 200
        data = json.loads(resp.data)
        assert data['ok'] == True

    def test_non_owner_blocked_from_complete(self, client, app, tournament_with_match):
        t_id, _, owner_id = tournament_with_match
        with app.app_context():
            other = User(username='Other', email='other@test.com', phone='003',
                         membership='member', membership_paid=True, role='member')
            other.set_password('pw')
            _db.session.add(other)
            _db.session.commit()
            other_id = other.id

        with client.session_transaction() as sess:
            sess['_user_id'] = str(other_id)
            sess['_fresh'] = True

        resp = client.post(f'/tournament/{t_id}/complete')
        assert resp.status_code == 403


class TestAdminCanDoEverything:
    """Admin role bypasses all ownership checks."""

    def test_admin_can_complete_any_tournament(self, client, app, tournament_with_match):
        t_id, _, _ = tournament_with_match
        with app.app_context():
            admin = User(username='Admin', email='admin@test.com', phone='004',
                         membership='member', membership_paid=True, role='admin')
            admin.set_password('pw')
            _db.session.add(admin)
            _db.session.commit()
            admin_id = admin.id

        with client.session_transaction() as sess:
            sess['_user_id'] = str(admin_id)
            sess['_fresh'] = True

        resp = client.post(f'/tournament/{t_id}/complete')
        assert resp.status_code in (200, 302)
