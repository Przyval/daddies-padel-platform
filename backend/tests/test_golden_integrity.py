"""Snapshot guard for golden fixtures.

These golden files are the source of truth for the canonical scoring-engine
port (plan A). This test pins their content hash so a regenerated/edited golden
can never land silently — if the reference engine output changes, the pinned
sha256 fails here and forces a conscious review.

Hashes are over the `cases` array only (sort_keys, compact), so provenance
fields (generated_at, source_commit) don't affect them.
"""
import glob
import hashlib
import json
import os

GOLDEN_DIR = os.path.join(os.path.dirname(__file__), 'golden')

# Pinned sha256 of each scoring golden's `cases` (from the Dart reference engine).
PINNED = {
    'scoring_bonus.json': '154d7d6c11e48fc6be26036978bd3bf91e7da6790fffa8d7c824f023c199aabd',
    'scoring_even_points.json': 'de2b5f82a0b7ff2ffdf7df07e973c26c33ec0dcca833ac0f40d47c9439cdae38',
    'scoring_points.json': 'e28b292861165833d6a517e327a9974a147c45acefbf9c8c81e751bdf8c1ed7a',
    'scoring_sets.json': '1f2753950243b5685250b593edf50cb84c612d60c9abe8b6ca9b2cf8ab115443',
    'scoring_tiebreak.json': '1c8605f6f5ae787856b5df194d52556563d87dd3042ef39957e812c7051fe83b',
}


def _cases_sha(cases):
    blob = json.dumps(cases, sort_keys=True, separators=(',', ':'))
    return hashlib.sha256(blob.encode()).hexdigest()


def test_scoring_golden_hashes_pinned():
    for fn, expected in PINNED.items():
        path = os.path.join(GOLDEN_DIR, fn)
        data = json.load(open(path))
        actual = _cases_sha(data['cases'])
        assert actual == data.get('cases_sha256'), f'{fn}: stored sha mismatch (file corrupt?)'
        assert actual == expected, (
            f'{fn}: golden changed! pinned={expected[:12]}… actual={actual[:12]}…\n'
            f'If intentional, update PINNED after reviewing the diff.'
        )


def test_scoring_golden_invariants():
    for path in glob.glob(os.path.join(GOLDEN_DIR, 'scoring_*.json')):
        data = json.load(open(path))
        for c in data['cases']:
            st = c['expected_standings']
            assert [s['rank'] for s in st] == list(range(1, len(st) + 1))
            for s in st:
                # score is exactly raw + even + court bonus
                assert s['score'] == s['raw_points'] + s['even_points'] + s['court_bonus']
            key = 'wins' if c['input'].get('sort_by_wins') else 'score'
            vals = [s[key] for s in st]
            assert vals == sorted(vals, reverse=True), f'{os.path.basename(path)}/{c["id"]}: bad sort'


def test_rotations_golden_no_double_booking():
    data = json.load(open(os.path.join(GOLDEN_DIR, 'rotations.json')))
    for case in data['cases']:
        n = case['players']
        for rnd in case['rounds']:
            seen = []
            for m in rnd['matches']:
                seen += m['team1'] + m['team2']
            assert sorted(seen) == list(range(1, n + 1)), \
                f"n={n} round={rnd['round']}: player double-booked or missing"
