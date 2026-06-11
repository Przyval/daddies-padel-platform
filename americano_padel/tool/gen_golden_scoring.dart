// Golden fixture generator — Americano SCORING (deterministic).
//
// Builds tournaments + results and runs the REAL ScoringEngine.calculateStandings
// from the reference engine, dumping standings with ALL intermediate values
// (raw points, even points, court bonus, diffs, wins/losses/ties, h2h, rank).
//
// Writes raw {schema_version, source_engine, cases} per group into
// ../backend/tests/golden/_raw/. A Python finalizer adds provenance + sha256.
//
// Run: dart run tool/gen_golden_scoring.dart
import 'dart:convert';
import 'dart:io';
import '../lib/domain/model/models.dart';
import '../lib/domain/model/tournament_kind.dart';
import '../lib/domain/engine/scoring/scoring_engine.dart';

const tid = 1;

Player pl(int i) => Player(id: i, tournamentId: tid, name: 'P$i', uuid: 'p$i');

List<Player> players(int n) => [for (var i = 1; i <= n; i++) pl(i)];

Court court(int number, {int extra = 0}) =>
    Court(id: number, tournamentId: tid, number: number, extraPoints: extra);

Game g(int roundId, int num, List<int> t1, List<int> t2,
        {int r1 = 0, int r2 = 0, String sets = ''}) =>
    Game(
      id: num, roundId: roundId, number: num,
      team1PlayerIds: t1.toSet(), team2PlayerIds: t2.toSet(),
      team1Result: r1, team2Result: r2, setResults: sets,
    );

Tournament tour({
  required String name,
  int resultNumber = 21, // >=0 points mode; -1 sets mode
  int extraPointsFromRound = 0,
  int pointsForWonGame = 3,
  int pointsForEvenGame = 1,
  bool sortByWins = false,
  bool sortHead2head = false,
}) =>
    Tournament(
      id: tid, name: name, kind: TournamentKind.normalAmericano,
      timestamp: 0, uuid: 'tour', resultNumber: resultNumber,
      extraPointsFromRound: extraPointsFromRound,
      pointsForWonGame: pointsForWonGame, pointsForEvenGame: pointsForEvenGame,
      sortByWins: sortByWins, sortHead2head: sortHead2head,
    );

Map<String, dynamic> dumpStanding(PlayerStanding s, int rank) => {
      'rank': rank,
      'player_id': s.playerId,
      'name': s.playerName,
      'score': s.score,
      'raw_points': s.totalScore,
      'even_points': s.evenPoints,
      'court_bonus': s.extraPoints,
      'wins': s.wins,
      'losses': s.losses,
      'ties': s.ties,
      'games': s.games,
      'attended_games': s.attendedGames,
      'diff_pts': s.diffPts,
      'game_diff': s.gameDiff,
      'set_diff': s.setDiff,
      'h2h_total': s.head2headTotal,
      'h2h': {for (final e in s.head2headDelta.entries) '${e.key}': e.value},
    };

Map<String, dynamic> runCase({
  required String id,
  required String note,
  required Tournament t,
  required int n,
  required List<Court> courts,
  required List<RoundWithGames> rounds,
}) {
  final ps = players(n);
  final standings =
      ScoringEngine.calculateStandings(tournament: t, rounds: rounds, players: ps, courts: courts);
  return {
    'id': id,
    'note': note,
    'input': {
      'players': n,
      'result_number': t.resultNumber,
      'mode': t.resultNumber == -1 ? 'sets' : 'points',
      'extra_points_from_round': t.extraPointsFromRound,
      'points_for_won_game': t.pointsForWonGame,
      'points_for_even_game': t.pointsForEvenGame,
      'sort_by_wins': t.sortByWins,
      'sort_head2head': t.sortHead2head,
      'courts': [for (final c in courts) {'number': c.number, 'extra_points': c.extraPoints}],
      'rounds': [
        for (final r in rounds)
          {
            'round': r.number,
            'games': [
              for (final gm in r.games)
                {
                  'team1': gm.team1PlayerIds.toList()..sort(),
                  'team2': gm.team2PlayerIds.toList()..sort(),
                  'team1_result': gm.team1Result,
                  'team2_result': gm.team2Result,
                  'sets': gm.setResults,
                }
            ]
          }
      ],
    },
    'expected_standings': [
      for (var i = 0; i < standings.length; i++) dumpStanding(standings[i], i + 1)
    ],
  };
}

