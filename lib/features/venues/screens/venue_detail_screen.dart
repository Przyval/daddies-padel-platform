import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/utils/snackbar_helper.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/core/widgets/micro_interactions.dart';

class VenueDetailScreen extends StatelessWidget {
  final String venueId;

  const VenueDetailScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context) {
    final ds = DataService();
    final venue = ds.getVenueById(venueId);

    if (venue == null) {
      return Scaffold(
        backgroundColor: AppColors.sagePaper,
        appBar: AppBar(
          title: const Text('Venue Tidak Ditemukan'),
          backgroundColor: AppColors.forestInk,
          foregroundColor: AppColors.agedLinen,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Venue ini tidak ditemukan.',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // Calculate venue stats
    final venueSessions = ds.sessions
        .where((s) => s.venue.toLowerCase() == venue.name.toLowerCase())
        .toList();
    final completedSessions = venueSessions
        .where((s) => s.status == SessionStatus.completed)
        .length;
    final upcomingSessions = venueSessions
        .where((s) =>
            s.status == SessionStatus.open ||
            s.status == SessionStatus.full ||
            s.status == SessionStatus.locked)
        .length;

    // Count unique players
    final playerIds = <String>{};
    for (final session in venueSessions) {
      final slots = ds.getSlotsForSession(session.id);
      for (final slot in slots) {
        playerIds.add(slot.userId);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.sagePaper,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ---- Hero App Bar ----
          SliverAppBar(
            expandedHeight: 200,
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
                      Color(0xFF2F3E34),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.agedLinen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.sports_tennis,
                          size: 36,
                          color: AppColors.agedLinen,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        venue.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.agedLinen,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          venue.address,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.agedLinen.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ---- Content ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Stats Row ----
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.sports_tennis,
                          value: '$completedSessions',
                          label: 'Sesi Selesai',
                          color: AppColors.statusCompleted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.event_available,
                          value: '$upcomingSessions',
                          label: 'Akan Datang',
                          color: AppColors.statusOpen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.people,
                          value: '${playerIds.length}',
                          label: 'Total Pemain',
                          color: AppColors.statusPaid,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ---- Bio / About ----
                  _buildSectionCard(
                    title: 'Tentang Venue',
                    child: Text(
                      venue.bio,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---- Info ----
                  _buildSectionCard(
                    title: 'Informasi',
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.grid_view_rounded,
                          label: 'Jumlah Court',
                          value: '${venue.courtCount} lapangan',
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.access_time_outlined,
                          label: 'Jam Operasional',
                          value: venue.openHours,
                        ),
                        if (venue.phone != null) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: venue.phone!));
                              SnackbarHelper.showSuccess(context, 'Nomor telepon disalin');
                            },
                            child: _InfoRow(
                              icon: Icons.phone_outlined,
                              label: 'Telepon',
                              value: venue.phone!,
                              valueColor: AppColors.statusPaid,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ---- Get Directions button ----
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => _openDirections(context, venue.name, venue.address, venue.mapUrl),
                      icon: const Icon(Icons.directions_outlined, size: 20),
                      label: const Text(
                        'Buka di Google Maps',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forestInk,
                        foregroundColor: AppColors.agedLinen,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---- Facilities ----
                  if (venue.facilities.isNotEmpty)
                    _buildSectionCard(
                      title: 'Fasilitas',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: venue.facilities
                            .map((f) => _FacilityChip(label: f))
                            .toList(),
                      ),
                    ),

                  if (venue.facilities.isNotEmpty) const SizedBox(height: 16),

                  // ---- Recent Sessions ----
                  if (venueSessions.isNotEmpty) ...[
                    _buildSectionCard(
                      title: 'Sesi Terakhir',
                      child: Column(
                        children: venueSessions
                            .take(5)
                            .map((s) => _RecentSessionTile(
                                  session: s,
                                  onTap: () => context.push(
                                    AppRoutes.sessionDetailPath(s.id),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDirections(BuildContext context, String name, String address, String? mapUrl) async {
    Uri uri;
    if (mapUrl != null && mapUrl.isNotEmpty) {
      uri = Uri.parse(mapUrl);
    } else {
      // Fall back to Google Maps search
      final query = Uri.encodeComponent('$name, $address');
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        SnackbarHelper.showError(context, 'Tidak bisa membuka Google Maps');
      }
    } catch (_) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Tidak bisa membuka Google Maps');
      }
    }
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.deepCharcoal,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          child,
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
          if (int.tryParse(value) != null)
            AnimatedCounter(
              value: int.parse(value),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            )
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
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.deepCharcoal,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Facility Chip
// =============================================================================

class _FacilityChip extends StatelessWidget {
  final String label;

  const _FacilityChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.forestInk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconForFacility(label),
            size: 14,
            color: AppColors.mossAccent,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.forestInk,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForFacility(String facility) {
    final lower = facility.toLowerCase();
    if (lower.contains('court')) return Icons.sports_tennis;
    if (lower.contains('park')) return Icons.local_parking;
    if (lower.contains('cafe') || lower.contains('café') || lower.contains('restaurant') || lower.contains('kantin')) return Icons.restaurant;
    if (lower.contains('shower') || lower.contains('locker')) return Icons.shower;
    if (lower.contains('wifi')) return Icons.wifi;
    if (lower.contains('shop') || lower.contains('rental')) return Icons.storefront;
    if (lower.contains('musholla') || lower.contains('prayer')) return Icons.mosque;
    if (lower.contains('kids') || lower.contains('anak')) return Icons.child_care;
    if (lower.contains('valet')) return Icons.car_rental;
    return Icons.check_circle_outline;
  }
}

// =============================================================================
// Recent Session Tile
// =============================================================================

class _RecentSessionTile extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onTap;

  const _RecentSessionTile({
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy', 'id_ID');
    final statusColor = _colorForStatus(session.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconForStatus(session.status),
                size: 18,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepCharcoal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dateFormat.format(session.date)} · ${session.timeStart}–${session.timeEnd}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Color _colorForStatus(SessionStatus status) {
    return switch (status) {
      SessionStatus.open || SessionStatus.full => AppColors.statusOpen,
      SessionStatus.locked => AppColors.statusLocked,
      SessionStatus.completed => AppColors.statusCompleted,
      SessionStatus.cancelled => AppColors.statusCancelled,
      _ => AppColors.mossAccent,
    };
  }

  IconData _iconForStatus(SessionStatus status) {
    return switch (status) {
      SessionStatus.open || SessionStatus.full => Icons.event_available,
      SessionStatus.locked => Icons.lock_outline,
      SessionStatus.completed => Icons.emoji_events_outlined,
      SessionStatus.cancelled => Icons.event_busy_outlined,
      _ => Icons.event_note_outlined,
    };
  }
}
