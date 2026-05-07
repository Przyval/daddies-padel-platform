enum RedemptionStatus { pending, used, expired, cancelled }

class RedemptionModel {
  final String id;
  final String userId;
  final String userName;
  final String partnerId;
  final String partnerName;
  final int chipsSpent;
  final String discountDescription;
  final RedemptionStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final String? verifiedBy;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  const RedemptionModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.partnerId,
    required this.partnerName,
    required this.chipsSpent,
    required this.discountDescription,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.usedAt,
    this.verifiedBy,
    this.deletedAt,
  });

  String get statusLabel => switch (status) {
    RedemptionStatus.pending => 'Aktif',
    RedemptionStatus.used => 'Digunakan',
    RedemptionStatus.expired => 'Kedaluwarsa',
    RedemptionStatus.cancelled => 'Dibatalkan',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'partnerId': partnerId,
    'partnerName': partnerName,
    'chipsSpent': chipsSpent,
    'discountDescription': discountDescription,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    if (usedAt != null) 'usedAt': usedAt!.toIso8601String(),
    if (verifiedBy != null) 'verifiedBy': verifiedBy,
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };

  factory RedemptionModel.fromJson(Map<String, dynamic> json) {
    return RedemptionModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      partnerId: json['partnerId'] as String? ?? '',
      partnerName: json['partnerName'] as String? ?? '',
      chipsSpent: _parseInt(json['chipsSpent']) ?? 0,
      discountDescription: json['discountDescription'] as String? ?? '',
      status: _parseStatus(json['status']),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      expiresAt: _parseDateTime(json['expiresAt']) ?? DateTime.now().add(const Duration(days: 30)),
      usedAt: _parseDateTime(json['usedAt']),
      verifiedBy: json['verifiedBy'] as String?,
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  static RedemptionStatus _parseStatus(dynamic value) {
    if (value is String) {
      for (final s in RedemptionStatus.values) {
        if (s.name == value) return s;
      }
    }
    return RedemptionStatus.pending;
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

  RedemptionModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? partnerId,
    String? partnerName,
    int? chipsSpent,
    String? discountDescription,
    RedemptionStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? usedAt,
    String? verifiedBy,
    DateTime? deletedAt,
  }) => RedemptionModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    userName: userName ?? this.userName,
    partnerId: partnerId ?? this.partnerId,
    partnerName: partnerName ?? this.partnerName,
    chipsSpent: chipsSpent ?? this.chipsSpent,
    discountDescription: discountDescription ?? this.discountDescription,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    usedAt: usedAt ?? this.usedAt,
    verifiedBy: verifiedBy ?? this.verifiedBy,
    deletedAt: deletedAt ?? this.deletedAt,
  );
}
