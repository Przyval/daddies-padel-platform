import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/models/user_model.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/models/rating_model.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/features/member/providers/member_provider.dart';
import 'package:daddies_app/core/widgets/micro_interactions.dart';

class PlayerStatsScreen extends StatelessWidget {
  final String userId;

  const PlayerStatsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final ds = DataService();
    final user = ds.getUserById(userId);

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.sagePaper,
        appBar: AppBar(
          title: const Text('Pemain Tidak Ditemukan'),
          backgroundColor: AppColors.forestInk,
          foregroundColor: AppColors.agedLinen,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Data pemain tidak ditemukan.',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // Compute all stats
    final allSlots = ds.getSlotsForUser(userId);
    final completedSessionIds = ds.sessions
        .where((s) => s.status == SessionStatus.completed)
        .map((s) => s.id)
        .toSet();
    final upcomingSessionIds = ds.sessions
        .where((s) =>
            s.status == SessionStatus.open ||
            s.status == SessionStatus.full ||
            s.status == SessionStatus.locked)
        .map((s) => s.id)
        .toSet();

    final totalSessions = allSlots.length;
    final completedSessions =
        allSlots.where((s) => completedSessionIds.contains(s.sessionId)).length;
    final upcomingSessions =
        allSlots.where((s) => upcomingSessionIds.contains(s.sessionId)).length;

    final ratings = ds.getRatingsForUser(userId);
    final avgRating = ds.getAverageRatingForUser(userId);

    // Favorite venues
    final venueCount = <String, int>{};
    for (final slot in allSlots) {
      final session = ds.getSessionById(slot.sessionId);
      if (session != null) {
        venueCount[session.venue] = (venueCount[session.venue] ?? 0) + 1;
      }
    }
    final sortedVenues = venueCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Session history per month (last 6 months)
    final now = DateTime.now();
    final monthlyData = <String, int>{};
    final monthLabels = <String>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      monthlyData[key] = 0;
      monthLabels.add(DateFormat('MMM', 'id_ID').format(month));
    }
    for (final slot in allSlots) {
      final session = ds.getSessionById(slot.sessionId);
      if (session != null) {
        final key =
            '${session.date.year}-${session.date.month.toString().padLeft(2, '0')}';
        if (monthlyData.containsKey(key)) {
          monthlyData[key] = monthlyData[key]! + 1;
        }
      }
    }

    // Recent ratings (last 5)
    final recentRatings = List<RatingModel>.from(ratings)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final last5Ratings = recentRatings.take(5).toList();

    final memberSince =
        DateFormat('d MMMM yyyy', 'id_ID').format(user.createdAt);

    // Match & attendance stats via MemberProvider
    final memberProvider = MemberProvider();
    final memberStats = memberProvider.getStatsForUser(userId);

