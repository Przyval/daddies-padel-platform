import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/models/kta_tier.dart';
import 'package:daddies_app/features/member/providers/member_provider.dart';

/// Public member profile screen, accessible at `/member/{id}`.
/// Viewable by guests (no auth required). Loaded via deferred import.
class PublicProfileScreen extends StatelessWidget {
  final String userId;

  PublicProfileScreen({super.key, required this.userId}); // NOT const — deferred

  @override
  Widget build(BuildContext context) {
    final ds = DataService();
    final user = ds.getUserById(userId);

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.sagePaper,
        appBar: AppBar(
          title: const Text('Profil Member'),
          backgroundColor: AppColors.forestInk,
          foregroundColor: AppColors.agedLinen,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 64,
                color: AppColors.mossAccent.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Member tidak ditemukan',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Profil ini mungkin sudah dihapus atau tidak tersedia.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Compute data
    final memberProvider = MemberProvider();
    final stats = memberProvider.getStatsForUser(userId);
    final avgRating = ds.getAverageRatingForUser(userId);
    final awards = ds.getAwardsForUser(userId);

    // KTA tier
    final completedSessions = stats.completedSessions;
    final tier = computeKtaTier(
      chipsBalance: user.chipsBalance,
      completedSessions: completedSessions,
    );

    // Member since
    final memberSince = DateFormat('d MMMM yyyy', 'id_ID').format(user.createdAt);

    // Check if viewer is owner
    final authProvider = context.read<AuthProvider>();
    final isOwner = authProvider.currentUser?.id == userId;

    // Initials
    final initials = _getInitials(user.name);

    // Profile share URL
    const domain = 'daddiespadel.com';
    final profileUrl = '$domain/member/$userId';

    return Scaffold(
      backgroundColor: AppColors.sagePaper,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ================================================================
          // Profile Header
          // ================================================================
          SliverAppBar(
            expandedHeight: 300,
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
                        // Avatar circle with initials
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.mossAccent,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.forestInk.withValues(alpha: 0.4),
                                blurRadius: 16,
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

                        // Name (bold, large)
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.agedLinen,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Nickname if available
                        if (user.nickname != null && user.nickname!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '"${user.nickname}"',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mossAccent.withValues(alpha: 0.9),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],

                        // Bio if available
                        if (user.bio != null && user.bio!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            user.bio!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.agedLinen.withValues(alpha: 0.75),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Tier badge
                        _TierBadge(tier: tier),
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

          // ================================================================
          // Content
          // ================================================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==========================================================
                  // Stats Cards (horizontal row of 3)
                  // ==========================================================
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle_outline,
                          value: '$completedSessions',
                          label: 'Sesi Dimainkan',
                          color: AppColors.forestInk,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.star,
                          value: avgRating > 0
                              ? avgRating.toStringAsFixed(1)
                              : '-',
                          label: 'Rating',
                          color: const Color(0xFFD4A017),
                          customChild: avgRating > 0
                              ? _buildStarRow(avgRating)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.calendar_month,
                          value: '',
                          label: 'Member Sejak',
                          color: AppColors.statusPaid,
                          customChild: Text(
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

                  // ==========================================================
                  // Awards Section
                  // ==========================================================
                  if (awards.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Penghargaan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepCharcoal,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.agedLinen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: awards.asMap().entries.map((entry) {
                          final index = entry.key;
                          final award = entry.value;
                          final isLast = index == awards.length - 1;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: isLast
                                  ? null
                                  : const Border(
                                      bottom: BorderSide(
                                        color: AppColors.divider,
                                        width: 0.5,
                                      ),
                                    ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.forestInk
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      award.typeEmoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        award.typeLabel,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.deepCharcoal,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        award.description,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textTertiary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.mossAccent
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    award.period,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mossAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // ==========================================================
                  // Action Buttons
                  // ==========================================================
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      // Edit Profile (only if viewer is owner)
                      if (isOwner) ...[
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  context.push(AppRoutes.editProfile),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit Profil'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.forestInk,
                                side: const BorderSide(
                                  color: AppColors.forestInk,
                                  width: 1.5,
                                ),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Share button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: profileUrl),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Link profil disalin!',
                                  ),
                                  backgroundColor: AppColors.forestInk,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: const Text('Bagikan Profil'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.forestInk,
                              foregroundColor: AppColors.agedLinen,
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

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
  // Star rating row
  // ===========================================================================
  Widget _buildStarRow(double avgRating) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < avgRating.floor()) {
          return const Icon(Icons.star, size: 14, color: Color(0xFFFFD700));
        } else if (i < avgRating.ceil() && avgRating % 1 >= 0.5) {
          return const Icon(Icons.star_half, size: 14, color: Color(0xFFFFD700));
        } else {
          return Icon(
            Icons.star_border,
            size: 14,
            color: AppColors.divider,
          );
        }
      }),
    );
  }

  // ===========================================================================
  // Initials helper
  // ===========================================================================
  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}

// =============================================================================
// Tier Badge
// =============================================================================
class _TierBadge extends StatelessWidget {
  final KtaTier tier;

  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final gradientColors = tier.gradientHex
        .map((hex) => Color(hex).withValues(alpha: 0.85))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(tier.gradientHex.first).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tier.emoji,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            tier.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.agedLinen,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
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
  final Widget? customChild;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.customChild,
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
          if (customChild != null)
            customChild!
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
