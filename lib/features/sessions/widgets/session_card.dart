import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/widgets/status_chip.dart';
import 'package:daddies_app/core/widgets/micro_interactions.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/core/widgets/venue_link.dart';

class SessionCard extends StatelessWidget {
  final SessionModel session;
  final int currentPlayers;
  final VoidCallback? onTap;

  const SessionCard({
    super.key,
    required this.session,
    required this.currentPlayers,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');

    return ScaleOnTap(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepCharcoal,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => navigateToVenue(context, session.venue),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.mossAccent),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  session.venue,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.mossAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SessionStatusChip(status: session.status),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _IconLabel(
                    icon: Icons.calendar_today_outlined,
                    text: dateFormat.format(session.date),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _IconLabel(
                    icon: Icons.access_time_outlined,
                    text: '${session.timeStart} - ${session.timeEnd}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.forestInk.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_outline, size: 16, color: AppColors.mossAccent),
                  const SizedBox(width: 6),
                  Text(
                    '$currentPlayers/${session.maxPlayers} pemain',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    rupiah.format(session.pricePerPlayer),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestInk,
                    ),
                  ),
                  const Text(
                    ' /orang',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
