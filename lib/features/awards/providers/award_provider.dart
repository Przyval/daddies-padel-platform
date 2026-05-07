import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:daddies_app/models/award_model.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/services/data_service.dart';

class AwardProvider extends ChangeNotifier {
  final DataService _dataService = DataService();
  final Uuid _uuid = const Uuid();

  bool _isBusy = false;
  String? _errorMessage;

  // ---------------------------------------------------------------------------
  // In-memory awards cache (until DataService adds native awards support)
  // ---------------------------------------------------------------------------
  final List<AwardModel> _awards = [];

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  List<AwardModel> get awards => List.unmodifiable(_awards);

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Returns all awards for a specific user.
  List<AwardModel> getAwardsForUser(String userId) {
    return _awards
        .where((a) => a.userId == userId && !a.isDeleted)
        .toList();
  }

  /// Checks if a user has a specific award type.
  bool hasAward(String userId, AwardType type) {
    return _awards.any(
      (a) => a.userId == userId && a.type == type && !a.isDeleted,
    );
  }

  /// Returns all awards for a given period string (e.g. "2026-02", "2026-Q1").
  List<AwardModel> getAwardsForPeriod(String period) {
    return _awards
        .where((a) => a.period == period && !a.isDeleted)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Compute monthly awards from DataService cache data
  // ---------------------------------------------------------------------------

  /// Computes awards for a given year/month based on session and slot data.
  ///
  /// Awards computed:
  /// - rookieOfMonth: user who joined (createdAt) within the month and attended most sessions
  /// - topAttendance: user with the most attended sessions in the month
  /// - loyalOne: user with the longest consecutive session streak
  /// - mostImproved: user whose session count grew most vs the previous month
  Future<List<AwardModel>> computeMonthlyAwards(int year, int month) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final period = '$year-${month.toString().padLeft(2, '0')}';
      final computed = <AwardModel>[];

      final users = _dataService.users;
      final sessions = _dataService.sessions;
      final slots = _dataService.slots;

      // Completed sessions within the target month
      final monthlySessions = sessions.where((s) =>
          s.status == SessionStatus.completed &&
          s.date.year == year &&
          s.date.month == month).toList();

      final monthlySessionIds = monthlySessions.map((s) => s.id).toSet();

      // -----------------------------------------------------------------------
      // Helper: count attended sessions for a user in a set of session IDs
      // -----------------------------------------------------------------------
      int attendedCount(String userId, Set<String> sessionIds) {
        return slots
            .where((s) =>
                s.userId == userId &&
                sessionIds.contains(s.sessionId) &&
                s.didAttend)
            .length;
      }

      // -----------------------------------------------------------------------
      // 1. Rookie of the Month
      //    User who joined (createdAt) within the month and attended most sessions.
      // -----------------------------------------------------------------------
      final rookies = users.where((u) =>
          u.createdAt.year == year && u.createdAt.month == month);

      if (rookies.isNotEmpty) {
        String? bestRookieId;
        String bestRookieName = '';
        int bestRookieCount = 0;

        for (final rookie in rookies) {
          final count = attendedCount(rookie.id, monthlySessionIds);
          if (count > bestRookieCount) {
            bestRookieCount = count;
            bestRookieId = rookie.id;
            bestRookieName = rookie.name;
          }
        }

        if (bestRookieId != null && bestRookieCount > 0) {
          computed.add(AwardModel(
            id: _uuid.v4(),
            userId: bestRookieId,
            userName: bestRookieName,
            type: AwardType.rookieOfMonth,
            period: period,
            value: bestRookieCount,
            description:
                '$bestRookieName bergabung bulan ini dan menghadiri $bestRookieCount sesi',
            awardedAt: DateTime.now(),
          ));
        }
      }

      // -----------------------------------------------------------------------
      // 2. Top Attendance
      //    User with the most attended sessions in the month.
      // -----------------------------------------------------------------------
      String? topAttendanceId;
      String topAttendanceName = '';
      int topAttendanceCount = 0;

      for (final user in users) {
        final count = attendedCount(user.id, monthlySessionIds);
        if (count > topAttendanceCount) {
          topAttendanceCount = count;
          topAttendanceId = user.id;
          topAttendanceName = user.name;
        }
      }

      if (topAttendanceId != null && topAttendanceCount > 0) {
        computed.add(AwardModel(
          id: _uuid.v4(),
          userId: topAttendanceId,
          userName: topAttendanceName,
          type: AwardType.topAttendance,
          period: period,
          value: topAttendanceCount,
          description:
              '$topAttendanceName menghadiri $topAttendanceCount sesi bulan ini',
          awardedAt: DateTime.now(),
        ));
      }

      // -----------------------------------------------------------------------
      // 3. The Loyal One
      //    User with the longest consecutive session streak (by session date order).
      // -----------------------------------------------------------------------
      final allCompleted = sessions
          .where((s) => s.status == SessionStatus.completed)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      String? loyalId;
      String loyalName = '';
      int longestStreak = 0;

      for (final user in users) {
        final userSlotSessionIds = slots
            .where((s) => s.userId == user.id && s.didAttend)
            .map((s) => s.sessionId)
            .toSet();

        int currentStreak = 0;
        int maxStreak = 0;

        for (final session in allCompleted) {
          if (userSlotSessionIds.contains(session.id)) {
            currentStreak++;
            if (currentStreak > maxStreak) maxStreak = currentStreak;
          } else {
            currentStreak = 0;
          }
        }

        if (maxStreak > longestStreak) {
          longestStreak = maxStreak;
          loyalId = user.id;
          loyalName = user.name;
        }
      }

      if (loyalId != null && longestStreak > 0) {
        computed.add(AwardModel(
          id: _uuid.v4(),
          userId: loyalId,
          userName: loyalName,
          type: AwardType.loyalOne,
          period: period,
          value: longestStreak,
          description:
              '$loyalName memiliki streak $longestStreak sesi berturut-turut',
          awardedAt: DateTime.now(),
        ));
      }

      // -----------------------------------------------------------------------
      // 4. Most Improved
      //    User whose session count grew the most vs the previous month.
      // -----------------------------------------------------------------------
      final prevMonth = month == 1 ? 12 : month - 1;
      final prevYear = month == 1 ? year - 1 : year;

      final prevMonthSessions = sessions.where((s) =>
          s.status == SessionStatus.completed &&
          s.date.year == prevYear &&
          s.date.month == prevMonth).toList();

      final prevSessionIds = prevMonthSessions.map((s) => s.id).toSet();

      String? improvedId;
      String improvedName = '';
      int bestGrowth = 0;

      for (final user in users) {
        final currentCount = attendedCount(user.id, monthlySessionIds);
        final previousCount = attendedCount(user.id, prevSessionIds);
        final growth = currentCount - previousCount;

        if (growth > bestGrowth) {
          bestGrowth = growth;
          improvedId = user.id;
          improvedName = user.name;
        }
      }

      if (improvedId != null && bestGrowth > 0) {
        computed.add(AwardModel(
          id: _uuid.v4(),
          userId: improvedId,
          userName: improvedName,
          type: AwardType.mostImproved,
          period: period,
          value: bestGrowth,
          description:
              '$improvedName meningkat $bestGrowth sesi dibanding bulan lalu',
          awardedAt: DateTime.now(),
        ));
      }

      // Store computed awards (avoid duplicates for same period + type)
      for (final award in computed) {
        final exists = _awards.any((a) =>
            a.period == award.period &&
            a.type == award.type &&
            !a.isDeleted);
        if (!exists) {
          _awards.add(award);
        }
      }

      _isBusy = false;
      notifyListeners();
      return computed;
    } catch (e) {
      _errorMessage = 'Gagal menghitung awards. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Manual award granting
  // ---------------------------------------------------------------------------

  /// Grants a manual award (e.g. MVP, Spirit Award) to a user.
  Future<bool> grantManualAward({
    required String userId,
    required String userName,
    required AwardType type,
    required String period,
    required String grantedBy,
    String? description,
  }) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final award = AwardModel(
        id: _uuid.v4(),
        userId: userId,
        userName: userName,
        type: type,
        period: period,
        value: 0,
        description: description ?? '$userName menerima ${type.name} untuk periode $period',
        grantedBy: grantedBy,
        awardedAt: DateTime.now(),
      );

      _awards.add(award);

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memberikan award. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }
}
