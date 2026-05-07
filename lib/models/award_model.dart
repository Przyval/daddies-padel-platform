enum AwardType {
  rookieOfMonth,
  loyalOne,
  mostImproved,
  topAttendance,
  topSpender,
  mvp,
  spiritAward,
}

class AwardModel {
  final String id;
  final String userId;
  final String userName;
  final AwardType type;
  final String period; // e.g. "2026-Q1", "2026-02"
  final int value; // e.g. session count, chips spent
  final String description;
  final String? sessionId;
  final String? grantedBy; // admin who granted manual awards
  final DateTime awardedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  const AwardModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    required this.period,
    required this.value,
    required this.description,
    this.sessionId,
    this.grantedBy,
    required this.awardedAt,
    this.deletedAt,
  });

  String get typeLabel => switch (type) {
    AwardType.rookieOfMonth => 'Rookie of the Month',
    AwardType.loyalOne => 'The Loyal One',
    AwardType.mostImproved => 'Most Improved',
    AwardType.topAttendance => 'Top Attendance',
    AwardType.topSpender => 'Top Spender',
    AwardType.mvp => 'MVP',
    AwardType.spiritAward => 'Spirit Award',
  };

  String get typeEmoji => switch (type) {
    AwardType.rookieOfMonth => '🌟',
    AwardType.loyalOne => '💎',
    AwardType.mostImproved => '📈',
    AwardType.topAttendance => '🏆',
    AwardType.topSpender => '💰',
    AwardType.mvp => '⭐',
    AwardType.spiritAward => '🤝',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'type': type.name,
    'period': period,
    'value': value,
    'description': description,
    if (sessionId != null) 'sessionId': sessionId,
    if (grantedBy != null) 'grantedBy': grantedBy,
    'awardedAt': awardedAt.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };

  factory AwardModel.fromJson(Map<String, dynamic> json) {
    return AwardModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      type: _parseType(json['type']),
      period: json['period'] as String? ?? '',
      value: _parseInt(json['value']) ?? 0,
      description: json['description'] as String? ?? '',
      sessionId: json['sessionId'] as String?,
      grantedBy: json['grantedBy'] as String?,
      awardedAt: _parseDateTime(json['awardedAt']) ?? DateTime.now(),
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  static AwardType _parseType(dynamic value) {
    if (value is String) {
      for (final t in AwardType.values) {
        if (t.name == value) return t;
      }
    }
    return AwardType.spiritAward;
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

  AwardModel copyWith({
    String? id,
    String? userId,
    String? userName,
    AwardType? type,
    String? period,
    int? value,
    String? description,
    String? sessionId,
    String? grantedBy,
    DateTime? awardedAt,
    DateTime? deletedAt,
  }) => AwardModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    userName: userName ?? this.userName,
    type: type ?? this.type,
    period: period ?? this.period,
    value: value ?? this.value,
    description: description ?? this.description,
    sessionId: sessionId ?? this.sessionId,
    grantedBy: grantedBy ?? this.grantedBy,
    awardedAt: awardedAt ?? this.awardedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );
}
