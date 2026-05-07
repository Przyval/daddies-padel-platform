enum SessionStatus { draft, open, full, locked, completed, cancelled }

class SessionModel {
  final String id;
  final String miminId;
  final String miminName;
  final String title;
  final String venue;
  final DateTime date;
  final String timeStart;
  final String timeEnd;
  final int maxPlayers;
  final int pricePerPlayer;
  final SessionStatus status;
  final DateTime createdAt;
  final String? notes;
  final int? courtNumber;
  final String? cancellationReason;
  final List<String> photoUrls;
  final DateTime? deletedAt;

  /// Match format: 'americano', 'mexicano', or null (manual).
  final String? matchFormat;

  /// Player IDs explicitly invited to this session.
  final List<String> invitedPlayerIds;

  /// Whether Daddies Chips staking is enabled for this session.
  final bool stakingEnabled;

  /// Chips stake amount per player (only used if stakingEnabled).
  final int stakeAmount;

  bool get isDeleted => deletedAt != null;

  const SessionModel({
    required this.id,
    required this.miminId,
    required this.miminName,
    required this.title,
    required this.venue,
    required this.date,
    required this.timeStart,
    required this.timeEnd,
    required this.maxPlayers,
    required this.pricePerPlayer,
    required this.status,
    required this.createdAt,
    this.notes,
    this.courtNumber,
    this.cancellationReason,
    this.photoUrls = const [],
    this.deletedAt,
    this.matchFormat,
    this.invitedPlayerIds = const [],
    this.stakingEnabled = false,
    this.stakeAmount = 0,
  });

  String get statusLabel {
    switch (status) {
      case SessionStatus.draft:
        return 'Draft';
      case SessionStatus.open:
        return 'Open';
      case SessionStatus.full:
        return 'Full';
      case SessionStatus.locked:
        return 'Locked';
      case SessionStatus.completed:
        return 'Selesai';
      case SessionStatus.cancelled:
        return 'Batal';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'miminId': miminId,
        'miminName': miminName,
        'title': title,
        'venue': venue,
        'date': date.toIso8601String(),
        'timeStart': timeStart,
        'timeEnd': timeEnd,
        'maxPlayers': maxPlayers,
        'pricePerPlayer': pricePerPlayer,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        if (notes != null) 'notes': notes,
        if (courtNumber != null) 'courtNumber': courtNumber,
        if (cancellationReason != null)
          'cancellationReason': cancellationReason,
        if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
        if (matchFormat != null) 'matchFormat': matchFormat,
        if (invitedPlayerIds.isNotEmpty) 'invitedPlayerIds': invitedPlayerIds,
        if (stakingEnabled) 'stakingEnabled': stakingEnabled,
        if (stakeAmount > 0) 'stakeAmount': stakeAmount,
      };

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as String? ?? '',
      miminId: json['miminId'] as String? ?? '',
      miminName: json['miminName'] as String? ?? 'Unknown',
      title: json['title'] as String? ?? 'Untitled Session',
      venue: json['venue'] as String? ?? '',
      date: _parseDateTime(json['date']) ?? DateTime.now(),
      timeStart: json['timeStart'] as String? ?? '00:00',
      timeEnd: json['timeEnd'] as String? ?? '00:00',
      maxPlayers: _parseInt(json['maxPlayers']) ?? 8,
      pricePerPlayer: _parseInt(json['pricePerPlayer']) ?? 0,
      status: _parseStatus(json['status']),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      notes: json['notes'] as String?,
      courtNumber: _parseInt(json['courtNumber']),
      cancellationReason: json['cancellationReason'] as String?,
      photoUrls: (json['photoUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      deletedAt: _parseDateTime(json['deletedAt']),
      matchFormat: json['matchFormat'] as String?,
      invitedPlayerIds: (json['invitedPlayerIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      stakingEnabled: json['stakingEnabled'] as bool? ?? false,
      stakeAmount: _parseInt(json['stakeAmount']) ?? 0,
    );
  }

  static SessionStatus _parseStatus(dynamic value) {
    if (value is String) {
      for (final s in SessionStatus.values) {
        if (s.name == value) return s;
      }
    }
    return SessionStatus.draft;
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

  SessionModel copyWith({
    String? id,
    String? miminId,
    String? miminName,
    String? title,
    String? venue,
    DateTime? date,
    String? timeStart,
    String? timeEnd,
    int? maxPlayers,
    int? pricePerPlayer,
    SessionStatus? status,
    DateTime? createdAt,
    String? notes,
    int? courtNumber,
    String? cancellationReason,
    List<String>? photoUrls,
    DateTime? deletedAt,
    String? matchFormat,
    List<String>? invitedPlayerIds,
    bool? stakingEnabled,
    int? stakeAmount,
  }) =>
      SessionModel(
        id: id ?? this.id,
        miminId: miminId ?? this.miminId,
        miminName: miminName ?? this.miminName,
        title: title ?? this.title,
        venue: venue ?? this.venue,
        date: date ?? this.date,
        timeStart: timeStart ?? this.timeStart,
        timeEnd: timeEnd ?? this.timeEnd,
        maxPlayers: maxPlayers ?? this.maxPlayers,
        pricePerPlayer: pricePerPlayer ?? this.pricePerPlayer,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        notes: notes ?? this.notes,
        courtNumber: courtNumber ?? this.courtNumber,
        cancellationReason: cancellationReason ?? this.cancellationReason,
        photoUrls: photoUrls ?? this.photoUrls,
        deletedAt: deletedAt ?? this.deletedAt,
        matchFormat: matchFormat ?? this.matchFormat,
        invitedPlayerIds: invitedPlayerIds ?? this.invitedPlayerIds,
        stakingEnabled: stakingEnabled ?? this.stakingEnabled,
        stakeAmount: stakeAmount ?? this.stakeAmount,
      );
}
