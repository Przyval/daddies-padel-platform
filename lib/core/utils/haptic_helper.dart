import 'package:flutter/services.dart';

/// Thin wrapper around [HapticFeedback] for consistent tactile feedback.
class HapticHelper {
  HapticHelper._();

  /// Light tap — button presses, toggles.
  static void light() => HapticFeedback.lightImpact();

  /// Medium tap — confirm actions (join, verify).
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy tap — destructive / important actions (reject, cancel).
  static void heavy() => HapticFeedback.heavyImpact();

  /// Success — completed action (upload, publish, save).
  static void success() => HapticFeedback.mediumImpact();

  /// Warning / error vibration.
  static void error() => HapticFeedback.vibrate();
}
