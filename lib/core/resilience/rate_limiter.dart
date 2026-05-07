/// Governor / rate limiter for user actions.
///
/// Prevents abuse and self-denial attacks by limiting how frequently
/// a user can perform certain actions (Release It! Ch.5 — Governor pattern).
///
/// Uses a sliding-window token bucket approach:
/// - Each action type has a max count within a time window.
/// - If exceeded, the action is rejected until the window slides forward.
class RateLimiter {
  final int maxActions;
  final Duration window;
  final List<DateTime> _timestamps = [];

  RateLimiter({
    required this.maxActions,
    required this.window,
  });

  /// Returns true if the action is allowed, false if rate-limited.
  bool tryAcquire() {
    _evictExpired();
    if (_timestamps.length >= maxActions) return false;
    _timestamps.add(DateTime.now());
    return true;
  }

  /// How long until the next action is allowed (Duration.zero if allowed now).
  Duration get timeUntilAllowed {
    _evictExpired();
    if (_timestamps.length < maxActions) return Duration.zero;
    final oldest = _timestamps.first;
    final expiresAt = oldest.add(window);
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Number of remaining actions in the current window.
  int get remaining {
    _evictExpired();
    return maxActions - _timestamps.length;
  }

  void reset() => _timestamps.clear();

  void _evictExpired() {
    final cutoff = DateTime.now().subtract(window);
    _timestamps.removeWhere((t) => t.isBefore(cutoff));
  }
}

/// Pre-configured rate limiters for common user actions.
abstract final class AppRateLimits {
  /// Join/leave session: max 5 per minute.
  static final sessionAction = RateLimiter(
    maxActions: 5,
    window: const Duration(minutes: 1),
  );

  /// Payment upload: max 3 per minute.
  static final paymentAction = RateLimiter(
    maxActions: 3,
    window: const Duration(minutes: 1),
  );

  /// Data refresh: max 3 per 30 seconds.
  static final dataRefresh = RateLimiter(
    maxActions: 3,
    window: const Duration(seconds: 30),
  );
}
