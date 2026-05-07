import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:daddies_app/models/referral_model.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/services/data_service.dart';

class ReferralProvider extends ChangeNotifier {
  final DataService _dataService = DataService();
  final Uuid _uuid = const Uuid();

  bool _isBusy = false;
  String? _errorMessage;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Referral Code Generation
  // ---------------------------------------------------------------------------

  /// Returns the user's existing referral code, or generates a new one.
  ///
  /// Format: `NAME-DDS-XXXX` where NAME is first 3 chars of the uppercase
  /// name and XXXX is 4 random alphanumeric characters.
  String getOrCreateReferralCode(String userId, String userName) {
    final user = _dataService.getUserById(userId);
    if (user != null && user.referralCode != null) {
      return user.referralCode!;
    }

    // Generate code: first 3 chars of uppercase name + "-DDS-" + 4 random
    final namePrefix = userName
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .padRight(3, 'X')
        .substring(0, 3);

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    final suffix = String.fromCharCodes(
      List.generate(4, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
    );

    final code = '$namePrefix-DDS-$suffix';

    // Persist to user
    if (user != null) {
      final updatedUser = user.copyWith(referralCode: code);
      _dataService.updateUser(updatedUser);
    }

    notifyListeners();
    return code;
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// Returns all referrals created by the given user, excluding soft-deleted.
  List<ReferralModel> getReferralsForUser(String userId) {
    return _dataService.referrals
        .where((r) => r.referrerId == userId && !r.isDeleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Returns all referrals where the given user is the referee.
  List<ReferralModel> getReferredByUser(String userId) {
    return _dataService.referrals
        .where((r) => r.refereeId == userId && !r.isDeleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ---------------------------------------------------------------------------
  // Apply Referral Code
  // ---------------------------------------------------------------------------

  /// Applies a referral code for a new user.
  ///
  /// Validates the code exists, is still pending, and the new user is not the
  /// referrer themselves. Updates the referral with the referee info and sets
  /// the new user's `referredBy` field. Does NOT complete the referral — that
  /// happens after the referee's first session via [checkReferralCompletion].
  Future<bool> applyReferralCode(
    String code,
    String newUserId,
    String newUserName,
  ) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Find the referral by code
      final referral = _dataService.referrals.cast<ReferralModel?>().firstWhere(
        (r) => r!.referralCode == code && !r.isDeleted,
        orElse: () => null,
      );

      if (referral == null) {
        _errorMessage = 'Kode referral tidak ditemukan.';
        _isBusy = false;
        notifyListeners();
        return false;
      }

      if (referral.status != ReferralStatus.pending) {
        _errorMessage = 'Kode referral sudah tidak berlaku.';
        _isBusy = false;
        notifyListeners();
        return false;
      }

      if (referral.referrerId == newUserId) {
        _errorMessage = 'Tidak bisa menggunakan kode referral sendiri.';
        _isBusy = false;
        notifyListeners();
        return false;
      }

      // Update referral with referee info
      final updatedReferral = referral.copyWith(
        refereeId: newUserId,
        refereeName: newUserName,
      );
      await _dataService.updateReferral(updatedReferral);

      // Update new user's referredBy field
      final newUser = _dataService.getUserById(newUserId);
      if (newUser != null) {
        final updatedUser = newUser.copyWith(referredBy: code);
        await _dataService.updateUser(updatedUser);
      }

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menerapkan kode referral. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Referral Completion Check
  // ---------------------------------------------------------------------------

  /// Checks whether a referred user has completed their first session.
  ///
  /// If so, marks the referral as completed and awards bonus chips to both
  /// the referrer and the referee.
  Future<bool> checkReferralCompletion(String userId) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _dataService.getUserById(userId);
      if (user == null || user.referredBy == null) {
        _isBusy = false;
        notifyListeners();
        return false;
      }

      // Find the referral for this user
      final referral = _dataService.referrals.cast<ReferralModel?>().firstWhere(
        (r) =>
            r!.refereeId == userId &&
            r.status == ReferralStatus.pending &&
            !r.isDeleted,
        orElse: () => null,
      );

      if (referral == null) {
        _isBusy = false;
        notifyListeners();
        return false;
      }

      // Check if user has completed at least one session
      final userSlots = _dataService.getSlotsForUser(userId);
      final hasCompletedSession = userSlots.any((slot) {
        if (!slot.didAttend) return false;
        final session = _dataService.getSessionById(slot.sessionId);
        return session != null &&
            session.status == SessionStatus.completed;
      });

      if (!hasCompletedSession) {
        _isBusy = false;
        notifyListeners();
        return false;
      }

      // Mark referral as completed
      final completedReferral = referral.copyWith(
        status: ReferralStatus.completed,
        completedAt: DateTime.now(),
      );
      await _dataService.updateReferral(completedReferral);

      // Award chips to referrer
      final referrer = _dataService.getUserById(referral.referrerId);
      if (referrer != null) {
        final updatedReferrer = referrer.copyWith(
          chipsBalance: referrer.chipsBalance + referral.referrerBonus,
        );
        await _dataService.updateUser(updatedReferrer);
      }

      // Award chips to referee
      final updatedReferee = user.copyWith(
        chipsBalance: user.chipsBalance + referral.refereeBonus,
      );
      await _dataService.updateUser(updatedReferee);

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyelesaikan referral. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Session-level Referral Completion
  // ---------------------------------------------------------------------------

  /// Checks all attendees of a completed session for referral eligibility.
  Future<void> checkReferralCompletionForSession(String sessionId) async {
    final slots = _dataService.getSlotsForSession(sessionId);
    final attendedUserIds = slots
        .where((s) => s.didAttend)
        .map((s) => s.userId)
        .toList();

    for (final userId in attendedUserIds) {
      await checkReferralCompletion(userId);
    }
  }

  // ---------------------------------------------------------------------------
  // Create Referral
  // ---------------------------------------------------------------------------

  /// Creates a new pending referral entry for a referral code.
  Future<bool> createReferral(
    String referrerId,
    String referrerName,
    String referralCode,
  ) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final referral = ReferralModel(
        id: _uuid.v4(),
        referrerId: referrerId,
        referrerName: referrerName,
        referralCode: referralCode,
        status: ReferralStatus.pending,
        createdAt: DateTime.now(),
      );

      await _dataService.addReferral(referral);

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal membuat referral. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }
}
