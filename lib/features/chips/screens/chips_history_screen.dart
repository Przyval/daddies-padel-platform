import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/widgets/empty_state.dart';
import 'package:daddies_app/models/chips_transaction_model.dart';
import 'package:daddies_app/features/chips/providers/chips_provider.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/services/data_service.dart';

class ChipsHistoryScreen extends StatefulWidget {
  const ChipsHistoryScreen({super.key});

  @override
  State<ChipsHistoryScreen> createState() => _ChipsHistoryScreenState();
}

enum _ChipsFilter { all, earned, spent }

class _ChipsHistoryScreenState extends State<ChipsHistoryScreen> {
  _ChipsFilter _filter = _ChipsFilter.all;

  static final _dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

  Future<void> _handleRefresh() async {
    await DataService().refresh();
    if (mounted) setState(() {});
  }

  List<ChipsTransactionModel> _applyFilter(
      List<ChipsTransactionModel> transactions) {
    switch (_filter) {
      case _ChipsFilter.all:
        return transactions;
      case _ChipsFilter.earned:
        return transactions.where((t) => t.amount > 0).toList();
      case _ChipsFilter.spent:
        return transactions.where((t) => t.amount < 0).toList();
    }
  }

  IconData _iconForSource(ChipsSource source) {
    return switch (source) {
      ChipsSource.sessionAttendance => Icons.event_available,
      ChipsSource.matchWin => Icons.emoji_events,
      ChipsSource.matchDraw => Icons.handshake_outlined,
      ChipsSource.streak3 => Icons.local_fire_department,
      ChipsSource.streak5 => Icons.local_fire_department,
      ChipsSource.ratingGiven => Icons.star_outline,
      ChipsSource.firstSession => Icons.celebration_outlined,
      ChipsSource.stakeWin => Icons.trending_up,
      ChipsSource.stakeLoss => Icons.trending_down,
      ChipsSource.redemption => Icons.redeem_outlined,
      ChipsSource.adminAdjust => Icons.admin_panel_settings_outlined,
      ChipsSource.welcomeBonus => Icons.card_giftcard,
      ChipsSource.referralBonus => Icons.people_outline,
    };
  }

  Color _iconColorForSource(ChipsSource source) {
    return switch (source) {
      ChipsSource.sessionAttendance => AppColors.success,
      ChipsSource.matchWin => const Color(0xFFFFD700),
      ChipsSource.matchDraw => AppColors.mossAccent,
      ChipsSource.streak3 => const Color(0xFFFF6B00),
      ChipsSource.streak5 => const Color(0xFFFF6B00),
      ChipsSource.ratingGiven => AppColors.warning,
      ChipsSource.firstSession => AppColors.statusPaid,
      ChipsSource.stakeWin => AppColors.success,
      ChipsSource.stakeLoss => AppColors.clayRed,
      ChipsSource.redemption => AppColors.clayRed,
      ChipsSource.adminAdjust => AppColors.forestInk,
      ChipsSource.welcomeBonus => AppColors.statusPaid,
      ChipsSource.referralBonus => AppColors.success,
    };
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final chipsProv = context.watch<ChipsProvider>();
    final userId = authProv.currentUser?.id;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daddies Chips')),
        body: const Center(child: Text('Silakan login terlebih dahulu.')),
      );
    }

    final balance = chipsProv.getBalance(userId);
    final transactions = _applyFilter(chipsProv.getTransactionsForUser(userId));

    return Scaffold(
      backgroundColor: AppColors.sagePaper,
      appBar: AppBar(
        title: const Text('Daddies Chips'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.agedLinen,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.forestInk,
        onRefresh: _handleRefresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // -- Balance card ------------------------------------------------
            _buildBalanceCard(balance),
            const SizedBox(height: 20),

            // -- Filter chips ------------------------------------------------
            _buildFilterChips(),
            const SizedBox(height: 16),

            // -- Section header -----------------------------------------------
            const Text(
              'Riwayat Transaksi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deepCharcoal,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            // -- Transaction list --------------------------------------------
            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: EmptyStateWidget(
                  icon: Icons.receipt_long_outlined,
                  title: 'Belum ada transaksi',
                  subtitle: 'Riwayat chips akan muncul di sini setelah kamu bermain.',
                ),
              )
            else
              ...transactions.map(_buildTransactionTile),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Balance card
  // ---------------------------------------------------------------------------

  Widget _buildBalanceCard(int balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.forestInk,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.monetization_on,
                color: AppColors.warning,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                NumberFormat('#,###', 'id_ID').format(balance),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: AppColors.agedLinen,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Daddies Chips',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.agedLinen.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter chips
  // ---------------------------------------------------------------------------

  Widget _buildFilterChips() {
    const filters = [
      (_ChipsFilter.all, 'Semua'),
      (_ChipsFilter.earned, 'Diperoleh'),
      (_ChipsFilter.spent, 'Digunakan'),
    ];

    return Row(
      children: filters.map((f) {
        final active = _filter == f.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _filter = f.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.forestInk : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                f.$2,
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
    );
  }

  // ---------------------------------------------------------------------------
  // Transaction tile
  // ---------------------------------------------------------------------------

  Widget _buildTransactionTile(ChipsTransactionModel txn) {
    final isPositive = txn.amount > 0;
    final amountColor = isPositive ? AppColors.success : AppColors.clayRed;
    final amountPrefix = isPositive ? '+' : '';
    final iconData = _iconForSource(txn.source);
    final iconColor = _iconColorForSource(txn.source);
    final dateStr = _dateFormat.format(txn.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepCharcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Amount
          Text(
            '$amountPrefix${txn.amount}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
