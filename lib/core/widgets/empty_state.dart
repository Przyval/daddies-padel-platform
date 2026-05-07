import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:daddies_app/core/theme/app_colors.dart';

class EmptyStateWidget extends StatefulWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.useLottie = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool useLottie;

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAction =
        widget.actionLabel != null && widget.onAction != null;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lottie animation above icon when useLottie is true
              if (widget.useLottie)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Lottie.asset(
                    'assets/animations/empty_state.json',
                    width: 120,
                    height: 120,
                    repeat: true,
                    frameRate: FrameRate.max,
                  ),
                ),

              // Icon area
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: AppColors.sagePaper,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 64,
                  color: AppColors.mossAccent,
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepCharcoal,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: AppColors.textSecondary,
                ),
              ),

              // Optional action button
              if (hasAction) ...[
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: widget.onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forestInk,
                      foregroundColor: AppColors.agedLinen,
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    child: Text(widget.actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
