"""Tournament service: schedule generation + derived standings (event sourcing)."""
import pytest
from app import create_app
from app.config import TestingConfig
from app.extensions import db as _db
from app.models import Tournament, TournamentParticipant, TournamentMatch
from app.services.tournament_service import TournamentService


@pytest.fixture
def app():
    # In-memory DB (TestingConfig binds at init_app) — never touches dev DB.
    app = create_app(TestingConfig)
    with app.app_context():
        _db.create_all()
        yield app
        _db.session.remove()
        _db.drop_all()


def test_americano_schedule_and_standings(app):
    with app.app_context():
        t = Tournament(name='Test Americano', format='americano')
        _db.session.add(t)
        _db.session.commit()

        for name in ['Alice', 'Bob', 'Charlie', 'David']:
            _db.session.add(TournamentParticipant(tournament_id=t.id, name=name))
        _db.session.commit()

        TournamentService.generate_schedule(t.id)

        rounds = t.rounds.all()
        assert len(rounds) == 3  # 4-player round robin

        # Score round 1 match 1: team1 14, team2 10 (sets are the source of truth).
        m1 = rounds[0].matches.first()
        m1.sets = [[14, 10]]
        m1.status = 'completed'
        _db.session.commit()

        standings = TournamentService.calculate_standings(t.id)
        by_name = {s['name']: s for s in standings}

        # Team 1 players got 14 points, team 2 players got 10. Unplayed matches
        # must NOT count (only 1 match completed).
        assert by_name[m1.team1_p1.name]['points'] == 14
        assert by_name[m1.team1_p1.name]['matches_played'] == 1
        assert by_name[m1.team2_p1.name]['points'] == 10
        assert by_name[m1.team2_p1.name]['matches_played'] == 1


def test_standings_ignore_pending_matches(app):
    """A tournament with zero completed matches yields zero points for everyone."""
    with app.app_context():
        t = Tournament(name='Empty', format='americano')
        _db.session.add(t)
        _db.session.commit()
        for name in ['A', 'B', 'C', 'D']:
            _db.session.add(TournamentParticipant(tournament_id=t.id, name=name))
        _db.session.commit()
        TournamentService.generate_schedule(t.id)

        standings = TournamentService.calculate_standings(t.id)
        assert all(s['points'] == 0 and s['matches_played'] == 0 for s in standings)
