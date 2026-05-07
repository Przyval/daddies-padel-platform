import 'dart:async';
import 'dart:math';

import 'package:daddies_app/core/resilience/circuit_breaker.dart';
import 'package:daddies_app/core/services/app_logger.dart';

/// Retry with exponential backoff and jitter.
///
/// Implements the "Dogpile" prevention from Release It! Ch.4:
/// random jitter prevents synchronized retries across clients.
///
/// Usage:
///   final result = await retryWithBackoff(
///     () => firestoreService.getUsers(),
///     maxAttempts: 3,
///   );
Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
  double backoffMultiplier = 2.0,
  Duration maxDelay = const Duration(seconds: 10),
  bool Function(Object error)? shouldRetry,
  String? tag,
}) async {
  final random = Random();
  var delay = initialDelay;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (e) {
      // Never retry circuit breaker rejections
      if (e is CircuitBreakerOpenException) rethrow;

      // Check if this error type is retryable
      if (shouldRetry != null && !shouldRetry(e)) rethrow;

      if (attempt == maxAttempts) rethrow;

      // Add random jitter (0-50% of delay) to prevent dogpile
      final jitter = Duration(
        milliseconds: (delay.inMilliseconds * random.nextDouble() * 0.5).round(),
      );
      final totalDelay = delay + jitter;

      if (tag != null) {
        AppLogger.w('Retry', '[$tag] Attempt $attempt/$maxAttempts failed, '
            'retrying in ${totalDelay.inMilliseconds}ms');
      }

      await Future<void>.delayed(totalDelay);

      // Exponential backoff with cap
      delay = Duration(
        milliseconds: min(
          (delay.inMilliseconds * backoffMultiplier).round(),
          maxDelay.inMilliseconds,
        ),
      );
    }
  }

  // Unreachable, but Dart needs it for type safety
  throw StateError('Retry loop completed without returning or throwing');
}
