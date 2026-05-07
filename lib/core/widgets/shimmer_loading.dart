import 'package:flutter/material.dart';
import 'package:daddies_app/core/theme/app_colors.dart';

// =============================================================================
// Shimmer animation wrapper
// =============================================================================

/// Provides a smooth left-to-right shimmer gradient animation.
///
/// Wrap any skeleton widget tree with [Shimmer] so that all descendant
/// [ShimmerBox] widgets share the same animation controller and paint in sync.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  /// Retrieve the nearest [ShimmerState] so that [ShimmerBox] can read the
  /// current gradient for painting.
  static ShimmerState? of(BuildContext context) {
    return context.findAncestorStateOfType<ShimmerState>();
  }

  @override
  State<Shimmer> createState() => ShimmerState();
}

class ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A [Listenable] that skeleton boxes subscribe to for repainting.
  Listenable get shimmerChanges => _controller;

  /// Returns a [LinearGradient] whose highlight band slides from left to right
  /// based on the current animation value and the provided [bounds].
  ///
  /// The gradient uses three stops to produce a subtle highlight sweep:
  /// base -> highlight -> base.
  Gradient gradient({required Rect bounds}) {
    const baseColor = AppColors.sagePaper; // Color(0xFFDADDD6)
    const highlightColor = AppColors.agedLinen; // Color(0xFFEFEDE6)

    // The sweep travels from -1.0 to 2.0 across the normalized width so the
    // highlight enters from the left, crosses the full width, and exits right.
    final double slide = _controller.value * 3.0 - 1.0; // range: -1.0 .. 2.0

    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        baseColor,
        baseColor,
        highlightColor,
        baseColor,
        baseColor,
      ],
      stops: [
        0.0,
        (slide - 0.3).clamp(0.0, 1.0),
        slide.clamp(0.0, 1.0),
        (slide + 0.3).clamp(0.0, 1.0),
        1.0,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// =============================================================================
// ShimmerBox — a single animated placeholder rectangle
// =============================================================================

/// A rounded rectangle that paints the current shimmer gradient.
///
/// Must be placed inside a [Shimmer] ancestor widget.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> {
  Listenable? _shimmerChanges;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shimmerChanges != null) {
      _shimmerChanges!.removeListener(_onShimmerChange);
    }
    _shimmerChanges = Shimmer.of(context)?.shimmerChanges;
    _shimmerChanges?.addListener(_onShimmerChange);
  }

  @override
  void dispose() {
    _shimmerChanges?.removeListener(_onShimmerChange);
    super.dispose();
  }

  void _onShimmerChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shimmerState = Shimmer.of(context);

    // Fallback: if no Shimmer ancestor is found, render a static placeholder.
    if (shimmerState == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.sagePaper,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: CustomPaint(
          painter: _ShimmerPainter(shimmerState: shimmerState),
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final ShimmerState shimmerState;

  _ShimmerPainter({required this.shimmerState});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = shimmerState.gradient(bounds: rect);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) => true;
}

// =============================================================================
// SessionCardSkeleton
// =============================================================================

/// Mimics the [SessionCard] layout while data is loading.
///
/// Structure (top-to-bottom):
///   - Title bar + status chip placeholder (row)
///   - Venue text line
///   - Date text line
///   - Bottom bar with player count + price placeholders
///
/// Height ~120, border radius 16.
class SessionCardSkeleton extends StatelessWidget {
  const SessionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Top section: title + status chip --
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Title placeholder
                const Expanded(
                  child: ShimmerBox(width: double.infinity, height: 14, borderRadius: 6),
                ),
                const SizedBox(width: 12),
                // Status chip placeholder
                const ShimmerBox(width: 56, height: 22, borderRadius: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // -- Venue text line --
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerBox(width: 180, height: 10, borderRadius: 5),
          ),
          const SizedBox(height: 8),

          // -- Date text line --
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerBox(width: 140, height: 10, borderRadius: 5),
          ),

          const Spacer(),

          // -- Bottom bar --
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.forestInk.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: const Row(
              children: [
                ShimmerBox(width: 100, height: 10, borderRadius: 5),
                Spacer(),
                ShimmerBox(width: 72, height: 10, borderRadius: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FinanceCardSkeleton
// =============================================================================

/// Mimics a finance transaction tile while data is loading.
///
/// Structure (left-to-right):
///   - Circle avatar icon placeholder
///   - Two text lines (category + description)
///   - Amount + date on the right
///
/// Height ~64, uses the same border radius and decoration as
/// `_buildTransactionTile`.
class FinanceCardSkeleton extends StatelessWidget {
  const FinanceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          // Circle avatar placeholder
          ShimmerBox(width: 40, height: 40, borderRadius: 10),
          SizedBox(width: 12),

          // Two text lines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShimmerBox(width: 120, height: 12, borderRadius: 5),
                SizedBox(height: 6),
                ShimmerBox(width: 80, height: 10, borderRadius: 5),
              ],
            ),
          ),
          SizedBox(width: 8),

          // Amount + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShimmerBox(width: 72, height: 12, borderRadius: 5),
              SizedBox(height: 6),
              ShimmerBox(width: 56, height: 10, borderRadius: 5),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SessionListSkeleton
// =============================================================================

/// Shows 4 [SessionCardSkeleton] items with consistent padding and spacing,
/// all wrapped in a single [Shimmer] animation.
class SessionListSkeleton extends StatelessWidget {
  const SessionListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: List.generate(4, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SessionCardSkeleton(),
            );
          }),
        ),
      ),
    );
  }
}

// =============================================================================
// FinanceListSkeleton
// =============================================================================

/// Shows 5 [FinanceCardSkeleton] items with consistent padding and spacing,
/// all wrapped in a single [Shimmer] animation.
class FinanceListSkeleton extends StatelessWidget {
  const FinanceListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: List.generate(5, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: FinanceCardSkeleton(),
            );
          }),
        ),
      ),
    );
  }
}
