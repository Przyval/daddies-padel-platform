import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/features/splash/screens/splash_screen.dart';
import 'package:daddies_app/features/auth/screens/login_screen.dart';
import 'package:daddies_app/features/home/screens/home_shell.dart';
import 'package:daddies_app/features/sessions/screens/session_detail_screen.dart';
import 'package:daddies_app/features/sessions/screens/create_session_screen.dart';
import 'package:daddies_app/features/sessions/screens/edit_session_screen.dart';
import 'package:daddies_app/features/sessions/screens/payment_upload_screen.dart';
import 'package:daddies_app/features/profile/screens/edit_profile_screen.dart';
import 'package:daddies_app/features/settings/screens/settings_screen.dart';
import 'package:daddies_app/features/notifications/screens/notification_center_screen.dart';
import 'package:daddies_app/features/member/screens/session_history_screen.dart';
import 'package:daddies_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:daddies_app/core/widgets/deferred_loader.dart';

// Deferred imports — these screens load on-demand to reduce initial bundle size.
import 'package:daddies_app/features/member/screens/leaderboard_screen.dart'
    deferred as leaderboard;
import 'package:daddies_app/features/venues/screens/venue_detail_screen.dart'
    deferred as venue_detail;
import 'package:daddies_app/features/member/screens/player_stats_screen.dart'
    deferred as player_stats;
import 'package:daddies_app/features/kta/screens/kta_digital_screen.dart'
    deferred as kta;
import 'package:daddies_app/features/partners/screens/partner_list_screen.dart'
    deferred as partners;
import 'package:daddies_app/features/scoring/screens/match_scoring_screen.dart'
    deferred as scoring;
import 'package:daddies_app/features/chips/screens/chips_history_screen.dart'
    deferred as chips;
import 'package:daddies_app/features/awards/screens/awards_showcase_screen.dart'
    deferred as awards;
import 'package:daddies_app/features/redemption/screens/redemption_screen.dart'
    deferred as redemption;
import 'package:daddies_app/features/referral/screens/referral_screen.dart'
    deferred as referral;
import 'package:daddies_app/features/explore/screens/explore_screen.dart'
    deferred as explore;
import 'package:daddies_app/features/member/screens/public_profile_screen.dart'
    deferred as public_profile;
import 'package:daddies_app/features/welcome/screens/welcome_flow_screen.dart'
    deferred as welcome;

/// Global router reference for navigation from services (e.g. notification taps).
GoRouter? globalRouter;

/// Route path constants for type-safe navigation.
class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const home = '/home';
  static const sessionDetail = '/session/:id';
  static const createSession = '/session/create';
  static const editSession = '/session/:id/edit';
  static const paymentUpload = '/session/:id/pay';
  static const matchScoring = '/session/:id/scoring';
  static const editProfile = '/profile/edit';
  static const settings = '/settings';
  static const notificationCenter = '/notifications';
  static const leaderboard = '/leaderboard';
  static const sessionHistory = '/history';
  static const venueDetail = '/venue/:id';
  static const playerStats = '/player/:id/stats';
  static const kta = '/kta';
  static const partnerList = '/partners';
  static const chipsHistory = '/chips';
  static const awardsShowcase = '/awards';
  static const redemptions = '/redemptions';
  static const referral = '/referral';
  static const joinReferral = '/join';
  static const explore = '/explore';
  static const memberProfile = '/member/:id';
  static const welcomeFlow = '/welcome';

  /// Routes accessible without authentication.
  static const publicRoutes = {
    explore,
    '/leaderboard',
    '/partners',
  };

  /// Route prefixes accessible without authentication.
  static bool isPublicRoute(String location) {
    if (publicRoutes.contains(location)) return true;
    if (location.startsWith('/member/')) return true;
    if (location.startsWith('/explore')) return true;
    return false;
  }

  /// Helper to build member profile path.
  static String memberProfilePath(String id) => '/member/$id';

  /// Helper to build session detail path.
  static String sessionDetailPath(String id) => '/session/$id';

  /// Helper to build session edit path.
  static String sessionEditPath(String id) => '/session/$id/edit';

  /// Helper to build payment upload path.
  static String paymentUploadPath(String id) => '/session/$id/pay';

  /// Helper to build match scoring path.
  static String matchScoringPath(String id) => '/session/$id/scoring';

  /// Helper to build venue detail path.
  static String venueDetailPath(String id) => '/venue/$id';

  /// Helper to build player stats path.
  static String playerStatsPath(String id) => '/player/$id/stats';
}

