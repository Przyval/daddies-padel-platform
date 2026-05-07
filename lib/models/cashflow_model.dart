enum CashFlowType { income, expense }

class CashFlowModel {
  final String id;
  final CashFlowType type;
  final String category;
  final int amount;
  final String? sessionId;
  final String description;
  final String recordedBy;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  const CashFlowModel({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    this.sessionId,
    required this.description,
    required this.recordedBy,
    required this.createdAt,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'category': category,
        'amount': amount,
        'sessionId': sessionId,
        'description': description,
        'recordedBy': recordedBy,
        'createdAt': createdAt.toIso8601String(),
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  factory CashFlowModel.fromJson(Map<String, dynamic> json) {
    return CashFlowModel(
      id: json['id'] as String? ?? '',
      type: _parseType(json['type']),
      category: json['category'] as String? ?? '',
      amount: _parseInt(json['amount']) ?? 0,
      sessionId: json['sessionId'] as String?,
      description: json['description'] as String? ?? '',
      recordedBy: json['recordedBy'] as String? ?? 'Unknown',
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  static CashFlowType _parseType(dynamic value) {
    if (value is String) {
      for (final t in CashFlowType.values) {
        if (t.name == value) return t;
      }
    }
    return CashFlowType.expense;
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

  CashFlowModel copyWith({
    String? id,
    CashFlowType? type,
    String? category,
    int? amount,
    String? sessionId,
    String? description,
    String? recordedBy,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) =>
      CashFlowModel(
        id: id ?? this.id,
        type: type ?? this.type,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        sessionId: sessionId ?? this.sessionId,
        description: description ?? this.description,
        recordedBy: recordedBy ?? this.recordedBy,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}