void writeGroup(String fileName, List<Map<String, dynamic>> cases) {
  final dir = Directory('../backend/tests/golden/_raw');
  dir.createSync(recursive: true);
  final payload = {
    'schema_version': 1,
    'source_engine': 'americano_padel_dart_reference',
    'cases': cases,
  };
  File('${dir.path}/$fileName')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));
  stderr.writeln('wrote ${dir.path}/$fileName (${cases.length} cases)');
}

void main() {
  // ── POINTS MODE ──────────────────────────────────────────────────────────
  final points = <Map<String, dynamic>>[
    runCase(
      id: 'p_normal', note: '4p 1 court, normal score 21-15',
      t: tour(name: 'normal'), n: 4, courts: [court(1)],
      rounds: [RoundWithGames(roundId: 1, number: 1, games: [g(1, 1, [1, 2], [3, 4], r1: 21, r2: 15)])],
    ),
    runCase(
      id: 'p_draw', note: 'draw 11-11 → both ties, no win/loss',
      t: tour(name: 'draw'), n: 4, courts: [court(1)],
      rounds: [RoundWithGames(roundId: 1, number: 1, games: [g(1, 1, [1, 2], [3, 4], r1: 11, r2: 11)])],
    ),
    runCase(
      id: 'p_zero_unplayed_vs_max', note: '0-0 not counted (hasResults=false); 21-0 max',
      t: tour(name: 'zeromax'), n: 8, courts: [court(1), court(2)],
      rounds: [
        RoundWithGames(roundId: 1, number: 1, games: [
          g(1, 1, [1, 2], [3, 4], r1: 0, r2: 0),   // unplayed → skipped
          g(1, 2, [5, 6], [7, 8], r1: 21, r2: 0),  // max
        ])
      ],
    ),
    runCase(
      id: 'p_equal_score_diff_tiebreak',
      note: '2 players equal score; tie-break by wins/losses/diff (NOT game_diff)',
      t: tour(name: 'eqdiff'), n: 4, courts: [court(1)],
      rounds: [
        RoundWithGames(roundId: 1, number: 1, games: [g(1, 1, [1, 2], [3, 4], r1: 15, r2: 15)]),
        RoundWithGames(roundId: 2, number: 2, games: [g(2, 2, [1, 3], [2, 4], r1: 20, r2: 10)]),
      ],
    ),
  ];

  // ── COURT BONUS ──────────────────────────────────────────────────────────
  final bonus = <Map<String, dynamic>>[
    runCase(
      id: 'bonus_boundary',
      note: 'extraPointsFromRound=2: round1 NO bonus, round2 bonus=+5 to all 4 in that court',
      t: tour(name: 'bonusB', extraPointsFromRound: 2), n: 4, courts: [court(1, extra: 5)],
      rounds: [
        RoundWithGames(roundId: 1, number: 1, games: [g(1, 1, [1, 2], [3, 4], r1: 10, r2: 8)]),
        RoundWithGames(roundId: 2, number: 2, games: [g(2, 2, [1, 3], [2, 4], r1: 10, r2: 8)]),
      ],
    ),
    runCase(
      id: 'bonus_per_court',
      note: '2 courts: court0 extra=0, court1 extra=7; only court1 players get bonus',
      t: tour(name: 'bonusC', extraPointsFromRound: 1), n: 8, courts: [court(1, extra: 0), court(2, extra: 7)],
      rounds: [
        RoundWithGames(roundId: 1, number: 1, games: [
          g(1, 1, [1, 2], [3, 4], r1: 12, r2: 10),  // court index 0 → extra 0
          g(1, 2, [5, 6], [7, 8], r1: 12, r2: 10),  // court index 1 → extra 7
        ])
      ],
    ),
  ];

  // ── EVEN POINTS / SIT-OUT ────────────────────────────────────────────────
  final even = <Map<String, dynamic>>[
    runCase(
      id: 'even_sit_twice',
      note: '5 players, 1 court, 2 rounds; P5 sits both → evenPoints=(maxGames-0)*(avg~/2)',
      t: tour(name: 'even5'), n: 5, courts: [court(1)],
      rounds: [
        RoundWithGames(roundId: 1, number: 1, games: [g(1, 1, [1, 2], [3, 4], r1: 21, r2: 0)]),
        RoundWithGames(roundId: 2, number: 2, games: [g(2, 2, [1, 3], [2, 4], r1: 21, r2: 0)]),
      ],
    ),
    runCase(
      id: 'even_varied',
      note: '6 players, 1 court, 3 rounds; uneven sit-out frequency reveals compensation',
      t: tour(name: 'even6'), n: 6, courts: [court(1)],
      rounds: [
        RoundWithGames(roundId: 1, number: 1, games: [g(1, 1, [1, 2], [3, 4], r1: 16, r2: 8)]),
        RoundWithGames(roundId: 2, number: 2, games: [g(2, 2, [1, 5], [2, 6], r1: 14, r2: 10)]),
        RoundWithGames(roundId: 3, number: 3, games: [g(3, 3, [3, 5], [4, 6], r1: 12, r2: 12)]),
      ],
    ),
  ];

  // ── SETS MODE ────────────────────────────────────────────────────────────
  final sets = <Map<String, dynamic>>[
    runCase(
      id: 's_2_0', note: 'straight sets 6-4,6-3 → winner team1, +pointsForWon',
      t: tour(name: 's20', resultNumber: -1, sortByWins: true), n: 4, courts: [court(1)],
      rounds: [RoundWithGames(roundId: 1, number: 1, games: [g(1, 1, [1, 2], [3, 4], sets: '6-4, 6-3')])],
    ),
    runCase(
      id: 's_3set', note: '3 sets 6-4,4-6,7-5 → winner team1',
      t: tour(name: 's3', resultNumber: -1, sortByWins: true), n: 4, courts: [court(1)],
      rounds: [RoundWithGames(roundId: 1, number: 1, games: [g(1, 1, [1, 2], [3, 4], sets: '6-4, 4-6, 7-5')])],
    ),
    runCase(
      id: 's_setdraw', note: '1-1 sets 6-4,4-6 → setWinner 0 → tie, pointsForEven each',
      t: tour(name: 'sd', resultNumber: -1, sortByWins: true), n: 4, courts: [court(1)],
      rounds: [RoundWithGames(roundId: 1, number: 1, games: [g(1, 1, [1, 2], [3, 4], sets: '6-4, 4-6')])],
    ),
    runCase(
      id: 's_equal_sets_diff_games',
      note: 'two winners with same sets-won but different game_diff — proves game_diff NOT in tiebreak',
      t: tour(name: 'seq', resultNumber: -1, sortByWins: true), n: 8, courts: [court(1), court(2)],
      rounds: [RoundWithGames(roundId: 1, number: 1, games: [
        g(1, 1, [1, 2], [3, 4], sets: '6-0, 6-0'),  // big game diff
        g(1, 2, [5, 6], [7, 8], sets: '6-4, 6-4'),  // small game diff
      ])],
    ),
  ];

  // ── TIE-BREAK / HEAD-TO-HEAD ─────────────────────────────────────────────
  final tiebreak = <Map<String, dynamic>>[
    runCase(
      id: 'h2h_decides',
      note: 'sortByWins+h2h: equal wins, A beat B head-to-head → A ranks above B',
      t: tour(name: 'h2h', resultNumber: 21, sortByWins: true, sortHead2head: true),
      n: 4, courts: [court(1)],
      rounds: [
        RoundWithGames(roundId: 1, number: 1, games: [g(1, 1, [1, 3], [2, 4], r1: 21, r2: 0)]),
        RoundWithGames(roundId: 2, number: 2, games: [g(2, 2, [1, 2], [3, 4], r1: 11, r2: 21)]),
      ],
    ),
    runCase(
      id: 'h2h_cycle',
      note: 'non-transitive h2h (A>B,B>C,C>A) all equal wins → Dart sort order captured as-is',
      t: tour(name: 'cycle', resultNumber: 21, sortByWins: true, sortHead2head: true),
      n: 6, courts: [court(1)],
      rounds: [
        RoundWithGames(roundId: 1, number: 1, games: [g(1, 1, [1, 5], [2, 6], r1: 21, r2: 0)]), // A(1)>B(2)
        RoundWithGames(roundId: 2, number: 2, games: [g(2, 2, [2, 6], [3, 5], r1: 21, r2: 0)]), // B(2)>C(3)
        RoundWithGames(roundId: 3, number: 3, games: [g(3, 3, [3, 5], [1, 6], r1: 21, r2: 0)]), // C(3)>A(1)
      ],
    ),
  ];

  writeGroup('scoring_points.json', points);
  writeGroup('scoring_bonus.json', bonus);
  writeGroup('scoring_even_points.json', even);
  writeGroup('scoring_sets.json', sets);
  writeGroup('scoring_tiebreak.json', tiebreak);
  stderr.writeln('DONE');
}
