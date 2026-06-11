"""Step 5 — scoring_engine_version is metadata only.

Proves: existing rows backfilled legacy, new rows default reference, unknown
values rejected by the DB, and the standings route does NOT touch the
canonical engine yet.
"""
import os
import tempfile

import pytest
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from app import create_app
from app.config import TestingConfig
from app.extensions import db as _db
from app.models import (
    Tournament, User,
    SCORING_ENGINE_LEGACY, SCORING_ENGINE_REFERENCE,
)

INITIAL_REV = 'f4e76968391b'


def test_existing_tournaments_are_backfilled_as_legacy(tmp_path):
    """Run the real Alembic migration over a DB that already has tournaments
    in every status — all must come out as legacy_flask_v1."""
    from flask_migrate import upgrade

    db_file = tmp_path / 'mig.db'

    class MigConfig(TestingConfig):
        SQLALCHEMY_DATABASE_URI = f'sqlite:///{db_file}'
        # Skip dev create_all() so the schema is owned by Alembic here —
        # otherwise tables exist before the migration runs.
        IS_PRODUCTION = True

    app = create_app(MigConfig)
    with app.app_context():
        upgrade(revision=INITIAL_REV)  # schema BEFORE the version column
        _db.session.execute(text(
            "INSERT INTO tournament (name, status) VALUES "
            "('t-notstarted','draft'),('t-inprogress','playing'),"
            "('t-scored','playing'),('t-completed','completed')"
        ))
        _db.session.commit()

        upgrade()  # to head — adds column + backfill

        rows = _db.session.execute(text(
            'SELECT status, scoring_engine_version FROM tournament'
        )).fetchall()
        assert len(rows) == 4
        assert all(v == SCORING_ENGINE_LEGACY for _, v in rows), rows
        # status must not influence the backfill
        assert {s for s, _ in rows} == {'draft', 'playing', 'completed'}


def test_new_tournament_defaults_to_reference_engine(app, db):
    t = Tournament(name='Baru', format='americano')
    _db.session.add(t)
    _db.session.commit()
    assert t.scoring_engine_version == SCORING_ENGINE_REFERENCE


def test_unknown_scoring_engine_version_is_rejected_by_database(app, db):
    t = Tournament(name='Bad', format='americano',
                   scoring_engine_version='engine_v2_test')
    _db.session.add(t)
    with pytest.raises(IntegrityError):
        _db.session.commit()
    _db.session.rollback()


def test_current_standings_route_does_not_invoke_canonical_engine(
        app, db, client, monkeypatch):
    """Step 5 is metadata-only: GET standings must not call the canonical engine."""
    import app.services.tournament_scoring.engine as canonical

    calls = {'n': 0}

    def spy(*a, **k):
        calls['n'] += 1
        raise AssertionError('canonical engine must not be called in Step 5')

    monkeypatch.setattr(canonical, 'calculate_standings', spy)

    u = User(username='Owner', email='o@t.com', phone='081x', role='member',
             membership='member', membership_paid=True)
    u.set_password('rahasia123')
    _db.session.add(u)
    _db.session.commit()
    token = client.post('/api/v1/auth/login',
                        json={'email': 'o@t.com', 'password': 'rahasia123'}
                        ).get_json()['data']['access_token']

    r = client.post('/api/v1/tournaments',
                    headers={'Authorization': f'Bearer {token}'},
                    json={'name': 'T', 'format': 'americano', 'num_courts': 1,
                          'participants': [{'name': n} for n in ['A', 'B', 'C', 'D']]})
    tid = r.get_json()['data']['id']

    rs = client.get(f'/api/v1/tournaments/{tid}/standings',
                    headers={'Authorization': f'Bearer {token}'})
    assert rs.status_code == 200
    assert calls['n'] == 0  # legacy calculate_leaderboard did the work
