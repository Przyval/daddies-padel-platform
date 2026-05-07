import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/models/slot_model.dart';
import 'package:daddies_app/models/payment_model.dart';
import 'package:daddies_app/features/sessions/providers/session_provider.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/core/widgets/loading_overlay.dart';
import 'package:daddies_app/core/utils/snackbar_helper.dart';
import 'package:daddies_app/core/widgets/success_overlay.dart';
import 'package:go_router/go_router.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:daddies_app/core/widgets/player_profile_sheet.dart';
import 'package:daddies_app/core/widgets/lottie_animations.dart';
import 'package:daddies_app/core/utils/haptic_helper.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/core/widgets/venue_link.dart';
import 'package:daddies_app/models/rating_model.dart';
import 'package:daddies_app/models/match_result_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:daddies_app/features/sessions/widgets/invite_members_sheet.dart';
import 'package:daddies_app/features/chips/providers/chips_provider.dart';
import 'package:daddies_app/features/referral/providers/referral_provider.dart';

class SessionDetailScreen extends StatelessWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final authProvider = context.watch<AuthProvider>();
    final session = sessionProvider.getSessionById(sessionId);

    if (session == null) {
      return Scaffold(
        backgroundColor: AppColors.sagePaper,
        appBar: AppBar(
          title: const Text('Sesi Tidak Ditemukan'),
          backgroundColor: AppColors.forestInk,
          foregroundColor: AppColors.agedLinen,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Sesi ini tidak ditemukan atau sudah dihapus.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final slots = sessionProvider.getSlotsForSession(sessionId);
    final payments = sessionProvider.getPaymentsForSession(sessionId);
    final confirmedCount = sessionProvider.getConfirmedCount(sessionId);
    final paidCount = sessionProvider.getPaidCount(sessionId);
    final canJoin = sessionProvider.canUserJoin(sessionId);
    final isMimin = authProvider.canManageSessions;
    final currentUser = authProvider.currentUser;

    final bool userIsInSession =
        currentUser != null && slots.any((s) => s.userId == currentUser.id);
    final bool isSessionMimin =
        currentUser != null && session.miminId == currentUser.id;

    final rupiahFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormatted =
        DateFormat('EEEE, d MMM yyyy', 'id_ID').format(session.date);

    final int totalCollected = payments
        .where((p) => p.status == PaymentStatus.verified)
        .fold<int>(0, (sum, p) => sum + p.amount);
    final int totalExpected = confirmedCount * session.pricePerPlayer;

    return Scaffold(
      backgroundColor: AppColors.sagePaper,
      appBar: AppBar(
        title: Text(
          session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.agedLinen,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _shareSession(context, session, rupiahFormat),
            icon: const Icon(Icons.share_outlined, size: 22),
            tooltip: 'Bagikan',
          ),
          IconButton(
            onPressed: () => _showQrCode(context, session),
            icon: const Icon(Icons.qr_code, size: 22),
            tooltip: 'QR Code',
          ),
          if ((isMimin || isSessionMimin) &&
              (session.status == SessionStatus.draft ||
                  session.status == SessionStatus.open ||
                  session.status == SessionStatus.full))
            IconButton(
              onPressed: () {
                context.push(
                  AppRoutes.sessionEditPath(session.id),
                  extra: session,
                );
              },
              icon: const Icon(Icons.edit_outlined, size: 22),
              tooltip: 'Edit Sesi',
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(
        context: context,
        session: session,
        slots: slots,
        canJoin: canJoin,
        userIsInSession: userIsInSession,
        isMimin: isMimin,
        isSessionMimin: isSessionMimin,
        sessionProvider: sessionProvider,
      ),
      body: LoadingOverlay(
        isLoading: sessionProvider.isBusy,
        child: RefreshIndicator(
        color: AppColors.forestInk,
        onRefresh: () => DataService().refresh(),
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // Header card
            // -----------------------------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.agedLinen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status chip
                  _SessionStatusChip(status: session.status),
                  const SizedBox(height: 12),

                  // Venue
                  GestureDetector(
                    onTap: () => navigateToVenue(context, session.venue),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 18, color: AppColors.mossAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            session.venue,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.deepCharcoal,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.mossAccent,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 16, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Date
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.mossAccent),
                      const SizedBox(width: 6),
                      Text(
                        dateFormatted,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.deepCharcoal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Time
                  Row(
                    children: [
                      const Icon(Icons.access_time_outlined,
                          size: 18, color: AppColors.mossAccent),
                      const SizedBox(width: 6),
                      Text(
                        '${session.timeStart} - ${session.timeEnd}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.deepCharcoal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Price
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined,
                          size: 18, color: AppColors.mossAccent),
                      const SizedBox(width: 6),
                      Text(
                        '${rupiahFormat.format(session.pricePerPlayer)} / orang',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.clayRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Mimin
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 18, color: AppColors.mossAccent),
                      const SizedBox(width: 6),
                      Text(
                        'Mimin: ${session.miminName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // Court number
                  if (session.courtNumber != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.grid_view_rounded,
                            size: 18, color: AppColors.mossAccent),
                        const SizedBox(width: 6),
                        Text(
                          'Court ${session.courtNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.deepCharcoal,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Player count summary
                  Row(
                    children: [
                      const Icon(Icons.group_outlined,
                          size: 18, color: AppColors.mossAccent),
                      const SizedBox(width: 6),
                      Text(
                        '$confirmedCount/${session.maxPlayers} pemain',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepCharcoal,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '($paidCount sudah bayar)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: 12),

                  // Total collected
                  Row(
                    children: [
                      const Text(
                        'Total terkumpul: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${rupiahFormat.format(totalCollected)} / ${rupiahFormat.format(totalExpected)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forestInk,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Notes
            if (session.notes != null && session.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined,
                        size: 18, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Catatan Mimin',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.notes!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.deepCharcoal,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Cancellation reason
            if (session.status == SessionStatus.cancelled &&
                session.cancellationReason != null &&
                session.cancellationReason!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.clayRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppColors.clayRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Alasan Pembatalan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.clayRed,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.cancellationReason!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.deepCharcoal,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // -----------------------------------------------------------------
            // Section: Pemain (Players / Slots)
            // -----------------------------------------------------------------
            const Text(
              'Pemain',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.deepCharcoal,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            if (slots.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.agedLinen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Belum ada pemain yang bergabung.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.agedLinen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: slots.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: AppColors.divider, height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    return _SlotRow(
                      slot: slot,
                      isMimin: isMimin || isSessionMimin,
                      payments: payments,
                      sessionProvider: sessionProvider,
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // -----------------------------------------------------------------
            // Section: Pembayaran (Payments)
            // -----------------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pembayaran',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepCharcoal,
                    letterSpacing: -0.3,
                  ),
                ),
                if ((isMimin || isSessionMimin) && slots.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      // Find unpaid players
                      final unpaidNames = <String>[];
                      for (final slot in slots) {
                        final hasPaid = payments.any(
                          (p) => p.userId == slot.userId && p.status != PaymentStatus.rejected,
                        );
                        if (!hasPaid) unpaidNames.add(slot.userName);
                      }

                      if (unpaidNames.isEmpty) {
                        SnackbarHelper.showSuccess(context, 'Semua pemain sudah bayar!');
                        return;
                      }

                      final message = StringBuffer()
                        ..writeln('Pengingat Pembayaran')
                        ..writeln('Sesi: ${session.title}')
                        ..writeln('Tanggal: $dateFormatted')
                        ..writeln('Nominal: ${rupiahFormat.format(session.pricePerPlayer)}/orang')
                        ..writeln()
                        ..writeln('Belum bayar:')
                        ..writeAll(unpaidNames.map((n) => '- $n'), '\n')
                        ..writeln()
                        ..writeln()
                        ..writeln('Mohon segera transfer. Terima kasih!');

                      HapticHelper.light();
                      Share.share(message.toString());
                    },
                    icon: const Icon(Icons.notifications_active_outlined, size: 16),
                    label: const Text('Ingatkan', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (payments.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.agedLinen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Belum ada pembayaran.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.agedLinen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: payments.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: AppColors.divider, height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    return _PaymentRow(
                      payment: payment,
                      isMimin: isMimin || isSessionMimin,
                      sessionProvider: sessionProvider,
                      rupiahFormat: rupiahFormat,
                    );
                  },
                ),
              ),

            // -----------------------------------------------------------------
            // Section: Galeri Foto
            // -----------------------------------------------------------------
            const SizedBox(height: 24),
            _PhotoGallerySection(
              sessionId: sessionId,
              sessionProvider: sessionProvider,
              isMimin: isMimin || isSessionMimin,
            ),

            // -----------------------------------------------------------------
            // Section: Rating Pemain
            // -----------------------------------------------------------------
            if (session.status == SessionStatus.completed) ...[
              const SizedBox(height: 24),
              const Text(
                'Rating Pemain',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepCharcoal,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              _RatingSection(
                sessionId: sessionId,
                slots: slots,
                sessionProvider: sessionProvider,
                currentUserId: currentUser?.id,
              ),
              const SizedBox(height: 8),
            ],

            // -----------------------------------------------------------------
            // Section: Match Results (Americano Scoring)
            // -----------------------------------------------------------------
            if (session.status == SessionStatus.completed ||
                session.status == SessionStatus.locked) ...[
              const SizedBox(height: 24),
              _MatchResultsSection(
                sessionId: sessionId,
                isMimin: isMimin || isSessionMimin,
              ),
            ],

            // -----------------------------------------------------------------
            // Section: Attendance (Absensi)
            // -----------------------------------------------------------------
            if ((isMimin || isSessionMimin) &&
                (session.status == SessionStatus.locked ||
                 session.status == SessionStatus.completed)) ...[
              const SizedBox(height: 24),
              _AttendanceSection(sessionId: sessionId, slots: slots),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
      ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Share & QR
  // ---------------------------------------------------------------------------

  void _shareSession(
    BuildContext context,
    SessionModel session,
    NumberFormat rupiahFormat,
  ) {
    final dateFormatted =
        DateFormat('EEEE, d MMM yyyy', 'id_ID').format(session.date);
    final text = StringBuffer()
      ..writeln('*${session.title}*')
      ..writeln()
      ..writeln('Venue: ${session.venue}')
      ..writeln('Tanggal: $dateFormatted')
      ..writeln('Waktu: ${session.timeStart} - ${session.timeEnd}')
      ..writeln('Harga: ${rupiahFormat.format(session.pricePerPlayer)}/orang')
      ..writeln('Max: ${session.maxPlayers} pemain')
      ..writeln()
      ..writeln('Join via Daddies Padel Community App!')
      ..writeln('daddies://session/${session.id}');

    Share.share(text.toString());
  }

  void _showQrCode(BuildContext context, SessionModel session) {
    final deepLink = 'daddies://session/${session.id}';
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              session.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan QR code untuk join sesi',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: deepLink,
                version: QrVersions.auto,
                size: 200,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF2F3E34),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: Color(0xFF2F3E34),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _shareSession(
                    context,
                    session,
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ),
                  );
                },
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Bagikan ke WhatsApp'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom action bar
  // ---------------------------------------------------------------------------

  Widget? _buildBottomBar({
    required BuildContext context,
    required SessionModel session,
    required List<SlotModel> slots,
    required bool canJoin,
    required bool userIsInSession,
    required bool isMimin,
    required bool isSessionMimin,
    required SessionProvider sessionProvider,
  }) {
    final List<Widget> actions = [];

    // --- Member actions ---
    if (canJoin &&
        (session.status == SessionStatus.open ||
            session.status == SessionStatus.full)) {
      actions.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final success = await sessionProvider.joinSession(sessionId);
              if (!context.mounted) return;
              if (success) {
                HapticHelper.success();
                SuccessOverlay.show(context, message: 'Berhasil bergabung!');
              } else {
                SnackbarHelper.showError(context, sessionProvider.errorMessage ?? 'Gagal join sesi');
              }
            },
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Join Sesi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestInk,
              foregroundColor: AppColors.agedLinen,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      );
    }

    if (userIsInSession &&
        session.status != SessionStatus.locked &&
        session.status != SessionStatus.completed &&
        session.status != SessionStatus.cancelled) {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 12));
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              _showConfirmDialog(
                context: context,
                title: 'Leave Sesi?',
                message: 'Kamu yakin ingin keluar dari sesi ini?',
                confirmLabel: 'Leave',
                confirmColor: AppColors.clayRed,
                onConfirm: () async {
                  final success = await sessionProvider.leaveSession(sessionId);
                  if (!context.mounted) return;
                  if (success) {
                    SnackbarHelper.showSuccess(context, 'Berhasil keluar dari sesi');
                  } else {
                    SnackbarHelper.showError(context, sessionProvider.errorMessage ?? 'Gagal keluar dari sesi');
                  }
                },
              );
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Leave'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.clayRed,
              side: const BorderSide(color: AppColors.clayRed, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      );
    }

    // --- Mimin actions ---
    if (isMimin || isSessionMimin) {
      // Invite players button (only for open/full sessions)
      if (session.status == SessionStatus.open ||
          session.status == SessionStatus.full) {
        if (actions.isNotEmpty) actions.add(const SizedBox(width: 12));
        actions.add(
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final slotUserIds = slots.map((s) => s.userId).toList();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => InviteMembersSheet(
                    sessionId: sessionId,
                    alreadyInSession: slotUserIds,
                    alreadyInvited: session.invitedPlayerIds,
                  ),
                );
              },
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Undang'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forestInk,
                side: const BorderSide(color: AppColors.forestInk),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        );
      }

      if (session.status == SessionStatus.open ||
          session.status == SessionStatus.full) {
        if (actions.isNotEmpty) actions.add(const SizedBox(width: 12));
        actions.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                _showConfirmDialog(
                  context: context,
                  title: 'Lock Sesi?',
                  message:
                      'Setelah di-lock, pemain tidak bisa join atau leave lagi.',
                  confirmLabel: 'Lock',
                  confirmColor: AppColors.forestInk,
                  onConfirm: () async {
                    final success = await sessionProvider.updateSessionStatus(
                        sessionId, SessionStatus.locked);
                    if (!context.mounted) return;
                    if (success) {
                      SnackbarHelper.showSuccess(context, 'Sesi berhasil di-lock');
                    } else {
                      SnackbarHelper.showError(context, sessionProvider.errorMessage ?? 'Gagal lock sesi');
                    }
                  },
                );
              },
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Lock Sesi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestInk,
                foregroundColor: AppColors.agedLinen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        );
      }

      if (session.status == SessionStatus.locked) {
        if (actions.isNotEmpty) actions.add(const SizedBox(width: 12));
        actions.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                _showConfirmDialog(
                  context: context,
                  title: 'Selesaikan Sesi?',
                  message:
                      'Tandai sesi ini sebagai selesai. Pastikan semua pembayaran sudah terverifikasi.',
                  confirmLabel: 'Selesai',
                  confirmColor: AppColors.statusCompleted,
                  onConfirm: () async {
                    final success = await sessionProvider.updateSessionStatus(
                        sessionId, SessionStatus.completed);
                    if (!context.mounted) return;
                    if (success) {
                      // Auto-award chips for session attendance + streaks
                      await context.read<ChipsProvider>().awardSessionCompletionChips(sessionId);
                      // Check referral completion for first-session users
                      if (context.mounted) {
                        await context.read<ReferralProvider>().checkReferralCompletionForSession(sessionId);
                      }
                      if (context.mounted) {
                        SnackbarHelper.showSuccess(context, 'Sesi selesai! Chips telah dibagikan');
                      }
                    } else {
                      SnackbarHelper.showError(context, sessionProvider.errorMessage ?? 'Gagal menyelesaikan sesi');
                    }
                  },
                );
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Complete Sesi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusCompleted,
                foregroundColor: AppColors.agedLinen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        );
      }

      if (session.status != SessionStatus.completed &&
          session.status != SessionStatus.cancelled) {
        if (actions.isNotEmpty) actions.add(const SizedBox(width: 12));
        actions.add(
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                _showCancelDialog(context, sessionProvider, sessionId);
              },
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.clayRed,
                side: const BorderSide(color: AppColors.clayRed, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        );
      }

      // Duplicate session
      if (isMimin || isSessionMimin) {
        actions.add(const SizedBox(width: 8));
        actions.add(
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final success = await sessionProvider.duplicateSession(session);
                if (!context.mounted) return;
                if (success) {
                  HapticHelper.success();
                  SuccessOverlay.show(context, message: 'Sesi berhasil diduplikasi!');
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Buat Ulang'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forestInk,
                side: const BorderSide(color: AppColors.forestInk),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        );
      }
    }

    if (actions.isEmpty) return null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.agedLinen,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions.where((w) => w is! SizedBox).map((w) {
            // Strip Expanded wrappers for Wrap layout
            if (w is Expanded) return w.child;
            return w;
          }).toList(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cancel with reason dialog
  // ---------------------------------------------------------------------------

  void _showCancelDialog(BuildContext context, SessionProvider sessionProvider, String sessionId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Sesi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Semua pemain akan dinotifikasi dan pembayaran terverifikasi akan di-refund.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan pembatalan',
                hintText: 'Contoh: Hujan deras, lapangan tergenang',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              final success = await sessionProvider.cancelSessionWithReason(sessionId, reason);
              if (context.mounted && success) {
                HapticHelper.heavy();
                SnackbarHelper.showSuccess(context, 'Sesi dibatalkan');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.clayRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Batalkan Sesi'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Confirmation dialog helper
  // ---------------------------------------------------------------------------

  void _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required Future<void> Function() onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.agedLinen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.deepCharcoal,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: AppColors.agedLinen,
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await onConfirm();
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Session Status Chip (detail-screen version)
// =============================================================================

class _SessionStatusChip extends StatelessWidget {
  final SessionStatus status;

  const _SessionStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    switch (status) {
      case SessionStatus.draft:
        bgColor = AppColors.textTertiary.withValues(alpha:0.15);
        textColor = AppColors.textTertiary;
        label = 'Draft';
      case SessionStatus.open:
        bgColor = AppColors.statusOpen.withValues(alpha:0.15);
        textColor = AppColors.statusOpen;
        label = 'Open';
      case SessionStatus.full:
        bgColor = AppColors.statusWaitlist.withValues(alpha:0.15);
        textColor = AppColors.statusWaitlist;
        label = 'Full';
      case SessionStatus.locked:
        bgColor = AppColors.statusLocked.withValues(alpha:0.15);
        textColor = AppColors.statusLocked;
        label = 'Locked';
      case SessionStatus.completed:
        bgColor = AppColors.statusCompleted.withValues(alpha:0.15);
        textColor = AppColors.statusCompleted;
        label = 'Selesai';
      case SessionStatus.cancelled:
        bgColor = AppColors.statusCancelled.withValues(alpha:0.15);
        textColor = AppColors.statusCancelled;
        label = 'Batal';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// =============================================================================
// Slot Status Chip
// =============================================================================

class _SlotStatusChip extends StatelessWidget {
  final SlotStatus status;

  const _SlotStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    switch (status) {
      case SlotStatus.registered:
        bgColor = AppColors.textTertiary.withValues(alpha:0.15);
        textColor = AppColors.textTertiary;
        label = 'Registered';
      case SlotStatus.waitlist:
        bgColor = AppColors.statusWaitlist.withValues(alpha:0.15);
        textColor = AppColors.statusWaitlist;
        label = 'Waitlist';
      case SlotStatus.confirmed:
        bgColor = AppColors.statusOpen.withValues(alpha:0.15);
        textColor = AppColors.statusOpen;
        label = 'Confirmed';
      case SlotStatus.paid:
        bgColor = AppColors.statusPaid.withValues(alpha:0.15);
        textColor = AppColors.statusPaid;
        label = 'Paid';
      case SlotStatus.locked:
        bgColor = AppColors.statusLocked.withValues(alpha:0.15);
        textColor = AppColors.statusLocked;
        label = 'Locked';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// =============================================================================
// Payment Status Chip
// =============================================================================

class _PaymentStatusChip extends StatelessWidget {
  final PaymentStatus status;

  const _PaymentStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    switch (status) {
      case PaymentStatus.pending:
        bgColor = AppColors.statusWaitlist.withValues(alpha:0.15);
        textColor = AppColors.statusWaitlist;
        label = 'Menunggu';
      case PaymentStatus.verified:
        bgColor = AppColors.statusOpen.withValues(alpha:0.15);
        textColor = AppColors.statusOpen;
        label = 'Terverifikasi';
      case PaymentStatus.rejected:
        bgColor = AppColors.statusCancelled.withValues(alpha:0.15);
        textColor = AppColors.statusCancelled;
        label = 'Ditolak';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// =============================================================================
// Slot Row Widget
// =============================================================================

class _SlotRow extends StatelessWidget {
  final SlotModel slot;
  final bool isMimin;
  final List<PaymentModel> payments;
  final SessionProvider sessionProvider;

  const _SlotRow({
    required this.slot,
    required this.isMimin,
    required this.payments,
    required this.sessionProvider,
  });

  @override
  Widget build(BuildContext context) {
    // Find the payment associated with this slot (if any).
    final slotPayments = payments.where((p) => p.slotId == slot.id).toList();
    final hasPendingPayment =
        slotPayments.any((p) => p.status == PaymentStatus.pending);
    final PaymentModel? pendingPayment = hasPendingPayment
        ? slotPayments.firstWhere((p) => p.status == PaymentStatus.pending)
        : null;

    return InkWell(
      onTap: () => showPlayerProfileSheet(context, slot.userId),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Player avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.mossAccent.withValues(alpha:0.2),
              child: Text(
                slot.userName.isNotEmpty ? slot.userName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forestInk,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Player name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepCharcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _SlotStatusChip(status: slot.status),
                ],
              ),
            ),

            // Mimin action buttons for pending payments
            if (isMimin && hasPendingPayment && pendingPayment != null) ...[
              IconButton(
                onPressed: () async {
                  HapticHelper.medium();
                  final success = await sessionProvider.verifyPayment(pendingPayment.id);
                  if (!context.mounted) return;
                  if (success) {
                    SnackbarHelper.showSuccess(context, 'Pembayaran ${slot.userName} berhasil diverifikasi');
                  } else {
                    SnackbarHelper.showError(context, sessionProvider.errorMessage ?? 'Gagal verifikasi pembayaran');
                  }
                },
                icon: const Icon(Icons.check_circle, size: 22),
                color: AppColors.statusOpen,
                tooltip: 'Verifikasi',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                onPressed: () {
                  _showRejectConfirmDialog(
                    context: context,
                    userName: slot.userName,
                    onConfirm: () async {
                      HapticHelper.heavy();
                      final success = await sessionProvider.rejectPayment(pendingPayment.id);
                      if (!context.mounted) return;
                      if (success) {
                        SnackbarHelper.showSuccess(context, 'Pembayaran ${slot.userName} ditolak');
                      } else {
                        SnackbarHelper.showError(context, sessionProvider.errorMessage ?? 'Gagal menolak pembayaran');
                      }
                    },
                  );
                },
                icon: const Icon(Icons.cancel, size: 22),
                color: AppColors.statusCancelled,
                tooltip: 'Tolak',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],

            // Chevron hint for tappable profile
            if (!(isMimin && hasPendingPayment && pendingPayment != null))
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Payment Row Widget
// =============================================================================

class _PaymentRow extends StatelessWidget {
  final PaymentModel payment;
  final bool isMimin;
  final SessionProvider sessionProvider;
  final NumberFormat rupiahFormat;

  const _PaymentRow({
    required this.payment,
    required this.isMimin,
    required this.sessionProvider,
    required this.rupiahFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name, amount, status
          Row(
            children: [
              // Payer avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.mossAccent.withValues(alpha:0.2),
                child: Text(
                  payment.userName.isNotEmpty
                      ? payment.userName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestInk,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Name + amount
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
                      rupiahFormat.format(payment.amount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Status chip
              _PaymentStatusChip(status: payment.status),
            ],
          ),

          // Proof image thumbnail (if available)
          if (payment.proofImagePath != null &&
              payment.proofImagePath!.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                _showProofImageDialog(context, payment.proofImagePath!);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.sagePaper,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildProofThumbnail(payment.proofImagePath!),
                ),
              ),
            ),
          ],

          // Verify / Reject buttons for mimin (pending payments only)
          if (isMimin && payment.status == PaymentStatus.pending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  height: 34,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      HapticHelper.medium();
                      final success = await sessionProvider.verifyPayment(payment.id);
                      if (!context.mounted) return;
                      if (success) {
                        SnackbarHelper.showSuccess(context, 'Pembayaran ${payment.userName} berhasil diverifikasi');
                      } else {
                        SnackbarHelper.showError(context, sessionProvider.errorMessage ?? 'Gagal verifikasi pembayaran');
                      }
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Verifikasi', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusOpen,
                      foregroundColor: AppColors.agedLinen,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showRejectConfirmDialog(
                        context: context,
                        userName: payment.userName,
                        onConfirm: () async {
                          HapticHelper.heavy();
                          final success = await sessionProvider.rejectPayment(payment.id);
                          if (!context.mounted) return;
                          if (success) {
                            SnackbarHelper.showSuccess(context, 'Pembayaran ${payment.userName} ditolak');
                          } else {
                            SnackbarHelper.showError(context, sessionProvider.errorMessage ?? 'Gagal menolak pembayaran');
                          }
                        },
                      );
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Tolak', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.clayRed,
                      side: const BorderSide(color: AppColors.clayRed),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Verified info
          if (payment.status == PaymentStatus.verified &&
              payment.verifiedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Diverifikasi pada ${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(payment.verifiedAt!)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isNetworkUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  Widget _buildProofThumbnail(String imagePath) {
    if (_isNetworkUrl(imagePath)) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        memCacheWidth: 160, // 2x for retina, limits decoded memory
        memCacheHeight: 160,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (context, url) => Container(
          color: AppColors.divider.withValues(alpha: 0.3),
          child: const Center(
            child: LottieLoading(width: 24, height: 24),
          ),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.image_outlined, color: AppColors.textTertiary, size: 28),
        ),
      );
    }
    final file = File(imagePath);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover, width: 80, height: 80,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.image_outlined, color: AppColors.textTertiary, size: 28),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.receipt_long_outlined, color: AppColors.textTertiary, size: 28),
    );
  }

  void _showProofImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.deepCharcoal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: AppColors.agedLinen),
                ),
              ),

              // Image
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildFullProofImage(imagePath),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullProofImage(String imagePath) {
    if (_isNetworkUrl(imagePath)) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (context, url) => const SizedBox(
          height: 200,
          child: Center(child: LottieLoading(width: 60, height: 30)),
        ),
        errorWidget: (context, url, error) => Container(
          height: 200,
          alignment: Alignment.center,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined, color: AppColors.textTertiary, size: 48),
              SizedBox(height: 8),
              Text('Gagal memuat gambar',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
            ],
          ),
        ),
      );
    }
    final file = File(imagePath);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 200,
          alignment: Alignment.center,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined, color: AppColors.textTertiary, size: 48),
              SizedBox(height: 8),
              Text('Gagal memuat gambar',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
            ],
          ),
        ),
      );
    }
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, color: AppColors.textTertiary, size: 48),
          SizedBox(height: 8),
          Text('File gambar tidak ditemukan',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
        ],
      ),
    );
  }
}

// =============================================================================
// Rating Section Widget
// =============================================================================

class _RatingSection extends StatefulWidget {
  final String sessionId;
  final List<SlotModel> slots;
  final SessionProvider sessionProvider;
  final String? currentUserId;

  const _RatingSection({
    required this.sessionId,
    required this.slots,
    required this.sessionProvider,
    required this.currentUserId,
  });

  @override
  State<_RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<_RatingSection> {
  final Map<String, int> _ratings = {};
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final existingRatings =
        widget.sessionProvider.getRatingsForSession(widget.sessionId);
    final hasRated =
        widget.sessionProvider.hasUserRatedSession(widget.sessionId);
    final userIsInSession = widget.currentUserId != null &&
        widget.slots.any((s) => s.userId == widget.currentUserId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.agedLinen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Interactive rating form (if user hasn't rated yet) ---
          if (!hasRated && userIsInSession) ...[
            const Text(
              'Berikan rating untuk pemain lain:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.slots
                .where((s) => s.userId != widget.currentUserId)
                .map((slot) => _buildPlayerRatingRow(slot)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRatings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestInk,
                  foregroundColor: AppColors.agedLinen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                  disabledBackgroundColor:
                      AppColors.forestInk.withValues(alpha: 0.5),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.agedLinen,
                        ),
                      )
                    : const Text(
                        'Kirim Rating',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ] else if (hasRated && userIsInSession) ...[
            Row(
              children: [
                Icon(Icons.check_circle,
                    size: 18,
                    color: AppColors.statusCompleted.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Kamu sudah memberikan rating untuk sesi ini.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // --- Existing ratings summary ---
          if (existingRatings.isNotEmpty) ...[
            if ((!hasRated && userIsInSession) || (hasRated && userIsInSession))
              const SizedBox(height: 16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
            const Text(
              'Rata-rata Rating Sesi Ini',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 10),
            ..._buildRatingSummary(existingRatings),
          ],

          // --- No ratings yet ---
          if (existingRatings.isEmpty && (hasRated || !userIsInSession)) ...[
            const Text(
              'Belum ada rating untuk sesi ini.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerRatingRow(SlotModel slot) {
    final currentRating = _ratings[slot.userId] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.mossAccent.withValues(alpha: 0.2),
            child: Text(
              slot.userName.isNotEmpty
                  ? slot.userName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.forestInk,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              slot.userName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.deepCharcoal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _ratings[slot.userId] = starIndex;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    starIndex <= currentRating
                        ? Icons.star
                        : Icons.star_border,
                    size: 26,
                    color: starIndex <= currentRating
                        ? AppColors.warning
                        : AppColors.textTertiary,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRatingSummary(List<RatingModel> ratings) {
    // Group ratings by toUserId and compute average
    final Map<String, List<RatingModel>> grouped = {};
    for (final r in ratings) {
      grouped.putIfAbsent(r.toUserId, () => []).add(r);
    }

    return grouped.entries.map((entry) {
      final userRatings = entry.value;
      final userName = userRatings.first.toUserName;
      final avgRating =
          userRatings.map((r) => r.rating).reduce((a, b) => a + b) /
              userRatings.length;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.mossAccent.withValues(alpha: 0.2),
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forestInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                userName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.deepCharcoal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return Icon(
                  starIndex <= avgRating.round()
                      ? Icons.star
                      : Icons.star_border,
                  size: 18,
                  color: starIndex <= avgRating.round()
                      ? AppColors.warning
                      : AppColors.textTertiary,
                );
              }),
            ),
            const SizedBox(width: 6),
            Text(
              avgRating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _submitRatings() async {
    // Filter out unrated players (rating == 0)
    final validRatings = Map<String, int>.fromEntries(
      _ratings.entries.where((e) => e.value > 0),
    );

    if (validRatings.isEmpty) {
      SnackbarHelper.showError(
          context, 'Berikan rating minimal untuk satu pemain');
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await widget.sessionProvider.submitRatings(
      sessionId: widget.sessionId,
      playerRatings: validRatings,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      HapticHelper.success();
      SuccessOverlay.show(context, message: 'Rating berhasil dikirim!');
    } else {
      SnackbarHelper.showError(
        context,
        widget.sessionProvider.errorMessage ?? 'Gagal mengirim rating',
      );
    }
  }
}

// =============================================================================
// Reject payment confirmation dialog (shared by _SlotRow and _PaymentRow)
// =============================================================================

void _showRejectConfirmDialog({
  required BuildContext context,
  required String userName,
  required Future<void> Function() onConfirm,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.agedLinen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Tolak Pembayaran?',
          style: TextStyle(
            color: AppColors.deepCharcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Pembayaran $userName akan ditolak. Pemain harus upload ulang bukti transfer.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.clayRed,
              foregroundColor: AppColors.agedLinen,
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await onConfirm();
            },
            child: const Text('Tolak'),
          ),
        ],
      );
    },
  );
}

// =============================================================================
// Photo Gallery Section
// =============================================================================

class _PhotoGallerySection extends StatelessWidget {
  final String sessionId;
  final SessionProvider sessionProvider;
  final bool isMimin;

  const _PhotoGallerySection({
    required this.sessionId,
    required this.sessionProvider,
    required this.isMimin,
  });

  @override
  Widget build(BuildContext context) {
    final photos = sessionProvider.getPhotosForSession(sessionId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Expanded(
              child: Text(
                'Galeri Foto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepCharcoal,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (isMimin)
              _AddPhotoButton(
                sessionId: sessionId,
                sessionProvider: sessionProvider,
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (photos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.agedLinen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 40,
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Belum ada foto sesi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
                if (isMimin) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Tap + untuk menambahkan foto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          _PhotoGrid(
            photos: photos,
            sessionId: sessionId,
            sessionProvider: sessionProvider,
            isMimin: isMimin,
          ),
      ],
    );
  }
}

// =============================================================================
// Add Photo Button
// =============================================================================

class _AddPhotoButton extends StatelessWidget {
  final String sessionId;
  final SessionProvider sessionProvider;

  const _AddPhotoButton({
    required this.sessionId,
    required this.sessionProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forestInk.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showPhotoSourceDialog(context),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 18, color: AppColors.forestInk),
              SizedBox(width: 4),
              Text(
                'Tambah',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forestInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoSourceDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tambah Foto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.forestInk.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: AppColors.forestInk),
                ),
                title: const Text('Kamera',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Ambil foto baru'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(context, ImageSource.camera);
                },
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.mossAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: AppColors.mossAccent),
                ),
                title: const Text('Galeri',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Pilih dari galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(context, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return;
    if (!context.mounted) return;

    final success =
        await sessionProvider.addPhotoToSession(sessionId, image.path);
    if (!context.mounted) return;

    if (success) {
      HapticHelper.success();
      SuccessOverlay.show(context, message: 'Foto berhasil ditambahkan!');
    } else {
      SnackbarHelper.showError(
          context, sessionProvider.errorMessage ?? 'Gagal menambah foto');
    }
  }
}

// =============================================================================
// Photo Grid
// =============================================================================

class _PhotoGrid extends StatelessWidget {
  final List<String> photos;
  final String sessionId;
  final SessionProvider sessionProvider;
  final bool isMimin;

  const _PhotoGrid({
    required this.photos,
    required this.sessionId,
    required this.sessionProvider,
    required this.isMimin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.agedLinen,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final photo = photos[index];
          return _PhotoThumbnail(
            photoPath: photo,
            index: index,
            allPhotos: photos,
            sessionId: sessionId,
            sessionProvider: sessionProvider,
            isMimin: isMimin,
          );
        },
      ),
    );
  }
}

// =============================================================================
// Photo Thumbnail
// =============================================================================

class _PhotoThumbnail extends StatelessWidget {
  final String photoPath;
  final int index;
  final List<String> allPhotos;
  final String sessionId;
  final SessionProvider sessionProvider;
  final bool isMimin;

  const _PhotoThumbnail({
    required this.photoPath,
    required this.index,
    required this.allPhotos,
    required this.sessionId,
    required this.sessionProvider,
    required this.isMimin,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPhotoViewer(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImage(),
            // Delete overlay for mimin
            if (isMimin)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (photoPath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: photoPath,
        fit: BoxFit.cover,
        memCacheWidth: 400, // Limit decoded resolution for card thumbnails
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) => Container(
          color: AppColors.divider,
          child: const Center(
            child: LottieLoading(width: 24, height: 24),
          ),
        ),
        errorWidget: (_, _, _) => Container(
          color: AppColors.divider,
          child: const Icon(Icons.broken_image_outlined,
              color: AppColors.textTertiary),
        ),
      );
    }
    // Local file
    return Image.file(
      File(photoPath),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: AppColors.divider,
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.textTertiary),
      ),
    );
  }

  void _showPhotoViewer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, _, _) => _FullScreenPhotoViewer(
          photos: allPhotos,
          initialIndex: index,
          sessionId: sessionId,
          sessionProvider: sessionProvider,
          isMimin: isMimin,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.agedLinen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Hapus Foto?',
          style: TextStyle(
            color: AppColors.deepCharcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Foto ini akan dihapus dari galeri sesi.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.clayRed,
              foregroundColor: AppColors.agedLinen,
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              HapticHelper.heavy();
              await sessionProvider.removePhotoFromSession(
                  sessionId, photoPath);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Full Screen Photo Viewer
// =============================================================================

class _FullScreenPhotoViewer extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final String sessionId;
  final SessionProvider sessionProvider;
  final bool isMimin;

  const _FullScreenPhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.sessionId,
    required this.sessionProvider,
    required this.isMimin,
  });

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismiss on tap background
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),

          // Photo pager
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: _buildFullImage(photo),
                ),
              );
            },
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    Text(
                      '${_currentIndex + 1} / ${widget.photos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (widget.isMimin)
                      IconButton(
                        onPressed: () => _deleteCurrentPhoto(),
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white, size: 24),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // Page indicators
          if (widget.photos.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.photos.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentIndex ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullImage(String photoPath) {
    if (photoPath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: photoPath,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (_, _) =>
            const Center(child: LottieLoading(width: 40, height: 40)),
        errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined,
            color: Colors.white54, size: 64),
      );
    }
    return Image.file(
      File(photoPath),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined,
          color: Colors.white54, size: 64),
    );
  }

  void _deleteCurrentPhoto() {
    final photo = widget.photos[_currentIndex];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.agedLinen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Hapus Foto?',
          style: TextStyle(
            color: AppColors.deepCharcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Foto ini akan dihapus dari galeri sesi.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.clayRed,
              foregroundColor: AppColors.agedLinen,
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              HapticHelper.heavy();
              await widget.sessionProvider
                  .removePhotoFromSession(widget.sessionId, photo);
              if (!mounted) return;
              if (widget.photos.isEmpty) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Match Results Section
// =============================================================================

class _MatchResultsSection extends StatelessWidget {
  final String sessionId;
  final bool isMimin;

  const _MatchResultsSection({
    required this.sessionId,
    required this.isMimin,
  });

  @override
  Widget build(BuildContext context) {
    final ds = DataService();
    final results = ds.getMatchResultsForSession(sessionId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Hasil Pertandingan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.deepCharcoal,
                letterSpacing: -0.3,
              ),
            ),
            if (isMimin)
              TextButton.icon(
                onPressed: () => context.push(
                  AppRoutes.matchScoringPath(sessionId),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Input Skor'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.forestInk,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (results.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.agedLinen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.scoreboard_outlined,
                  size: 32,
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Belum ada hasil pertandingan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
                ),
                if (isMimin) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Tap "Input Skor" untuk mulai.',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ],
            ),
          )
        else ...[
          _buildLeaderboard(results),
          const SizedBox(height: 12),
          ...results.map((r) => _MatchResultCard(result: r)),
        ],
      ],
    );
  }

  Widget _buildLeaderboard(List<MatchResultModel> results) {
    final playerPoints = <String, int>{};
    final playerWins = <String, int>{};
    final playerNames = <String, String>{};

    for (final r in results) {
      for (final id in r.team1PlayerIds) {
        playerPoints[id] = (playerPoints[id] ?? 0) + r.team1Score;
        playerNames[id] = r.team1PlayerNames[r.team1PlayerIds.indexOf(id)];
      }
      for (final id in r.team2PlayerIds) {
        playerPoints[id] = (playerPoints[id] ?? 0) + r.team2Score;
        playerNames[id] = r.team2PlayerNames[r.team2PlayerIds.indexOf(id)];
      }
      for (final id in r.winnerIds) {
        playerWins[id] = (playerWins[id] ?? 0) + 1;
      }
    }

    final sorted = playerPoints.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forestInk.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Klasemen Sesi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.forestInk,
            ),
          ),
          const SizedBox(height: 8),
          ...sorted.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final playerId = entry.value.key;
            final points = entry.value.value;
            final wins = playerWins[playerId] ?? 0;
            final name = playerNames[playerId] ?? 'Unknown';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      rank <= 3
                          ? ['\u{1F947}', '\u{1F948}', '\u{1F949}'][rank - 1]
                          : '$rank.',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: rank == 1 ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.deepCharcoal,
                      ),
                    ),
                  ),
                  Text(
                    '${wins}W',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusCompleted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${points}pts',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestInk,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MatchResultCard extends StatelessWidget {
  final MatchResultModel result;

  const _MatchResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isTeam1Winner = result.winningTeam == 1;
    final isTeam2Winner = result.winningTeam == 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Round ${result.round}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: result.team1PlayerNames
                      .map((n) => Text(
                            n,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isTeam1Winner ? FontWeight.w700 : FontWeight.w500,
                              color: isTeam1Winner ? AppColors.statusCompleted : AppColors.deepCharcoal,
                            ),
                            textAlign: TextAlign.center,
                          ))
                      .toList(),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.forestInk.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${result.team1Score} : ${result.team2Score}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.forestInk,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: result.team2PlayerNames
                      .map((n) => Text(
                            n,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isTeam2Winner ? FontWeight.w700 : FontWeight.w500,
                              color: isTeam2Winner ? AppColors.statusCompleted : AppColors.deepCharcoal,
                            ),
                            textAlign: TextAlign.center,
                          ))
                      .toList(),
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
// Attendance Section (Mimin only)
// =============================================================================

class _AttendanceSection extends StatefulWidget {
  final String sessionId;
  final List<SlotModel> slots;

  const _AttendanceSection({
    required this.sessionId,
    required this.slots,
  });

  @override
  State<_AttendanceSection> createState() => _AttendanceSectionState();
}

class _AttendanceSectionState extends State<_AttendanceSection> {
  final DataService _ds = DataService();

  @override
  Widget build(BuildContext context) {
    final freshSlots = _ds.getSlotsForSession(widget.sessionId);
    final confirmedSlots = freshSlots
        .where((s) =>
            s.status == SlotStatus.confirmed ||
            s.status == SlotStatus.paid ||
            s.status == SlotStatus.locked)
        .toList();

    final attendedCount = confirmedSlots.where((s) => s.didAttend).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Absensi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.deepCharcoal,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.statusCompleted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$attendedCount/${confirmedSlots.length} hadir',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.statusCompleted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.agedLinen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: confirmedSlots.length,
            separatorBuilder: (_, __) =>
                const Divider(color: AppColors.divider, height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final slot = confirmedSlots[index];
              return ListTile(
                dense: true,
                leading: Icon(
                  slot.didAttend ? Icons.check_circle : Icons.circle_outlined,
                  color: slot.didAttend ? AppColors.statusCompleted : AppColors.textTertiary,
                  size: 22,
                ),
                title: Text(
                  slot.userName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: slot.didAttend ? FontWeight.w600 : FontWeight.w500,
                    color: slot.didAttend ? AppColors.deepCharcoal : AppColors.textSecondary,
                  ),
                ),
                trailing: slot.didAttend
                    ? const Text(
                        'Hadir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.statusCompleted,
                        ),
                      )
                    : null,
                onTap: () async {
                  try {
                    if (slot.didAttend) {
                      await _ds.unmarkAttendance(slot.id);
                    } else {
                      await _ds.markAttendance(slot.id);
                      HapticHelper.light();
                    }
                    setState(() {});
                  } catch (e) {
                    if (context.mounted) {
                      SnackbarHelper.showError(context, 'Gagal update absensi');
                    }
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
