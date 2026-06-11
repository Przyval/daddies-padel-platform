// Golden fixture generator — deterministic Americano rotation core.
//
// Emits the pre-computed rotation tables (the reference's source of truth)
// applied to identity-ordered players 1..N, at the natural court count N/4.
// This is the DETERMINISTIC core of AmericanoRotation._fromTable() — the part
// the Python port must reproduce byte-for-byte. (resolve() additionally
// shuffles players and CourtDistributor randomizes on retry, so those layers
// are validated by invariants, not golden equality.)
//
// Run: dart run tool/gen_golden_rotations.dart > ../backend/tests/golden/rotations.json
import 'dart:convert';
import '../lib/domain/engine/rotation/pre_computed_tables.dart';

void main() {
  final out = <String, dynamic>{
    '_meta': {
      'source': 'americano_padel PreComputedTables (reference port)',
      'mapping': 'each round = groups of 4 indices: [a,b,c,d] => team1(a,b) vs team2(c,d), 1-based',
      'players': 'identity order, player id == index',
      'courts': 'natural = N/4',
    },
    'cases': <dynamic>[],
  };

  final counts = PreComputedTables.tables.keys.toList()..sort();
  for (final n in counts) {
    final table = PreComputedTables.tables[n]!;
    final courtsPerRound = n ~/ 4;
    final rounds = <dynamic>[];

    for (int r = 0; r < table.length; r++) {
      final indices = table[r];
      final matches = <dynamic>[];
      for (int c = 0; c < courtsPerRound; c++) {
        final base = c * 4;
        matches.add({
          'court': c + 1,
          'team1': [indices[base], indices[base + 1]],
          'team2': [indices[base + 2], indices[base + 3]],
        });
      }
      rounds.add({'round': r + 1, 'matches': matches});
    }

    (out['cases'] as List).add({
      'players': n,
      'courts': courtsPerRound,
      'total_rounds': table.length,
      'rounds': rounds,
    });
  }

  print(const JsonEncoder.withIndent('  ').convert(out));
}
