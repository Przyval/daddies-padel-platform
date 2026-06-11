"""Parity: Python engine vs Dart golden — bonus."""
import pytest
from golden_loader import load, assert_case_parity

CASES = load('scoring_bonus.json')


@pytest.mark.parametrize('case', CASES, ids=[c['id'] for c in CASES])
def test_bonus_parity(case):
    assert_case_parity(case)
