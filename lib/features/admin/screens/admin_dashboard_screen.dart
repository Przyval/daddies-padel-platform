import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/utils/stagger_helper.dart';
import 'package:daddies_app/core/widgets/shimmer_loading.dart';
import 'package:daddies_app/core/widgets/empty_state.dart';
import 'package:daddies_app/core/widgets/error_state.dart';
import 'package:daddies_app/core/utils/snackbar_helper.dart';
import 'package:daddies_app/models/user_model.dart';
import 'package:daddies_app/models/payment_model.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/features/member/providers/member_provider.dart';
import 'package:daddies_app/features/finance/providers/finance_provider.dart';
import 'package:daddies_app/features/sessions/providers/session_provider.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/core/services/export_service.dart';
import 'package:daddies_app/core/utils/validators.dart';
import 'package:daddies_app/models/venue_model.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:uuid/uuid.dart';
import 'package:daddies_app/core/widgets/micro_interactions.dart';
import 'package:daddies_app/features/admin/widgets/analytics_charts.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _staggerController;
  bool _isLoading = true;
  String? _errorMessage;

  static final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Skip refresh if DataService already loaded (from splash)
    if (DataService().isInitialized) {
      if (mounted) {
        setState(() => _isLoading = false);
        _staggerController.forward(from: 0);
      }
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await DataService().refresh();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Gagal memuat data.');
    }
    if (mounted) {
      setState(() => _isLoading = false);
      _staggerController.forward(from: 0);
    }
  }

  Widget _staggerItem(int index, int total, {required Widget child}) {
    return buildStaggerItem(controller: _staggerController, index: index, total: total, child: child);
  }

  Future<void> _handleExport(String type) async {
    try {
      final ds = DataService();
      switch (type) {
        case 'sessions':
          await ExportService.exportSessionsCsv(ds.sessions);
        case 'members':
          await ExportService.exportMembersCsv(ds.users);
        case 'finance':
          await ExportService.exportFinanceCsv(ds.cashflows);
      }
    } catch (_) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Gagal export data. Coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export',
            onSelected: _handleExport,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'sessions',
                child: Row(
                  children: [
                    Icon(Icons.sports_tennis, size: 20),
                    SizedBox(width: 12),
                    Text('Export Sesi (CSV)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'members',
                child: Row(
                  children: [
                    Icon(Icons.people_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Export Anggota (CSV)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'finance',
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Export Keuangan (CSV)'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.agedLinen,
          labelColor: AppColors.agedLinen,
          unselectedLabelColor: AppColors.agedLinen.withValues(alpha: 0.5),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Anggota'),
            Tab(text: 'Pembayaran'),
            Tab(text: 'Venue'),
            Tab(text: 'Analitik'),
          ],
        ),
      ),
      body: _isLoading
          ? const SessionListSkeleton()
          : _errorMessage != null
              ? ErrorStateWidget(
                  message: _errorMessage!,
                  onRetry: _loadData,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(rupiah: _rupiah, onRefresh: _loadData, staggerItem: _staggerItem, staggerController: _staggerController),
                    _MembersTab(onRefresh: _loadData),
                    _PaymentsTab(rupiah: _rupiah, onRefresh: _loadData),
                    _VenueTab(onRefresh: _loadData),
                    _AnalyticsTab(onRefresh: _loadData),
                  ],
                ),
    );
  }
}

// =============================================================================
// Tab 1: Overview
// =============================================================================

class _OverviewTab extends StatelessWidget {
  final NumberFormat rupiah;
  final Future<void> Function() onRefresh;
  final Widget Function(int index, int total, {required Widget child}) staggerItem;
  final AnimationController staggerController;

  const _OverviewTab({required this.rupiah, required this.onRefresh, required this.staggerItem, required this.staggerController});

