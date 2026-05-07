import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/widgets/empty_state.dart';
import 'package:daddies_app/models/referral_model.dart';
import 'package:daddies_app/features/referral/providers/referral_provider.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';

class ReferralScreen extends StatefulWidget {
  // Do NOT use const — this screen is deferred-imported by the router.
  // ignore: prefer_const_constructors_in_immutables
  ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final TextEditingController _codeController = TextEditingController();
  static final _dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kode referral disalin: $code'),
        backgroundColor: AppColors.forestInk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareCode(String code) {
    final text =
        'Yuk gabung Daddies Padel! Pakai kode referral saya: $code';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Teks undangan disalin ke clipboard'),
        backgroundColor: AppColors.forestInk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _applyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final authProv = context.read<AuthProvider>();
    final refProv = context.read<ReferralProvider>();
    final user = authProv.currentUser;
    if (user == null) return;

    final success = await refProv.applyReferralCode(code, user.id, user.name);

    if (!mounted) return;

    if (success) {
      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kode referral berhasil diterapkan!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(refProv.errorMessage ?? 'Gagal menerapkan kode.'),
          backgroundColor: AppColors.clayRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final refProv = context.watch<ReferralProvider>();
    final userId = authProv.currentUser?.id;
    final userName = authProv.currentUser?.name ?? '';

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Referral')),
        body: Center(child: Text('Silakan login terlebih dahulu.')),
      );
    }

    final referralCode = refProv.getOrCreateReferralCode(userId, userName);
    final referrals = refProv.getReferralsForUser(userId);
    final completedCount =
        referrals.where((r) => r.status == ReferralStatus.completed).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Referral'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.agedLinen,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // -- Referral code card -------------------------------------------
          _buildReferralCodeCard(referralCode),
          SizedBox(height: 20),

          // -- Stats section ------------------------------------------------
          _buildStatsSection(completedCount),
          SizedBox(height: 20),

          // -- Referral list header -----------------------------------------
          Text(
            'Daftar Referral',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepCharcoal,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 12),

          // -- Referral list ------------------------------------------------
          if (referrals.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 32),
              child: EmptyStateWidget(
                icon: Icons.people_outline,
                title: 'Belum ada referral',
                subtitle:
                    'Bagikan kode referral kamu untuk mengajak teman bergabung.',
              ),
            )
          else
            ...referrals.map(_buildReferralTile),

          SizedBox(height: 28),

          // -- Apply referral code section ----------------------------------
          _buildApplyCodeSection(refProv),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Referral Code Card
  // ---------------------------------------------------------------------------

  Widget _buildReferralCodeCard(String code) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.forestInk,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            'Kode Referral Kamu',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.white.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: 12),
          Text(
            code,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Copy button
              OutlinedButton.icon(
                onPressed: () => _copyCode(code),
                icon: Icon(Icons.copy, size: 18),
                label: Text('Salin'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.white,
                  side: BorderSide(
                    color: AppColors.white.withValues(alpha: 0.4),
                  ),
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              SizedBox(width: 12),
              // Share button
              OutlinedButton.icon(
                onPressed: () => _shareCode(code),
                icon: Icon(Icons.share, size: 18),
                label: Text('Bagikan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.white,
                  side: BorderSide(
                    color: AppColors.white.withValues(alpha: 0.4),
                  ),
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats Section
  // ---------------------------------------------------------------------------

  Widget _buildStatsSection(int completedCount) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.group_add, color: AppColors.success, size: 24),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completedCount teman berhasil diajak',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepCharcoal,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Setiap teman yang bermain = bonus chips!',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Referral Tile
  // ---------------------------------------------------------------------------

  Widget _buildReferralTile(ReferralModel referral) {
    final hasReferee = referral.refereeName != null &&
        referral.refereeName!.isNotEmpty;
    final displayName = hasReferee ? referral.refereeName! : 'Menunggu...';
    final dateStr = _dateFormat.format(referral.createdAt);

    final Color statusColor;
    final String statusLabel;
    switch (referral.status) {
      case ReferralStatus.pending:
        statusColor = AppColors.warning;
        statusLabel = referral.statusLabel;
      case ReferralStatus.completed:
        statusColor = AppColors.success;
        statusLabel = referral.statusLabel;
      case ReferralStatus.expired:
        statusColor = AppColors.textTertiary;
        statusLabel = referral.statusLabel;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar placeholder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.sagePaper,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasReferee ? Icons.person : Icons.hourglass_empty,
              color: hasReferee ? AppColors.forestInk : AppColors.textTertiary,
              size: 20,
            ),
          ),
          SizedBox(width: 12),

          // Name and date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: hasReferee
                        ? AppColors.deepCharcoal
                        : AppColors.textTertiary,
                    fontStyle:
                        hasReferee ? FontStyle.normal : FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),

          // Status badge and bonus indicator
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              if (referral.status == ReferralStatus.completed) ...[
                SizedBox(height: 4),
                Text(
                  '+${referral.referrerBonus} chips',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Apply Code Section
  // ---------------------------------------------------------------------------

  Widget _buildApplyCodeSection(ReferralProvider refProv) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Masukkan Kode Referral',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.deepCharcoal,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Punya kode referral dari teman? Masukkan di sini.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Contoh: ALI-DDS-X7K2',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: AppColors.forestInk, width: 1.5),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: refProv.isBusy ? null : _applyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestInk,
                    foregroundColor: AppColors.agedLinen,
                    shape: const StadiumBorder(),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: refProv.isBusy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.agedLinen,
                          ),
                        )
                      : Text(
                          'Gunakan',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
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
