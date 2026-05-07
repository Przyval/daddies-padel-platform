import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:daddies_app/core/services/app_logger.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import 'package:daddies_app/firebase_options.dart';
import 'package:daddies_app/core/theme/app_theme.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/features/sessions/providers/session_provider.dart';
import 'package:daddies_app/features/finance/providers/finance_provider.dart';
import 'package:daddies_app/features/member/providers/member_provider.dart';
import 'package:daddies_app/features/chips/providers/chips_provider.dart';
import 'package:daddies_app/features/awards/providers/award_provider.dart';
import 'package:daddies_app/features/redemption/providers/redemption_provider.dart';
import 'package:daddies_app/features/referral/providers/referral_provider.dart';
import 'package:daddies_app/core/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Crashlytics not supported on web
    if (!kIsWeb) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (e) {
    AppLogger.e('Main', 'Firebase init failed', error: e);
  }
  await initializeDateFormatting('id_ID', null);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Run app immediately — heavy services init in SplashScreen
  runApp(const DaddiesApp());
}

class DaddiesApp extends StatelessWidget {
  const DaddiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DataService()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, SessionProvider>(
          create: (ctx) => SessionProvider(ctx.read<AuthProvider>()),
          update: (_, auth, prev) => prev!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, FinanceProvider>(
          create: (ctx) => FinanceProvider(ctx.read<AuthProvider>()),
          update: (_, auth, prev) => prev!..updateAuth(auth),
        ),
        ChangeNotifierProvider(create: (_) => MemberProvider()),
        ChangeNotifierProvider(create: (_) => ChipsProvider()),
        ChangeNotifierProvider(create: (_) => AwardProvider()),
        ChangeNotifierProvider(create: (_) => RedemptionProvider()),
        ChangeNotifierProvider(create: (_) => ReferralProvider()),
      ],
      child: _AppWithRouter(),
    );
  }
}

/// Separate widget so we can access AuthProvider from context to build the router.
class _AppWithRouter extends StatefulWidget {
  @override
  State<_AppWithRouter> createState() => _AppWithRouterState();
}

/// Disables the Android 12+ stretch overscroll; uses classic clamping instead.
class _NoStretchScrollBehavior extends ScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
      child: child,
    );
  }
}

class _AppWithRouterState extends State<_AppWithRouter> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    _router ??= createRouter(context.read<AuthProvider>());
    globalRouter = _router;
    final themeMode = context.watch<ThemeProvider>().themeMode;

    return MaterialApp.router(
      title: 'Daddies Padel',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _NoStretchScrollBehavior(),
      routerConfig: _router!,
    );
  }
}
