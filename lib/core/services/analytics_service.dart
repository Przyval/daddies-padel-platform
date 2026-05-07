import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized analytics & crash reporting service.
///
/// Wraps Firebase Analytics and Crashlytics into a single API.
/// All event names follow snake_case convention.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  late final FirebaseAnalytics _analytics;
  late final FirebaseCrashlytics _crashlytics;
  bool _initialized = false;

  /// Call once during app startup, after Firebase.initializeApp().
  Future<void> initialize() async {
    if (_initialized) return;

    _analytics = FirebaseAnalytics.instance;
    _crashlytics = FirebaseCrashlytics.instance;

    // Crashlytics not supported on web
    if (!kIsWeb) {
      await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
      FlutterError.onError = _crashlytics.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
    }

    _initialized = true;
  }

  // ===========================================================================
  // User identity
  // ===========================================================================

  /// Set user properties for analytics & crash reports.
  void setUser({required String userId, required String role}) {
    _analytics.setUserId(id: userId);
    _analytics.setUserProperty(name: 'user_role', value: role);
    _crashlytics.setUserIdentifier(userId);
    _crashlytics.setCustomKey('user_role', role);
  }

  void clearUser() {
    _analytics.setUserId(id: null);
    _crashlytics.setUserIdentifier('');
  }

  // ===========================================================================
  // Auth events
  // ===========================================================================

  void logLogin({required String method}) {
    _analytics.logLogin(loginMethod: method);
  }

  void logLogout() {
    _log('user_logout');
  }

  // ===========================================================================
  // Session events
  // ===========================================================================

  void logSessionCreated({required String sessionId, required String venue}) {
    _log('session_created', {
      'session_id': sessionId,
      'venue': venue,
    });
  }

  void logSessionJoined({required String sessionId}) {
    _log('session_joined', {'session_id': sessionId});
  }

  void logSessionLeft({required String sessionId}) {
    _log('session_left', {'session_id': sessionId});
  }

  void logSessionStatusChanged({
    required String sessionId,
    required String newStatus,
  }) {
    _log('session_status_changed', {
      'session_id': sessionId,
      'new_status': newStatus,
    });
  }

  // ===========================================================================
  // Payment events
  // ===========================================================================

  void logPaymentUploaded({
    required String sessionId,
    required int amount,
  }) {
    _log('payment_uploaded', {
      'session_id': sessionId,
      'amount': amount,
    });
  }

  void logPaymentVerified({required String paymentId}) {
    _log('payment_verified', {'payment_id': paymentId});
  }

  // ===========================================================================
  // Finance events
  // ===========================================================================

  void logCashFlowAdded({
    required String type,
    required int amount,
    required String category,
  }) {
    _log('cashflow_added', {
      'type': type,
      'amount': amount,
      'category': category,
    });
  }

  // ===========================================================================
  // Navigation / screen views
  // ===========================================================================

  void logScreenView({required String screenName}) {
    _analytics.logScreenView(screenName: screenName);
  }

  // ===========================================================================
  // Error recording
  // ===========================================================================

  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    _crashlytics.recordError(error, stack, fatal: fatal);
  }

  // ===========================================================================
  // SLI (Service Level Indicator) events
  // ===========================================================================

  /// Track a booking attempt (join/leave session) for SLO measurement.
  void logBookingAttempt({
    required bool success,
    required int latencyMs,
    String? errorType,
  }) {
    _log('sli_booking_attempt', {
      'success': success ? 1 : 0,
      'latency_ms': latencyMs,
      if (errorType != null) 'error_type': errorType,
    });
  }

  /// Track a payment attempt (upload/verify) for SLO measurement.
  void logPaymentAttempt({
    required bool success,
    required int latencyMs,
    String? errorType,
  }) {
    _log('sli_payment_attempt', {
      'success': success ? 1 : 0,
      'latency_ms': latencyMs,
      if (errorType != null) 'error_type': errorType,
    });
  }

  /// Track app load (splash → ready) for SLO measurement.
  void logAppLoad({
    required bool success,
    required int latencyMs,
    String? failureReason,
  }) {
    _log('sli_app_load', {
      'success': success ? 1 : 0,
      'latency_ms': latencyMs,
      if (failureReason != null) 'failure_reason': failureReason,
    });
  }

  /// Track data load (Firestore initial fetch) for SLO measurement.
  void logDataLoad({
    required bool success,
    required int latencyMs,
    int? userCount,
    int? sessionCount,
  }) {
    _log('sli_data_load', {
      'success': success ? 1 : 0,
      'latency_ms': latencyMs,
      if (userCount != null) 'user_count': userCount,
      if (sessionCount != null) 'session_count': sessionCount,
    });
  }

  // ===========================================================================
  // Internal
  // ===========================================================================

  void _log(String name, [Map<String, Object>? params]) {
    _analytics.logEvent(name: name, parameters: params);
  }
}
