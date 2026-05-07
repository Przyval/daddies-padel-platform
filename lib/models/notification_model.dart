enum NotificationType {
  sessionCreated,
  paymentVerified,
  paymentRejected,
  sessionLocked,
  sessionCompleted,
  sessionCancelled,
  waitlistPromoted,
  sessionInvite,
  reminder,
  general,
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? sessionId;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.sessionId,
    required this.createdAt,
    this.isRead = false,
    this.deletedAt,
  });

  NotificationModel copyWith({bool? isRead, DateTime? deletedAt}) {
    return NotificationModel(
      id: id,
      title: title,
      body: body,
      type: type,
      sessionId: sessionId,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'sessionId': sessionId,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: _parseType(json['type']),
      sessionId: json['sessionId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
    );
  }

  static NotificationType _parseType(dynamic value) {
    if (value is String) {
      return NotificationType.values.where((e) => e.name == value).firstOrNull ??
          NotificationType.general;
    }
    return NotificationType.general;
  }
}
