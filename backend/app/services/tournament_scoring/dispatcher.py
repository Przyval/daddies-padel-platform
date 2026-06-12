"""Version dispatcher — fail closed.

    legacy_flask_v1        -> legacy calculate_leaderboard (unchanged)
    americano_reference_v1 -> adapters -> canonical engine
    anything else          -> UnsupportedScoringEngineVersion

Step 4a: defined and unit-tested only. NO route imports this yet (cutover is
Step 4b). Standings and rotation are SEPARATE operations so a standings call
can never create or modify rounds.
"""
from __future__ import annotations

from .engine import calculate_standings
from .exceptions import UnsupportedScoringEngineVersion
from .adapters import adapt_tournament_to_engine_input
from .adapters.flask_output import adapt_canonical_standings_to_legacy_rows

# Version constants live on the model layer; import here is adapter-adjacent
# (dispatcher already sits above the pure core).
SCORING_ENGINE_LEGACY = 'legacy_flask_v1'
SCORING_ENGINE_REFERENCE = 'americano_reference_v1'


def _default_legacy_calculator(tournament):
    # Lazy import keeps this package importable without the app context.
    from app.services.tournament_legacy_scoring import calculate_leaderboard
    return calculate_leaderboard(tournament)


def calculate_tournament_standings(tournament, *, legacy_calculator=None):
    """Compute standings for `tournament` with the engine its version pins.

    BOTH paths return rows in the legacy calculate_leaderboard shape
    (participant/points/wins/.../teammates/h2h), so every existing template
    and serializer keeps working; canonical rows additionally carry
    rank/raw_score/bonus_points. Raises UnsupportedScoringEngineVersion for
    unknown/None/empty versions (fail closed — no silent legacy fallback).
    """
    version = getattr(tournament, 'scoring_engine_version', None)

    if version == SCORING_ENGINE_LEGACY:
        legacy = legacy_calculator or _default_legacy_calculator
        return legacy(tournament)

    if version == SCORING_ENGINE_REFERENCE:
        canonical_input = adapt_tournament_to_engine_input(tournament)
        result = calculate_standings(
            players=canonical_input.players,
            games=canonical_input.games,
            config=canonical_input.config,
        )
        participants = tournament.participants.all()
        return adapt_canonical_standings_to_legacy_rows(result, participants)

    raise UnsupportedScoringEngineVersion(version)


def generate_tournament_rotation(tournament, participants):
    """Rotation dispatch (Step 4c). Separate from standings by design.

    Returns tuple[RotationRound, ...] with PARTICIPANT IDS in the team slots,
    or None meaning "canonical rotation does not apply — caller must use the
    legacy generators". Scope (documented in golden/README):
      - reference + format 'americano' + table count (8/12/../32) + natural
        courts (N/4)  -> pre-computed reference table, players shuffled first
        (the reference shuffles too: it's an input permutation, the table core
        itself is deterministic)
      - reference but non-table count / non-natural courts -> None (the
        reference randomizes those layers; legacy generator is our fallback)
      - legacy version -> None (legacy generators own rotation)
      - unknown version -> UnsupportedScoringEngineVersion (fail closed)
    """
    import random as _random

    from .types import Player
    from .rotations import apply_table, has_table

    version = getattr(tournament, 'scoring_engine_version', None)
    if version == SCORING_ENGINE_LEGACY:
        return None
    if version != SCORING_ENGINE_REFERENCE:
        raise UnsupportedScoringEngineVersion(version)

    if tournament.format != 'americano':
        return None
    n = len(participants)
    if not has_table(n) or tournament.num_courts != n // 4:
        return None

    shuffled = list(participants)
    _random.shuffle(shuffled)
    players = [Player(id=p.id, source_order=i) for i, p in enumerate(shuffled)]
    return apply_table(players)
