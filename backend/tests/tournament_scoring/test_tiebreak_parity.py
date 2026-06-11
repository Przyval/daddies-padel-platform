"""Parity: Python engine vs Dart golden — tiebreak."""
import pytest
from golden_loader import load, assert_case_parity

CASES = load('scoring_tiebreak.json')


@pytest.mark.parametrize('case', CASES, ids=[c['id'] for c in CASES])
def test_tiebreak_parity(case):
    assert_case_parity(case)
