import 'dart:async';

import 'package:daddies_app/core/services/app_logger.dart';

/// Bulkhead pattern — limits concurrent operations per category.
///
/// Like watertight compartments on a ship: a failure in one category
/// (e.g. leaderboard loading) can't exhaust resources needed by another
/// (e.g. session join). Release It! Ch.5 — Bulkheads.
///
/// In Dart's single-threaded model, this limits concurrent *async*
/// operations (Futures in flight), not threads.
class Bulkhead {
  final String name;
  final int maxConcurrent;
  int _active = 0;

  Bulkhead({required this.name, required this.maxConcurrent});

  int get active => _active;
  bool get isFull => _active >= maxConcurrent;

  /// Execute [operation] within this bulkhead's concurrency limit.
  /// Throws [BulkheadRejectedException] if the limit is reached.
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_active >= maxConcurrent) {
      AppLogger.w('Bulkhead', '[$name] Rejected — $maxConcurrent concurrent ops already running');
      throw BulkheadRejectedException(name, maxConcurrent);
    }

    _active++;
    try {
      return await operation();
    } finally {
      _active--;
    }
  }

  Map<String, dynamic> toHealthMap() => {
        'name': name,
        'active': _active,
        'maxConcurrent': maxConcurrent,
      };
}

/// Thrown when a bulkhead is at capacity.
class BulkheadRejectedException implements Exception {
  final String bulkheadName;
  final int maxConcurrent;
  const BulkheadRejectedException(this.bulkheadName, this.maxConcurrent);

  @override
  String toString() =>
      'BulkheadRejectedException: [$bulkheadName] at capacity ($maxConcurrent)';
}

/// Pre-configured bulkheads for the app.
abstract final class AppBulkheads {
  /// Critical operations: session join/leave, payment verify.
  /// Higher limit — these must succeed.
  static final critical = Bulkhead(name: 'critical', maxConcurrent: 10);

  /// Non-critical operations: leaderboard, stats, partner list.
  /// Lower limit — can be shed under load.
  static final background = Bulkhead(name: 'background', maxConcurrent: 5);
}
