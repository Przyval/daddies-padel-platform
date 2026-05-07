import 'package:flutter_test/flutter_test.dart';
import 'package:daddies_app/models/notification_model.dart';

void main() {
  group('NotificationModel', () {
    test('fromJson with complete data', () {
      final json = {
        'id': 'notif-1',
        'title': 'Session Created',
        'body': 'Your session has been created successfully',
        'type': 'sessionCreated',
        'sessionId': 'session-123',
        'createdAt': '2025-06-15T10:00:00.000',
        'isRead': false,
      };

      final notification = NotificationModel.fromJson(json);
      expect(notification.id, 'notif-1');
      expect(notification.title, 'Session Created');
      expect(notification.body, 'Your session has been created successfully');
      expect(notification.type, NotificationType.sessionCreated);
      expect(notification.sessionId, 'session-123');
      expect(notification.createdAt, isNotNull);
      expect(notification.isRead, false);
    });

    test('fromJson with null/missing fields uses defaults', () {
      final json = <String, dynamic>{};

      final notification = NotificationModel.fromJson(json);
      expect(notification.id, '');
      expect(notification.title, '');
      expect(notification.body, '');
      expect(notification.type, NotificationType.general);
      expect(notification.sessionId, isNull);
      expect(notification.isRead, false);
      expect(notification.createdAt, isNotNull);
    });

    test('fromJson with invalid type defaults to general', () {
      final json = {
        'id': 'notif-2',
        'title': 'Test',
        'body': 'Test body',
        'type': 'invalidType',
        'createdAt': '2025-06-15T10:00:00.000',
      };

      final notification = NotificationModel.fromJson(json);
      expect(notification.type, NotificationType.general);
    });

    test('fromJson with null type defaults to general', () {
      final json = {
        'id': 'notif-3',
        'title': 'Test',
        'body': 'Test body',
        'type': null,
        'createdAt': '2025-06-15T10:00:00.000',
      };

      final notification = NotificationModel.fromJson(json);
      expect(notification.type, NotificationType.general);
    });

    test('fromJson with invalid createdAt defaults to now', () {
      final json = {
        'id': 'notif-4',
        'title': 'Test',
        'body': 'Test body',
        'type': 'paymentVerified',
        'createdAt': 'invalid-date',
      };

      final before = DateTime.now();
      final notification = NotificationModel.fromJson(json);
      final after = DateTime.now();

      expect(notification.createdAt.isAfter(before.subtract(Duration(seconds: 1))), true);
      expect(notification.createdAt.isBefore(after.add(Duration(seconds: 1))), true);
    });

    test('toJson roundtrip', () {
      final original = NotificationModel(
        id: 'notif-x',
        title: 'Payment Verified',
        body: 'Your payment has been verified',
        type: NotificationType.paymentVerified,
        sessionId: 'session-456',
        createdAt: DateTime(2025, 6, 15, 10, 30),
        isRead: true,
      );

      final restored = NotificationModel.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.body, original.body);
      expect(restored.type, original.type);
      expect(restored.sessionId, original.sessionId);
      expect(restored.createdAt, original.createdAt);
      expect(restored.isRead, original.isRead);
    });

    test('toJson includes all fields', () {
      final notification = NotificationModel(
        id: 'notif-y',
        title: 'Session Locked',
        body: 'The session is now locked',
        type: NotificationType.sessionLocked,
        sessionId: 'session-789',
        createdAt: DateTime(2025, 6, 15, 14, 45),
        isRead: false,
      );

      final json = notification.toJson();
      expect(json['id'], 'notif-y');
      expect(json['title'], 'Session Locked');
      expect(json['body'], 'The session is now locked');
      expect(json['type'], 'sessionLocked');
      expect(json['sessionId'], 'session-789');
      expect(json['isRead'], false);
      expect(json['createdAt'], isNotNull);
    });

    test('copyWith creates modified copy', () {
      final notification = NotificationModel(
        id: 'notif-1',
        title: 'Reminder',
        body: 'Session starts soon',
        type: NotificationType.reminder,
        sessionId: 'session-111',
        createdAt: DateTime(2025, 6, 15, 09, 00),
        isRead: false,
      );

      final updated = notification.copyWith(isRead: true);
      expect(updated.isRead, true);
      expect(updated.id, 'notif-1');
      expect(updated.title, 'Reminder');
      expect(updated.body, 'Session starts soon');
      expect(updated.type, NotificationType.reminder);
      expect(updated.sessionId, 'session-111');
      expect(updated.createdAt, notification.createdAt);
    });

    test('copyWith preserves all fields when isRead is not changed', () {
      final notification = NotificationModel(
        id: 'notif-2',
        title: 'Waitlist Promoted',
        body: 'You have been promoted from waitlist',
        type: NotificationType.waitlistPromoted,
        sessionId: 'session-222',
        createdAt: DateTime(2025, 6, 14, 15, 30),
        isRead: true,
      );

      final copy = notification.copyWith();
      expect(copy.id, notification.id);
      expect(copy.title, notification.title);
      expect(copy.body, notification.body);
      expect(copy.type, notification.type);
      expect(copy.sessionId, notification.sessionId);
      expect(copy.createdAt, notification.createdAt);
      expect(copy.isRead, notification.isRead);
    });

    test('fromJson handles all notification types', () {
      final types = [
        'sessionCreated',
        'paymentVerified',
        'paymentRejected',
        'sessionLocked',
        'sessionCompleted',
        'sessionCancelled',
        'waitlistPromoted',
        'reminder',
        'general',
      ];

      for (final typeStr in types) {
        final json = {
          'id': 'notif-$typeStr',
          'title': 'Test',
          'body': 'Test body',
          'type': typeStr,
          'createdAt': '2025-06-15T10:00:00.000',
        };

        final notification = NotificationModel.fromJson(json);
        expect(notification.type.name, typeStr);
      }
    });
  });
}
