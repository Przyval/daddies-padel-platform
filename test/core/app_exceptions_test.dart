import 'package:flutter_test/flutter_test.dart';
import 'package:daddies_app/core/errors/app_exceptions.dart';

void main() {
  group('AppExceptions', () {
    test('DataWriteException has correct message', () {
      const ex = DataWriteException('Gagal menambah user.');
      expect(ex.message, 'Gagal menambah user.');
      expect(ex.cause, isNull);
      expect(ex.toString(), contains('DataWriteException'));
    });

    test('DataWriteException preserves cause', () {
      final cause = Exception('network error');
      final ex = DataWriteException('Write failed', cause);
      expect(ex.cause, cause);
    });

    test('DataReadException has correct message', () {
      const AppException ex = DataReadException('Read failed');
      expect(ex.message, 'Read failed');
    });

    test('NetworkException has correct message', () {
      const AppException ex = NetworkException('No connection');
      expect(ex.message, 'No connection');
    });

    test('AuthException has correct message', () {
      const AppException ex = AuthException('Login failed');
      expect(ex.message, 'Login failed');
    });

    test('ConflictException has correct message', () {
      const AppException ex = ConflictException('Slot already taken');
      expect(ex.message, 'Slot already taken');
    });

    test('All exceptions are AppException subtypes', () {
      const exceptions = <AppException>[
        DataWriteException('test'),
        DataReadException('test'),
        NetworkException('test'),
        AuthException('test'),
        ConflictException('test'),
      ];

      for (final ex in exceptions) {
        expect(ex, isA<AppException>());
        expect(ex.message, 'test');
      }
    });
  });
}
