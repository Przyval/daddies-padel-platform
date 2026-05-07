enum SlotStatus { registered, waitlist, confirmed, paid, locked }

class SlotModel {
  final String id;
  final String sessionId;
  final String userId;
  final String userName;
  final SlotStatus status;
  final DateTime joinedAt;
  final DateTime? confirmedAt;
  final DateTime? attendedAt; // Set when Mimin marks attendance
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  const SlotModel({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.userName,
    required this.status,
    required this.joinedAt,
    this.confirmedAt,
    this.attendedAt,
    this.deletedAt,
  });

  bool get didAttend => attendedAt != null;

  String get statusLabel {
    switch (status) {
      case SlotStatus.registered:
        return 'Registered';
      case SlotStatus.waitlist:
        return 'Waitlist';
      case SlotStatus.confirmed:
        return 'Confirmed';
      case SlotStatus.paid:
        return 'Paid';
      case SlotStatus.locked:
        return 'Locked';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'userId': userId,
        'userName': userName,
        'status': status.name,
        'joinedAt': joinedAt.toIso8601String(),
        'confirmedAt': confirmedAt?.toIso8601String(),
        if (attendedAt != null) 'attendedAt': attendedAt!.toIso8601String(),
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Unknown',
      status: _parseStatus(json['status']),
      joinedAt: _parseDateTime(json['joinedAt']) ?? DateTime.now(),
      confirmedAt: _parseDateTime(json['confirmedAt']),
      attendedAt: _parseDateTime(json['attendedAt']),
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  static SlotStatus _parseStatus(dynamic value) {
    if (value is String) {
      for (final s in SlotStatus.values) {
        if (s.name == value) return s;
      }
    }
    return SlotStatus.registered;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  SlotModel copyWith({
    String? id,
    String? sessionId,
    String? userId,
    String? userName,
    SlotStatus? status,
    DateTime? joinedAt,
    DateTime? confirmedAt,
    DateTime? attendedAt,
    DateTime? deletedAt,
  }) =>
      SlotModel(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        status: status ?? this.status,
        joinedAt: joinedAt ?? this.joinedAt,
        confirmedAt: confirmedAt ?? this.confirmedAt,
        attendedAt: attendedAt ?? this.attendedAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}
