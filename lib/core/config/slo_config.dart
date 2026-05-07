/// SLO (Service Level Objective) definitions for the Daddies Padel Platform.
///
/// These targets guide monitoring and alerting. Track actual performance
/// via Firebase Analytics custom events (sli_*) and Firebase Performance traces.
abstract final class SloConfig {
  // ── Booking (join/leave session) ──────────────────────────────────

  static const double bookingSuccessTarget = 0.99; // 99%
  static const int bookingLatencyTargetMs = 5000; // 5 seconds

  // ── Payment (upload & verification) ───────────────────────────────
  static const double paymentSuccessTarget = 0.99; // 99%
  static const int paymentLatencyTargetMs = 3000; // 3 seconds

  // ── App Load (splash → home) ──────────────────────────────────────
  static const double appLoadSuccessTarget = 0.95; // 95%
  static const int appLoadLatencyTargetMs = 5000; // 5 seconds

  // ── Data Load (Firestore initial fetch) ───────────────────────────
  static const double dataLoadSuccessTarget = 0.95; // 95%
  static const int dataLoadLatencyTargetMs = 10000; // 10 seconds

  // ── Core Web Vitals (web platform) ──────────────────────────────
  // Targets per Google's "Good" thresholds at p75.
  static const int lcpTargetMs = 2500; // Largest Contentful Paint
  static const int inpTargetMs = 200; // Interaction to Next Paint
  static const double clsTarget = 0.1; // Cumulative Layout Shift
  static const int fcpTargetMs = 1800; // First Contentful Paint
  static const int ttfbTargetMs = 800; // Time to First Byte
}
