"""Flask/SQLAlchemy <-> canonical engine adapters.

This is the ONLY layer allowed to import DB models. The canonical engine
package itself stays pure (no Flask, no SQLAlchemy).
"""
from .flask_input import CanonicalTournamentInput, adapt_tournament_to_engine_input
from .flask_output import adapt_canonical_standings_to_rows

__all__ = [
    'CanonicalTournamentInput',
    'adapt_tournament_to_engine_input',
    'adapt_canonical_standings_to_rows',
]
