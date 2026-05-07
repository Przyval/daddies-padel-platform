class RatingModel {
  final String id;
  final String sessionId;
  final String fromUserId;
  final String toUserId;
  final String toUserName;
  final int rating; // 1-5
  final DateTime createdAt;

  const RatingModel({
    required this.id,
    required this.sessionId,
    required this.fromUserId,
    required this.toUserId,
    required this.toUserName,
    required this.rating,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'toUserName': toUserName,
        'rating': rating,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      fromUserId: json['fromUserId'] as String? ?? '',
      toUserId: json['toUserId'] as String? ?? '',
      toUserName: json['toUserName'] as String? ?? '',
      rating: _parseInt(json['rating']) ?? 3,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  RatingModel copyWith({
    String? id,
    String? sessionId,
    String? fromUserId,
    String? toUserId,
    String? toUserName,
    int? rating,
    DateTime? createdAt,
  }) =>
      RatingModel(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        fromUserId: fromUserId ?? this.fromUserId,
        toUserId: toUserId ?? this.toUserId,
        toUserName: toUserName ?? this.toUserName,
        rating: rating ?? this.rating,
        createdAt: createdAt ?? this.createdAt,
      );
}
