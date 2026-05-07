import 'package:flutter_test/flutter_test.dart';
import 'package:daddies_app/models/session_model.dart';

void main() {
  group('SessionModel', () {
    test('fromJson with complete data', () {
      final json = {
        'id': 'session-1',
        'miminId': 'user-hendy',
        'miminName': 'Hendy Wijaya',
        'title': 'Mabar Sabtu Sore',
        'venue': 'Genesis Padel',
        'date': '2025-06-15T16:00:00.000',
        'timeStart': '16:00',
        'timeEnd': '18:00',
        'maxPlayers': 8,
        'pricePerPlayer': 150000,
        'status': 'open',
        'createdAt': '2025-06-10T10:00:00.000',
      };

      final session = SessionModel.fromJson(json);
      expect(session.id, 'session-1');
      expect(session.miminName, 'Hendy Wijaya');
      expect(session.title, 'Mabar Sabtu Sore');
      expect(session.maxPlayers, 8);
      expect(session.pricePerPlayer, 150000);
      expect(session.status, SessionStatus.open);
    });

    test('fromJson with null fields uses defaults', () {
      final session = SessionModel.fromJson(<String, dynamic>{});
      expect(session.id, '');
      expect(session.title, 'Untitled Session');
      expect(session.maxPlayers, 8);
      expect(session.pricePerPlayer, 0);
      expect(session.status, SessionStatus.draft);
    });

    test('fromJson with invalid status falls back to draft', () {
      final json = {
        'id': 'session-1',
        'miminId': 'user-1',
        'miminName': 'Test',
        'title': 'Test',
        'venue': 'Test',
        'date': '2025-06-15T16:00:00.000',
        'timeStart': '16:00',
        'timeEnd': '18:00',
        'maxPlayers': 8,
        'pricePerPlayer': 100000,
        'status': 'invalidStatus',
        'createdAt': '2025-06-10T10:00:00.000',
      };

      final session = SessionModel.fromJson(json);
      expect(session.status, SessionStatus.draft);
    });

    test('fromJson handles numeric strings for int fields', () {
      final json = {
        'id': 'session-1',
        'miminId': 'user-1',
        'miminName': 'Test',
        'title': 'Test',
        'venue': 'Test',
        'date': '2025-06-15T16:00:00.000',
        'timeStart': '16:00',
        'timeEnd': '18:00',
        'maxPlayers': '12',
        'pricePerPlayer': '200000',
        'status': 'open',
        'createdAt': '2025-06-10T10:00:00.000',
      };

      final session = SessionModel.fromJson(json);
      expect(session.maxPlayers, 12);
      expect(session.pricePerPlayer, 200000);
    });

    test('fromJson handles double values for int fields', () {
      final json = {
        'id': 'session-1',
        'miminId': 'user-1',
        'miminName': 'Test',
        'title': 'Test',
        'venue': 'Test',
        'date': '2025-06-15T16:00:00.000',
        'timeStart': '16:00',
        'timeEnd': '18:00',
        'maxPlayers': 8.0,
        'pricePerPlayer': 150000.0,
        'status': 'open',
        'createdAt': '2025-06-10T10:00:00.000',
      };

      final session = SessionModel.fromJson(json);
      expect(session.maxPlayers, 8);
      expect(session.pricePerPlayer, 150000);
    });

    test('toJson roundtrip', () {
      final original = SessionModel(
        id: 'session-x',
        miminId: 'user-1',
        miminName: 'Test Mimin',
        title: 'Test Session',
        venue: 'Test Venue',
        date: DateTime(2025, 7, 1, 16),
        timeStart: '16:00',
        timeEnd: '18:00',
        maxPlayers: 8,
        pricePerPlayer: 175000,
        status: SessionStatus.locked,
        createdAt: DateTime(2025, 6, 25),
      );

      final restored = SessionModel.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.status, original.status);
      expect(restored.maxPlayers, original.maxPlayers);
      expect(restored.pricePerPlayer, original.pricePerPlayer);
    });

    test('copyWith creates modified copy', () {
      final session = SessionModel(
        id: 'session-1',
        miminId: 'user-1',
        miminName: 'Mimin',
        title: 'Old Title',
        venue: 'Old Venue',
        date: DateTime(2025, 7, 1),
        timeStart: '16:00',
        timeEnd: '18:00',
        maxPlayers: 8,
        pricePerPlayer: 150000,
        status: SessionStatus.open,
        createdAt: DateTime(2025, 6, 25),
      );

      final updated = session.copyWith(
        title: 'New Title',
        status: SessionStatus.full,
      );
      expect(updated.title, 'New Title');
      expect(updated.status, SessionStatus.full);
      expect(updated.venue, 'Old Venue');
    });

    test('photoUrls roundtrip', () {
      final original = SessionModel(
        id: 'session-photo',
        miminId: 'user-1',
        miminName: 'Test',
        title: 'Photo Test',
        venue: 'Test Venue',
        date: DateTime(2025, 7, 1),
        timeStart: '16:00',
        timeEnd: '18:00',
        maxPlayers: 8,
        pricePerPlayer: 100000,
        status: SessionStatus.open,
        createdAt: DateTime(2025, 6, 25),
        photoUrls: ['https://example.com/1.jpg', '/local/path/2.jpg'],
      );

      final json = original.toJson();
      expect(json['photoUrls'], ['https://example.com/1.jpg', '/local/path/2.jpg']);

      final restored = SessionModel.fromJson(json);
      expect(restored.photoUrls.length, 2);
      expect(restored.photoUrls[0], 'https://example.com/1.jpg');
      expect(restored.photoUrls[1], '/local/path/2.jpg');
    });

    test('photoUrls defaults to empty list', () {
      final session = SessionModel.fromJson(<String, dynamic>{});
      expect(session.photoUrls, isEmpty);
    });

    test('copyWith photoUrls', () {
      final session = SessionModel(
        id: 'session-1',
        miminId: 'user-1',
        miminName: 'Test',
        title: 'Test',
        venue: 'Venue',
        date: DateTime(2025, 7, 1),
        timeStart: '16:00',
        timeEnd: '18:00',
        maxPlayers: 8,
        pricePerPlayer: 100000,
        status: SessionStatus.open,
        createdAt: DateTime(2025, 6, 25),
      );

      final updated = session.copyWith(photoUrls: ['photo1.jpg']);
      expect(updated.photoUrls, ['photo1.jpg']);
      expect(session.photoUrls, isEmpty);
    });

    test('statusLabel returns correct labels', () {
      SessionModel makeSession(SessionStatus s) => SessionModel(
            id: '',
            miminId: '',
            miminName: '',
            title: '',
            venue: '',
            date: DateTime.now(),
            timeStart: '',
            timeEnd: '',
            maxPlayers: 8,
            pricePerPlayer: 0,
            status: s,
            createdAt: DateTime.now(),
          );

      expect(makeSession(SessionStatus.draft).statusLabel, 'Draft');
      expect(makeSession(SessionStatus.open).statusLabel, 'Open');
      expect(makeSession(SessionStatus.full).statusLabel, 'Full');
      expect(makeSession(SessionStatus.locked).statusLabel, 'Locked');
      expect(makeSession(SessionStatus.completed).statusLabel, 'Selesai');
      expect(makeSession(SessionStatus.cancelled).statusLabel, 'Batal');
    });
  });
}
