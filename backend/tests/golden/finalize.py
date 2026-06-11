#!/usr/bin/env python3
"""Finalize golden fixtures: wrap the Dart-generated raw cases with provenance
(source commit, timestamp) + a sha256 over the *cases* (stable), and validate
invariants. Repeatable: re-running with the same engine yields identical cases
(only generated_at changes).

Usage:
  dart run tool/gen_golden_scoring.dart          # writes backend/tests/golden/_raw/*.json
  python3 backend/tests/golden/finalize.py       # writes backend/tests/golden/scoring_*.json
"""
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, '_raw')


def git_sha():
    try:
        return subprocess.check_output(
            ['git', '-C', HERE, 'rev-parse', 'HEAD'], text=True).strip()
    except Exception:
        return 'unknown'


def validate(name, cases):
    """Structural invariants — fail loudly so a bad golden never lands silently."""
    for c in cases:
        st = c['expected_standings']
        ranks = [s['rank'] for s in st]
        assert ranks == list(range(1, len(st) + 1)), f'{name}/{c["id"]}: ranks not 1..N'
        # score = raw + even + bonus must hold for every row
        for s in st:
            assert s['score'] == s['raw_points'] + s['even_points'] + s['court_bonus'], \
                f'{name}/{c["id"]}: score != raw+even+bonus for {s["name"]}'
        # primary sort key must be non-increasing (score for compareByScore,
        # wins for compareByWins)
        key = 'wins' if c['input'].get('sort_by_wins') else 'score'
        vals = [s[key] for s in st]
        assert vals == sorted(vals, reverse=True), \
            f'{name}/{c["id"]}: {key} not non-increasing -> sort broken'


def main():
    if not os.path.isdir(RAW):
        print('No _raw/ dir — run the Dart generator first.', file=sys.stderr)
        sys.exit(1)
    sha = git_sha()
    now = datetime.now(timezone.utc).isoformat()
    count = 0
    for fn in sorted(os.listdir(RAW)):
        if not fn.endswith('.json'):
            continue
        raw = json.load(open(os.path.join(RAW, fn)))
        cases = raw['cases']
        validate(fn, cases)
        cases_blob = json.dumps(cases, sort_keys=True, separators=(',', ':'))
        out = {
            'schema_version': raw.get('schema_version', 1),
            'source_engine': raw.get('source_engine', 'americano_padel_dart_reference'),
            'source_commit': sha,
            'generated_at': now,
            'cases_sha256': hashlib.sha256(cases_blob.encode()).hexdigest(),
            'cases': cases,
        }
        with open(os.path.join(HERE, fn), 'w') as f:
            json.dump(out, f, indent=2)
        print(f'  {fn}: {len(cases)} cases, sha256={out["cases_sha256"][:12]}…')
        count += 1
    print(f'Finalized {count} golden files.')


if __name__ == '__main__':
    main()