  @override
  Widget build(BuildContext context) {
    final memberProv = context.watch<MemberProvider>();
    final financeProv = context.watch<FinanceProvider>();
    final sessionProv = context.watch<SessionProvider>();

    final sessions = sessionProv.sessions;
    final openCount =
        sessions.where((s) => s.status == SessionStatus.open).length;
    final completedCount =
        sessions.where((s) => s.status == SessionStatus.completed).length;

    return RefreshIndicator(
      color: AppColors.forestInk,
      onRefresh: onRefresh,
      child: AnimatedBuilder(
        animation: staggerController,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats grid
            staggerItem(0, 6, child: _buildStatsGrid(
              totalMembers: memberProv.totalMembers,
              totalSessions: sessions.length,
              openSessions: openCount,
              completedSessions: completedCount,
              totalRevenue: financeProv.totalIncome,
              totalExpenses: financeProv.totalExpense,
              balance: financeProv.balance,
            )),
            const SizedBox(height: 24),

            // Leaderboard
            staggerItem(1, 6, child: const Text(
              'Leaderboard Pemain',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deepCharcoal,
                letterSpacing: -0.3,
              ),
            )),
            const SizedBox(height: 12),
            staggerItem(2, 6, child: _buildLeaderboard(memberProv)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid({
    required int totalMembers,
    required int totalSessions,
    required int openSessions,
    required int completedSessions,
    required int totalRevenue,
    required int totalExpenses,
    required int balance,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.people,
                label: 'Total Anggota',
                value: '$totalMembers',
                color: AppColors.forestInk,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.sports_tennis,
                label: 'Total Sesi',
                value: '$totalSessions',
                color: AppColors.mossAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.play_circle_outline,
                label: 'Sesi Open',
                value: '$openSessions',
                color: AppColors.statusOpen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline,
                label: 'Selesai',
                value: '$completedSessions',
                color: AppColors.statusCompleted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.arrow_upward,
                label: 'Pemasukan',
                value: rupiah.format(totalRevenue),
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.arrow_downward,
                label: 'Pengeluaran',
                value: rupiah.format(totalExpenses),
                color: AppColors.clayRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _StatCard(
          icon: Icons.account_balance_wallet,
          label: 'Saldo',
          value: rupiah.format(balance),
          color: AppColors.forestInk,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildLeaderboard(MemberProvider memberProv) {
    final leaderboard = memberProv.getLeaderboard();
    if (leaderboard.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.leaderboard,
        title: 'Belum ada data',
        subtitle: 'Data pemain akan muncul setelah ada sesi.',
      );
    }

    return Column(
      children: List.generate(
        leaderboard.length > 10 ? 10 : leaderboard.length,
        (index) {
          final stats = leaderboard[index];
          final rank = index + 1;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: rank <= 3
                  ? (rank == 1
                      ? const Color(0xFFD4A843).withValues(alpha: 0.10)
                      : rank == 2
                          ? const Color(0xFFA0A0A0).withValues(alpha: 0.10)
                          : const Color(0xFFC4885B).withValues(alpha: 0.10))
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Rank
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? (rank == 1
                                ? const Color(0xFFD4A843)
                                : rank == 2
                                    ? const Color(0xFFA0A0A0)
                                    : const Color(0xFFC4885B))
                            .withValues(alpha: 0.15)
                        : AppColors.sagePaper,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: rank <= 3
                            ? (rank == 1
                                ? const Color(0xFFD4A843)
                                : rank == 2
                                    ? const Color(0xFFA0A0A0)
                                    : const Color(0xFFC4885B))
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.forestInk,
                  child: Text(
                    stats.userName.isNotEmpty
                        ? stats.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepCharcoal,
                        ),
                      ),
                      Text(
                        '${stats.totalSessions} sesi | ${(stats.completionRate * 100).toStringAsFixed(0)}% selesai',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Avg/month badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.forestInk.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${stats.avgSessionsPerMonth.toStringAsFixed(1)}/bln',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestInk,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Tab 2: Members
// =============================================================================

class _MembersTab extends StatefulWidget {
  final Future<void> Function() onRefresh;

  const _MembersTab({required this.onRefresh});

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final memberProv = context.watch<MemberProvider>();
    final auth = context.watch<AuthProvider>();

    var members = memberProv.members;
    if (_searchQuery.isNotEmpty) {
      members = members
          .where((m) =>
              m.name.toLowerCase().contains(_searchQuery) ||
              m.phone.contains(_searchQuery))
          .toList();
    }

    return RefreshIndicator(
      color: AppColors.forestInk,
      onRefresh: widget.onRefresh,
      child: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari anggota...',
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppColors.textTertiary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          // Role summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _RoleBadge(
                  label: 'Admin',
                  count: memberProv
                      .getMembersByRole(UserRole.superAdmin)
                      .length,
                  color: AppColors.clayRed,
                ),
                const SizedBox(width: 8),
                _RoleBadge(
                  label: 'Mimin',
                  count:
                      memberProv.getMembersByRole(UserRole.mimin).length,
                  color: AppColors.forestInk,
                ),
                const SizedBox(width: 8),
                _RoleBadge(
                  label: 'Bendahara',
                  count: memberProv
                      .getMembersByRole(UserRole.bendahara)
                      .length,
                  color: AppColors.statusPaid,
                ),
                const SizedBox(width: 8),
                _RoleBadge(
                  label: 'Member',
                  count: memberProv
                      .getMembersByRole(UserRole.member)
                      .length,
                  color: AppColors.mossAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Member list
          Expanded(
            child: members.isEmpty
                ? const Center(
                    child: EmptyStateWidget(
                      icon: Icons.people_outline,
                      title: 'Tidak ada anggota',
                      subtitle: 'Tidak ditemukan anggota yang cocok.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final stats = memberProv.getStatsForUser(member.id);
                      return _MemberTile(
                        member: member,
                        stats: stats,
                        isSuperAdmin: auth.isSuperAdmin,
                        onRoleChanged: auth.isSuperAdmin
                            ? (newRole) async {
                                final success = await memberProv
                                    .updateMemberRole(member.id, newRole);
                                if (!context.mounted) return;
                                if (success) {
                                  SnackbarHelper.showSuccess(
                                      context, 'Role berhasil diubah');
                                } else {
                                  SnackbarHelper.showError(
                                      context, 'Gagal mengubah role');
                                }
                              }
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final UserModel member;
  final MemberStats stats;
  final bool isSuperAdmin;
  final void Function(UserRole)? onRoleChanged;

  const _MemberTile({
    required this.member,
    required this.stats,
    required this.isSuperAdmin,
    this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.forestInk,
                child: Text(
                  member.name.isNotEmpty
                      ? member.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.phone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Role chip (tappable for superAdmin)
              if (isSuperAdmin && onRoleChanged != null)
                PopupMenuButton<UserRole>(
                  onSelected: onRoleChanged,
                  color: AppColors.surfaceElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _roleColor(member.role).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          member.roleLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _roleColor(member.role),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: _roleColor(member.role),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (_) => UserRole.values.map((role) {
                    return PopupMenuItem(
                      value: role,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _roleColor(role),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            role == UserRole.superAdmin
                                ? 'Super Admin'
                                : role == UserRole.mimin
                                    ? 'Mimin'
                                    : role == UserRole.bendahara
                                        ? 'Bendahara'
                                        : 'Member',
                            style: TextStyle(
                              fontWeight: member.role == role
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          if (member.role == role) ...[
                            const Spacer(),
                            const Icon(Icons.check,
                                size: 16, color: AppColors.forestInk),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _roleColor(member.role).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    member.roleLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _roleColor(member.role),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(
            children: [
              _MiniStat(
                  icon: Icons.sports_tennis,
                  value: '${stats.totalSessions}',
                  label: 'Sesi'),
              const SizedBox(width: 16),
              _MiniStat(
                  icon: Icons.trending_up,
                  value: '${stats.avgSessionsPerMonth.toStringAsFixed(1)}/bln',
                  label: 'Rata-rata'),
              const SizedBox(width: 16),
              _MiniStat(
                  icon: Icons.check_circle_outline,
                  value:
                      '${(stats.completionRate * 100).toStringAsFixed(0)}%',
                  label: 'Selesai'),
              if (stats.favoriteVenue != null) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.location_on_outlined,
                    value: stats.favoriteVenue!,
                    label: 'Favorit',
                    truncate: true,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return AppColors.clayRed;
      case UserRole.mimin:
        return AppColors.forestInk;
      case UserRole.bendahara:
        return AppColors.statusPaid;
      case UserRole.member:
        return AppColors.mossAccent;
    }
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool truncate;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    this.truncate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        truncate
            ? Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                value,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _RoleBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// =============================================================================
// Tab 3: Cross-Session Payments
// =============================================================================

class _PaymentsTab extends StatefulWidget {
  final NumberFormat rupiah;
  final Future<void> Function() onRefresh;

  const _PaymentsTab({required this.rupiah, required this.onRefresh});

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  PaymentStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final ds = DataService();
    var payments = List<PaymentModel>.from(ds.payments);

    // Filter by status
    if (_statusFilter != null) {
      payments = payments
          .where((p) => p.status == _statusFilter)
          .toList();
    }

    // Sort by latest
    payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Counts
    final pendingCount =
        ds.payments.where((p) => p.status == PaymentStatus.pending).length;
    final verifiedCount =
        ds.payments.where((p) => p.status == PaymentStatus.verified).length;
    final rejectedCount =
        ds.payments.where((p) => p.status == PaymentStatus.rejected).length;

    return RefreshIndicator(
      color: AppColors.forestInk,
      onRefresh: widget.onRefresh,
      child: Column(
        children: [
          // Summary badges
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _PaymentFilterChip(
                  label: 'Semua (${ds.payments.length})',
                  isSelected: _statusFilter == null,
                  color: AppColors.forestInk,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 8),
                _PaymentFilterChip(
                  label: 'Pending ($pendingCount)',
                  isSelected: _statusFilter == PaymentStatus.pending,
                  color: AppColors.warning,
                  onTap: () =>
                      setState(() => _statusFilter = PaymentStatus.pending),
                ),
                const SizedBox(width: 8),
                _PaymentFilterChip(
                  label: 'Verified ($verifiedCount)',
                  isSelected: _statusFilter == PaymentStatus.verified,
                  color: AppColors.success,
                  onTap: () =>
                      setState(() => _statusFilter = PaymentStatus.verified),
                ),
                const SizedBox(width: 8),
                _PaymentFilterChip(
                  label: 'Ditolak ($rejectedCount)',
                  isSelected: _statusFilter == PaymentStatus.rejected,
                  color: AppColors.clayRed,
                  onTap: () =>
                      setState(() => _statusFilter = PaymentStatus.rejected),
                ),
              ],
            ),
          ),
          // Payment list
          Expanded(
            child: payments.isEmpty
                ? const Center(
                    child: EmptyStateWidget(
                      icon: Icons.payment,
                      title: 'Tidak ada pembayaran',
                      subtitle: 'Pembayaran akan muncul di sini.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: payments.length,
                    itemBuilder: (context, index) {
                      final payment = payments[index];
                      final session =
                          ds.getSessionById(payment.sessionId);

                      return _PaymentTile(
                        payment: payment,
                        sessionTitle: session?.title ?? 'Sesi tidak ditemukan',
                        rupiah: widget.rupiah,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PaymentFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _PaymentFilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.white : color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentModel payment;
  final String sessionTitle;
  final NumberFormat rupiah;

  const _PaymentTile({
    required this.payment,
    required this.sessionTitle,
    required this.rupiah,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(payment.createdAt);

    final Color statusColor;
    final String statusLabel;
    switch (payment.status) {
      case PaymentStatus.pending:
        statusColor = AppColors.warning;
        statusLabel = 'Pending';
      case PaymentStatus.verified:
        statusColor = AppColors.success;
        statusLabel = 'Verified';
      case PaymentStatus.rejected:
        statusColor = AppColors.clayRed;
        statusLabel = 'Ditolak';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.userName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepCharcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sessionTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Amount + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rupiah.format(payment.amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Stat Card widget
// =============================================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: int.tryParse(value) != null
                      ? AnimatedCounter(
                          value: int.parse(value),
                          style: TextStyle(
                            fontSize: fullWidth ? 20 : 16,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: -0.3,
                          ),
                        )
                      : Text(
                          value,
                          style: TextStyle(
                            fontSize: fullWidth ? 20 : 16,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: -0.3,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 4: Venue Management
// =============================================================================

class _VenueTab extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _VenueTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final ds = DataService();
    final venues = ds.venues;

    return RefreshIndicator(
      color: AppColors.forestInk,
      onRefresh: onRefresh,
      child: venues.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 80),
                EmptyStateWidget(
                  icon: Icons.location_city_outlined,
                  title: 'Belum ada venue',
                  subtitle: 'Tambah venue pertama untuk komunitas.',
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: venues.length + 1,
              itemBuilder: (context, index) {
                if (index == venues.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _showVenueForm(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Venue'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.forestInk,
                          side: const BorderSide(color: AppColors.forestInk),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  );
                }

                final venue = venues[index];
                return _VenueTile(
                  venue: venue,
                  onEdit: () => _showVenueForm(context, venue: venue),
                  onDelete: () => _confirmDelete(context, venue),
                );
              },
            ),
    );
  }

  void _showVenueForm(BuildContext context, {VenueModel? venue}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VenueFormSheet(venue: venue),
    );
  }

  void _confirmDelete(BuildContext context, VenueModel venue) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Venue?'),
        content: Text('Venue "${venue.name}" akan dihapus. Aksi ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DataService().deleteVenue(venue.id);
              if (context.mounted) {
                SnackbarHelper.showSuccess(context, 'Venue berhasil dihapus');
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.clayRed),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _VenueTile extends StatelessWidget {
  final VenueModel venue;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VenueTile({
    required this.venue,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.forestInk.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sports_tennis, color: AppColors.forestInk, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepCharcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${venue.courtCount} court · ${venue.address}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColors.forestInk,
            onPressed: onEdit,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.clayRed,
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _VenueFormSheet extends StatefulWidget {
  final VenueModel? venue;

  const _VenueFormSheet({this.venue});

  @override
  State<_VenueFormSheet> createState() => _VenueFormSheetState();
}

class _VenueFormSheetState extends State<_VenueFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _bioController;
  late final TextEditingController _phoneController;
  late final TextEditingController _courtCountController;
  late final TextEditingController _openHoursController;
  late final TextEditingController _mapUrlController;

  bool get _isEditing => widget.venue != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.venue?.name ?? '');
    _addressController = TextEditingController(text: widget.venue?.address ?? '');
    _bioController = TextEditingController(text: widget.venue?.bio ?? '');
    _phoneController = TextEditingController(text: widget.venue?.phone ?? '');
    _courtCountController = TextEditingController(
      text: widget.venue?.courtCount.toString() ?? '1',
    );
    _openHoursController = TextEditingController(
      text: widget.venue?.openHours ?? '06:00 - 22:00',
    );
    _mapUrlController = TextEditingController(text: widget.venue?.mapUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _courtCountController.dispose();
    _openHoursController.dispose();
    _mapUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final courtCount = int.tryParse(_courtCountController.text.trim()) ?? 1;
    final phone = _phoneController.text.trim();
    final mapUrl = _mapUrlController.text.trim();

    final venue = VenueModel(
      id: widget.venue?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      bio: _bioController.text.trim(),
      phone: phone.isEmpty ? null : phone,
      courtCount: courtCount,
      openHours: _openHoursController.text.trim(),
      mapUrl: mapUrl.isEmpty ? null : mapUrl,
      facilities: widget.venue?.facilities ?? [],
    );

    if (_isEditing) {
      await DataService().updateVenue(venue);
    } else {
      await DataService().addVenue(venue);
    }

    if (!mounted) return;
    Navigator.pop(context);
    SnackbarHelper.showSuccess(
      context,
      _isEditing ? 'Venue berhasil diperbarui' : 'Venue berhasil ditambahkan',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _isEditing ? 'Edit Venue' : 'Tambah Venue Baru',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Venue'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.required(v, 'Nama'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Alamat'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => Validators.required(v, 'Alamat'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                validator: (v) => Validators.required(v, 'Deskripsi'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _courtCountController,
                      decoration: const InputDecoration(labelText: 'Jumlah Court'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 1) return 'Minimal 1 court';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _openHoursController,
                      decoration: const InputDecoration(labelText: 'Jam Operasional'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Telepon (opsional)'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _mapUrlController,
                decoration: const InputDecoration(
                  labelText: 'Google Maps URL (opsional)',
                  hintText: 'https://maps.google.com/...',
                ),
                keyboardType: TextInputType.url,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasScheme || !uri.host.contains('.')) {
                    return 'URL tidak valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestInk,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    _isEditing ? 'Simpan Perubahan' : 'Tambah Venue',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Tab 5: Analytics
// =============================================================================

class _AnalyticsTab extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _AnalyticsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final ds = DataService();

    return RefreshIndicator(
      color: AppColors.forestInk,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pertumbuhan Anggota',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepCharcoal,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          MemberGrowthChart(users: ds.users),
          const SizedBox(height: 24),

          const Text(
            'Utilisasi Sesi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepCharcoal,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          SessionUtilizationChart(sessions: ds.sessions, slots: ds.slots),
          const SizedBox(height: 24),

          const Text(
            'Pendapatan Bulanan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepCharcoal,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          RevenueChart(cashflows: ds.cashflows),
          const SizedBox(height: 24),

          const Text(
            'Ekonomi Chips',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepCharcoal,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          ChipsEconomyChart(transactions: ds.chipsTransactions),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
