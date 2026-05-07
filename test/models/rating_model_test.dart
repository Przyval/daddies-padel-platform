import 'package:flutter_test/flutter_test.dart';
import 'package:daddies_app/models/rating_model.dart';

void main() {
  group('RatingModel', () {
    test('fromJson with complete data', () {
      final json = {
        'id': 'rating-1',
        'sessionId': 'session-1',
        'fromUserId': 'user-1',
        'toUserId': 'user-2',
        'toUserName': 'John Doe',
        'rating': 5,
        'createdAt': '2025-01-15T10:00:00.000',
      };

      final rating = RatingModel.fromJson(json);
      expect(rating.id, 'rating-1');
      expect(rating.sessionId, 'session-1');
      expect(rating.fromUserId, 'user-1');
      expect(rating.toUserId, 'user-2');
      expect(rating.toUserName, 'John Doe');
      expect(rating.rating, 5);
      expect(rating.createdAt, DateTime(2025, 1, 15, 10, 0, 0));
    });

    test('fromJson with null/missing fields uses defaults', () {
      final json = <String, dynamic>{
        'id': null,
        'sessionId': null,
        'fromUserId': null,
        'toUserId': null,
        'toUserName': null,
        'rating': null,
        'createdAt': null,
      };

      final rating = RatingModel.fromJson(json);
      expect(rating.id, '');
      expect(rating.sessionId, '');
      expect(rating.fromUserId, '');
      expect(rating.toUserId, '');
      expect(rating.toUserName, '');
      expect(rating.rating, 3); // defaults to 3
      expect(rating.createdAt, isA<DateTime>());
    });

    test('fromJson with missing fields uses defaults', () {
      final rating = RatingModel.fromJson(<String, dynamic>{});
      expect(rating.id, '');
      expect(rating.sessionId, '');
      expect(rating.fromUserId, '');
      expect(rating.toUserId, '');
      expect(rating.toUserName, '');
      expect(rating.rating, 3); // defaults to 3
    });

    test('fromJson with invalid rating value (double like 4.0 -> 4)', () {
      final json = {
        'id': 'rating-1',
        'sessionId': 'session-1',
        'fromUserId': 'user-1',
        'toUserId': 'user-2',
        'toUserName': 'Jane Doe',
        'rating': 4.5, // double value
        'createdAt': '2025-01-15T10:00:00.000',
      };

      final rating = RatingModel.fromJson(json);
      expect(rating.rating, 4); // should convert to int
      expect(rating.rating, isA<int>());
    });

    test('fromJson with string rating converts to int', () {
      final json = {
        'id': 'rating-1',
        'sessionId': 'session-1',
        'fromUserId': 'user-1',
        'toUserId': 'user-2',
        'toUserName': 'Test User',
        'rating': '2',
        'createdAt': '2025-01-15T10:00:00.000',
      };

      final rating = RatingModel.fromJson(json);
      expect(rating.rating, 2);
    });

    test('toJson produces correct output', () {
      final rating = RatingModel(
        id: 'rating-1',
        sessionId: 'session-1',
        fromUserId: 'user-1',
        toUserId: 'user-2',
        toUserName: 'John Doe',
        rating: 4,
        createdAt: DateTime(2025, 6, 1),
      );

      final json = rating.toJson();
      expect(json['id'], 'rating-1');
      expect(json['sessionId'], 'session-1');
      expect(json['fromUserId'], 'user-1');
      expect(json['toUserId'], 'user-2');
      expect(json['toUserName'], 'John Doe');
      expect(json['rating'], 4);
      expect(json['createdAt'], '2025-06-01T00:00:00.000');
    });

    test('toJson roundtrip', () {
      final original = RatingModel(
        id: 'rating-x',
        sessionId: 'session-x',
        fromUserId: 'user-x',
        toUserId: 'user-y',
        toUserName: 'Roundtrip User',
        rating: 5,
        createdAt: DateTime(2025, 3, 15, 14, 30),
      );

      final restored = RatingModel.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.sessionId, original.sessionId);
      expect(restored.fromUserId, original.fromUserId);
      expect(restored.toUserId, original.toUserId);
      expect(restored.toUserName, original.toUserName);
      expect(restored.rating, original.rating);
      expect(restored.createdAt, original.createdAt);
    });

    test('copyWith creates modified copy', () {
      final rating = RatingModel(
        id: 'rating-1',
        sessionId: 'session-1',
        fromUserId: 'user-1',
        toUserId: 'user-2',
        toUserName: 'John Doe',
        rating: 3,
        createdAt: DateTime(2025, 1, 1),
      );

      final updated = rating.copyWith(rating: 5, toUserName: 'Jane Doe');
      expect(updated.rating, 5);
      expect(updated.toUserName, 'Jane Doe');
      expect(updated.id, 'rating-1');
      expect(updated.sessionId, 'session-1');
      expect(updated.fromUserId, 'user-1');
      expect(updated.toUserId, 'user-2');
      expect(updated.createdAt, DateTime(2025, 1, 1));
    });
  });
}
