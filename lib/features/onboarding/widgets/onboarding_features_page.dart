import 'package:flutter/material.dart';

import 'package:daddies_app/core/theme/app_colors.dart';

/// Onboarding Page 2 — Feature highlights with visual cards.
class OnboardingFeaturesPage extends StatelessWidget {
  const OnboardingFeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),

          const Text(
            'Semua yang kamu butuhkan',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.forestInk,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dalam satu aplikasi',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 32),

          const _FeatureCard(
            icon: Icons.calendar_month_outlined,
            title: 'Sesi & Booking',
            subtitle:
                'Temukan sesi padel, join langsung, dan kelola pembayaran dari satu tempat.',
          ),
          const SizedBox(height: 12),
          const _FeatureCard(
            icon: Icons.emoji_events_outlined,
            title: 'Leaderboard & Awards',
            subtitle:
                'Pantau peringkat, kumpulkan Daddies Chips, dan raih achievement.',
          ),
          const SizedBox(height: 12),
          const _FeatureCard(
            icon: Icons.handshake_outlined,
            title: 'Partner & Diskon',
            subtitle:
                'Akses diskon eksklusif dari partner Daddies Community.',
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.forestInk.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.forestInk, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
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
