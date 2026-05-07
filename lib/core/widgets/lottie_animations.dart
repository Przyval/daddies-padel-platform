import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Centralized Lottie animation assets and reusable widgets.
class LottieAssets {
  LottieAssets._();

  static const String successCheck = 'assets/animations/success_check.json';
  static const String loadingDots = 'assets/animations/loading_dots.json';
  static const String emptyState = 'assets/animations/empty_state.json';
}

/// Animated success checkmark — plays once.
class LottieSuccess extends StatelessWidget {
  final double size;

  const LottieSuccess({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      LottieAssets.successCheck,
      width: size,
      height: size,
      repeat: false,
      frameRate: FrameRate.max,
    );
  }
}

/// Bouncing dots loading indicator — loops continuously.
class LottieLoading extends StatelessWidget {
  final double width;
  final double height;

  const LottieLoading({super.key, this.width = 80, this.height = 40});

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      LottieAssets.loadingDots,
      width: width,
      height: height,
      repeat: true,
      frameRate: FrameRate.max,
    );
  }
}

/// Floating empty-state animation — loops continuously.
class LottieEmptyState extends StatelessWidget {
  final double size;

  const LottieEmptyState({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      LottieAssets.emptyState,
      width: size,
      height: size,
      repeat: true,
      frameRate: FrameRate.max,
    );
  }
}
