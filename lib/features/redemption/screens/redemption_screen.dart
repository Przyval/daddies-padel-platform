import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/widgets/empty_state.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/features/chips/providers/chips_provider.dart';
import 'package:daddies_app/features/redemption/providers/redemption_provider.dart';
import 'package:daddies_app/models/partner_model.dart';
import 'package:daddies_app/models/redemption_model.dart';
import 'package:daddies_app/models/kta_tier.dart';
import 'package:daddies_app/services/data_service.dart';

class RedemptionScreen extends StatefulWidget {
  // Do NOT use const — this screen is deferred-imported by the router.
  // ignore: prefer_const_constructors_in_immutables
  RedemptionScreen({super.key});

  @override
  State<RedemptionScreen> createState() => _RedemptionScreenState();
}

class _RedemptionScreenState extends State<RedemptionScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    // Check for expired redemptions on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RedemptionProvider>().checkExpiredRedemptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Tukar Chips'),
          backgroundColor: AppColors.forestInk,
          foregroundColor: AppColors.agedLinen,
        ),
        body: Center(
          child: Text(
            'Login terlebih dahulu',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    context.watch<RedemptionProvider>();
    final chipsProv = context.watch<ChipsProvider>();
    final balance = chipsProv.getBalance(user.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Tukar Chips'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.agedLinen,
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.mossAccent.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.toll, size: 16, color: AppColors.agedLinen),
                    SizedBox(width: 4),
                    Text(
                      '$balance',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.agedLinen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppColors.agedLinen,
            child: Row(
              children: [
                _buildTab(0, 'Partner Diskon'),
                SizedBox(width: 8),
                _buildTab(1, 'Riwayat Saya'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: _selectedTab == 0
                ? _PartnerDiskonTab(
                    userId: user.id,
                    userName: user.name,
                    balance: balance,
                  )
                : _RiwayatSayaTab(userId: user.id),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final active = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.forestInk : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Tab 1: Partner Diskon
// =============================================================================

class _PartnerDiskonTab extends StatelessWidget {
  final String userId;
  final String userName;
  final int balance;

  _PartnerDiskonTab({
    required this.userId,
    required this.userName,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final ds = DataService();
    final partners = ds.getActivePartners()
        .where((p) => p.chipsPrice != null && p.chipsPrice! > 0)
        .toList();

    if (partners.isEmpty) {
      return Center(
        child: EmptyStateWidget(
          icon: Icons.storefront_outlined,
          title: 'Belum ada partner',
          subtitle: 'Partner diskon akan segera tersedia',
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.forestInk,
      onRefresh: () => DataService().refresh(),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: partners.length,
        itemBuilder: (context, index) {
          final partner = partners[index];
          return _PartnerCard(
            partner: partner,
            userId: userId,
            userName: userName,
            balance: balance,
          );
        },
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final PartnerModel partner;
  final String userId;
  final String userName;
  final int balance;

  _PartnerCard({
    required this.partner,
    required this.userId,
    required this.userName,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final chipsPrice = partner.chipsPrice ?? 0;
    final canAfford = balance >= chipsPrice;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Discount badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.forestInk.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${partner.discountPercent}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.forestInk,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepCharcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      partner.discountDescription,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Category badge + tier requirement row
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.mossAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  partner.category,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mossAccent,
                  ),
                ),
              ),
              if (partner.minimumTier != null) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Min. ${partner.minimumTier!.label}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
              Spacer(),
              // Chips price indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.toll, size: 14, color: AppColors.forestInk),
                  SizedBox(width: 4),
                  Text(
                    '$chipsPrice chips',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestInk,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          // Redeem button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: canAfford
                  ? () => _confirmRedeem(context, chipsPrice)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestInk,
                foregroundColor: AppColors.agedLinen,
                disabledBackgroundColor: AppColors.divider,
                disabledForegroundColor: AppColors.textTertiary,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: Text(
                canAfford
                    ? 'Tukar $chipsPrice Chips'
                    : 'Chips Tidak Cukup',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRedeem(BuildContext context, int chipsPrice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Konfirmasi Tukar Chips',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.deepCharcoal,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              partner.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.deepCharcoal,
              ),
            ),
            SizedBox(height: 4),
            Text(
              partner.discountDescription,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.toll, size: 20, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text(
                    '$chipsPrice chips akan dikurangi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Voucher berlaku 30 hari setelah penukaran.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _doRedeem(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestInk,
              foregroundColor: AppColors.agedLinen,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: Text('Tukar Sekarang'),
          ),
        ],
      ),
    );
  }

  void _doRedeem(BuildContext context) async {
    final redemptionProv = context.read<RedemptionProvider>();
    final chipsProv = context.read<ChipsProvider>();

    final ok = await redemptionProv.createRedemption(
      userId: userId,
      userName: userName,
      partner: partner,
      chipsProvider: chipsProv,
    );

    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil menukar chips! Cek Riwayat Saya.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final error = redemptionProv.errorMessage ?? 'Gagal menukar chips.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.clayRed,
        ),
      );
    }
  }
}

// =============================================================================
// Tab 2: Riwayat Saya
// =============================================================================

class _RiwayatSayaTab extends StatelessWidget {
  final String userId;

  _RiwayatSayaTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    final redemptionProv = context.watch<RedemptionProvider>();
    final redemptions = redemptionProv.getRedemptionsForUser(userId);

    if (redemptions.isEmpty) {
      return Center(
        child: EmptyStateWidget(
          icon: Icons.receipt_long_outlined,
          title: 'Belum ada riwayat',
          subtitle: 'Tukar chips kamu untuk mendapat diskon dari partner',
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.forestInk,
      onRefresh: () => DataService().refresh(),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: redemptions.length,
        itemBuilder: (context, index) {
          final r = redemptions[index];
          return _RedemptionTile(redemption: r);
        },
      ),
    );
  }
}

class _RedemptionTile extends StatelessWidget {
  final RedemptionModel redemption;

  _RedemptionTile({required this.redemption});

  Color _statusColor() {
    return switch (redemption.status) {
      RedemptionStatus.pending => AppColors.warning,
      RedemptionStatus.used => AppColors.success,
      RedemptionStatus.expired => AppColors.textTertiary,
      RedemptionStatus.cancelled => AppColors.clayRed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    final statusColor = _statusColor();
    final isActive = redemption.status == RedemptionStatus.pending &&
        redemption.expiresAt.isAfter(DateTime.now());

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            redemption.partnerName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepCharcoal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            redemption.discountDescription,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    // Status badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        redemption.statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Info row: chips spent + date
                Row(
                  children: [
                    Icon(Icons.toll, size: 14, color: AppColors.textTertiary),
                    SizedBox(width: 4),
                    Text(
                      '${redemption.chipsSpent} chips',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      dateFormat.format(redemption.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    if (isActive) ...[
                      SizedBox(width: 12),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Exp: ${dateFormat.format(redemption.expiresAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // QR code section for active redemptions
          if (isActive)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Divider(color: AppColors.divider, height: 1),
                  SizedBox(height: 16),
                  Text(
                    'Tunjukkan QR ke partner',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: QrImageView(
                      data: 'DEDIS-REDEEM:${redemption.id}:${redemption.userId}:${redemption.partnerId}',
                      version: QrVersions.auto,
                      size: 160,
                      backgroundColor: AppColors.white,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.forestInk,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: AppColors.forestInk,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: OutlinedButton(
                      onPressed: () => _confirmCancel(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.clayRed,
                        side: BorderSide(color: AppColors.clayRed.withValues(alpha: 0.4)),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Batalkan & Refund Chips',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Batalkan Redemption?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.deepCharcoal,
          ),
        ),
        content: Text(
          '${redemption.chipsSpent} chips akan dikembalikan ke saldo kamu.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Tidak',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _doCancel(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.clayRed,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  void _doCancel(BuildContext context) async {
    final redemptionProv = context.read<RedemptionProvider>();
    final chipsProv = context.read<ChipsProvider>();

    final ok = await redemptionProv.cancelRedemption(
      redemption.id,
      chipsProv,
    );

    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Redemption dibatalkan. Chips dikembalikan.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final error = redemptionProv.errorMessage ?? 'Gagal membatalkan.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.clayRed,
        ),
      );
    }
  }
}
