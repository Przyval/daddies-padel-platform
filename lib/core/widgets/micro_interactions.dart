import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =============================================================================
// ScaleOnTap — Duolingo-style press-down bounce effect
// =============================================================================

/// Wraps any widget with a scale-down-on-press + spring-back animation.
///
/// On press: scales to [scaleFactor] (default 0.95) with haptic feedback.
/// On release: springs back to 1.0 with an elastic curve.
///
/// Usage:
/// ```dart
/// ScaleOnTap(
///   onTap: () => doSomething(),
///   child: MyCard(...),
/// )
/// ```
class ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final bool enableHaptic;

  const ScaleOnTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.95,
    this.enableHaptic = true,
  });

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
      reverseCurve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    if (widget.enableHaptic) {
      HapticFeedback.selectionClick();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// =============================================================================
// AnimatedCounter — Numbers that count up with spring effect
// =============================================================================

/// Animates a number from 0 to [value] with a count-up effect.
///
/// Triggers animation on first build and whenever [value] changes.
///
/// Usage:
/// ```dart
/// AnimatedCounter(
///   value: 42,
///   style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
///   duration: Duration(milliseconds: 800),
/// )
/// ```
class AnimatedCounter extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final String suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.prefix = '',
    this.suffix = '',
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final current = (_previousValue +
                (_animation.value * (widget.value - _previousValue)))
            .round();
        return Text(
          '${widget.prefix}$current${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

// =============================================================================
// SpringButton — Primary action button with bounce feedback
// =============================================================================

/// A primary action button with Duolingo-style spring animation on press.
/// Combines [ScaleOnTap] with the app's standard button styling.
class SpringButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;

  const SpringButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleOnTap(
      onTap: isLoading ? null : onTap,
      scaleFactor: 0.93,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: onTap != null
              ? (backgroundColor ?? const Color(0xFF2F3E34))
              : const Color(0xFF2F3E34).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: (backgroundColor ?? const Color(0xFF2F3E34))
                        .withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foregroundColor ?? const Color(0xFFEFEDE6),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20,
                          color: foregroundColor ?? const Color(0xFFEFEDE6)),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: foregroundColor ?? const Color(0xFFEFEDE6),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// =============================================================================
// ConfettiOverlay — Mini celebration burst
// =============================================================================

/// Shows a brief confetti burst animation overlay.
///
/// Call [ConfettiOverlay.show(context)] to trigger.
class ConfettiOverlay {
  static void show(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ConfettiWidget(
        onComplete: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _ConfettiWidget extends StatefulWidget {
  final VoidCallback onComplete;

  const _ConfettiWidget({required this.onComplete});

  @override
  State<_ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<_ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pieces = List.generate(30, (_) => _ConfettiPiece(
      x: _random.nextDouble(),
      speed: 0.5 + _random.nextDouble() * 1.5,
      wobble: _random.nextDouble() * 2 * pi,
      size: 4 + _random.nextDouble() * 6,
      color: _confettiColors[_random.nextInt(_confettiColors.length)],
    ));

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _confettiColors = [
    Color(0xFF2F3E34), // forestInk
    Color(0xFF6B8F71), // mossAccent
    Color(0xFFD4A017), // gold
    Color(0xFFA3543A), // clayRed
    Color(0xFF4A6350), // sage
    Color(0xFFE8C547), // yellow
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return IgnorePointer(
          child: CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ConfettiPainter(
              pieces: _pieces,
              progress: _controller.value,
            ),
          ),
        );
      },
    );
  }
}

class _ConfettiPiece {
  final double x;
  final double speed;
  final double wobble;
  final double size;
  final Color color;

  _ConfettiPiece({
    required this.x,
    required this.speed,
    required this.wobble,
    required this.size,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;

  _ConfettiPainter({required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final t = progress * piece.speed;
      if (t > 1.0) continue;

      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = piece.color.withValues(alpha: opacity);

      final x = piece.x * size.width + sin(t * 6 + piece.wobble) * 30;
      final y = -20 + t * size.height * 0.8;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 4 + piece.wobble);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 0.6),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// =============================================================================
// PulseAnimation — Subtle breathing effect for attention
// =============================================================================

/// Wraps a widget with a subtle pulse (scale) animation to draw attention.
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;

  const PulseAnimation({
    super.key,
    required this.child,
    this.minScale = 0.97,
    this.maxScale = 1.03,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}
