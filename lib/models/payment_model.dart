enum PaymentStatus { pending, verified, rejected }

class PaymentModel {
  final String id;
  final String slotId;
  final String sessionId;
  final String userId;
  final String userName;
  final int amount;
  final String? proofImagePath;
  final PaymentStatus status;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  const PaymentModel({
    required this.id,
    required this.slotId,
    required this.sessionId,
    required this.userId,
    required this.userName,
    required this.amount,
    this.proofImagePath,
    required this.status,
    this.verifiedBy,
    this.verifiedAt,
    required this.createdAt,
    this.deletedAt,
  });

  String get statusLabel {
    switch (status) {
      case PaymentStatus.pending:
        return 'Menunggu';
      case PaymentStatus.verified:
        return 'Terverifikasi';
      case PaymentStatus.rejected:
        return 'Ditolak';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slotId': slotId,
        'sessionId': sessionId,
        'userId': userId,
        'userName': userName,
        'amount': amount,
        'proofImagePath': proofImagePath,
        'status': status.name,
        'verifiedBy': verifiedBy,
        'verifiedAt': verifiedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      slotId: json['slotId'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Unknown',
      amount: _parseInt(json['amount']) ?? 0,
      proofImagePath: json['proofImagePath'] as String?,
      status: _parseStatus(json['status']),
      verifiedBy: json['verifiedBy'] as String?,
      verifiedAt: _parseDateTime(json['verifiedAt']),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  static PaymentStatus _parseStatus(dynamic value) {
    if (value is String) {
      for (final s in PaymentStatus.values) {
        if (s.name == value) return s;
      }
    }
    return PaymentStatus.pending;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  PaymentModel copyWith({
    String? id,
    String? slotId,
    String? sessionId,
    String? userId,
    String? userName,
    int? amount,
    String? proofImagePath,
    PaymentStatus? status,
    String? verifiedBy,
    DateTime? verifiedAt,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) =>
      PaymentModel(
        id: id ?? this.id,
        slotId: slotId ?? this.slotId,
        sessionId: sessionId ?? this.sessionId,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        amount: amount ?? this.amount,
        proofImagePath: proofImagePath ?? this.proofImagePath,
        status: status ?? this.status,
        verifiedBy: verifiedBy ?? this.verifiedBy,
        verifiedAt: verifiedAt ?? this.verifiedAt,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}
