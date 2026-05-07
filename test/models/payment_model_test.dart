import 'package:flutter_test/flutter_test.dart';
import 'package:daddies_app/models/payment_model.dart';

void main() {
  group('PaymentModel', () {
    test('fromJson with complete data', () {
      final json = {
        'id': 'pay-1a',
        'slotId': 'slot-1a',
        'sessionId': 'session-1',
        'userId': 'user-arif',
        'userName': 'Arif Budiman',
        'amount': 150000,
        'proofImagePath': 'https://example.com/proof.jpg',
        'status': 'verified',
        'verifiedBy': 'Fajar Nugroho',
        'verifiedAt': '2025-06-11T12:00:00.000',
        'createdAt': '2025-06-10T10:00:00.000',
      };

      final payment = PaymentModel.fromJson(json);
      expect(payment.id, 'pay-1a');
      expect(payment.amount, 150000);
      expect(payment.status, PaymentStatus.verified);
      expect(payment.verifiedBy, 'Fajar Nugroho');
      expect(payment.verifiedAt, isNotNull);
      expect(payment.proofImagePath, 'https://example.com/proof.jpg');
    });

    test('fromJson with null optional fields', () {
      final json = {
        'id': 'pay-1',
        'slotId': 'slot-1',
        'sessionId': 'session-1',
        'userId': 'user-1',
        'userName': 'Test',
        'amount': 100000,
        'proofImagePath': null,
        'status': 'pending',
        'verifiedBy': null,
        'verifiedAt': null,
        'createdAt': '2025-06-10T10:00:00.000',
      };

      final payment = PaymentModel.fromJson(json);
      expect(payment.status, PaymentStatus.pending);
      expect(payment.proofImagePath, isNull);
      expect(payment.verifiedBy, isNull);
      expect(payment.verifiedAt, isNull);
    });

    test('fromJson with missing fields uses defaults', () {
      final payment = PaymentModel.fromJson(<String, dynamic>{});
      expect(payment.id, '');
      expect(payment.userName, 'Unknown');
      expect(payment.amount, 0);
      expect(payment.status, PaymentStatus.pending);
    });

    test('fromJson with invalid status falls back to pending', () {
      final json = {
        'id': 'pay-1',
        'slotId': 'slot-1',
        'sessionId': 'session-1',
        'userId': 'user-1',
        'userName': 'Test',
        'amount': 100000,
        'status': 'badStatus',
        'createdAt': '2025-06-10T10:00:00.000',
      };

      final payment = PaymentModel.fromJson(json);
      expect(payment.status, PaymentStatus.pending);
    });

    test('fromJson handles double amount from Firestore', () {
      final json = {
        'id': 'pay-1',
        'slotId': 'slot-1',
        'sessionId': 'session-1',
        'userId': 'user-1',
        'userName': 'Test',
        'amount': 150000.0,
        'status': 'pending',
        'createdAt': '2025-06-10T10:00:00.000',
      };

      final payment = PaymentModel.fromJson(json);
      expect(payment.amount, 150000);
    });

    test('toJson roundtrip', () {
      final original = PaymentModel(
        id: 'pay-x',
        slotId: 'slot-x',
        sessionId: 'session-x',
        userId: 'user-x',
        userName: 'Test User',
        amount: 200000,
        proofImagePath: 'https://example.com/proof.jpg',
        status: PaymentStatus.verified,
        verifiedBy: 'Admin',
        verifiedAt: DateTime(2025, 6, 12),
        createdAt: DateTime(2025, 6, 10),
      );

      final restored = PaymentModel.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.amount, original.amount);
      expect(restored.status, original.status);
      expect(restored.verifiedBy, original.verifiedBy);
      expect(restored.proofImagePath, original.proofImagePath);
    });

    test('copyWith creates modified copy', () {
      final payment = PaymentModel(
        id: 'pay-1',
        slotId: 'slot-1',
        sessionId: 'session-1',
        userId: 'user-1',
        userName: 'Test',
        amount: 100000,
        status: PaymentStatus.pending,
        createdAt: DateTime(2025, 6, 10),
      );

      final updated = payment.copyWith(
        status: PaymentStatus.verified,
        verifiedBy: 'Admin',
        verifiedAt: DateTime(2025, 6, 12),
      );
      expect(updated.status, PaymentStatus.verified);
      expect(updated.verifiedBy, 'Admin');
      expect(updated.amount, 100000);
    });

    test('statusLabel returns correct labels', () {
      PaymentModel makePayment(PaymentStatus s) => PaymentModel(
            id: '',
            slotId: '',
            sessionId: '',
            userId: '',
            userName: '',
            amount: 0,
            status: s,
            createdAt: DateTime.now(),
          );

      expect(makePayment(PaymentStatus.pending).statusLabel, 'Menunggu');
      expect(makePayment(PaymentStatus.verified).statusLabel, 'Terverifikasi');
      expect(makePayment(PaymentStatus.rejected).statusLabel, 'Ditolak');
    });
  });
}
