"""Engine-migration policy for EXISTING tournaments (Step 6).

Policy (agreed):
  draft / not started ............ migratable (rounds regenerated)
  in progress, ZERO scored match . migratable (pairing preview = regeneration)
  any completed match ............ IMMUTABLE — refuse; an explicit, audited
                                   recompute is out of scope by design
  status 'completed' ............. IMMUTABLE — never recompute history
  already reference .............. refuse (no-op would hide caller bugs)

Migration is one-way (legacy -> reference). Rounds are REGENERATED because the
reference rotation pairs differently; that is only safe while nothing has been
scored, which is exactly what the policy enforces. Every migration emits an
audit log line (who, tournament, from->to, rounds regenerated).
"""
from __future__ import annotations

from flask import current_app


class MigrationNotAllowed(RuntimeError):
    def __init__(self, code: str, reason: str):
        super().__init__(reason)
        self.code = code
        self.reason = reason


def migration_eligibility(tournament):
    """Return (eligible: bool, code: str, reason: str) without changing anything."""
    from app.models import SCORING_ENGINE_REFERENCE

    if tournament.scoring_engine_version == SCORING_ENGINE_REFERENCE:
        return False, 'ALREADY_REFERENCE', 'Turnamen sudah memakai engine reference'
    if tournament.status == 'completed':
        return False, 'COMPLETED_IMMUTABLE', 'Turnamen selesai tidak boleh dihitung ulang'
    if any(m.status == 'completed' for m in tournament.all_matches):
        return False, 'HAS_SCORES', ('Sudah ada skor tercatat — migrasi akan '
                                     'mengubah hasil; tetap di engine legacy')
    return True, 'ELIGIBLE', 'Belum ada skor; aman dimigrasikan (ronde digenerate ulang)'


def migrate_to_reference(tournament, *, actor_id=None):
    """Enforce the policy, flip the version, regenerate rounds, audit-log.

    Returns a summary dict. Raises MigrationNotAllowed when the policy refuses.
    Caller commits the session."""
    from app.models import SCORING_ENGINE_REFERENCE

    eligible, code, reason = migration_eligibility(tournament)
    if not eligible:
        raise MigrationNotAllowed(code, reason)

    old_version = tournament.scoring_engine_version
    old_rounds = tournament.total_rounds
    tournament.scoring_engine_version = SCORING_ENGINE_REFERENCE

    # Regenerate: _generate_all_rounds dispatches by version, so the new
    # rounds come from the reference rotation (or its documented fallback).
    from app.routes.tournament import _generate_all_rounds
    _generate_all_rounds(tournament)
    new_rounds = tournament.total_rounds

    summary = {
        'tournament_id': tournament.id,
        'from_version': old_version,
        'to_version': SCORING_ENGINE_REFERENCE,
        'rounds_before': old_rounds,
        'rounds_after': new_rounds,
        'actor_id': actor_id,
    }
    current_app.logger.info(
        'ENGINE_MIGRATION tournament=%s %s->%s rounds=%s->%s actor=%s',
        tournament.id, old_version, SCORING_ENGINE_REFERENCE,
        old_rounds, new_rounds, actor_id,
    )
    return summary
