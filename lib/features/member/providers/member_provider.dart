import 'package:flutter/foundation.dart';

import 'package:daddies_app/models/user_model.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/models/slot_model.dart';
import 'package:daddies_app/models/season_model.dart';
import 'package:daddies_app/services/data_service.dart';

enum LeaderboardSort { completedSessions, matchWins, totalPoints, attendanceRate }

/// Per-member statistics computed from sessions/slots data.
class MemberStats {
  final String userId;
  final String userName;
  final UserRole role;
  final int totalSessions;
  final int completedSessions;
  final int upcomingSessions;
  final double avgSessionsPerMonth;
  final double completionRate;
  final String? favoriteVenue;
  final int totalSpent;
  final DateTime memberSince;
  final int currentStreak;
  final int longestStreak;
  final int matchWins;
  final int matchLosses;
  final int matchDraws;
  final int totalPoints;
  final int attendedCount;
  final int attendableCount; // sessions where attendance was tracked
  final double attendanceRate;

  const MemberStats({
    required this.userId,
    required this.userName,
    required this.role,
    required this.totalSessions,
    required this.completedSessions,
    required this.upcomingSessions,
    required this.avgSessionsPerMonth,
    required this.completionRate,
    required this.favoriteVenue,
    required this.totalSpent,
    required this.memberSince,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.matchWins = 0,
    this.matchLosses = 0,
    this.matchDraws = 0,
    this.totalPoints = 0,
    this.attendedCount = 0,
    this.attendableCount = 0,
    this.attendanceRate = 0,
  });

  /// Badges earned based on stats.
  List<MemberBadge> get badges {
    final list = <MemberBadge>[];
    if (completedSessions >= 1) list.add(MemberBadge.bintangBaru);
    if (completedSessions >= 5) list.add(MemberBadge.reguler);
    if (completedSessions >= 10) list.add(MemberBadge.veteran);
    if (completedSessions >= 25) list.add(MemberBadge.legend);
    if (currentStreak >= 3) list.add(MemberBadge.setia);
    if (currentStreak >= 5) list.add(MemberBadge.ironMan);
    if (completionRate >= 0.9 && completedSessions >= 5) list.add(MemberBadge.reliable);
    return list;
  }
}

enum MemberBadge {
  bintangBaru,
  reguler,
  veteran,
  legend,
  setia,
  ironMan,
  reliable;

  String get label => switch (this) {
    MemberBadge.bintangBaru => 'Bintang Baru',
    MemberBadge.reguler => 'Reguler',
    MemberBadge.veteran => 'Veteran',
    MemberBadge.legend => 'Legend',
    MemberBadge.setia => 'Setia',
    MemberBadge.ironMan => 'Iron Man',
    MemberBadge.reliable => 'Reliable',
  };

  String get emoji => switch (this) {
    MemberBadge.bintangBaru => '\u2B50',
    MemberBadge.reguler => '\uD83C\uDFBE',
    MemberBadge.veteran => '\uD83C\uDFC6',
    MemberBadge.legend => '\uD83D\uDC51',
    MemberBadge.setia => '\uD83D\uDD25',
    MemberBadge.ironMan => '\u26A1',
    MemberBadge.reliable => '\u2705',
  };
}

class MemberProvider extends ChangeNotifier {
  final DataService _dataService = DataService();

  // ---------------------------------------------------------------------------
  // All members
  // ---------------------------------------------------------------------------

