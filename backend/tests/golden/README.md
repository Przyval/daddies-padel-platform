# Golden fixtures — Americano reference engine

Source of truth for porting the reference scoring/rotation engine
(`americano_padel/` Flutter, "Ported from AmericanoActivity") into a canonical
Python engine. Generated FROM the Dart engine, not hand-written.

## Files
- `rotations.json` — deterministic rotation core: pre-computed optimal tables
  for 8/12/16/20/24/28/32 players at natural court count (N/4), identity players.
  Gen: `americano_padel/tool/gen_golden_rotations.dart`.
- `scoring_points.json` / `scoring_sets.json` / `scoring_bonus.json` /
  `scoring_even_points.json` / `scoring_tiebreak.json` — run the REAL
  `ScoringEngine.calculateStandings` with constructed results; dump every
  intermediate (raw points, even points, court bonus, diffs, W/L/T, h2h, rank).
  Gen: `americano_padel/tool/gen_golden_scoring.dart` → `finalize.py`.

Each file: `{schema_version, source_engine, source_commit, generated_at,
cases_sha256, cases}`. The sha is over `cases` only (stable). `finalize.py`
re-wraps + validates; `test_golden_integrity.py` pins the sha so golden cannot
drift silently.

## Reference-behavior facts proven by the scoring golden
- **Court bonus** is added to `extraPoints` of ALL 4 players in a court's game,
  only from round `extraPointsFromRound` onward, **points mode only**, and it
  DOES change ranking. (Flask stores the config but never applies it — the bug.)
- **Even-points** (sit-out) = `(maxGames - games) * (avgScore // 2)`, where
  `avgScore = floor(totalGamePoints / playedGames)`. Integer division.
- **`game_diff` / `set_diff` are tracked but NOT used in any tie-break.**
  Tie-break (compareByScore) = score → wins → losses → extraPoints → diffPts.
  compareByWins = wins → losses → h2h(pairwise) → score → extraPoints → diffPts.
- **`sortByWins`** ranks any win above a higher pure score (wins dominate).
- **h2h is pairwise (non-transitive)** → cycles fall through to score/diff.

## ⚠️ Parity strategy (important — the rotation is partly RANDOM)

The reference rotation is **not a pure function**:
1. `AmericanoRotation.resolve()` does `players.shuffle()` (random each run).
2. `CourtDistributor.fitToCourts()` shuffles on retries when the requested
   court count ≠ the table's natural courts-per-round.

So "100% identical rotation vs Dart" is only achievable — and only meaningful —
for the **deterministic core**: pre-computed table + natural courts + identity
players. That is what `rotations.json` captures and what the Python port must
reproduce **byte-for-byte**.

For the randomized layers (player shuffle, court redistribution, the general
constraint-satisfaction fallback for non-table counts), both engines randomize,
so the port is validated by **invariants**, not golden equality:
- every player appears exactly once per round (no double-booking),
- correct partner/opponent constraints over the tournament,
- correct round count and courts-per-round,
- sit-out frequency fairness.

## Still TODO in Step 1 (golden generation)
- [ ] Scoring golden: input results → expected standings (points mode + sets
      mode), incl. **court bonus** (`extraPointsFromRound`/court `extraPoints`),
      **even-points** (sit-out compensation), diff, W/L/D, **head-to-head**,
      final tie-break order.
- [ ] Odd / non-table player counts (general fallback) — invariant fixtures.
- [ ] Playoff bracket golden (participants + progression).
