import 'package:flutter_test/flutter_test.dart';
import 'package:daddies_app/models/cashflow_model.dart';

void main() {
  group('CashFlowModel', () {
    test('fromJson with complete data', () {
      final json = {
        'id': 'cf-1',
        'type': 'income',
        'category': 'Session Fee',
        'amount': 1200000,
        'sessionId': 'session-1',
        'description': 'Pemasukan sesi Mabar Sabtu Sore',
        'recordedBy': 'Fajar Nugroho',
        'createdAt': '2025-06-10T10:00:00.000',
      };

      final cf = CashFlowModel.fromJson(json);
      expect(cf.id, 'cf-1');
      expect(cf.type, CashFlowType.income);
      expect(cf.category, 'Session Fee');
      expect(cf.amount, 1200000);
      expect(cf.sessionId, 'session-1');
      expect(cf.description, 'Pemasukan sesi Mabar Sabtu Sore');
      expect(cf.recordedBy, 'Fajar Nugroho');
    });

    test('fromJson with null sessionId', () {
      final json = {
        'id': 'cf-1',
        'type': 'expense',
        'category': 'Equipment',
        'amount': 450000,
        'sessionId': null,
        'description': 'Bola padel',
        'recordedBy': 'Admin',
        'createdAt': '2025-06-10T10:00:00.000',
      };

      final cf = CashFlowModel.fromJson(json);
      expect(cf.type, CashFlowType.expense);
      expect(cf.sessionId, isNull);
    });

    test('fromJson with missing fields uses defaults', () {
      final cf = CashFlowModel.fromJson(<String, dynamic>{});
      expect(cf.id, '');
      expect(cf.type, CashFlowType.expense);
      expect(cf.category, '');
      expect(cf.amount, 0);
      expect(cf.description, '');
      expect(cf.recordedBy, 'Unknown');
    });

    test('fromJson with invalid type falls back to expense', () {
      final json = {
        'id': 'cf-1',
        'type': 'badType',
        'category': 'Test',
        'amount': 100,
        'description': 'Test',
        'recordedBy': 'Test',
        'createdAt': '2025-06-10T10:00:00.000',
      };

      final cf = CashFlowModel.fromJson(json);
      expect(cf.type, CashFlowType.expense);
    });

    test('fromJson handles double amount', () {
      final json = {
        'id': 'cf-1',
        'type': 'income',
        'category': 'Test',
        'amount': 500000.0,
        'description': 'Test',
        'recordedBy': 'Test',
        'createdAt': '2025-06-10T10:00:00.000',
      };

      final cf = CashFlowModel.fromJson(json);
      expect(cf.amount, 500000);
    });

    test('toJson roundtrip with sessionId', () {
      final original = CashFlowModel(
        id: 'cf-x',
        type: CashFlowType.income,
        category: 'Session Fee',
        amount: 1000000,
        sessionId: 'session-1',
        description: 'Test description',
        recordedBy: 'Admin',
        createdAt: DateTime(2025, 6, 10),
      );

      final restored = CashFlowModel.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.amount, original.amount);
      expect(restored.sessionId, original.sessionId);
    });

    test('toJson roundtrip without sessionId', () {
      final original = CashFlowModel(
        id: 'cf-x',
        type: CashFlowType.expense,
        category: 'Equipment',
        amount: 150000,
        description: 'Bola padel',
        recordedBy: 'Admin',
        createdAt: DateTime(2025, 6, 10),
      );

      final restored = CashFlowModel.fromJson(original.toJson());
      expect(restored.sessionId, isNull);
    });
  });
}