/// Creates the app's GoRouter with auth-based redirect.
GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isLoggedIn = authProvider.isLoggedIn;
      final location = state.matchedLocation;
      final isSplash = location == AppRoutes.splash;
      final isLogin = location == AppRoutes.login;
      final isOnboarding = location == AppRoutes.onboarding;
      final isWelcome = location == AppRoutes.welcomeFlow;

      // Allow splash to handle its own flow
      if (isSplash) return null;

      // Allow onboarding without auth
      if (isOnboarding) return null;

      // Public routes: accessible without auth
      if (AppRoutes.isPublicRoute(location)) return null;

      // Login page: allow if not logged in, redirect to home if logged in
      if (isLogin) return isLoggedIn ? AppRoutes.home : null;

      // Welcome flow: only for authenticated first-login users
      if (isWelcome) return isLoggedIn ? null : AppRoutes.explore;

      // Not logged in -> redirect to explore (not login!)
      if (!isLoggedIn) {
        return AppRoutes.explore;
      }

      // First login -> redirect to welcome flow
      if (authProvider.isFirstLogin && !isWelcome) {
        return AppRoutes.welcomeFlow;
      }

      // Role-based route guards
      if (location == '/session/create' ||
          location.endsWith('/edit') ||
          location.endsWith('/scoring')) {
        if (!authProvider.canManageSessions) {
          return AppRoutes.home;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeShell(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/session/create',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const CreateSessionScreen(),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: '/session/:id',
        pageBuilder: (context, state) {
          final sessionId = state.pathParameters['id'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: SessionDetailScreen(sessionId: sessionId),
            transitionsBuilder: _slideUpTransition,
          );
        },
        routes: [
          GoRoute(
            path: 'edit',
            pageBuilder: (context, state) {
              // EditSessionScreen takes a SessionModel via extra
              final session = state.extra as SessionModel?;
              if (session != null) {
                return CustomTransitionPage(
                  key: state.pageKey,
                  child: EditSessionScreen(session: session),
                  transitionsBuilder: _slideUpTransition,
                );
              }
              // Fallback: go back to session detail
              return CustomTransitionPage(
                key: state.pageKey,
                child: SessionDetailScreen(
                    sessionId: state.pathParameters['id'] ?? ''),
                transitionsBuilder: _slideUpTransition,
              );
            },
          ),
          GoRoute(
            path: 'pay',
            pageBuilder: (context, state) {
              // PaymentUploadScreen takes a SessionModel via extra
              final session = state.extra as SessionModel?;
              if (session != null) {
                return CustomTransitionPage(
                  key: state.pageKey,
                  child: PaymentUploadScreen(session: session),
                  transitionsBuilder: _slideUpTransition,
                );
              }
              return CustomTransitionPage(
                key: state.pageKey,
                child: SessionDetailScreen(
                    sessionId: state.pathParameters['id'] ?? ''),
                transitionsBuilder: _slideUpTransition,
              );
            },
          ),
          GoRoute(
            path: 'scoring',
            pageBuilder: (context, state) {
              final sessionId = state.pathParameters['id'] ?? '';
              return CustomTransitionPage(
                key: state.pageKey,
                child: DeferredLoader(
                  loadLibrary: scoring.loadLibrary,
                  builder: (_) => scoring.MatchScoringScreen(sessionId: sessionId),
                ),
                transitionsBuilder: _slideUpTransition,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const EditProfileScreen(),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.notificationCenter,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const NotificationCenterScreen(),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: DeferredLoader(
            loadLibrary: leaderboard.loadLibrary,
            builder: (_) => leaderboard.LeaderboardScreen(),
          ),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.sessionHistory,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SessionHistoryScreen(),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: '/venue/:id',
        pageBuilder: (context, state) {
          final venueId = state.pathParameters['id'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: DeferredLoader(
              loadLibrary: venue_detail.loadLibrary,
              builder: (_) => venue_detail.VenueDetailScreen(venueId: venueId),
            ),
            transitionsBuilder: _slideUpTransition,
          );
        },
      ),
      GoRoute(
        path: '/player/:id/stats',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['id'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: DeferredLoader(
              loadLibrary: player_stats.loadLibrary,
              builder: (_) => player_stats.PlayerStatsScreen(userId: userId),
            ),
            transitionsBuilder: _slideUpTransition,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.kta,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: DeferredLoader(
            loadLibrary: kta.loadLibrary,
            builder: (_) => kta.KtaDigitalScreen(),
          ),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.partnerList,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: DeferredLoader(
            loadLibrary: partners.loadLibrary,
            builder: (_) => partners.PartnerListScreen(),
          ),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.chipsHistory,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: DeferredLoader(
            loadLibrary: chips.loadLibrary,
            builder: (_) => chips.ChipsHistoryScreen(),
          ),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.awardsShowcase,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: DeferredLoader(
            loadLibrary: awards.loadLibrary,
            builder: (_) => awards.AwardsShowcaseScreen(),
          ),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.redemptions,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: DeferredLoader(
            loadLibrary: redemption.loadLibrary,
            builder: (_) => redemption.RedemptionScreen(),
          ),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.referral,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: DeferredLoader(
            loadLibrary: referral.loadLibrary,
            builder: (_) => referral.ReferralScreen(),
          ),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.joinReferral,
        redirect: (context, state) {
          final code = state.uri.queryParameters['ref'];
          if (code != null && code.isNotEmpty) {
            return '${AppRoutes.referral}?ref=$code';
          }
          return AppRoutes.home;
        },
      ),
      GoRoute(
        path: AppRoutes.explore,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: DeferredLoader(
            loadLibrary: explore.loadLibrary,
            builder: (_) => explore.ExploreScreen(),
          ),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.welcomeFlow,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: DeferredLoader(
            loadLibrary: welcome.loadLibrary,
            builder: (_) => welcome.WelcomeFlowScreen(),
          ),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/member/:id',
        pageBuilder: (context, state) {
          final memberId = state.pathParameters['id'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: DeferredLoader(
              loadLibrary: public_profile.loadLibrary,
              builder: (_) => public_profile.PublicProfileScreen(userId: memberId),
            ),
            transitionsBuilder: _slideUpTransition,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFFDADDD6),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFA3543A)),
            const SizedBox(height: 16),
            Text(
              'Halaman tidak ditemukan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C1F1D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.uri}',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF8A8D8B),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(opacity: animation, child: child);
}

Widget _slideUpTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final tween = Tween(begin: const Offset(0, 0.15), end: Offset.zero)
      .chain(CurveTween(curve: Curves.easeOutCubic));
  return SlideTransition(
    position: animation.drive(tween),
    child: FadeTransition(opacity: animation, child: child),
  );
}
