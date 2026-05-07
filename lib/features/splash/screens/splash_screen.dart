import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/core/services/analytics_service.dart';
import 'package:daddies_app/core/widgets/lottie_animations.dart';
import 'package:daddies_app/core/services/notification_service.dart';
import 'package:daddies_app/core/services/connectivity_service.dart';
import 'package:daddies_app/core/services/app_logger.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/services/data_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _ringController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _ringScale;
  late Animation<double> _ringFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _versionFade;

  String _loadingStatus = 'Memulai...';

  @override
  void initState() {
    super.initState();

    // Logo animation: scale up + fade in (0-600ms)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Ring pulse animation
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _ringScale = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );

    _ringFade = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );

    // Text animations: staggered fade + slide (starts at 400ms)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _versionFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    // Sequence the animations
    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ringController.forward();
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _textController.forward();
    });

    // Initialize data + check auth after animation
    _initAndRoute();
  }

  Future<void> _initAndRoute() async {
    final stopwatch = Stopwatch()..start();

    // Fire-and-forget ALL background services — don't block navigation.
    bool initSuccess = true;
    String? failureReason;

    // Non-blocking: analytics, notifications, public data — all in background
    Future.wait([
      AnalyticsService.instance.initialize(),
      NotificationService.instance.initialize(),
      DataService().initializePublicData(),
    ]).timeout(const Duration(seconds: 5)).catchError((_) => <void>[]);

    ConnectivityService.instance.initialize();

    // Only wait for the logo animation to finish (~1 second)
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 1000) {
      await Future<void>.delayed(Duration(milliseconds: 1000 - elapsed));
    }
    if (!mounted) return;

    // Quick session restore — no await on slow Firebase Auth
    final authProvider = context.read<AuthProvider>();
    bool restored = false;
    try {
      restored = await Future.value(authProvider.restoreSession())
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {
      restored = false;
    }

    if (!mounted) return;

    if (restored) {
      context.go(AppRoutes.home);
    } else {
      // Check if onboarding has been completed
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;

      if (!mounted) return;

      if (onboardingDone) {
        context.go(AppRoutes.explore);
      } else {
        context.go(AppRoutes.onboarding);
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.forestInk,
        body: Stack(
          children: [
            // Subtle radial gradient background
            Center(
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.mossAccent.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Main centered content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo with ring pulse
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Expanding ring pulse
                        AnimatedBuilder(
                          animation: _ringController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _ringScale.value,
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        ),

                        // Main logo circle
                        AnimatedBuilder(
                          animation: _logoController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _logoScale.value,
                              child: Opacity(
                                opacity: _logoFade.value,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: AppColors.agedLinen,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.sports_tennis,
                                    color: AppColors.forestInk,
                                    size: 56,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // "DADDIES" title - slide up + fade
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _titleSlide,
                        child: Opacity(
                          opacity: _titleFade.value,
                          child: const Text(
                            'DADDIES',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: AppColors.agedLinen,
                              letterSpacing: 10,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Subtitle - staggered slide up + fade
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _subtitleSlide,
                        child: Opacity(
                          opacity: _subtitleFade.value,
                          child: const Text(
                            'PADEL COMMUNITY',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mossAccent,
                              letterSpacing: 4,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Loading indicator above version
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _versionFade.value,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const LottieLoading(width: 64, height: 32),
                          const SizedBox(height: 8),
                          Text(
                            _loadingStatus,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mossAccent.withValues(alpha: 0.6),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Version text at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _versionFade.value,
                    child: Text(
                      'v1.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.mossAccent.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
