class VenueModel {
  final String id;
  final String name;
  final String address;
  final String bio;
  final String? imageUrl;
  final String? phone;
  final List<String> facilities;
  final String? mapUrl;
  final int courtCount;
  final String openHours;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  const VenueModel({
    required this.id,
    required this.name,
    required this.address,
    required this.bio,
    this.imageUrl,
    this.phone,
    this.facilities = const [],
    this.mapUrl,
    this.courtCount = 1,
    this.openHours = '06:00 - 22:00',
    this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'bio': bio,
        'imageUrl': imageUrl,
        'phone': phone,
        'facilities': facilities,
        'mapUrl': mapUrl,
        'courtCount': courtCount,
        'openHours': openHours,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    return VenueModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      phone: json['phone'] as String?,
      facilities: (json['facilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mapUrl: json['mapUrl'] as String?,
      courtCount: _parseInt(json['courtCount']) ?? 1,
      openHours: json['openHours'] as String? ?? '06:00 - 22:00',
      deletedAt: _parseDateTime(json['deletedAt']),
    );
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

  VenueModel copyWith({
    String? id,
    String? name,
    String? address,
    String? bio,
    String? imageUrl,
    String? phone,
    List<String>? facilities,
    String? mapUrl,
    int? courtCount,
    String? openHours,
    DateTime? deletedAt,
  }) =>
      VenueModel(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        bio: bio ?? this.bio,
        imageUrl: imageUrl ?? this.imageUrl,
        phone: phone ?? this.phone,
        facilities: facilities ?? this.facilities,
        mapUrl: mapUrl ?? this.mapUrl,
        courtCount: courtCount ?? this.courtCount,
        openHours: openHours ?? this.openHours,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}
