"""Parity: Python engine vs Dart golden — sets."""
import pytest
from golden_loader import load, assert_case_parity

CASES = load('scoring_sets.json')


@pytest.mark.parametrize('case', CASES, ids=[c['id'] for c in CASES])
def test_sets_parity(case):
    assert_case_parity(case)
