"""Canonical Americano scoring engine (reference port). Pure Python, no Flask/DB.

Public API:
    from app.services.tournament_scoring import (
        calculate_standings, Player, Team, Court, GameResult, EngineConfig,
        PlayerStanding,
    )
"""
from .types import Player, Team, Court, GameResult, EngineConfig, PlayerStanding
from .engine import calculate_standings

__all__ = [
    'calculate_standings',
    'Player', 'Team', 'Court', 'GameResult', 'EngineConfig', 'PlayerStanding',
]
