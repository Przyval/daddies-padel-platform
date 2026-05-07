/// Web bundle size budgets for the Daddies Padel Platform.
///
/// These are enforced in CI via scripts/check-bundle-size.sh and
/// .github/workflows/ci.yml. Update both when changing values.
abstract final class PerformanceBudget {
  /// Maximum size for main.dart.js (dart2js output).
  static const int mainJsMaxBytes = 6 * 1024 * 1024; // 6 MB

  /// Maximum size for canvaskit.wasm.
  static const int canvaskitWasmMaxBytes = 8 * 1024 * 1024; // 8 MB

  /// Maximum total web build size.
  static const int totalBuildMaxBytes = 40 * 1024 * 1024; // 40 MB

  /// Target image cache limit per thumbnail (decoded pixels).
  /// Used in memCacheWidth/memCacheHeight for CachedNetworkImage.
  static const int thumbnailCachePixels = 160; // 80px * 2x retina
  static const int cardImageCachePixels = 400; // ~200px * 2x retina
}
