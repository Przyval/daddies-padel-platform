"""Add Tournament.scoring_engine_version (metadata only — no behavior change).

Safe order, so existing tournaments can never be mislabeled as reference:
  1. ADD COLUMN nullable, no server default
  2. Backfill all existing NULL -> 'legacy_flask_v1'
  3. Add allowed-values check constraint
  4. ALTER -> NOT NULL with server default 'americano_reference_v1'

Existing rows = legacy_flask_v1 (their standings keep using the legacy engine).
New rows (ORM, API, or direct SQL) = americano_reference_v1.

Revision ID: a1c2e3f4b5d6
Revises: f4e76968391b
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'a1c2e3f4b5d6'
down_revision = 'f4e76968391b'
branch_labels = None
depends_on = None

LEGACY = 'legacy_flask_v1'
REFERENCE = 'americano_reference_v1'
CK_NAME = 'ck_tournament_scoring_engine_version'


def upgrade():
    # 1. nullable, no default — new rows during the migration window stay NULL
    #    and get backfilled below rather than silently claiming REFERENCE.
    op.add_column(
        'tournament',
        sa.Column('scoring_engine_version', sa.String(length=40), nullable=True),
    )

    # 2. backfill every existing row as legacy (regardless of status)
    op.execute(
        sa.text(
            'UPDATE tournament SET scoring_engine_version = :legacy '
            'WHERE scoring_engine_version IS NULL'
        ).bindparams(legacy=LEGACY)
    )

    # 3 + 4. constraint, NOT NULL, and server default — batch mode so the same
    # migration runs on SQLite (table-rebuild) and PostgreSQL (plain ALTERs).
    with op.batch_alter_table('tournament') as batch:
        batch.create_check_constraint(
            CK_NAME,
            f"scoring_engine_version IN ('{LEGACY}', '{REFERENCE}')",
        )
        batch.alter_column(
            'scoring_engine_version',
            existing_type=sa.String(length=40),
            nullable=False,
            server_default=REFERENCE,
        )


def downgrade():
    with op.batch_alter_table('tournament') as batch:
        batch.drop_constraint(CK_NAME, type_='check')
        batch.drop_column('scoring_engine_version')
