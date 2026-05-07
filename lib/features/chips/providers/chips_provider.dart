import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:daddies_app/models/chips_transaction_model.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/models/user_model.dart';
import 'package:daddies_app/services/data_service.dart';

class ChipsProvider extends ChangeNotifier {
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
  // Getters
  // ---------------------------------------------------------------------------

  /// Returns the chips balance for the given user from DataService cache.
  int getBalance(String userId) {
    final user = _dataService.getUserById(userId);
    return user?.chipsBalance ?? 0;
  }

  /// Returns all chips transactions for a specific user, sorted newest first.
  List<ChipsTransactionModel> getTransactionsForUser(String userId) {
    final all = _dataService.chipsTransactions
        .where((t) => t.userId == userId && !t.isDeleted)
        .toList();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  /// Returns all users sorted by chipsBalance descending (leaderboard).
  List<UserModel> getChipsLeaderboard() {
    final allUsers = List<UserModel>.from(_dataService.users);
    allUsers.sort((a, b) => b.chipsBalance.compareTo(a.chipsBalance));
    return allUsers;
  }

  // ---------------------------------------------------------------------------
  // Award Chips (generic)
  // ---------------------------------------------------------------------------

  /// Awards (or deducts) chips for a user.
  ///
  /// Creates a [ChipsTransactionModel], persists it via DataService, and
  /// updates the user's denormalized chipsBalance.
  Future<bool> awardChips({
    required String userId,
    required String userName,
    required int amount,
    required ChipsSource source,
    required String description,
    String? sessionId,
    String? matchResultId,
  }) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _dataService.getUserById(userId);
      final currentBalance = user?.chipsBalance ?? 0;
      final balanceAfter = currentBalance + amount;

      final ChipsTransactionType type;
      if (source == ChipsSource.adminAdjust) {
        type = ChipsTransactionType.adjustment;
      } else if (source == ChipsSource.streak3 ||
          source == ChipsSource.streak5 ||
          source == ChipsSource.firstSession) {
        type = ChipsTransactionType.bonus;
      } else if (amount < 0) {
        type = ChipsTransactionType.spent;
      } else {
        type = ChipsTransactionType.earned;
      }

      final txn = ChipsTransactionModel(
        id: _uuid.v4(),
        userId: userId,
        userName: userName,
        amount: amount,
        balanceAfter: balanceAfter,
        type: type,
        source: source,
        description: description,
        sessionId: sessionId,
        matchResultId: matchResultId,
        createdAt: DateTime.now(),
      );

      // Atomic: write transaction + update balance in a single Firestore
      // transaction to prevent TOCTOU races on concurrent awards.
      await _dataService.awardChipsAtomic(
        txn: txn,
        userId: userId,
        amount: amount,
      );

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memberikan chips. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Session Completion Chips
  // ---------------------------------------------------------------------------

  /// Awards chips for attending a completed session.
  ///
  /// Each attended slot earns [ChipsSource.sessionAttendance] (+10).
  /// Additionally checks consecutive session streaks:
  /// - 3 consecutive sessions: +15 bonus
  /// - 5 consecutive sessions: +30 bonus
  /// First-ever session earns a [ChipsSource.firstSession] (+20) bonus.
  Future<bool> awardSessionCompletionChips(String sessionId) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final slots = _dataService.getSlotsForSession(sessionId);
      final attendedSlots = slots.where((s) => s.didAttend).toList();

      for (final slot in attendedSlots) {
        // Base attendance chips
        await awardChips(
          userId: slot.userId,
          userName: slot.userName,
          amount: ChipsTransactionModel.chipsForSource(
              ChipsSource.sessionAttendance),
          source: ChipsSource.sessionAttendance,
          description: 'Kehadiran sesi',
          sessionId: sessionId,
        );

        // Check if this is the user's first session ever
        final userSlots = _dataService.getSlotsForUser(slot.userId);
        final completedAttendedSlots = userSlots.where((s) {
          if (!s.didAttend) return false;
          final session = _dataService.getSessionById(s.sessionId);
          return session != null &&
              session.status == SessionStatus.completed;
        }).toList();

        if (completedAttendedSlots.length == 1) {
          await awardChips(
            userId: slot.userId,
            userName: slot.userName,
            amount:
                ChipsTransactionModel.chipsForSource(ChipsSource.firstSession),
            source: ChipsSource.firstSession,
            description: 'Bonus sesi pertama!',
            sessionId: sessionId,
          );
        }

        // Check consecutive session streak
        final streak = _getConsecutiveStreak(slot.userId);
        if (streak >= 5) {
          await awardChips(
            userId: slot.userId,
            userName: slot.userName,
            amount:
                ChipsTransactionModel.chipsForSource(ChipsSource.streak5),
            source: ChipsSource.streak5,
            description: 'Streak 5 sesi berturut-turut!',
            sessionId: sessionId,
          );
        } else if (streak >= 3) {
          await awardChips(
            userId: slot.userId,
            userName: slot.userName,
            amount:
                ChipsTransactionModel.chipsForSource(ChipsSource.streak3),
            source: ChipsSource.streak3,
            description: 'Streak 3 sesi berturut-turut!',
            sessionId: sessionId,
          );
        }
      }

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memberikan chips sesi. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  /// Counts how many of the most recent completed sessions (by date) this
  /// user attended consecutively.
  int _getConsecutiveStreak(String userId) {
    final allSessions = _dataService.sessions
        .where((s) => s.status == SessionStatus.completed)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    int streak = 0;
    for (final session in allSessions) {
      final slots = _dataService.getSlotsForSession(session.id);
      final attended =
          slots.any((s) => s.userId == userId && s.didAttend);
      if (attended) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // ---------------------------------------------------------------------------
  // Match Chips
  // ---------------------------------------------------------------------------

  /// Awards chips for match results.
  ///
  /// Winners receive [ChipsSource.matchWin] (+5) or [ChipsSource.matchDraw] (+2).
  /// If staking is enabled, winners gain and losers lose the stake amount.
  Future<bool> awardMatchChips({
    required String matchResultId,
    required String sessionId,
    required List<String> winnerIds,
    required List<String> winnerNames,
    required List<String> loserIds,
    required List<String> loserNames,
    required bool isDraw,
    required bool stakingEnabled,
    required int stakeAmount,
  }) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (isDraw) {
        // Both teams get draw chips
        final allIds = [...winnerIds, ...loserIds];
        final allNames = [...winnerNames, ...loserNames];
        for (int i = 0; i < allIds.length; i++) {
          await awardChips(
            userId: allIds[i],
            userName: allNames[i],
            amount:
                ChipsTransactionModel.chipsForSource(ChipsSource.matchDraw),
            source: ChipsSource.matchDraw,
            description: 'Hasil seri pertandingan',
            sessionId: sessionId,
            matchResultId: matchResultId,
          );
        }
      } else {
        // Winners get matchWin chips
        for (int i = 0; i < winnerIds.length; i++) {
          await awardChips(
            userId: winnerIds[i],
            userName: winnerNames[i],
            amount:
                ChipsTransactionModel.chipsForSource(ChipsSource.matchWin),
            source: ChipsSource.matchWin,
            description: 'Menang pertandingan',
            sessionId: sessionId,
            matchResultId: matchResultId,
          );
        }
      }

      // Staking: winners gain, losers lose
      if (stakingEnabled && stakeAmount > 0 && !isDraw) {
        for (int i = 0; i < winnerIds.length; i++) {
          await awardChips(
            userId: winnerIds[i],
            userName: winnerNames[i],
            amount: stakeAmount,
            source: ChipsSource.stakeWin,
            description: 'Staking menang (+$stakeAmount chips)',
            sessionId: sessionId,
            matchResultId: matchResultId,
          );
        }
        for (int i = 0; i < loserIds.length; i++) {
          await awardChips(
            userId: loserIds[i],
            userName: loserNames[i],
            amount: -stakeAmount,
            source: ChipsSource.stakeLoss,
            description: 'Staking kalah (-$stakeAmount chips)',
            sessionId: sessionId,
            matchResultId: matchResultId,
          );
        }
      }

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memberikan chips pertandingan. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Admin Adjustment
  // ---------------------------------------------------------------------------

  /// Manual admin adjustment of a user's chips balance.
  Future<bool> adjustChips(String userId, int amount, String reason) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _dataService.getUserById(userId);
      if (user == null) {
        _errorMessage = 'User tidak ditemukan.';
        _isBusy = false;
        notifyListeners();
        return false;
      }

      await awardChips(
        userId: userId,
        userName: user.name,
        amount: amount,
        source: ChipsSource.adminAdjust,
        description: 'Penyesuaian admin: $reason',
      );

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyesuaikan chips. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }
}
