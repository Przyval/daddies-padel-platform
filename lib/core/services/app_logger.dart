import 'package:flutter/foundation.dart';

/// Log levels ordered by severity.
enum LogLevel { debug, info, warning, error }

/// Centralized logger with leveled output and tag-based filtering.
///
/// Usage:
///   AppLogger.d('DataService', 'Loaded 5 sessions');
///   AppLogger.e('AuthProvider', 'Login failed', error: e, stackTrace: st);
class AppLogger {
  AppLogger._();

  /// Minimum level to output. In release mode, only warnings and errors.
  static LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;

  static void d(String tag, String message) =>
      _log(LogLevel.debug, tag, message);

  static void i(String tag, String message) =>
      _log(LogLevel.info, tag, message);

  static void w(String tag, String message, {Object? error}) =>
      _log(LogLevel.warning, tag, message, error: error);

  static void e(String tag, String message,
          {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, tag, message,
          error: error, stackTrace: stackTrace);

  static void _log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;

    final prefix = switch (level) {
      LogLevel.debug => '\u{1F41B} DEBUG',
      LogLevel.info => '\u{2139}\u{FE0F}  INFO',
      LogLevel.warning => '\u{26A0}\u{FE0F}  WARN',
      LogLevel.error => '\u{274C} ERROR',
    };

    final timestamp =
        DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.SSS

    final buffer = StringBuffer('$prefix [$timestamp] $tag: $message');
    if (error != null) {
      buffer.write('\n  Cause: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n  Stack: $stackTrace');
    }

    // Use debugPrint for line-length safety (avoids truncation on Android).
    debugPrint(buffer.toString());
  }
}
