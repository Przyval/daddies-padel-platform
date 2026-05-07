enum ReferralStatus { pending, completed, expired }

class ReferralModel {
  final String id;
  final String referrerId;
  final String referrerName;
  final String? refereeId;
  final String? refereeName;
  final String referralCode;
  final ReferralStatus status;
  final int referrerBonus; // chips awarded to referrer
  final int refereeBonus; // chips awarded to referee
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  static const int defaultReferrerBonus = 50;
  static const int defaultRefereeBonus = 20;

  const ReferralModel({
    required this.id,
    required this.referrerId,
    required this.referrerName,
    this.refereeId,
    this.refereeName,
    required this.referralCode,
    required this.status,
    this.referrerBonus = defaultReferrerBonus,
    this.refereeBonus = defaultRefereeBonus,
    required this.createdAt,
    this.completedAt,
    this.deletedAt,
  });

  String get statusLabel => switch (status) {
    ReferralStatus.pending => 'Menunggu',
    ReferralStatus.completed => 'Selesai',
    ReferralStatus.expired => 'Kedaluwarsa',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'referrerId': referrerId,
    'referrerName': referrerName,
    if (refereeId != null) 'refereeId': refereeId,
    if (refereeName != null) 'refereeName': refereeName,
    'referralCode': referralCode,
    'status': status.name,
    'referrerBonus': referrerBonus,
    'refereeBonus': refereeBonus,
    'createdAt': createdAt.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };

  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      id: json['id'] as String? ?? '',
      referrerId: json['referrerId'] as String? ?? '',
      referrerName: json['referrerName'] as String? ?? '',
      refereeId: json['refereeId'] as String?,
      refereeName: json['refereeName'] as String?,
      referralCode: json['referralCode'] as String? ?? '',
      status: _parseStatus(json['status']),
      referrerBonus: _parseInt(json['referrerBonus']) ?? defaultReferrerBonus,
      refereeBonus: _parseInt(json['refereeBonus']) ?? defaultRefereeBonus,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      completedAt: _parseDateTime(json['completedAt']),
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  static ReferralStatus _parseStatus(dynamic value) {
    if (value is String) {
      for (final s in ReferralStatus.values) {
        if (s.name == value) return s;
      }
    }
    return ReferralStatus.pending;
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

  ReferralModel copyWith({
    String? id,
    String? referrerId,
    String? referrerName,
    String? refereeId,
    String? refereeName,
    String? referralCode,
    ReferralStatus? status,
    int? referrerBonus,
    int? refereeBonus,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? deletedAt,
  }) => ReferralModel(
    id: id ?? this.id,
    referrerId: referrerId ?? this.referrerId,
    referrerName: referrerName ?? this.referrerName,
    refereeId: refereeId ?? this.refereeId,
    refereeName: refereeName ?? this.refereeName,
    referralCode: referralCode ?? this.referralCode,
    status: status ?? this.status,
    referrerBonus: referrerBonus ?? this.referrerBonus,
    refereeBonus: refereeBonus ?? this.refereeBonus,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt ?? this.completedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );
}
