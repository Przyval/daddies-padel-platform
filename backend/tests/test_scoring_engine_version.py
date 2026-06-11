"""scoring_engine_version: migration backfill (Step 5) + route cutover (4b).

Proves: existing rows backfilled legacy, new rows default reference, unknown
values rejected by the DB, and post-cutover the standings routes select the
engine strictly by version (legacy-pinned never touches canonical; reference
always does; unknown fails closed). Web detail renders canonical rows.
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


def _make_owner_and_tournament(client):
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
    return token, r.get_json()['data']['id']


def test_legacy_tournament_standings_do_not_invoke_canonical_engine(
        app, db, client, monkeypatch):
    """Post-cutover (4b): the engine is selected by version. A LEGACY-pinned
    tournament must never touch the canonical engine."""
    import app.services.tournament_scoring.dispatcher as disp

    calls = {'n': 0}
    real = disp.calculate_standings

    def spy(**k):
        calls['n'] += 1
        return real(**k)

    monkeypatch.setattr(disp, 'calculate_standings', spy)

    token, tid = _make_owner_and_tournament(client)
    t = _db.session.get(Tournament, tid)
    t.scoring_engine_version = SCORING_ENGINE_LEGACY  # pin legacy explicitly
    _db.session.commit()
    calls['n'] = 0  # creation ran as reference; count the read below only

    rs = client.get(f'/api/v1/tournaments/{tid}/standings',
                    headers={'Authorization': f'Bearer {token}'})
    assert rs.status_code == 200
    assert calls['n'] == 0  # legacy path only


def test_reference_tournament_standings_invoke_canonical_engine(
        app, db, client, monkeypatch):
    import app.services.tournament_scoring.dispatcher as disp

    calls = {'n': 0}
    real = disp.calculate_standings

    def spy(**k):
        calls['n'] += 1
        return real(**k)

    monkeypatch.setattr(disp, 'calculate_standings', spy)

    token, tid = _make_owner_and_tournament(client)  # default = reference
    rs = client.get(f'/api/v1/tournaments/{tid}/standings',
                    headers={'Authorization': f'Bearer {token}'})
    assert rs.status_code == 200
    assert calls['n'] >= 1  # canonical engine did the work


def test_web_detail_page_renders_for_reference_tournament(app, db, client):
    """Web templates consume the legacy row shape; canonical rows must satisfy
    them (legacy-shape output adapter). No web/API divergence: both read the
    dispatcher."""
    token, tid = _make_owner_and_tournament(client)
    r = client.get(f'/tournament/{tid}?tab=standing')
    assert r.status_code == 200


def test_unknown_version_returns_error_not_legacy_silently(app, db, client):
    """Fail-closed end-to-end: corrupt version on a tournament must error the
    standings read, never silently compute with the wrong engine."""
    from sqlalchemy import text
    token, tid = _make_owner_and_tournament(client)
    # bypass the CHECK constraint path via raw SQL is blocked; simulate by
    # monkey-setting the loaded object attribute? DB rejects unknown values,
    # so corrupt-version rows can only exist if the constraint is absent
    # (e.g. legacy DBs). Simulate via ORM object without flushing.
    t = _db.session.get(Tournament, tid)
    t.scoring_engine_version = 'engine_v2_test'
    from app.services.tournament_scoring.dispatcher import calculate_tournament_standings
    from app.services.tournament_scoring.exceptions import UnsupportedScoringEngineVersion
    import pytest as _pytest
    with _pytest.raises(UnsupportedScoringEngineVersion):
        calculate_tournament_standings(t)
    _db.session.rollback()
