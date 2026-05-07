import 'package:daddies_app/models/kta_tier.dart';

/// A partner/tenant that offers discounts to Dedis members.
class PartnerModel {
  final String id;
  final String name;
  final String? logoUrl;
  final String category; // e.g. 'Physio', 'F&B', 'Sports Equipment'
  final int discountPercent;
  final String discountDescription; // e.g. 'Diskon 10% untuk semua treatment'
  final String? address;
  final String? phone;
  final String? website;
  final bool isActive;
  final KtaTier? minimumTier; // null = all tiers allowed
  final int? chipsPrice; // cost in chips for redemption
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  const PartnerModel({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.category,
    required this.discountPercent,
    required this.discountDescription,
    this.address,
    this.phone,
    this.website,
    this.isActive = true,
    this.minimumTier,
    this.chipsPrice,
    required this.createdAt,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (logoUrl != null) 'logoUrl': logoUrl,
        'category': category,
        'discountPercent': discountPercent,
        'discountDescription': discountDescription,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (website != null) 'website': website,
        'isActive': isActive,
        if (minimumTier != null) 'minimumTier': minimumTier!.name,
        if (chipsPrice != null) 'chipsPrice': chipsPrice,
        'createdAt': createdAt.toIso8601String(),
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  factory PartnerModel.fromJson(Map<String, dynamic> json) {
    return PartnerModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      category: json['category'] as String? ?? 'Lainnya',
      discountPercent: _parseInt(json['discountPercent']) ?? 0,
      discountDescription: json['discountDescription'] as String? ?? '',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      minimumTier: parseTier(json['minimumTier'] as String?),
      chipsPrice: _parseInt(json['chipsPrice']),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  PartnerModel copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? category,
    int? discountPercent,
    String? discountDescription,
    String? address,
    String? phone,
    String? website,
    bool? isActive,
    KtaTier? minimumTier,
    int? chipsPrice,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) =>
      PartnerModel(
        id: id ?? this.id,
        name: name ?? this.name,
        logoUrl: logoUrl ?? this.logoUrl,
        category: category ?? this.category,
        discountPercent: discountPercent ?? this.discountPercent,
        discountDescription: discountDescription ?? this.discountDescription,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        website: website ?? this.website,
        isActive: isActive ?? this.isActive,
        minimumTier: minimumTier ?? this.minimumTier,
        chipsPrice: chipsPrice ?? this.chipsPrice,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );

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
