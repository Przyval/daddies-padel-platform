import 'package:flutter/material.dart';

import 'package:daddies_app/models/session_model.dart';

/// Heritage Athletic Editorial — Color System
///
/// The palette is hyper-restrained to evoke "Quiet Luxury."
/// Every "gray" is slightly warmed by the forest green/cream base.
/// See DESIGN.md for full specification.
class AppColors {
  AppColors._();

  // ─── Primary (Forest Green) ───────────────────────────────────────
  static const Color primary = Color(0xFF082217);
  static const Color primaryContainer = Color(0xFF1E372B);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF85A091);
  static const Color primaryFixed = Color(0xFFCCE9D8);
  static const Color primaryFixedDim = Color(0xFFB1CDBC);

  // ─── Secondary (Neutral) ──────────────────────────────────────────
  static const Color secondary = Color(0xFF5E5E5E);
  static const Color secondaryContainer = Color(0xFFE2E2E2);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF646464);

  // ─── Tertiary (Moss Green) ────────────────────────────────────────
  static const Color tertiary = Color(0xFF032217);
  static const Color tertiaryContainer = Color(0xFF1A372C);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF81A192);

  // ─── Surfaces (The Paper Stack) ───────────────────────────────────
  static const Color surface = Color(0xFFFAF9F5);
  static const Color surfaceBright = Color(0xFFFAF9F5);
  static const Color surfaceDim = Color(0xFFDBDAD6);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF4F4F0);
  static const Color surfaceContainer = Color(0xFFEFEEEA);
  static const Color surfaceContainerHigh = Color(0xFFE9E8E4);
  static const Color surfaceContainerHighest = Color(0xFFE3E2DF);
  static const Color surfaceVariant = Color(0xFFE3E2DF);
  static const Color surfaceTint = Color(0xFF4A6456);

  // ─── Content (Text & Icons) ───────────────────────────────────────
  static const Color onSurface = Color(0xFF1B1C1A);
  static const Color onSurfaceVariant = Color(0xFF424844);
  static const Color onBackground = Color(0xFF1B1C1A);
  static const Color outline = Color(0xFF727974);
  static const Color outlineVariant = Color(0xFFC2C8C2);

  // ─── Inverse ──────────────────────────────────────────────────────
  static const Color inverseSurface = Color(0xFF2F312E);
  static const Color inverseOnSurface = Color(0xFFF2F1ED);
  static const Color inversePrimary = Color(0xFFB1CDBC);

  // ─── Semantic ─────────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color success = Color(0xFF4A7C59);
  static const Color warning = Color(0xFFD4A843);
  static const Color info = Color(0xFF3D6B8E);

  // ─── Functional (white alias) ─────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);

  // ─── Legacy aliases (backward compatibility) ──────────────────────
  static const Color surfaceElevated = surfaceContainerLowest;
  static const Color forestInk = primary;
  static const Color sagePaper = surfaceDim;
  static const Color agedLinen = surfaceContainerLow;
  static const Color mossAccent = surfaceTint;
  static const Color deepCharcoal = onSurface;
  static const Color clayRed = error;
  static const Color textPrimary = onSurface;
  static const Color textSecondary = onSurfaceVariant;
  static const Color textTertiary = outline;
  static const Color textOnPrimary = onPrimary;
  static const Color background = surface;
  static const Color divider = outlineVariant;

  // ─── Dark Mode ────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF1B1C1A);
  static const Color darkSurface = Color(0xFF252624);
  static const Color darkSurfaceElevated = Color(0xFF2F312E);
  static const Color darkSurfaceContainerLow = Color(0xFF1F201E);
  static const Color darkSurfaceContainerHigh = Color(0xFF2F312E);
  static const Color darkSurfaceContainerHighest = Color(0xFF3A3C39);
  static const Color darkDivider = Color(0xFF424844);
  static const Color darkTextPrimary = Color(0xFFE3E2DF);
  static const Color darkTextSecondary = Color(0xFFC2C8C2);
  static const Color darkTextTertiary = Color(0xFF8C9389);

  // ─── Status colors for session flow ───────────────────────────────
  static const Color statusOpen = success;
  static const Color statusWaitlist = warning;
  static const Color statusPaid = info;
  static const Color statusLocked = primary;
  static const Color statusCompleted = surfaceTint;
  static const Color statusCancelled = error;

  /// Returns the accent color for a session status.
  static Color sessionAccentColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.draft:
        return outline;
      case SessionStatus.open:
        return statusOpen;
      case SessionStatus.full:
        return statusWaitlist;
      case SessionStatus.locked:
        return statusLocked;
      case SessionStatus.completed:
        return statusCompleted;
      case SessionStatus.cancelled:
        return statusCancelled;
    }
  }
}
