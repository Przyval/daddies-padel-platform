"""Parity: Python engine vs Dart golden — points."""
import pytest
from golden_loader import load, assert_case_parity

CASES = load('scoring_points.json')


@pytest.mark.parametrize('case', CASES, ids=[c['id'] for c in CASES])
def test_points_parity(case):
    assert_case_parity(case)
