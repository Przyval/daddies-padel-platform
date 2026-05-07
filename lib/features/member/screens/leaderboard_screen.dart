import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/features/member/providers/member_provider.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/core/widgets/player_profile_sheet.dart';
import 'package:daddies_app/core/widgets/empty_state.dart';
import 'package:daddies_app/core/widgets/micro_interactions.dart';
import 'package:daddies_app/models/season_model.dart';
import 'package:daddies_app/services/data_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Season? _selectedSeason;
  LeaderboardSort _sortBy = LeaderboardSort.completedSessions;

  static const _sortLabels = {
    LeaderboardSort.completedSessions: 'Sesi',
    LeaderboardSort.matchWins: 'Menang',
    LeaderboardSort.totalPoints: 'Poin',
    LeaderboardSort.attendanceRate: 'Kehadiran',
  };

  @override
  Widget build(BuildContext context) {
    final memberProv = context.watch<MemberProvider>();
    final authProv = context.watch<AuthProvider>();
    final leaderboard = memberProv.getLeaderboard(
      season: _selectedSeason,
      sortBy: _sortBy,
    );
    final currentUserId = authProv.currentUser?.id;
    final seasons = SeasonHelper.allSeasons();

    return Scaffold(
      backgroundColor: AppColors.sagePaper,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.agedLinen,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.forestInk,
        onRefresh: () => DataService().refresh(),
        child: Column(
          children: [
            // Season dropdown + sort chips
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: AppColors.agedLinen,
              child: Column(
                children: [
                  // Season selector
                  SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        const Icon(Icons.date_range, size: 16, color: AppColors.textTertiary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Season?>(
                              value: _selectedSeason,
                              isDense: true,
                              isExpanded: true,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.deepCharcoal,
                              ),
                              items: [
                                const DropdownMenuItem<Season?>(
                                  value: null,
                                  child: Text('Semua Waktu'),
                                ),
                                ...seasons.map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.name),
                                    )),
                              ],
                              onChanged: (v) => setState(() => _selectedSeason = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Sort chips
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: LeaderboardSort.values.map((sort) {
                        final active = _sortBy == sort;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _sortBy = sort),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: active ? AppColors.forestInk : AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _sortLabels[sort]!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                  color: active ? AppColors.white : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Leaderboard list
            Expanded(
              child: leaderboard.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        EmptyStateWidget(
                          icon: Icons.leaderboard_outlined,
                          title: 'Belum ada data pemain',
                          subtitle: 'Leaderboard akan muncul setelah ada sesi',
                          useLottie: true,
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: leaderboard.length,
                      itemBuilder: (context, index) {
                        final stats = leaderboard[index];
                        final rank = index + 1;
                        final isMe = stats.userId == currentUserId;

                        // Top 3 podium for first 3 entries
                        if (index == 0 && leaderboard.length >= 3) {
                          return _PodiumSection(
                            top3: leaderboard.take(3).toList(),
                            currentUserId: currentUserId,
                            sortBy: _sortBy,
                          );
                        }
                        // Skip indices 1, 2 (covered by podium)
                        if (index == 1 || index == 2) {
                          return const SizedBox.shrink();
                        }

                        return _LeaderboardCard(
                          rank: rank,
                          stats: stats,
                          isMe: isMe,
                          sortBy: _sortBy,
                          onTap: () => showPlayerProfileSheet(context, stats.userId),
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

// =============================================================================
// Podium Section — Top 3 players
// =============================================================================

class _PodiumSection extends StatelessWidget {
  final List<MemberStats> top3;
  final String? currentUserId;
  final LeaderboardSort sortBy;

  const _PodiumSection({required this.top3, this.currentUserId, required this.sortBy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          Expanded(child: _PodiumCard(rank: 2, stats: top3[1], isMe: top3[1].userId == currentUserId, sortBy: sortBy)),
          const SizedBox(width: 8),
          // 1st place (taller)
          Expanded(child: _PodiumCard(rank: 1, stats: top3[0], isMe: top3[0].userId == currentUserId, sortBy: sortBy)),
          const SizedBox(width: 8),
          // 3rd place
          Expanded(child: _PodiumCard(rank: 3, stats: top3[2], isMe: top3[2].userId == currentUserId, sortBy: sortBy)),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final int rank;
  final MemberStats stats;
  final bool isMe;
  final LeaderboardSort sortBy;

  const _PodiumCard({required this.rank, required this.stats, required this.isMe, required this.sortBy});

  static const _medalColors = {1: Color(0xFFFFD700), 2: Color(0xFFC0C0C0), 3: Color(0xFFCD7F32)};
  static const _medalEmoji = {1: '\uD83E\uDD47', 2: '\uD83E\uDD48', 3: '\uD83E\uDD49'};

  String _valueForSort() {
    return switch (sortBy) {
      LeaderboardSort.completedSessions => '${stats.completedSessions} sesi',
      LeaderboardSort.matchWins => '${stats.matchWins} W',
      LeaderboardSort.totalPoints => '${stats.totalPoints} pts',
      LeaderboardSort.attendanceRate => '${(stats.attendanceRate * 100).round()}%',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _medalColors[rank]!;
    final height = rank == 1 ? 140.0 : rank == 2 ? 115.0 : 100.0;
    final initials = _getInitials(stats.userName);

    return GestureDetector(
      onTap: () => showPlayerProfileSheet(context, stats.userId),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.forestInk.withValues(alpha: 0.06) : AppColors.agedLinen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_medalEmoji[rank]!, style: TextStyle(fontSize: rank == 1 ? 24 : 20)),
            const SizedBox(height: 4),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.2)),
              child: Center(child: Text(initials, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.forestInk))),
            ),
            const SizedBox(height: 4),
            Text(
              stats.userName.split(' ').first,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.deepCharcoal),
              overflow: TextOverflow.ellipsis, maxLines: 1,
            ),
            Text(_valueForSort(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Leaderboard Card
// =============================================================================

class _LeaderboardCard extends StatelessWidget {
  final int rank;
  final MemberStats stats;
  final bool isMe;
  final LeaderboardSort sortBy;
  final VoidCallback onTap;

  const _LeaderboardCard({
    required this.rank,
    required this.stats,
    required this.isMe,
    required this.sortBy,
    required this.onTap,
  });

  String _primaryValue() {
    return switch (sortBy) {
      LeaderboardSort.completedSessions => '${stats.completedSessions} sesi',
      LeaderboardSort.matchWins => '${stats.matchWins} menang',
      LeaderboardSort.totalPoints => '${stats.totalPoints} poin',
      LeaderboardSort.attendanceRate => '${(stats.attendanceRate * 100).round()}%',
    };
  }

  @override
  Widget build(BuildContext context) {
    final rupiahFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final completionPct = (stats.completionRate * 100).round();
    final initials = _getInitials(stats.userName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ScaleOnTap(
        onTap: onTap,
        scaleFactor: 0.97,
        child: Material(
          color: isMe
              ? AppColors.forestInk.withValues(alpha: 0.10)
              : AppColors.agedLinen,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Rank
                SizedBox(
                  width: 32,
                  child: Text(
                    '#$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isMe ? AppColors.forestInk : AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Avatar
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMe ? AppColors.mossAccent.withValues(alpha: 0.30) : AppColors.mossAccent.withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.mossAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name + details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            stats.userName,
                            style: TextStyle(fontSize: 15, fontWeight: isMe ? FontWeight.w800 : FontWeight.w600, color: AppColors.deepCharcoal),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.forestInk, borderRadius: BorderRadius.circular(4)),
                            child: const Text('KAMU', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.agedLinen, letterSpacing: 0.5)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Row(children: [
                        Text(_primaryValue(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(width: 8),
                        Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.textTertiary)),
                        const SizedBox(width: 8),
                        Text('$completionPct% selesai', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        if (stats.currentStreak > 0) ...[
                          const SizedBox(width: 8),
                          Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.textTertiary)),
                          const SizedBox(width: 8),
                          Text(
                            '${stats.currentStreak}w streak',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: stats.currentStreak >= 5 ? const Color(0xFFFF6B00) : AppColors.mossAccent),
                          ),
                        ],
                      ]),
                      if (stats.badges.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4, runSpacing: 2,
                          children: stats.badges.map((badge) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.forestInk.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                            child: Text('${badge.emoji} ${badge.label}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.forestInk)),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                // Total spent
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(rupiahFormat.format(stats.totalSpent), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.forestInk)),
                    const SizedBox(height: 2),
                    const Text('spent', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _getInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
}
