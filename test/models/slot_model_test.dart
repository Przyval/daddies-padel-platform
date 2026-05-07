import 'package:flutter_test/flutter_test.dart';
import 'package:daddies_app/models/slot_model.dart';

void main() {
  group('SlotModel', () {
    test('fromJson with complete data', () {
      final json = {
        'id': 'slot-1a',
        'sessionId': 'session-1',
        'userId': 'user-arif',
        'userName': 'Arif Budiman',
        'status': 'confirmed',
        'joinedAt': '2025-06-10T10:00:00.000',
        'confirmedAt': '2025-06-11T08:00:00.000',
      };

      final slot = SlotModel.fromJson(json);
      expect(slot.id, 'slot-1a');
      expect(slot.sessionId, 'session-1');
      expect(slot.userId, 'user-arif');
      expect(slot.userName, 'Arif Budiman');
      expect(slot.status, SlotStatus.confirmed);
      expect(slot.confirmedAt, isNotNull);
    });

    test('fromJson with null confirmedAt', () {
      final json = {
        'id': 'slot-1',
        'sessionId': 'session-1',
        'userId': 'user-1',
        'userName': 'Test',
        'status': 'waitlist',
        'joinedAt': '2025-06-10T10:00:00.000',
        'confirmedAt': null,
      };

      final slot = SlotModel.fromJson(json);
      expect(slot.status, SlotStatus.waitlist);
      expect(slot.confirmedAt, isNull);
    });

    test('fromJson with missing fields uses defaults', () {
      final slot = SlotModel.fromJson(<String, dynamic>{});
      expect(slot.id, '');
      expect(slot.userName, 'Unknown');
      expect(slot.status, SlotStatus.registered);
    });

    test('fromJson with invalid status falls back to registered', () {
      final json = {
        'id': 'slot-1',
        'sessionId': 'session-1',
        'userId': 'user-1',
        'userName': 'Test',
        'status': 'badStatus',
        'joinedAt': '2025-06-10T10:00:00.000',
      };

      final slot = SlotModel.fromJson(json);
      expect(slot.status, SlotStatus.registered);
    });

    test('toJson roundtrip', () {
      final original = SlotModel(
        id: 'slot-x',
        sessionId: 'session-1',
        userId: 'user-1',
        userName: 'Test User',
        status: SlotStatus.paid,
        joinedAt: DateTime(2025, 6, 10),
        confirmedAt: DateTime(2025, 6, 11),
      );

      final restored = SlotModel.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.status, original.status);
      expect(restored.confirmedAt, original.confirmedAt);
    });

    test('toJson roundtrip with null confirmedAt', () {
      final original = SlotModel(
        id: 'slot-x',
        sessionId: 'session-1',
        userId: 'user-1',
        userName: 'Test User',
        status: SlotStatus.waitlist,
        joinedAt: DateTime(2025, 6, 10),
      );

      final restored = SlotModel.fromJson(original.toJson());
      expect(restored.confirmedAt, isNull);
    });

    test('copyWith creates modified copy', () {
      final slot = SlotModel(
        id: 'slot-1',
        sessionId: 'session-1',
        userId: 'user-1',
        userName: 'Test',
        status: SlotStatus.confirmed,
        joinedAt: DateTime(2025, 6, 10),
      );

      final updated = slot.copyWith(
        status: SlotStatus.paid,
        confirmedAt: DateTime(2025, 6, 11),
      );
      expect(updated.status, SlotStatus.paid);
      expect(updated.confirmedAt, DateTime(2025, 6, 11));
      expect(updated.userId, 'user-1');
    });

    test('statusLabel returns correct labels', () {
      SlotModel makeSlot(SlotStatus s) => SlotModel(
            id: '',
            sessionId: '',
            userId: '',
            userName: '',
            status: s,
            joinedAt: DateTime.now(),
          );

      expect(makeSlot(SlotStatus.registered).statusLabel, 'Registered');
      expect(makeSlot(SlotStatus.waitlist).statusLabel, 'Waitlist');
      expect(makeSlot(SlotStatus.confirmed).statusLabel, 'Confirmed');
      expect(makeSlot(SlotStatus.paid).statusLabel, 'Paid');
      expect(makeSlot(SlotStatus.locked).statusLabel, 'Locked');
    });
  });
}