    return Scaffold(
      backgroundColor: AppColors.sagePaper,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ---- Header ----
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.forestInk,
            foregroundColor: AppColors.agedLinen,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2F3E34),
                      Color(0xFF4A6350),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.mossAccent,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.forestInk.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _getInitials(user.name),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.agedLinen,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Name + nickname
                        Text(
                          user.nickname ?? user.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.agedLinen,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (user.nickname != null &&
                            user.nickname!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  AppColors.agedLinen.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // Role badge
                        _RoleBadge(role: user.role),

                        const SizedBox(height: 10),

                        // Average rating with stars
                        if (avgRating > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ...List.generate(5, (i) {
                                if (i < avgRating.floor()) {
                                  return const Icon(Icons.star,
                                      size: 18, color: Color(0xFFFFD700));
                                } else if (i < avgRating.ceil() &&
                                    avgRating % 1 >= 0.5) {
                                  return const Icon(Icons.star_half,
                                      size: 18, color: Color(0xFFFFD700));
                                } else {
                                  return Icon(Icons.star_border,
                                      size: 18,
                                      color: AppColors.agedLinen
                                          .withValues(alpha: 0.4));
                                }
                              }),
                              const SizedBox(width: 8),
                              Text(
                                avgRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              title: Text(
                user.nickname ?? user.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // ---- Content ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Grid (2x3)
                  _buildStatsGrid(
                    totalSessions: totalSessions,
                    completedSessions: completedSessions,
                    upcomingSessions: upcomingSessions,
                    ratingCount: ratings.length,
                    avgRating: avgRating,
                    memberSince: memberSince,
                  ),
                  const SizedBox(height: 24),

                  // Match Performance
                  if (memberStats.matchWins > 0 ||
                      memberStats.matchLosses > 0 ||
                      memberStats.matchDraws > 0) ...[
                    _buildSectionTitle('Performa Match'),
                    const SizedBox(height: 12),
                    _buildMatchStats(memberStats),
                    const SizedBox(height: 24),
                  ],

                  // Attendance
                  if (memberStats.attendableCount > 0) ...[
                    _buildSectionTitle('Kehadiran'),
                    const SizedBox(height: 12),
                    _buildAttendanceCard(memberStats),
                    const SizedBox(height: 24),
                  ],

                  // Badges
                  if (memberStats.badges.isNotEmpty) ...[
                    _buildSectionTitle('Badge'),
                    const SizedBox(height: 12),
                    _buildBadges(context, memberStats.badges),
                    const SizedBox(height: 24),
                  ],

                  // Session History Chart
                  _buildSectionTitle('Riwayat Sesi'),
                  const SizedBox(height: 12),
                  _buildSessionChart(monthlyData, monthLabels),
                  const SizedBox(height: 24),

                  // Favorite Venues
                  if (sortedVenues.isNotEmpty) ...[
                    _buildSectionTitle('Venue Favorit'),
                    const SizedBox(height: 12),
                    _buildFavoriteVenues(sortedVenues),
                    const SizedBox(height: 24),
                  ],

                  // Recent Ratings
                  if (last5Ratings.isNotEmpty) ...[
                    _buildSectionTitle('Rating Terbaru'),
                    const SizedBox(height: 12),
                    _buildRecentRatings(last5Ratings, ds),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Stats Grid
  // ===========================================================================
  Widget _buildStatsGrid({
    required int totalSessions,
    required int completedSessions,
    required int upcomingSessions,
    required int ratingCount,
    required double avgRating,
    required String memberSince,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatGridCard(
                icon: Icons.sports_tennis,
                value: '$totalSessions',
                label: 'Total Sesi',
                color: AppColors.forestInk,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatGridCard(
                icon: Icons.check_circle_outline,
                value: '$completedSessions',
                label: 'Sesi Selesai',
                color: AppColors.statusCompleted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatGridCard(
                icon: Icons.event_available,
                value: '$upcomingSessions',
                label: 'Sesi Mendatang',
                color: AppColors.statusOpen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatGridCard(
                icon: Icons.star_outline,
                value: '$ratingCount',
                label: 'Total Rating',
                color: const Color(0xFFD4A017),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatGridCard(
                icon: Icons.star,
                value: avgRating > 0 ? avgRating.toStringAsFixed(1) : '-',
                label: 'Average Rating',
                color: const Color(0xFFD4A017),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatGridCard(
                icon: Icons.calendar_month,
                value: '',
                label: 'Member Sejak',
                color: AppColors.statusPaid,
                customValue: Text(
                  memberSince,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.statusPaid,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // Session History Chart
  // ===========================================================================
  Widget _buildSessionChart(
      Map<String, int> monthlyData, List<String> monthLabels) {
    final values = monthlyData.values.toList();
    final maxVal = values.isEmpty
        ? 1
        : values.reduce((a, b) => a > b ? a : b).clamp(1, 999);
    const maxBarHeight = 100.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.agedLinen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final count = values[i];
          final barHeight = maxVal > 0
              ? (count / maxVal) * maxBarHeight
              : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Count on top
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Bar
                  Container(
                    width: 30,
                    height: barHeight < 4 && count > 0 ? 4 : barHeight,
                    decoration: BoxDecoration(
                      color: count > 0
                          ? AppColors.forestInk
                          : AppColors.divider,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Month label
                  Text(
                    monthLabels[i],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // Favorite Venues
  // ===========================================================================
  Widget _buildFavoriteVenues(List<MapEntry<String, int>> sortedVenues) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.agedLinen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: sortedVenues.asMap().entries.map((entry) {
          final index = entry.key;
          final venue = entry.value;
          final isLast = index == sortedVenues.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(
                      bottom: BorderSide(color: AppColors.divider, width: 0.5),
                    ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.mossAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.mossAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    venue.key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepCharcoal,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.forestInk.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${venue.value}x main',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestInk,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // Recent Ratings
  // ===========================================================================
  Widget _buildRecentRatings(List<RatingModel> ratings, DataService ds) {
    final dateFormat = DateFormat('d MMM yyyy', 'id_ID');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.agedLinen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: ratings.asMap().entries.map((entry) {
          final index = entry.key;
          final rating = entry.value;
          final isLast = index == ratings.length - 1;
          final fromUser = ds.getUserById(rating.fromUserId);
          final session = ds.getSessionById(rating.sessionId);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(
                      bottom: BorderSide(color: AppColors.divider, width: 0.5),
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // From user avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.mossAccent.withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: Text(
                      fromUser != null
                          ? _getInitials(fromUser.name)
                          : '?',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mossAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fromUser?.name ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepCharcoal,
                        ),
                      ),
                      if (session != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          session.title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        dateFormat.format(rating.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Stars
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    return Icon(
                      i < rating.rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: i < rating.rating
                          ? const Color(0xFFD4A017)
                          : AppColors.divider,
                    );
                  }),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // Match Stats
  // ===========================================================================
  Widget _buildMatchStats(MemberStats stats) {
    final totalMatches = stats.matchWins + stats.matchLosses + stats.matchDraws;
    final winRate = totalMatches > 0
        ? (stats.matchWins / totalMatches * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.agedLinen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Points highlight
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.forestInk,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${stats.totalPoints}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.agedLinen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Poin',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepCharcoal,
                    ),
                  ),
                  Text(
                    '$totalMatches match dimainkan',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          // Win/Loss/Draw row
          Row(
            children: [
              Expanded(
                child: _MatchStatItem(
                  value: '${stats.matchWins}',
                  label: 'Menang',
                  color: AppColors.statusCompleted,
                ),
              ),
              Expanded(
                child: _MatchStatItem(
                  value: '${stats.matchLosses}',
                  label: 'Kalah',
                  color: AppColors.clayRed,
                ),
              ),
              Expanded(
                child: _MatchStatItem(
                  value: '${stats.matchDraws}',
                  label: 'Seri',
                  color: AppColors.textTertiary,
                ),
              ),
              Expanded(
                child: _MatchStatItem(
                  value: '$winRate%',
                  label: 'Win Rate',
                  color: AppColors.forestInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Attendance Card
  // ===========================================================================
  Widget _buildAttendanceCard(MemberStats stats) {
    final pct = (stats.attendanceRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.agedLinen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: stats.attendanceRate,
                  strokeWidth: 6,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    pct >= 80
                        ? AppColors.statusCompleted
                        : pct >= 50
                            ? AppColors.statusPaid
                            : AppColors.clayRed,
                  ),
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepCharcoal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tingkat Kehadiran',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepCharcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hadir ${stats.attendedCount} dari ${stats.attendableCount} sesi',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                if (stats.currentStreak > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Streak: ${stats.currentStreak} minggu berturut-turut',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mossAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Badges
  // ===========================================================================
  Widget _buildBadges(BuildContext context, List<MemberBadge> badges) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges.map((badge) {
        return ScaleOnTap(
          onTap: () => ConfettiOverlay.show(context),
          scaleFactor: 0.9,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.forestInk.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(badge.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  badge.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestInk,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.deepCharcoal,
        letterSpacing: -0.3,
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}

// =============================================================================
// Role Badge (light version for dark background)
// =============================================================================
class _RoleBadge extends StatelessWidget {
  final UserRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (role) {
      UserRole.superAdmin => (
          AppColors.agedLinen.withValues(alpha: 0.2),
          AppColors.agedLinen,
          Icons.shield,
        ),
      UserRole.mimin => (
          AppColors.agedLinen.withValues(alpha: 0.2),
          AppColors.agedLinen,
          Icons.admin_panel_settings,
        ),
      UserRole.bendahara => (
          AppColors.agedLinen.withValues(alpha: 0.2),
          AppColors.agedLinen,
          Icons.account_balance_wallet,
        ),
      UserRole.member => (
          AppColors.agedLinen.withValues(alpha: 0.2),
          AppColors.agedLinen,
          Icons.person,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            _roleLabel(role),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.mimin:
        return 'Mimin';
      case UserRole.bendahara:
        return 'Bendahara';
      case UserRole.member:
        return 'Member';
    }
  }
}

// =============================================================================
// Match Stat Item
// =============================================================================
class _MatchStatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MatchStatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Stat Grid Card
// =============================================================================
class _StatGridCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Widget? customValue;

  const _StatGridCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.customValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          if (customValue != null)
            customValue!
          else if (int.tryParse(value) != null)
            AnimatedCounter(
              value: int.parse(value),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            )
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
