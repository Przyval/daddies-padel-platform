enum ChipsTransactionType { earned, spent, bonus, adjustment }

enum ChipsSource {
  sessionAttendance,  // +10
  matchWin,           // +5
  matchDraw,          // +2
  streak3,            // +15
  streak5,            // +30
  ratingGiven,        // +2
  firstSession,       // +20
  stakeWin,           // variable
  stakeLoss,          // variable (negative)
  redemption,         // negative
  adminAdjust,        // variable
  welcomeBonus,       // +25 (signup welcome)
  referralBonus,      // +50 referrer, +20 referee
}

class ChipsTransactionModel {
  final String id;
  final String userId;
  final String userName;
  final int amount; // signed: positive = earned, negative = spent
  final int balanceAfter;
  final ChipsTransactionType type;
  final ChipsSource source;
  final String description;
  final String? sessionId;
  final String? matchResultId;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  const ChipsTransactionModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.amount,
    required this.balanceAfter,
    required this.type,
    required this.source,
    required this.description,
    this.sessionId,
    this.matchResultId,
    required this.createdAt,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'amount': amount,
    'balanceAfter': balanceAfter,
    'type': type.name,
    'source': source.name,
    'description': description,
    if (sessionId != null) 'sessionId': sessionId,
    if (matchResultId != null) 'matchResultId': matchResultId,
    'createdAt': createdAt.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };

  factory ChipsTransactionModel.fromJson(Map<String, dynamic> json) {
    return ChipsTransactionModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      amount: _parseInt(json['amount']) ?? 0,
      balanceAfter: _parseInt(json['balanceAfter']) ?? 0,
      type: _parseType(json['type']),
      source: _parseSource(json['source']),
      description: json['description'] as String? ?? '',
      sessionId: json['sessionId'] as String?,
      matchResultId: json['matchResultId'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  static ChipsTransactionType _parseType(dynamic value) {
    if (value is String) {
      for (final t in ChipsTransactionType.values) {
        if (t.name == value) return t;
      }
    }
    return ChipsTransactionType.earned;
  }

  static ChipsSource _parseSource(dynamic value) {
    if (value is String) {
      for (final s in ChipsSource.values) {
        if (s.name == value) return s;
      }
    }
    return ChipsSource.adminAdjust;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  ChipsTransactionModel copyWith({
    String? id,
    String? userId,
    String? userName,
    int? amount,
    int? balanceAfter,
    ChipsTransactionType? type,
    ChipsSource? source,
    String? description,
    String? sessionId,
    String? matchResultId,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) => ChipsTransactionModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    userName: userName ?? this.userName,
    amount: amount ?? this.amount,
    balanceAfter: balanceAfter ?? this.balanceAfter,
    type: type ?? this.type,
    source: source ?? this.source,
    description: description ?? this.description,
    sessionId: sessionId ?? this.sessionId,
    matchResultId: matchResultId ?? this.matchResultId,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  /// Chips value for each fixed-amount source type.
  static int chipsForSource(ChipsSource source) {
    return switch (source) {
      ChipsSource.sessionAttendance => 10,
      ChipsSource.matchWin => 5,
      ChipsSource.matchDraw => 2,
      ChipsSource.streak3 => 15,
      ChipsSource.streak5 => 30,
      ChipsSource.ratingGiven => 2,
      ChipsSource.firstSession => 20,
      ChipsSource.welcomeBonus => 25,
      _ => 0, // variable amounts
    };
  }
}
