import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/features/member/screens/member_dashboard_screen.dart';
import 'package:daddies_app/features/member/providers/member_provider.dart';
import 'package:daddies_app/features/chips/providers/chips_provider.dart';
import 'package:daddies_app/features/sessions/screens/session_list_screen.dart';
import 'package:daddies_app/features/finance/screens/finance_dashboard_screen.dart';
import 'package:daddies_app/features/admin/screens/admin_dashboard_screen.dart';
import 'package:daddies_app/core/widgets/offline_banner.dart';
import 'package:daddies_app/core/services/notification_service.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  int _unreadCount = 0;

  /// Tracks which tab indices have been visited at least once.
  /// Tabs are only built on first visit (lazy), then kept alive.
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    _unreadCount = NotificationService.instance.unreadCount;
    NotificationService.instance.addListener(_onNotificationChanged);
  }

  @override
  void dispose() {
    NotificationService.instance.removeListener(_onNotificationChanged);
    super.dispose();
  }

  void _onNotificationChanged() {
    final count = NotificationService.instance.unreadCount;
    if (count != _unreadCount) {
      setState(() => _unreadCount = count);
    }
  }

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.explore);
      });
      return const SizedBox.shrink();
    }

    final showFinance = auth.canManageFinance;
    final showAdmin = auth.isSuperAdmin;

    final screenBuilders = <Widget Function()>[
      () => const MemberDashboardScreen(),
      () => const SessionListScreen(),
      if (showFinance) () => const FinanceDashboardScreen(),
      if (showAdmin) () => const AdminDashboardScreen(),
      () => _ProfileTab(auth: auth),
    ];

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: Badge(
          isLabelVisible: _unreadCount > 0,
          label: Text('$_unreadCount'),
          child: const Icon(Icons.dashboard_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: _unreadCount > 0,
          label: Text('$_unreadCount'),
          child: const Icon(Icons.dashboard),
        ),
        label: 'Beranda',
      ),
      const NavigationDestination(
        icon: Icon(Icons.sports_tennis_outlined),
        selectedIcon: Icon(Icons.sports_tennis),
        label: 'Sesi',
      ),
      if (showFinance)
        const NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'Kas',
        ),
      if (showAdmin)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profil',
      ),
    ];

    final safeIndex = _currentIndex.clamp(0, screenBuilders.length - 1);
    _visitedTabs.add(safeIndex);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: safeIndex,
              children: [
                for (int i = 0; i < screenBuilders.length; i++)
                  _visitedTabs.contains(i)
                      ? _KeepAliveTab(child: screenBuilders[i]())
                      : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(48)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceBright.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(48)),
              border: Border(
                top: BorderSide(
                  color: AppColors.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.forestInk.withValues(alpha: 0.06),
                  blurRadius: 40,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              destinations: destinations,
              height: 68,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              indicatorColor: AppColors.forestInk.withValues(alpha: 0.12),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a child widget with [AutomaticKeepAliveClientMixin] so it stays
/// alive when off-screen in an [IndexedStack], avoiding unnecessary rebuilds.
class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _ProfileTab extends StatelessWidget {
  final AuthProvider auth;

  const _ProfileTab({required this.auth});

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    final displayName = user.nickname ?? user.name;
    final memberSince =
        DateFormat('MMMM yyyy', 'id_ID').format(user.createdAt);

    // Compute player stats reactively via Provider
    final memberProv = context.watch<MemberProvider>();
    final chipsProv = context.watch<ChipsProvider>();
    final stats = memberProv.getStatsForUser(user.id);
    final gamesPlayed = stats.completedSessions;
    final upcomingGames = stats.upcomingSessions;
    final chipsBalance = chipsProv.getBalance(user.id);

    // Initials
    final parts = user.name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // Gradient header
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.forestInk,
            foregroundColor: AppColors.agedLinen,
            actions: [
              IconButton(
                onPressed: () => context.push(AppRoutes.editProfile),
                icon: const Icon(Icons.edit_outlined, size: 22),
                tooltip: 'Edit Profil',
              ),
            ],
            title: const Text(
              'Profil',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.forestInk,
                      Color(0xFF3A4D40),
                      Color(0xFF4A5F4E),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Avatar
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.mossAccent,
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (user.nickname != null && user.nickname!.isNotEmpty)
                          Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.sagePaper.withValues(alpha: 0.6),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.agedLinen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user.roleLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.sagePaper.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ProfileStatItem(
                            icon: Icons.sports_tennis,
                            value: '$gamesPlayed',
                            label: 'Game Selesai',
                            color: AppColors.statusCompleted,
                          ),
                        ),
                        Container(
                            width: 1,
                            height: 36,
                            color: AppColors.divider),
                        Expanded(
                          child: _ProfileStatItem(
                            icon: Icons.event_available,
                            value: '$upcomingGames',
                            label: 'Akan Datang',
                            color: AppColors.statusOpen,
                          ),
                        ),
                        Container(
                            width: 1,
                            height: 36,
                            color: AppColors.divider),
                        Expanded(
                          child: _ProfileStatItem(
                            icon: Icons.toll,
                            value: '$chipsBalance',
                            label: 'Chips',
                            color: AppColors.statusPaid,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bio
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.forestInk.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user.bio!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Leaderboard tile
                  _ProfileNavTile(
                    icon: Icons.leaderboard,
                    iconColor: AppColors.statusPaid,
                    title: 'Leaderboard',
                    subtitle: 'Ranking pemain Daddies',
                    onTap: () => context.push('/leaderboard'),
                  ),

                  const SizedBox(height: 8),

                  // Session History tile
                  _ProfileNavTile(
                    icon: Icons.history,
                    iconColor: AppColors.mossAccent,
                    title: 'Riwayat Sesi',
                    subtitle: 'Lihat semua sesi yang kamu ikuti',
                    onTap: () => context.push('/history'),
                  ),

                  const SizedBox(height: 8),

                  // KTA Digital tile
                  _ProfileNavTile(
                    icon: Icons.badge_outlined,
                    iconColor: AppColors.forestInk,
                    title: 'KTA Digital',
                    subtitle: 'Kartu anggota & partner diskon',
                    onTap: () => context.push(AppRoutes.kta),
                  ),

                  const SizedBox(height: 8),

                  // Partner Dedis tile
                  _ProfileNavTile(
                    icon: Icons.handshake_outlined,
                    iconColor: AppColors.mossAccent,
                    title: 'Partner Dedis',
                    subtitle: 'Diskon eksklusif dari partner',
                    onTap: () => context.push(AppRoutes.partnerList),
                  ),

                  const SizedBox(height: 8),

                  // Chips History tile
                  _ProfileNavTile(
                    icon: Icons.toll,
                    iconColor: AppColors.statusPaid,
                    title: 'Chips',
                    subtitle: '$chipsBalance chips tersedia',
                    onTap: () => context.push(AppRoutes.chipsHistory),
                  ),

                  const SizedBox(height: 8),

                  // Awards tile
                  _ProfileNavTile(
                    icon: Icons.emoji_events_outlined,
                    iconColor: const Color(0xFFD4A017),
                    title: 'Awards',
                    subtitle: 'Penghargaan bulanan',
                    onTap: () => context.push(AppRoutes.awardsShowcase),
                  ),

                  const SizedBox(height: 8),

                  // Redemption tile
                  _ProfileNavTile(
                    icon: Icons.redeem_outlined,
                    iconColor: AppColors.forestInk,
                    title: 'Tukar Chips',
                    subtitle: 'Diskon dari partner',
                    onTap: () => context.push(AppRoutes.redemptions),
                  ),

                  const SizedBox(height: 8),

                  // Referral tile
                  _ProfileNavTile(
                    icon: Icons.share_outlined,
                    iconColor: AppColors.mossAccent,
                    title: 'Referral',
                    subtitle: 'Ajak teman & dapatkan chips',
                    onTap: () => context.push(AppRoutes.referral),
                  ),

                  const SizedBox(height: 12),

                  // Info items
                  _ProfileItem(
                    icon: Icons.phone_outlined,
                    label: 'Nomor Telepon',
                    value: user.phone.isNotEmpty ? user.phone : '-',
                  ),
                  _ProfileItem(
                    icon: Icons.calendar_today_outlined,
                    label: 'Member Sejak',
                    value: memberSince,
                  ),

                  const SizedBox(height: 12),

                  // Settings tile
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => context.push(AppRoutes.settings),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.settings_outlined,
                                size: 20, color: AppColors.mossAccent),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pengaturan',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.deepCharcoal,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tema, notifikasi, dan lainnya',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Logout button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Keluar'),
                            content:
                                const Text('Yakin ingin keluar dari akun?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  auth.logout();
                                  context.go(AppRoutes.explore);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.clayRed,
                                ),
                                child: const Text('Keluar'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon:
                          const Icon(Icons.logout, color: AppColors.clayRed),
                      label: const Text(
                        'Keluar',
                        style: TextStyle(color: AppColors.clayRed),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.clayRed),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text(
                    'Daddies Padel Community v1.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Profile Stat Item
// =============================================================================

class _ProfileStatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _ProfileStatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
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
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ProfileNavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileNavTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.mossAccent),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepCharcoal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
