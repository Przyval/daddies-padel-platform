import 'package:flutter/material.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/widgets/lottie_animations.dart';

/// Shows a success animation overlay that auto-dismisses after [duration].
///
/// Usage:
/// ```dart
/// SuccessOverlay.show(context, message: 'Sesi berhasil dibuat');
/// ```
class SuccessOverlay {
  SuccessOverlay._();

  static Future<void> show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (ctx, anim, secondAnim, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, anim, secondAnim) {
        // Auto-dismiss after duration
        Future.delayed(duration, () {
          if (ctx.mounted && Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
          }
        });

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 200,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LottieSuccess(size: 96),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepCharcoal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