  List<UserModel> get members {
    final list = List<UserModel>.from(_dataService.users);
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  int get totalMembers => _dataService.users.length;

  List<UserModel> getMembersByRole(UserRole role) {
    return _dataService.getUsersByRole(role);
  }

  // ---------------------------------------------------------------------------
  // Per-member stats
  // ---------------------------------------------------------------------------

  MemberStats getStatsForUser(String userId) {
    final user = _dataService.getUserById(userId);
    if (user == null) {
      return MemberStats(
        userId: userId,
        userName: 'Unknown',
        role: UserRole.member,
        totalSessions: 0,
        completedSessions: 0,
        upcomingSessions: 0,
        avgSessionsPerMonth: 0,
        completionRate: 0,
        favoriteVenue: null,
        totalSpent: 0,
        memberSince: DateTime.now(),
      );
    }

    // Get all slots for this user
    final userSlots = _dataService.getSlotsForUser(userId);
    final sessionIds = userSlots.map((s) => s.sessionId).toSet();

    // Get the actual sessions
    final userSessions = sessionIds
        .map((id) => _dataService.getSessionById(id))
        .whereType<SessionModel>()
        .toList();

    // Also include sessions where user is the mimin
    final miminSessions = _dataService.getSessionsByMimin(userId);
    for (final s in miminSessions) {
      if (!sessionIds.contains(s.id)) {
        userSessions.add(s);
      }
    }

    final totalSessions = userSessions.length;

    final completedSessions = userSessions
        .where((s) => s.status == SessionStatus.completed)
        .length;

    final upcomingSessions = userSessions
        .where((s) =>
            s.status == SessionStatus.open ||
            s.status == SessionStatus.full ||
            s.status == SessionStatus.locked)
        .length;

    // Average sessions per month
    final monthsSinceMember = _monthsBetween(user.createdAt, DateTime.now());
    final avgPerMonth = monthsSinceMember > 0
        ? totalSessions / monthsSinceMember
        : totalSessions.toDouble();

    // Completion rate
    final completionRate =
        totalSessions > 0 ? completedSessions / totalSessions : 0.0;

    // Favorite venue (most frequently visited)
    final venueCount = <String, int>{};
    for (final session in userSessions) {
      venueCount[session.venue] = (venueCount[session.venue] ?? 0) + 1;
    }
    String? favoriteVenue;
    if (venueCount.isNotEmpty) {
      favoriteVenue = venueCount.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    // Total spent (sum of pricePerPlayer for sessions where user has a paid/locked slot)
    int totalSpent = 0;
    for (final slot in userSlots) {
      if (slot.status == SlotStatus.paid || slot.status == SlotStatus.locked) {
        final session = _dataService.getSessionById(slot.sessionId);
        if (session != null) {
          totalSpent += session.pricePerPlayer;
        }
      }
    }

    // Calculate weekly streaks from completed sessions
    final completedDates = userSessions
        .where((s) => s.status == SessionStatus.completed)
        .map((s) => s.date)
        .toList()
      ..sort();

    final streaks = _calculateWeeklyStreaks(completedDates);

    // Match stats (win/loss/draw/points)
    final userMatches = _dataService.getMatchResultsForUser(userId);
    int wins = 0, losses = 0, draws = 0, points = 0;
    for (final m in userMatches) {
      points += m.pointsFor(userId);
      if (m.didWin(userId)) {
        wins++;
      } else if (m.didLose(userId)) {
        losses++;
      } else {
        draws++;
      }
    }

    // Attendance stats
    int attended = 0;
    int attendable = 0;
    for (final slot in userSlots) {
      if (slot.status == SlotStatus.confirmed ||
          slot.status == SlotStatus.paid ||
          slot.status == SlotStatus.locked) {
        // Only count sessions that are locked/completed (where attendance is tracked)
        final session = _dataService.getSessionById(slot.sessionId);
        if (session != null &&
            (session.status == SessionStatus.locked ||
             session.status == SessionStatus.completed)) {
          attendable++;
          if (slot.didAttend) attended++;
        }
      }
    }

    return MemberStats(
      userId: userId,
      userName: user.name,
      role: user.role,
      totalSessions: totalSessions,
      completedSessions: completedSessions,
      upcomingSessions: upcomingSessions,
      avgSessionsPerMonth: avgPerMonth,
      completionRate: completionRate,
      favoriteVenue: favoriteVenue,
      totalSpent: totalSpent,
      memberSince: user.createdAt,
      currentStreak: streaks.$1,
      longestStreak: streaks.$2,
      matchWins: wins,
      matchLosses: losses,
      matchDraws: draws,
      totalPoints: points,
      attendedCount: attended,
      attendableCount: attendable,
      attendanceRate: attendable > 0 ? attended / attendable : 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Leaderboard: members ranked by multiple criteria
  // ---------------------------------------------------------------------------

  List<MemberStats> getLeaderboard({
    Season? season,
    LeaderboardSort sortBy = LeaderboardSort.completedSessions,
  }) {
    List<MemberStats> stats;

    if (season != null) {
      stats = _dataService.users
          .map((u) => getStatsForUserInSeason(u.id, season))
          .toList();
    } else {
      stats = _dataService.users
          .map((u) => getStatsForUser(u.id))
          .toList();
    }

    stats.sort((a, b) {
      switch (sortBy) {
        case LeaderboardSort.completedSessions:
          final cmp = b.completedSessions.compareTo(a.completedSessions);
          if (cmp != 0) return cmp;
          return b.completionRate.compareTo(a.completionRate);
        case LeaderboardSort.matchWins:
          final cmp = b.matchWins.compareTo(a.matchWins);
          if (cmp != 0) return cmp;
          return b.totalPoints.compareTo(a.totalPoints);
        case LeaderboardSort.totalPoints:
          final cmp = b.totalPoints.compareTo(a.totalPoints);
          if (cmp != 0) return cmp;
          return b.matchWins.compareTo(a.matchWins);
        case LeaderboardSort.attendanceRate:
          final cmp = b.attendanceRate.compareTo(a.attendanceRate);
          if (cmp != 0) return cmp;
          return b.attendedCount.compareTo(a.attendedCount);
      }
    });

    return stats;
  }

  /// Stats for a user filtered to a specific season's date range.
  MemberStats getStatsForUserInSeason(String userId, Season season) {
    final user = _dataService.getUserById(userId);
    if (user == null) {
      return MemberStats(
        userId: userId,
        userName: 'Unknown',
        role: UserRole.member,
        totalSessions: 0,
        completedSessions: 0,
        upcomingSessions: 0,
        avgSessionsPerMonth: 0,
        completionRate: 0,
        favoriteVenue: null,
        totalSpent: 0,
        memberSince: DateTime.now(),
      );
    }

    // Get all slots for this user
    final userSlots = _dataService.getSlotsForUser(userId);
    final sessionIds = userSlots.map((s) => s.sessionId).toSet();

    // Get sessions within the season date range
    final userSessions = sessionIds
        .map((id) => _dataService.getSessionById(id))
        .whereType<SessionModel>()
        .where((s) => season.contains(s.date))
        .toList();

    // Also include mimin sessions in season
    final miminSessions = _dataService.getSessionsByMimin(userId);
    for (final s in miminSessions) {
      if (!sessionIds.contains(s.id) && season.contains(s.date)) {
        userSessions.add(s);
      }
    }

    final completedSessions = userSessions
        .where((s) => s.status == SessionStatus.completed)
        .length;

    final upcomingSessions = userSessions
        .where((s) =>
            s.status == SessionStatus.open ||
            s.status == SessionStatus.full ||
            s.status == SessionStatus.locked)
        .length;

    final completionRate =
        userSessions.isNotEmpty ? completedSessions / userSessions.length : 0.0;

    // Total spent in season
    int totalSpent = 0;
    for (final slot in userSlots) {
      if (slot.status == SlotStatus.paid || slot.status == SlotStatus.locked) {
        final session = _dataService.getSessionById(slot.sessionId);
        if (session != null && season.contains(session.date)) {
          totalSpent += session.pricePerPlayer;
        }
      }
    }

    // Match stats in season
    final userMatches = _dataService.getMatchResultsForUser(userId);
    int wins = 0, losses = 0, draws = 0, points = 0;
    for (final m in userMatches) {
      // Check if the match's session falls within the season
      final session = _dataService.getSessionById(m.sessionId);
      if (session == null || !season.contains(session.date)) continue;

      points += m.pointsFor(userId);
      if (m.didWin(userId)) {
        wins++;
      } else if (m.didLose(userId)) {
        losses++;
      } else {
        draws++;
      }
    }

    // Attendance in season
    int attended = 0;
    int attendable = 0;
    for (final slot in userSlots) {
      if (slot.status == SlotStatus.confirmed ||
          slot.status == SlotStatus.paid ||
          slot.status == SlotStatus.locked) {
        final session = _dataService.getSessionById(slot.sessionId);
        if (session != null &&
            season.contains(session.date) &&
            (session.status == SessionStatus.locked ||
             session.status == SessionStatus.completed)) {
          attendable++;
          if (slot.didAttend) attended++;
        }
      }
    }

    return MemberStats(
      userId: userId,
      userName: user.name,
      role: user.role,
      totalSessions: userSessions.length,
      completedSessions: completedSessions,
      upcomingSessions: upcomingSessions,
      avgSessionsPerMonth: userSessions.length / 3.0, // quarter = ~3 months
      completionRate: completionRate,
      favoriteVenue: null,
      totalSpent: totalSpent,
      memberSince: user.createdAt,
      matchWins: wins,
      matchLosses: losses,
      matchDraws: draws,
      totalPoints: points,
      attendedCount: attended,
      attendableCount: attendable,
      attendanceRate: attendable > 0 ? attended / attendable : 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Role management (superAdmin only)
  // ---------------------------------------------------------------------------

  Future<bool> updateMemberRole(String userId, UserRole newRole) async {
    final user = _dataService.getUserById(userId);
    if (user == null) return false;

    try {
      await _dataService.updateUser(user.copyWith(role: newRole));
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  double _monthsBetween(DateTime from, DateTime to) {
    final diff = to.difference(from);
    return diff.inDays / 30.44; // average days per month
  }

  /// Returns (currentStreak, longestStreak) in consecutive weeks with sessions.
  static (int, int) _calculateWeeklyStreaks(List<DateTime> sortedDates) {
    if (sortedDates.isEmpty) return (0, 0);

    // Group dates into ISO week numbers
    final weeks = <int>{};
    for (final date in sortedDates) {
      // Convert to week-of-epoch for consistent ordering
      final daysSinceEpoch = date.difference(DateTime(2020)).inDays;
      final week = daysSinceEpoch ~/ 7;
      weeks.add(week);
    }

    final sortedWeeks = weeks.toList()..sort();
    int currentStreak = 1;
    int longestStreak = 1;
    int tempStreak = 1;

    for (int i = 1; i < sortedWeeks.length; i++) {
      if (sortedWeeks[i] == sortedWeeks[i - 1] + 1) {
        tempStreak++;
        if (tempStreak > longestStreak) longestStreak = tempStreak;
      } else {
        tempStreak = 1;
      }
    }

    // Current streak: check if last week includes the current or previous week
    final now = DateTime.now();
    final currentWeek = now.difference(DateTime(2020)).inDays ~/ 7;
    final lastWeekWithSession = sortedWeeks.last;

    if (lastWeekWithSession >= currentWeek - 1) {
      // Active streak - count backwards from the end
      currentStreak = 1;
      for (int i = sortedWeeks.length - 2; i >= 0; i--) {
        if (sortedWeeks[i + 1] - sortedWeeks[i] == 1) {
          currentStreak++;
        } else {
          break;
        }
      }
    } else {
      currentStreak = 0;
    }

    return (currentStreak, longestStreak);
  }
}
