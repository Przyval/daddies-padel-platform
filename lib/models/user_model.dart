enum UserRole { superAdmin, mimin, bendahara, member }

enum SkillLevel { pemula, menengah, mahir, pro }

class UserModel {
  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final DateTime createdAt;
  final String? avatarUrl;
  final String? bio;
  final String? nickname;
  final SkillLevel skillLevel;
  final String? memberNumber; // KTA number, e.g. 'DDS-001'
  final int chipsBalance; // Daddies Chips balance (denormalized)
  final String? referralCode; // Personal referral code, e.g. 'ALI-DDS-X7K2'
  final String? referredBy; // Referral code used when joining
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.avatarUrl,
    this.bio,
    this.nickname,
    this.skillLevel = SkillLevel.pemula,
    this.memberNumber,
    this.chipsBalance = 0,
    this.referralCode,
    this.referredBy,
    this.deletedAt,
  });

  String get roleLabel {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.mimin:
        return 'Mimin';
      case UserRole.bendahara:
        return 'Bendahara';
      case UserRole.member:
        return 'Member';
    }
  }

  String get skillLevelLabel {
    switch (skillLevel) {
      case SkillLevel.pemula:
        return 'Pemula';
      case SkillLevel.menengah:
        return 'Menengah';
      case SkillLevel.mahir:
        return 'Mahir';
      case SkillLevel.pro:
        return 'Pro';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (bio != null) 'bio': bio,
        if (nickname != null) 'nickname': nickname,
        'skillLevel': skillLevel.name,
        if (memberNumber != null) 'memberNumber': memberNumber,
        'chipsBalance': chipsBalance,
        if (referralCode != null) 'referralCode': referralCode,
        if (referredBy != null) 'referredBy': referredBy,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      phone: json['phone'] as String? ?? '',
      role: _parseRole(json['role']),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      nickname: json['nickname'] as String?,
      skillLevel: _parseSkillLevel(json['skillLevel']),
      memberNumber: json['memberNumber'] as String?,
      chipsBalance: _parseInt(json['chipsBalance']) ?? 0,
      referralCode: json['referralCode'] as String?,
      referredBy: json['referredBy'] as String?,
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  static UserRole _parseRole(dynamic value) {
    if (value is String) {
      for (final r in UserRole.values) {
        if (r.name == value) return r;
      }
    }
    return UserRole.member;
  }

  static SkillLevel _parseSkillLevel(dynamic value) {
    if (value is String) {
      for (final s in SkillLevel.values) {
        if (s.name == value) return s;
      }
    }
    return SkillLevel.pemula;
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

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    UserRole? role,
    DateTime? createdAt,
    String? avatarUrl,
    String? bio,
    String? nickname,
    SkillLevel? skillLevel,
    String? memberNumber,
    int? chipsBalance,
    String? referralCode,
    String? referredBy,
    DateTime? deletedAt,
  }) =>
      UserModel(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        createdAt: createdAt ?? this.createdAt,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        nickname: nickname ?? this.nickname,
        skillLevel: skillLevel ?? this.skillLevel,
        memberNumber: memberNumber ?? this.memberNumber,
        chipsBalance: chipsBalance ?? this.chipsBalance,
        referralCode: referralCode ?? this.referralCode,
        referredBy: referredBy ?? this.referredBy,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}
