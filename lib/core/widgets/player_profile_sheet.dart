import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/models/user_model.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/core/widgets/venue_link.dart';

/// Shows a professional player profile bottom sheet.
void showPlayerProfileSheet(BuildContext context, String userId) {
  final ds = DataService();
  final user = ds.getUserById(userId);
  if (user == null) return;

  // Calculate player stats from DataService cache
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

  final gamesPlayed =
      allSlots.where((s) => completedSessionIds.contains(s.sessionId)).length;
  final upcomingGames =
      allSlots.where((s) => upcomingSessionIds.contains(s.sessionId)).length;

  // Find favorite venue
  final venueCount = <String, int>{};
  for (final slot in allSlots) {
    final session = ds.getSessionById(slot.sessionId);
    if (session != null) {
      venueCount[session.venue] = (venueCount[session.venue] ?? 0) + 1;
    }
  }
  String? favoriteVenue;
  if (venueCount.isNotEmpty) {
    favoriteVenue = venueCount.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  final avgRating = ds.getAverageRatingForUser(userId);
  final ratingCount = ds.getRatingsForUser(userId).length;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PlayerProfileContent(
      user: user,
      gamesPlayed: gamesPlayed,
      upcomingGames: upcomingGames,
      totalSessions: allSlots.length,
      favoriteVenue: favoriteVenue,
      avgRating: avgRating,
      ratingCount: ratingCount,
    ),
  );
}

class _PlayerProfileContent extends StatelessWidget {
  final UserModel user;
  final int gamesPlayed;
  final int upcomingGames;
  final int totalSessions;
  final String? favoriteVenue;
  final double avgRating;
  final int ratingCount;

  const _PlayerProfileContent({
    required this.user,
    required this.gamesPlayed,
    required this.upcomingGames,
    required this.totalSessions,
    required this.favoriteVenue,
    required this.avgRating,
    required this.ratingCount,
  });

  @override
  Widget build(BuildContext context) {
    final memberSince =
        DateFormat('MMMM yyyy', 'id_ID').format(user.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ---- Profile Header ----
          _buildProfileHeader(context, memberSince),

          const SizedBox(height: 20),

          // ---- Bio ----
          if (user.bio != null && user.bio!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                user.bio!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),

          if (user.bio != null && user.bio!.isNotEmpty)
            const SizedBox(height: 20),

          // ---- Stats Cards ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildStatsRow(),
          ),

          const SizedBox(height: 20),

          // ---- Info Section ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildInfoSection(context, memberSince),
          ),

          const SizedBox(height: 20),

          // ---- Detail Stats Button ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.playerStatsPath(user.id));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forestInk,
                  side: const BorderSide(color: AppColors.forestInk),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Lihat Statistik Lengkap',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, String memberSince) {
    final initials = _getInitials(user.name);
    final displayName = user.nickname ?? user.name;

    return Column(
      children: [
        // Avatar
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.forestInk,
            boxShadow: [
              BoxShadow(
                color: AppColors.forestInk.withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.agedLinen,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Name
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.deepCharcoal,
            letterSpacing: -0.5,
          ),
        ),

        if (user.nickname != null && user.nickname!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            user.name,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ],

        const SizedBox(height: 8),

        // Role badge
        _RoleBadge(role: user.role),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.sports_tennis,
                value: '$gamesPlayed',
                label: 'Game Selesai',
                color: AppColors.statusCompleted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.event_available,
                value: '$upcomingGames',
                label: 'Akan Datang',
                color: AppColors.statusOpen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.leaderboard,
                value: '$totalSessions',
                label: 'Total Join',
                color: AppColors.statusPaid,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.star,
                value: avgRating > 0 ? avgRating.toStringAsFixed(1) : '-',
                label: '$ratingCount Rating',
                color: const Color(0xFFD4A017),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context, String memberSince) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.forestInk.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.calendar_month,
            label: 'Member sejak',
            value: memberSince,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.emoji_events_outlined,
            label: 'Level',
            value: user.skillLevelLabel,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.star,
            label: 'Rating',
            value: avgRating > 0 ? '${avgRating.toStringAsFixed(1)} ($ratingCount ulasan)' : 'Belum ada',
          ),
          if (favoriteVenue != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                navigateToVenue(context, favoriteVenue!);
              },
              child: _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Venue favorit',
                value: favoriteVenue!,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Telepon',
            value: user.phone.isNotEmpty ? user.phone : '-',
          ),
        ],
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
// Role Badge
// =============================================================================

class _RoleBadge extends StatelessWidget {
  final UserRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (role) {
      UserRole.superAdmin => (
          AppColors.clayRed.withValues(alpha: 0.12),
          AppColors.clayRed,
          Icons.shield,
        ),
      UserRole.mimin => (
          AppColors.forestInk.withValues(alpha: 0.12),
          AppColors.forestInk,
          Icons.admin_panel_settings,
        ),
      UserRole.bendahara => (
          AppColors.statusPaid.withValues(alpha: 0.12),
          AppColors.statusPaid,
          Icons.account_balance_wallet,
        ),
      UserRole.member => (
          AppColors.mossAccent.withValues(alpha: 0.12),
          AppColors.mossAccent,
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
// Stat Card
// =============================================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
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
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Info Row
// =============================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.mossAccent),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.deepCharcoal,
            ),
          ),
        ),
      ],
    );
  }
}
