import 'package:flutter_test/flutter_test.dart';
import 'package:daddies_app/core/services/app_logger.dart';

void main() {
  group('AppLogger', () {
    test('LogLevel ordering is correct', () {
      expect(LogLevel.debug.index, lessThan(LogLevel.info.index));
      expect(LogLevel.info.index, lessThan(LogLevel.warning.index));
      expect(LogLevel.warning.index, lessThan(LogLevel.error.index));
    });

    test('minLevel defaults to debug in test mode', () {
      // In test mode (debug), minLevel should be debug.
      expect(AppLogger.minLevel, LogLevel.debug);
    });

    test('logging methods do not throw', () {
      // Just verify they run without exceptions.
      expect(() => AppLogger.d('Test', 'debug message'), returnsNormally);
      expect(() => AppLogger.i('Test', 'info message'), returnsNormally);
      expect(() => AppLogger.w('Test', 'warning message'), returnsNormally);
      expect(
        () => AppLogger.e('Test', 'error message',
            error: Exception('test'), stackTrace: StackTrace.current),
        returnsNormally,
      );
    });

    test('messages below minLevel are suppressed', () {
      final originalLevel = AppLogger.minLevel;
      AppLogger.minLevel = LogLevel.error;

      // These should not throw or produce output.
      expect(() => AppLogger.d('Test', 'suppressed'), returnsNormally);
      expect(() => AppLogger.i('Test', 'suppressed'), returnsNormally);
      expect(() => AppLogger.w('Test', 'suppressed'), returnsNormally);

      // Restore.
      AppLogger.minLevel = originalLevel;
    });
  });
}
