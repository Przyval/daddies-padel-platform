"""Shared fixtures for tournament tests."""
import pytest
import json
from app import create_app
from app.extensions import db as _db
from app.models import (
    Tournament, TournamentParticipant, TournamentRound, TournamentMatch
)


@pytest.fixture
def app():
    app = create_app()
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite://'  # in-memory
    app.config['WTF_CSRF_ENABLED'] = False
    app.config['RATELIMIT_ENABLED'] = False  # don't throttle the test client
    with app.app_context():
        _db.create_all()
        yield app
        _db.session.remove()
        _db.drop_all()


@pytest.fixture
def db(app):
    return _db


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def tournament_8p(app, db):
    """Create an 8-player americano tournament with 2 courts, 21 points."""
    t = Tournament(
        name='Test Tournament', format='americano', status='playing',
        num_courts=2, scoring_mode='points', points_per_game=21,
        current_round=1, win_points=3, draw_points=1, loss_points=0,
        sort_by_wins=True
    )
    db.session.add(t)
    db.session.flush()

    names = ['Adi', 'Budi', 'Candra', 'Dedi', 'Eko', 'Farid', 'Gani', 'Hadi']
    participants = []
    for i, name in enumerate(names):
        p = TournamentParticipant(tournament_id=t.id, name=name, seed=i + 1)
        db.session.add(p)
        participants.append(p)
    db.session.flush()

    # Create Round 1 with 2 matches
    rnd = TournamentRound(tournament_id=t.id, round_number=1)
    db.session.add(rnd)
    db.session.flush()

    # Court 1: Adi+Budi vs Candra+Dedi
    m1 = TournamentMatch(
        tournament_id=t.id, round_id=rnd.id, court=1,
        team1_p1_id=participants[0].id, team1_p2_id=participants[1].id,
        team2_p1_id=participants[2].id, team2_p2_id=participants[3].id,
        status='pending'
    )
    # Court 2: Eko+Farid vs Gani+Hadi
    m2 = TournamentMatch(
        tournament_id=t.id, round_id=rnd.id, court=2,
        team1_p1_id=participants[4].id, team1_p2_id=participants[5].id,
        team2_p1_id=participants[6].id, team2_p2_id=participants[7].id,
        status='pending'
    )
    db.session.add_all([m1, m2])
    db.session.commit()

    return t, participants, rnd, [m1, m2]
