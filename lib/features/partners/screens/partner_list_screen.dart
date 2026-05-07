import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/models/partner_model.dart';
import 'package:daddies_app/services/data_service.dart';

class PartnerListScreen extends StatelessWidget {
  const PartnerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = DataService();
    final partners = ds.getActivePartners();

    // Group by category
    final grouped = <String, List<PartnerModel>>{};
    for (final p in partners) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }
    final categories = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Partner Dedis'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: partners.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    size: 56,
                    color: AppColors.textTertiary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum ada partner',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Partner dengan diskon eksklusif segera hadir',
                    style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              itemBuilder: (context, catIdx) {
                final category = categories[catIdx];
                final items = grouped[category]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (catIdx > 0) const SizedBox(height: 20),
                    // Category header
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.forestInk,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepCharcoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...items.map((p) => _PartnerCard(partner: p)),
                  ],
                );
              },
            ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final PartnerModel partner;

  const _PartnerCard({required this.partner});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Discount badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.forestInk,
                        AppColors.forestInk.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${partner.discountPercent}%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.white,
                            height: 1,
                          ),
                        ),
                        const Text(
                          'OFF',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partner.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepCharcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        partner.discountDescription,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Contact info
            if (partner.address != null || partner.phone != null) ...[
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: AppColors.divider,
              ),
              const SizedBox(height: 10),
              if (partner.address != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          partner.address!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (partner.phone != null)
                InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:${partner.phone}')),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 14, color: AppColors.mossAccent),
                      const SizedBox(width: 6),
                      Text(
                        partner.phone!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mossAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
