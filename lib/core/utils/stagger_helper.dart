import 'package:flutter/material.dart';

/// Builds a staggered fade+slide animation for a child widget.
///
/// Used across dashboard screens for smooth entry animations.
/// [controller] is the parent AnimationController (typically 600ms).
/// [index] is the item's position in the stagger sequence.
/// [total] is the total number of items to stagger across.
Widget buildStaggerItem({
  required AnimationController controller,
  required int index,
  required int total,
  required Widget child,
}) {
  final start = (index / total).clamp(0.0, 1.0);
  final end = ((index + 3) / total).clamp(0.0, 1.0);
  final opacity = Tween<double>(begin: 0, end: 1).animate(
    CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    ),
  );
  final slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    ),
  );
  return SlideTransition(
    position: slide,
    child: FadeTransition(opacity: opacity, child: child),
  );
}
