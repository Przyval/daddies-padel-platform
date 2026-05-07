import 'package:go_router/go_router.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/core/services/app_logger.dart';

/// Parses and handles deep links for the Daddies Padel Platform.
///
/// Supported link patterns:
/// - `daddiespadel.com/session/{id}` → session detail
/// - `daddiespadel.com/join?ref=CODE` → referral code
/// - `daddiespadel.com/invite?session={id}` → session invite
class DeepLinkService {
  DeepLinkService._();

  static const _tag = 'DeepLink';

  /// Stores a deferred deep link when the user isn't logged in yet.
  /// After login, call [consumeDeferredLink] to navigate.
  static String? _deferredLink;

  /// Whether there is a pending deferred deep link.
  static bool get hasDeferredLink => _deferredLink != null;

  /// Stores a link for deferred navigation (pre-login).
  static void storeDeferredLink(String link) {
    AppLogger.i(_tag, 'Stored deferred deep link: $link');
    _deferredLink = link;
  }

  /// Consumes and navigates to the deferred deep link, if any.
  /// Returns true if a link was consumed.
  static bool consumeDeferredLink() {
    final link = _deferredLink;
    if (link == null) return false;
    _deferredLink = null;
    AppLogger.i(_tag, 'Consuming deferred deep link: $link');
    return handleLink(link);
  }

  /// Parses an incoming deep link URI and navigates accordingly.
  /// Returns true if the link was recognized and handled.
  static bool handleLink(String link) {
    try {
      final uri = Uri.tryParse(link);
      if (uri == null) return false;

      final router = globalRouter;
      if (router == null) {
        // Router not ready yet — defer it
        storeDeferredLink(link);
        return false;
      }

      return _handleUri(uri, router);
    } catch (e) {
      AppLogger.e(_tag, 'Failed to handle deep link', error: e);
      return false;
    }
  }

  static bool _handleUri(Uri uri, GoRouter router) {
    final path = uri.path;
    final params = uri.queryParameters;

    // Pattern: /join?ref=CODE (referral)
    if (path == '/join' && params.containsKey('ref')) {
      final code = params['ref']!;
      AppLogger.i(_tag, 'Referral deep link: code=$code');
      router.go('${AppRoutes.referral}?ref=$code');
      return true;
    }

    // Pattern: /invite?session=ID (session invite)
    if (path == '/invite' && params.containsKey('session')) {
      final sessionId = params['session']!;
      AppLogger.i(_tag, 'Session invite deep link: session=$sessionId');
      router.go(AppRoutes.sessionDetailPath(sessionId));
      return true;
    }

    // Pattern: /session/{id}
    if (path.startsWith('/session/') && !path.contains('/create')) {
      final sessionId = path.replaceFirst('/session/', '');
      if (sessionId.isNotEmpty) {
        AppLogger.i(_tag, 'Session deep link: id=$sessionId');
        router.go(AppRoutes.sessionDetailPath(sessionId));
        return true;
      }
    }

    // Pattern: /member/{id} (public profile)
    if (path.startsWith('/member/')) {
      final memberId = path.replaceFirst('/member/', '');
      if (memberId.isNotEmpty) {
        AppLogger.i(_tag, 'Member profile deep link: id=$memberId');
        router.go(AppRoutes.memberProfilePath(memberId));
        return true;
      }
    }

    // Pattern: /explore
    if (path == '/explore') {
      router.go(AppRoutes.explore);
      return true;
    }

    // Pattern: /chips
    if (path == '/chips') {
      router.go(AppRoutes.chipsHistory);
      return true;
    }

    // Pattern: /awards
    if (path == '/awards') {
      router.go(AppRoutes.awardsShowcase);
      return true;
    }

    // Pattern: /kta
    if (path == '/kta') {
      router.go(AppRoutes.kta);
      return true;
    }

    AppLogger.w(_tag, 'Unrecognized deep link: $uri');
    return false;
  }

  /// Generates a shareable referral link.
  static String buildReferralLink(String code) {
    return 'https://daddiespadel.com/join?ref=$code';
  }

  /// Generates a shareable session invite link.
  static String buildSessionInviteLink(String sessionId) {
    return 'https://daddiespadel.com/invite?session=$sessionId';
  }

  /// Generates a shareable member profile link.
  static String buildMemberProfileLink(String userId) {
    return 'https://daddiespadel.com/member/$userId';
  }
}
