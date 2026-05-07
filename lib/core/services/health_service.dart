import 'package:daddies_app/core/resilience/circuit_breaker.dart';
import 'package:daddies_app/core/resilience/bulkhead.dart';
import 'package:daddies_app/services/data_service.dart';

/// App health status — more than just "is it running?"
///
/// Release It! Ch.8: Health checks should include connection pool status,
/// cache state, circuit breaker states, and whether the app is accepting work.
enum HealthStatus { healthy, degraded, unhealthy }

class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  final List<CircuitBreaker> _circuitBreakers = [];

  /// Register a circuit breaker for health reporting.
  void registerCircuitBreaker(CircuitBreaker cb) {
    if (!_circuitBreakers.contains(cb)) {
      _circuitBreakers.add(cb);
    }
  }

  /// Overall app health status.
  HealthStatus get status {
    final openBreakers =
        _circuitBreakers.where((cb) => cb.state == CircuitState.open).length;

    if (openBreakers >= 2) return HealthStatus.unhealthy;
    if (openBreakers >= 1) return HealthStatus.degraded;

    final ds = DataService();
    if (ds.hasError) return HealthStatus.degraded;

    return HealthStatus.healthy;
  }

  /// Detailed health report for debugging.
  Map<String, dynamic> get report {
    final ds = DataService();
    return {
      'status': status.name,
      'timestamp': DateTime.now().toIso8601String(),
      'dataService': {
        'initialized': ds.isInitialized,
        'hasError': ds.hasError,
        'lastError': ds.lastError,
        'lastSyncedAt': ds.lastSyncedAt?.toIso8601String(),
        'cacheSize': {
          'users': ds.users.length,
          'sessions': ds.sessions.length,
          'slots': ds.slots.length,
          'payments': ds.payments.length,
        },
      },
      'circuitBreakers':
          _circuitBreakers.map((cb) => cb.toHealthMap()).toList(),
      'bulkheads': [
        AppBulkheads.critical.toHealthMap(),
        AppBulkheads.background.toHealthMap(),
      ],
    };
  }
}
