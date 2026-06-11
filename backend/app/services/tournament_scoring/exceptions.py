"""Structured errors for the scoring dispatcher/adapters. Fail-closed by design."""
from __future__ import annotations


class UnsupportedScoringEngineVersion(RuntimeError):
    """Raised when a tournament carries a scoring_engine_version we don't know.

    Unknown values must error — never silently fall back to legacy."""

    def __init__(self, version):
        super().__init__(
            f'Unsupported tournament scoring engine version: {version!r}'
        )
        self.version = version


class InvalidTournamentScoringData(RuntimeError):
    """Raised when a COMPLETED match carries corrupt data (missing players,
    invalid sets_json, empty results). Silent skipping would produce a wrong
    leaderboard, so we refuse to compute instead."""

    def __init__(self, match_id, reason):
        super().__init__(f'Match {match_id}: {reason}')
        self.match_id = match_id
        self.reason = reason
