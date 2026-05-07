/// Americano & Mexicano round-robin rotation algorithm for padel.
///
/// Generates fair team pairings across multiple rounds, minimizing
/// repeat partnerships while ensuring everyone plays every round.
library;

/// A pairing of two teams for a single court in one round.
class TeamPair {
  final List<String> team1;
  final List<String> team2;

  const TeamPair({required this.team1, required this.team2});

  @override
  String toString() => '${team1.join("+")} vs ${team2.join("+")}';
}

/// Assignment of a [TeamPair] to a specific court.
class CourtAssignment {
  final int court;
  final TeamPair pair;

  const CourtAssignment({required this.court, required this.pair});
}

/// One complete round: a list of court assignments.
class RoundPairing {
  final int round;
  final List<CourtAssignment> courts;

  const RoundPairing({required this.round, required this.courts});

  /// All player IDs involved in this round.
  List<String> get allPlayerIds =>
      courts.expand((c) => [...c.pair.team1, ...c.pair.team2]).toList();
}

/// Player standings used for Mexicano reseeding.
class PlayerStanding {
  final String playerId;
  final int totalPoints;
  final int matchesPlayed;

  const PlayerStanding({
    required this.playerId,
    required this.totalPoints,
    required this.matchesPlayed,
  });
}

/// Core rotation algorithm for Americano and Mexicano padel formats.
class AmericanoRotation {
  AmericanoRotation._();

  /// Generate a full Americano schedule for [playerIds] (4–16 players).
  ///
  /// Uses the circle method for round-robin with a partner-minimization
  /// heuristic. Each round produces matches for `playerCount / 4` courts.
  /// Players sit out in rotation when count isn't divisible by 4.
  static List<RoundPairing> generateSchedule(List<String> playerIds) {
    assert(playerIds.length >= 4, 'Need at least 4 players');
    assert(playerIds.length <= 16, 'Maximum 16 players supported');

    final n = playerIds.length;
    final playersPerRound = (n ~/ 4) * 4; // largest multiple of 4 ≤ n
    final courtsPerRound = playersPerRound ~/ 4;
    final sitOutCount = n - playersPerRound;

    // Track how many times each pair has been partners
    final partnerCount = <String, int>{};

    String pairKey(String a, String b) {
      final sorted = [a, b]..sort();
      return '${sorted[0]}|${sorted[1]}';
    }

    void recordPartnership(String a, String b) {
      final key = pairKey(a, b);
      partnerCount[key] = (partnerCount[key] ?? 0) + 1;
    }

    int getPartnerCount(String a, String b) {
      return partnerCount[pairKey(a, b)] ?? 0;
    }

    // Generate all unique pairings using circle method
    // For n players, we need n-1 rounds (or n rounds if n is even but we
    // want everyone to play with everyone).
    final totalRounds = n - 1 + (n.isEven ? 0 : 1);

    // Use circle method to generate opponent matchups
    final rounds = <RoundPairing>[];
    final sitOutTracker = List.generate(n, (i) => 0); // times sat out

    for (int r = 0; r < totalRounds && rounds.length < totalRounds; r++) {
      // Determine who sits out this round (those who sat out least)
      List<String> activePlayers;
      if (sitOutCount > 0) {
        final indexed = List.generate(n, (i) => i);
        indexed.sort((a, b) => sitOutTracker[a].compareTo(sitOutTracker[b]));
        final sitOutIndices = indexed.sublist(n - sitOutCount).toSet();
        for (final idx in sitOutIndices) {
          sitOutTracker[idx]++;
        }
        activePlayers = [
          for (int i = 0; i < n; i++)
            if (!sitOutIndices.contains(i)) playerIds[i],
        ];
      } else {
        activePlayers = List.of(playerIds);
      }

      // Generate pairings for this round using greedy partner minimization
      final assignments = _greedyPairRound(
        activePlayers,
        courtsPerRound,
        getPartnerCount,
      );

      if (assignments == null) continue;

      // Record partnerships
      for (final court in assignments) {
        recordPartnership(court.pair.team1[0], court.pair.team1[1]);
        recordPartnership(court.pair.team2[0], court.pair.team2[1]);
      }

      rounds.add(RoundPairing(round: rounds.length + 1, courts: assignments));
    }

    return rounds;
  }

  /// Generate one Mexicano round by reseeding players based on standings.
  ///
  /// Mexicano pairs: 1st+4th vs 2nd+3rd, 5th+8th vs 6th+7th, etc.
  /// This ensures competitive balance as the tournament progresses.
  static RoundPairing generateMexicanoRound(
    List<PlayerStanding> standings,
    int roundNumber,
  ) {
    // Sort by total points descending
    final sorted = List.of(standings)
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    final courts = <CourtAssignment>[];
    int courtNum = 1;

    // Process in groups of 4: 1+4 vs 2+3
    for (int i = 0; i + 3 < sorted.length; i += 4) {
      courts.add(CourtAssignment(
        court: courtNum++,
        pair: TeamPair(
          team1: [sorted[i].playerId, sorted[i + 3].playerId],
          team2: [sorted[i + 1].playerId, sorted[i + 2].playerId],
        ),
      ));
    }

    return RoundPairing(round: roundNumber, courts: courts);
  }

  /// Greedy algorithm to pair players into teams with minimal repeat partners.
  static List<CourtAssignment>? _greedyPairRound(
    List<String> players,
    int numCourts,
    int Function(String, String) getPartnerCount,
  ) {
    if (players.length < numCourts * 4) return null;

    // Generate all possible pairs with their partner count
    final pairs = <(String, String, int)>[];
    for (int i = 0; i < players.length; i++) {
      for (int j = i + 1; j < players.length; j++) {
        pairs.add((
          players[i],
          players[j],
          getPartnerCount(players[i], players[j]),
        ));
      }
    }

    // Sort pairs by partner count (ascending — prefer fresh pairings)
    pairs.sort((a, b) => a.$3.compareTo(b.$3));

    final used = <String>{};
    final courts = <CourtAssignment>[];
    int courtNum = 1;

    // Greedily pick two non-overlapping pairs per court
    for (int ci = 0; ci < numCourts; ci++) {
      (String, String)? team1;
      (String, String)? team2;

      for (final pair in pairs) {
        if (used.contains(pair.$1) || used.contains(pair.$2)) continue;

        if (team1 == null) {
          team1 = (pair.$1, pair.$2);
          used.addAll([pair.$1, pair.$2]);
        } else if (team2 == null) {
          team2 = (pair.$1, pair.$2);
          used.addAll([pair.$1, pair.$2]);
          break;
        }
      }

      if (team1 == null || team2 == null) return null;

      courts.add(CourtAssignment(
        court: courtNum++,
        pair: TeamPair(
          team1: [team1.$1, team1.$2],
          team2: [team2.$1, team2.$2],
        ),
      ));
    }

    return courts;
  }
}
