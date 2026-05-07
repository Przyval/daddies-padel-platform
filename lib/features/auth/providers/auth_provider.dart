import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daddies_app/models/user_model.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/core/services/app_logger.dart';
import 'package:daddies_app/core/services/analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  fb.FirebaseAuth? _firebaseAuth;
  GoogleSignIn? _googleSignIn;

  fb.FirebaseAuth get _auth {
    _firebaseAuth ??= fb.FirebaseAuth.instance;
    return _firebaseAuth!;
  }

  GoogleSignIn get _google {
    _googleSignIn ??= GoogleSignIn();
    return _googleSignIn!;
  }

  static const _phoneKey = 'auth_phone';

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isGuestBrowsing = false;
  bool _isFirstLogin = false;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isGuest => _isGuestBrowsing && _currentUser == null;
  bool get canBrowse => isLoggedIn || isGuest;
  bool get isFirstLogin => _isFirstLogin;

  /// Route path after successful login, considering first-login status.
  String get postLoginRoute => _isFirstLogin ? '/welcome' : '/home';

  bool get isSuperAdmin =>
      _currentUser != null && _currentUser!.role == UserRole.superAdmin;
  bool get isMimin =>
      _currentUser != null && _currentUser!.role == UserRole.mimin;
  bool get isBendahara =>
      _currentUser != null && _currentUser!.role == UserRole.bendahara;
  bool get isMember =>
      _currentUser != null && _currentUser!.role == UserRole.member;

  bool get canManageSessions => isSuperAdmin || isMimin;
  bool get canManageFinance => isSuperAdmin || isBendahara;

  /// Enter guest browsing mode (no account needed).
  void browseAsGuest() {
    _isGuestBrowsing = true;
    notifyListeners();
  }

  /// Clear first-login flag after welcome flow completes.
  void clearFirstLogin() {
    _isFirstLogin = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Session Restoration (P0.5)
  // ---------------------------------------------------------------------------

  /// Try to restore a previous session. Returns true if a session was restored.
  Future<bool> restoreSession() async {
    // 1. Check Firebase Auth for social login persistence
    final fbUser = _auth.currentUser;
    if (fbUser != null) {
      _currentUser = _mapFirebaseUser(
        fbUser,
        fbUser.displayName ?? fbUser.email ?? 'User',
      );
      notifyListeners();
      return true;
    }

    // 2. Check SharedPreferences for phone login persistence
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString(_phoneKey);
      if (phone != null && phone.isNotEmpty) {
        final user = DataService().getUserByPhone(phone);
        if (user != null) {
          _currentUser = user;
          notifyListeners();
          return true;
        }
        // Stored phone no longer matches a user — clear stale data
        await prefs.remove(_phoneKey);
      }
    } catch (e) {
      AppLogger.w('AuthProvider', 'restoreSession prefs error', error: e);
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Phone + Password Login (demo)
  // ---------------------------------------------------------------------------

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Ensure DataService is initialized (may have been cleared on logout)
      final ds = DataService();
      if (!ds.isInitialized) {
        await ds.initialize();
      }

      // Double-check: if users are still empty after init, force re-initialize
      if (ds.users.isEmpty) {
        ds.clearCache();
        await ds.initialize();
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));

      if (password != 'daddies') {
        _errorMessage = 'Password salah. Hint: daddies';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final user = ds.getUserByPhone(phone);
      if (user == null) {
        _errorMessage = 'Nomor telepon tidak ditemukan.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = user;
      _isLoading = false;

      // Persist phone for session restoration
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_phoneKey, phone);
      } catch (_) {}

      _trackLogin('phone');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await _google.signIn();

      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final fb.UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      _currentUser = _mapFirebaseUser(
        userCredential.user!,
        googleUser.displayName ?? googleUser.email,
      );

      _trackLogin('google');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.e('AuthProvider', 'Google sign-in failed', error: e);
      _errorMessage = 'Google sign-in gagal. Coba lagi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Facebook Sign-In
  // ---------------------------------------------------------------------------

  Future<bool> signInWithFacebook() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.cancelled) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (result.status != LoginStatus.success) {
        _errorMessage = 'Facebook sign-in gagal.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final fb.OAuthCredential credential =
          fb.FacebookAuthProvider.credential(result.accessToken!.tokenString);

      final fb.UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final userData = await FacebookAuth.instance.getUserData();

      _currentUser = _mapFirebaseUser(
        userCredential.user!,
        userData['name'] as String? ?? userCredential.user!.email ?? 'User',
      );

      _trackLogin('facebook');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.e('AuthProvider', 'Facebook sign-in failed', error: e);
      _errorMessage = 'Facebook sign-in gagal. Coba lagi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  UserModel _mapFirebaseUser(fb.User firebaseUser, String displayName) {
    final phone = firebaseUser.phoneNumber ?? '';

    // Try to match existing user by phone
    UserModel? matched;
    if (phone.isNotEmpty) {
      matched = DataService().getUserByPhone(phone);
    }
    if (matched != null) {
      _isFirstLogin = false;
      return matched;
    }

    // New user from social sign-in — mark as first login
    _isFirstLogin = true;
    _isGuestBrowsing = false;

    final newUser = UserModel(
      id: firebaseUser.uid,
      name: displayName,
      phone: firebaseUser.phoneNumber ?? firebaseUser.email ?? '',
      role: UserRole.member,
      createdAt: DateTime.now(),
    );

    // Persist new user to Firestore
    DataService().addUser(newUser);

    return newUser;
  }

  // ---------------------------------------------------------------------------
  // Profile Update
  // ---------------------------------------------------------------------------

  Future<bool> updateProfile({
    required String name,
    required String phone,
    String? nickname,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = _currentUser!.copyWith(
        name: name,
        phone: phone,
        nickname: nickname,
        bio: bio,
        avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
      );
      await DataService().updateUser(updated);

      _currentUser = updated;

      // Update persisted phone
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_phoneKey, phone);
      } catch (_) {}

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui profil. Coba lagi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  Future<void> logout() async {
    try {
      await _auth.signOut();
      await _google.signOut();
    } catch (_) {}

    // Clear persisted phone login
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_phoneKey);
    } catch (_) {}

    // Clear data cache
    DataService().clearCache();

    AnalyticsService.instance.logLogout();
    AnalyticsService.instance.clearUser();

    _currentUser = null;
    _errorMessage = null;
    _isGuestBrowsing = false;
    _isFirstLogin = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _trackLogin(String method) {
    final user = _currentUser;
    if (user == null) return;
    final analytics = AnalyticsService.instance;
    analytics.setUser(userId: user.id, role: user.role.name);
    analytics.logLogin(method: method);
  }
}
