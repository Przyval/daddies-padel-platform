"""Parity + invariants: Python rotation table core vs Dart golden (rotations.json)."""
import json
import os

import pytest

from app.services.tournament_scoring import Player, apply_table

GOLDEN = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'golden', 'rotations.json')
CASES = json.load(open(GOLDEN))['cases']


def _identity_players(n):
    return [Player(id=i, source_order=i - 1) for i in range(1, n + 1)]


@pytest.mark.parametrize('case', CASES, ids=[f"n{c['players']}" for c in CASES])
def test_rotation_matches_golden_byte_for_byte(case):
    n = case['players']
    rounds = apply_table(_identity_players(n))
    assert rounds is not None
    assert len(rounds) == case['total_rounds']
    for rnd, grnd in zip(rounds, case['rounds']):
        assert rnd.number == grnd['round']
        assert len(rnd.matches) == len(grnd['matches'])
        for m, gm in zip(rnd.matches, grnd['matches']):
            assert m.court == gm['court']
            assert list(m.team1) == gm['team1']
            assert list(m.team2) == gm['team2']


@pytest.mark.parametrize('case', CASES, ids=[f"n{c['players']}" for c in CASES])
def test_rotation_invariants(case):
    n = case['players']
    rounds = apply_table(_identity_players(n))
    assert len(rounds) == n - 1                       # round-robin length
    for rnd in rounds:
        assert len(rnd.matches) == n // 4             # natural courts
        seen = []
        for m in rnd.matches:
            seen += list(m.team1) + list(m.team2)
        assert sorted(seen) == list(range(1, n + 1))  # every player once, no dup

    # Partner/opponent coverage sanity: over the whole tournament every player
    # partners and opposes others a balanced number of times (no one is isolated).
    partners = {i: set() for i in range(1, n + 1)}
    opponents = {i: set() for i in range(1, n + 1)}
    for rnd in rounds:
        for m in rnd.matches:
            a, b = m.team1
            c, d = m.team2
            partners[a].add(b); partners[b].add(a)
            partners[c].add(d); partners[d].add(c)
            for x in (a, b):
                for y in (c, d):
                    opponents[x].add(y); opponents[y].add(x)
    for i in range(1, n + 1):
        assert partners[i], f'player {i} never partnered anyone'
        assert opponents[i], f'player {i} never opposed anyone'


def test_no_table_returns_none():
    # non-table count (e.g. 9) → caller must fall back; pure, no exception
    assert apply_table(_identity_players(9)) is None
