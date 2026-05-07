import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/services/data_service.dart';

/// Onboarding Page 1 — Hero with real community stats & upcoming session.
class OnboardingHeroPage extends StatelessWidget {
  const OnboardingHeroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = DataService();
    final memberCount = ds.users.length;
    final completedSessions =
        ds.sessions.where((s) => s.status == SessionStatus.completed).length;
    final partnerCount = ds.partners.length;
    final hasData = memberCount > 0 || completedSessions > 0;

    final upcoming = ds.sessions
        .where((s) =>
            s.date.isAfter(DateTime.now()) &&
            (s.status == SessionStatus.open ||
                s.status == SessionStatus.locked))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Heritage badge
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.forestInk,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sports_tennis,
              color: AppColors.onPrimary,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          const Text(
            'DADDIES',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.forestInk,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'PADEL COMMUNITY',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.mossAccent,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Main bareng, tumbuh bareng.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 32),

          // Stats row — show shimmer-like placeholder when no data
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.forestInk,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _StatItem(
                  icon: Icons.people_alt_outlined,
                  value: hasData ? '$memberCount' : '12+',
                  label: 'Anggota',
                ),
                const _StatDivider(),
                _StatItem(
                  icon: Icons.calendar_today_outlined,
                  value: hasData ? '$completedSessions' : '8+',
                  label: 'Sesi',
                ),
                const _StatDivider(),
                _StatItem(
                  icon: Icons.handshake_outlined,
                  value: hasData ? '$partnerCount' : '4',
                  label: 'Partner',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Upcoming session card
          if (upcoming.isNotEmpty) _UpcomingSessionCard(session: upcoming.first),

          if (upcoming.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_available,
                      color: AppColors.mossAccent, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Sesi baru segera hadir!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gabung untuk jadi yang pertama tahu',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.mossAccent, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onPrimary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.onPrimary.withValues(alpha: 0.15),
    );
  }
}

class _UpcomingSessionCard extends StatelessWidget {
  final SessionModel session;
  const _UpcomingSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, d MMM', 'id_ID').format(session.date);
    final spotsLeft = session.maxPlayers -
        DataService()
            .slots
            .where((s) => s.sessionId == session.id)
            .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_fill,
                  color: AppColors.success, size: 16),
              const SizedBox(width: 6),
              const Text(
                'SESI MENDATANG',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: spotsLeft > 0
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  spotsLeft > 0 ? '$spotsLeft slot tersisa' : 'Penuh',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: spotsLeft > 0
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            session.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${session.venue}  •  $dateStr  •  ${session.timeStart}–${session.timeEnd}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
