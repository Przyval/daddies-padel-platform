import 'dart:async';

import 'package:daddies_app/core/services/app_logger.dart';

/// Circuit Breaker states per Release It! Ch.5.
enum CircuitState { closed, open, halfOpen }

/// A circuit breaker that wraps dangerous operations (e.g. Firebase calls).
///
/// - **Closed**: calls pass through. After [failureThreshold] failures within
///   [resetWindow], the circuit trips to Open.
/// - **Open**: calls fail immediately with [CircuitBreakerOpenException].
///   After [cooldownDuration], transitions to Half-Open.
/// - **Half-Open**: allows one trial call. Success resets to Closed;
///   failure returns to Open.
///
/// Based on Release It! 2nd Edition (Nygard, Ch.5 — Stability Patterns).
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration cooldownDuration;
  final Duration resetWindow;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureAt;
  DateTime? _openedAt;

  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.cooldownDuration = const Duration(seconds: 30),
    this.resetWindow = const Duration(minutes: 2),
  });

  CircuitState get state => _state;

  /// Execute [operation] through the circuit breaker.
  Future<T> call<T>(Future<T> Function() operation) async {
    switch (_state) {
      case CircuitState.open:
        if (_shouldAttemptReset()) {
          _state = CircuitState.halfOpen;
          AppLogger.i('CircuitBreaker', '[$name] Half-Open — allowing trial call');
        } else {
          throw CircuitBreakerOpenException(name);
        }

      case CircuitState.halfOpen:
      case CircuitState.closed:
        break;
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  /// Reset the circuit breaker to closed state (e.g. for admin control).
  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _lastFailureAt = null;
    _openedAt = null;
    AppLogger.i('CircuitBreaker', '[$name] Manually reset to Closed');
  }

  bool _shouldAttemptReset() {
    if (_openedAt == null) return false;
    return DateTime.now().difference(_openedAt!) >= cooldownDuration;
  }

  void _onSuccess() {
    if (_state == CircuitState.halfOpen) {
      AppLogger.i('CircuitBreaker', '[$name] Half-Open trial succeeded — resetting to Closed');
    }
    _state = CircuitState.closed;
    _failureCount = 0;
    _lastFailureAt = null;
    _openedAt = null;
  }

  void _onFailure() {
    final now = DateTime.now();

    // Reset failure count if outside the rolling window
    if (_lastFailureAt != null &&
        now.difference(_lastFailureAt!) > resetWindow) {
      _failureCount = 0;
    }

    _failureCount++;
    _lastFailureAt = now;

    if (_state == CircuitState.halfOpen) {
      _state = CircuitState.open;
      _openedAt = now;
      AppLogger.w('CircuitBreaker', '[$name] Half-Open trial failed — back to Open');
    } else if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
      _openedAt = now;
      AppLogger.w('CircuitBreaker',
          '[$name] Tripped to Open after $_failureCount failures');
    }
  }

  /// Snapshot for health reporting.
  Map<String, dynamic> toHealthMap() => {
        'name': name,
        'state': _state.name,
        'failureCount': _failureCount,
        'lastFailure': _lastFailureAt?.toIso8601String(),
        'openedAt': _openedAt?.toIso8601String(),
      };
}

/// Thrown when a call is rejected because the circuit is open.
class CircuitBreakerOpenException implements Exception {
  final String circuitName;
  const CircuitBreakerOpenException(this.circuitName);

  @override
  String toString() =>
      'CircuitBreakerOpenException: [$circuitName] is Open — call rejected';
}
