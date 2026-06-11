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
from .adapters import (
    adapt_tournament_to_engine_input,
    adapt_canonical_standings_to_rows,
)

# Version constants live on the model layer; import here is adapter-adjacent
# (dispatcher already sits above the pure core).
SCORING_ENGINE_LEGACY = 'legacy_flask_v1'
SCORING_ENGINE_REFERENCE = 'americano_reference_v1'


def _default_legacy_calculator(tournament):
    # Lazy import to avoid a circular dependency at module load
    # (routes -> dispatcher -> routes). Mechanical extraction of the legacy
    # function into its own module is recommended for Step 4b.
    from app.routes.tournament import calculate_leaderboard
    return calculate_leaderboard(tournament)


def calculate_tournament_standings(tournament, *, legacy_calculator=None):
    """Compute standings for `tournament` with the engine its version pins.

    Returns:
      legacy   -> whatever calculate_leaderboard returns (unchanged shape)
      reference-> list[dict] rows from adapt_canonical_standings_to_rows
    Raises UnsupportedScoringEngineVersion for unknown/None/empty versions.
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
        return adapt_canonical_standings_to_rows(result, participants)

    raise UnsupportedScoringEngineVersion(version)


def generate_tournament_rotation(tournament, participants):
    """Round generation dispatch — intentionally NOT implemented in Step 4a.

    Kept as a separate operation (never reachable from standings) so the
    cutover in Step 4b wires it explicitly. Until then every caller keeps
    using the existing in-route generators."""
    raise NotImplementedError(
        'Rotation dispatch arrives in Step 4b; use the existing route-level '
        'generators until the cutover.'
    )
