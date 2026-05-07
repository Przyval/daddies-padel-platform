import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/core/widgets/empty_state.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/features/sessions/providers/session_provider.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/core/widgets/venue_link.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  SessionStatus? _statusFilter;
  String? _venueFilter;

  @override
  Widget build(BuildContext context) {
    final sessionProv = context.watch<SessionProvider>();
    final authProv = context.watch<AuthProvider>();
    final currentUser = authProv.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Tidak ada pengguna yang login.')),
      );
    }

    // Get all sessions the user participated in
    final allSessions = sessionProv.sessions;
    final mySessions = allSessions.where((s) {
      final slots = sessionProv.getSlotsForSession(s.id);
      return slots.any((slot) => slot.userId == currentUser.id) ||
          s.miminId == currentUser.id;
    }).toList();

    // Sort by date descending
    mySessions.sort((a, b) => b.date.compareTo(a.date));

    // Apply filters
    if (_statusFilter != null) {
      mySessions.removeWhere((s) => s.status != _statusFilter);
    }
    if (_venueFilter != null) {
      mySessions.removeWhere((s) => s.venue != _venueFilter);
    }

    final dateFormat = DateFormat('EEE, d MMM yyyy', 'id_ID');
    final rupiahFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.sagePaper,
      appBar: AppBar(
        title: const Text('Riwayat Sesi'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.agedLinen,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                if (value == 'all') {
                  _statusFilter = null;
                  _venueFilter = null;
                } else if (value == 'completed') {
                  _statusFilter = SessionStatus.completed;
                } else if (value == 'cancelled') {
                  _statusFilter = SessionStatus.cancelled;
                } else if (value == 'upcoming') {
                  _statusFilter = SessionStatus.open;
                }
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('Semua')),
              const PopupMenuItem(value: 'completed', child: Text('Selesai')),
              const PopupMenuItem(value: 'cancelled', child: Text('Dibatalkan')),
              const PopupMenuItem(value: 'upcoming', child: Text('Akan Datang')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.forestInk,
        onRefresh: () => DataService().refresh(),
        child: mySessions.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 80),
                EmptyStateWidget(
                  icon: Icons.history,
                  title: 'Belum ada riwayat',
                  subtitle: 'Sesi yang kamu ikuti akan muncul di sini.',
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: mySessions.length,
              itemBuilder: (context, index) {
                final session = mySessions[index];
                final slots = sessionProv.getSlotsForSession(session.id);
                final confirmedCount =
                    sessionProv.getConfirmedCount(session.id);

                return _HistoryCard(
                  session: session,
                  confirmedCount: confirmedCount,
                  totalSlots: slots.length,
                  dateFormat: dateFormat,
                  rupiahFormat: rupiahFormat,
                  onTap: () => context.push(
                    AppRoutes.sessionDetailPath(session.id),
                  ),
                );
              },
            ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final SessionModel session;
  final int confirmedCount;
  final int totalSlots;
  final DateFormat dateFormat;
  final NumberFormat rupiahFormat;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.session,
    required this.confirmedCount,
    required this.totalSlots,
    required this.dateFormat,
    required this.rupiahFormat,
    required this.onTap,
  });

  Color _statusColor() {
    switch (session.status) {
      case SessionStatus.completed:
        return AppColors.statusCompleted;
      case SessionStatus.cancelled:
        return AppColors.statusCancelled;
      case SessionStatus.open:
        return AppColors.statusOpen;
      case SessionStatus.full:
        return AppColors.statusWaitlist;
      case SessionStatus.locked:
        return AppColors.statusLocked;
      case SessionStatus.draft:
        return AppColors.textTertiary;
    }
  }

  String _statusLabel() {
    switch (session.status) {
      case SessionStatus.completed:
        return 'Selesai';
      case SessionStatus.cancelled:
        return 'Batal';
      case SessionStatus.open:
        return 'Open';
      case SessionStatus.full:
        return 'Full';
      case SessionStatus.locked:
        return 'Locked';
      case SessionStatus.draft:
        return 'Draft';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.agedLinen,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: color, width: 4),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Date column
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${session.date.day}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1,
                        ),
                      ),
                      Text(
                        DateFormat('MMM', 'id_ID').format(session.date),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Title + venue + time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepCharcoal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      GestureDetector(
                        onTap: () => navigateToVenue(context, session.venue),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                session.venue,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.mossAccent,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '  ·  ${session.timeStart}–${session.timeEnd}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _statusLabel(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$confirmedCount/${session.maxPlayers} pemain',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Price + chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rupiahFormat.format(session.pricePerPlayer),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forestInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.textTertiary),
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
