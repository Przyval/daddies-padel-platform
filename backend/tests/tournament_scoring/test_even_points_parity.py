"""Parity: Python engine vs Dart golden — even_points."""
import pytest
from golden_loader import load, assert_case_parity

CASES = load('scoring_even_points.json')


@pytest.mark.parametrize('case', CASES, ids=[c['id'] for c in CASES])
def test_even_points_parity(case):
    assert_case_parity(case)
