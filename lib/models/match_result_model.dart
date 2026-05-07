/// A single match result within an Americano-style session.
///
/// Each session can have multiple rounds. In each round, two teams
/// of two players face off. Scores are tracked per team, and
/// individual points are derived from team performance.
class MatchResultModel {
  final String id;
  final String sessionId;
  final int round;

  /// Team 1 player user IDs.
  final List<String> team1PlayerIds;

  /// Team 1 player names (denormalized for display).
  final List<String> team1PlayerNames;

  /// Team 2 player user IDs.
  final List<String> team2PlayerIds;

  /// Team 2 player names (denormalized for display).
  final List<String> team2PlayerNames;

  /// Score for team 1.
  final int team1Score;

  /// Score for team 2.
  final int team2Score;

  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  const MatchResultModel({
    required this.id,
    required this.sessionId,
    required this.round,
    required this.team1PlayerIds,
    required this.team1PlayerNames,
    required this.team2PlayerIds,
    required this.team2PlayerNames,
    required this.team1Score,
    required this.team2Score,
    required this.createdAt,
    this.deletedAt,
  });

  /// Determines the winning team (1, 2, or 0 for draw).
  int get winningTeam {
    if (team1Score > team2Score) return 1;
    if (team2Score > team1Score) return 2;
    return 0;
  }

  /// Returns the list of user IDs on the winning team.
  List<String> get winnerIds {
    if (winningTeam == 1) return team1PlayerIds;
    if (winningTeam == 2) return team2PlayerIds;
    return [];
  }

  /// Returns the list of user IDs on the losing team.
  List<String> get loserIds {
    if (winningTeam == 1) return team2PlayerIds;
    if (winningTeam == 2) return team1PlayerIds;
    return [];
  }

  /// All player IDs in this match.
  List<String> get allPlayerIds => [...team1PlayerIds, ...team2PlayerIds];

  /// Points earned by a specific player (their team's score).
  int pointsFor(String userId) {
    if (team1PlayerIds.contains(userId)) return team1Score;
    if (team2PlayerIds.contains(userId)) return team2Score;
    return 0;
  }

  /// Whether the given user won this match.
  bool didWin(String userId) => winnerIds.contains(userId);

  /// Whether the given user lost this match.
  bool didLose(String userId) => loserIds.contains(userId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'round': round,
        'team1PlayerIds': team1PlayerIds,
        'team1PlayerNames': team1PlayerNames,
        'team2PlayerIds': team2PlayerIds,
        'team2PlayerNames': team2PlayerNames,
        'team1Score': team1Score,
        'team2Score': team2Score,
        'createdAt': createdAt.toIso8601String(),
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  factory MatchResultModel.fromJson(Map<String, dynamic> json) {
    return MatchResultModel(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      round: _parseInt(json['round']) ?? 1,
      team1PlayerIds: _parseStringList(json['team1PlayerIds']),
      team1PlayerNames: _parseStringList(json['team1PlayerNames']),
      team2PlayerIds: _parseStringList(json['team2PlayerIds']),
      team2PlayerNames: _parseStringList(json['team2PlayerNames']),
      team1Score: _parseInt(json['team1Score']) ?? 0,
      team2Score: _parseInt(json['team2Score']) ?? 0,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  MatchResultModel copyWith({
    String? id,
    String? sessionId,
    int? round,
    List<String>? team1PlayerIds,
    List<String>? team1PlayerNames,
    List<String>? team2PlayerIds,
    List<String>? team2PlayerNames,
    int? team1Score,
    int? team2Score,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) =>
      MatchResultModel(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        round: round ?? this.round,
        team1PlayerIds: team1PlayerIds ?? this.team1PlayerIds,
        team1PlayerNames: team1PlayerNames ?? this.team1PlayerNames,
        team2PlayerIds: team2PlayerIds ?? this.team2PlayerIds,
        team2PlayerNames: team2PlayerNames ?? this.team2PlayerNames,
        team1Score: team1Score ?? this.team1Score,
        team2Score: team2Score ?? this.team2Score,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );

  static List<String> _parseStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
