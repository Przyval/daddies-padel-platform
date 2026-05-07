/// Base exception for all app-level errors.
sealed class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a Firestore write/update/delete fails.
class DataWriteException extends AppException {
  const DataWriteException(super.message, [super.cause]);
}

/// Thrown when a Firestore read/load fails.
class DataReadException extends AppException {
  const DataReadException(super.message, [super.cause]);
}

/// Thrown when a network operation fails.
class NetworkException extends AppException {
  const NetworkException(super.message, [super.cause]);
}

/// Thrown when authentication fails.
class AuthException extends AppException {
  const AuthException(super.message, [super.cause]);
}

/// Thrown when a concurrency conflict is detected (e.g. slot already taken).
class ConflictException extends AppException {
  const ConflictException(super.message, [super.cause]);
}

/// Thrown when a user action is rate-limited (Governor pattern).
class RateLimitedException extends AppException {
  final Duration retryAfter;
  const RateLimitedException(super.message, this.retryAfter, [super.cause]);
}
