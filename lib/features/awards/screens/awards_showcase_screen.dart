import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/widgets/empty_state.dart';
import 'package:daddies_app/features/awards/providers/award_provider.dart';
import 'package:daddies_app/models/award_model.dart';
import 'package:daddies_app/services/data_service.dart';

class AwardsShowcaseScreen extends StatefulWidget {
  const AwardsShowcaseScreen({super.key});

  @override
  State<AwardsShowcaseScreen> createState() => _AwardsShowcaseScreenState();
}

class _AwardsShowcaseScreenState extends State<AwardsShowcaseScreen> {
  _PeriodFilter _selectedFilter = _PeriodFilter.month;
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedQuarter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _selectedQuarter = ((now.month - 1) ~/ 3) + 1;

    // Trigger initial computation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _computeAwards();
    });
  }

  String get _currentPeriod {
    if (_selectedFilter == _PeriodFilter.month) {
      return '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
    }
    return '$_selectedYear-Q$_selectedQuarter';
  }

  String get _periodLabel {
    if (_selectedFilter == _PeriodFilter.month) {
      return _monthName(_selectedMonth);
    }
    return 'Q$_selectedQuarter $_selectedYear';
  }

  Future<void> _computeAwards() async {
    final provider = context.read<AwardProvider>();
    if (_selectedFilter == _PeriodFilter.month) {
      await provider.computeMonthlyAwards(_selectedYear, _selectedMonth);
    } else {
      // For quarter, compute all 3 months
      final startMonth = (_selectedQuarter - 1) * 3 + 1;
      for (int m = startMonth; m < startMonth + 3; m++) {
        await provider.computeMonthlyAwards(_selectedYear, m);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final awardProv = context.watch<AwardProvider>();
    final awards = awardProv.getAwardsForPeriod(_currentPeriod);

    // For quarter view, aggregate awards from all 3 months
    List<AwardModel> displayAwards;
    if (_selectedFilter == _PeriodFilter.quarter) {
      final startMonth = (_selectedQuarter - 1) * 3 + 1;
      final allQuarterAwards = <AwardModel>[];
      for (int m = startMonth; m < startMonth + 3; m++) {
        final period = '$_selectedYear-${m.toString().padLeft(2, '0')}';
        allQuarterAwards.addAll(awardProv.getAwardsForPeriod(period));
      }
      displayAwards = allQuarterAwards;
    } else {
      displayAwards = awards;
    }

    return Scaffold(
      backgroundColor: AppColors.sagePaper,
      appBar: AppBar(
        title: const Text('Awards'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.agedLinen,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.forestInk,
        onRefresh: () async {
          await DataService().refresh();
          await _computeAwards();
        },
        child: Column(
          children: [
            // Period selector header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: AppColors.agedLinen,
              child: Column(
                children: [
                  // Filter type toggle (Month / Quarter)
                  Row(
                    children: [
                      _FilterChip(
                        label: 'Bulanan',
                        active: _selectedFilter == _PeriodFilter.month,
                        onTap: () {
                          setState(() => _selectedFilter = _PeriodFilter.month);
                          _computeAwards();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Kuartal',
                        active: _selectedFilter == _PeriodFilter.quarter,
                        onTap: () {
                          setState(() => _selectedFilter = _PeriodFilter.quarter);
                          _computeAwards();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Period dropdown
                  SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events_outlined,
                            size: 16, color: AppColors.textTertiary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: _selectedFilter == _PeriodFilter.month
                                ? DropdownButton<int>(
                                    value: _selectedMonth,
                                    isDense: true,
                                    isExpanded: true,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.deepCharcoal,
                                    ),
                                    items: List.generate(12, (i) {
                                      final m = i + 1;
                                      return DropdownMenuItem(
                                        value: m,
                                        child: Text(
                                            '${_monthName(m)} $_selectedYear'),
                                      );
                                    }),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedMonth = v);
                                        _computeAwards();
                                      }
                                    },
                                  )
                                : DropdownButton<int>(
                                    value: _selectedQuarter,
                                    isDense: true,
                                    isExpanded: true,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.deepCharcoal,
                                    ),
                                    items: List.generate(4, (i) {
                                      final q = i + 1;
                                      return DropdownMenuItem(
                                        value: q,
                                        child: Text('Q$q $_selectedYear'),
                                      );
                                    }),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedQuarter = v);
                                        _computeAwards();
                                      }
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Awards list
            Expanded(
              child: awardProv.isBusy
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.forestInk,
                        ),
                      ),
                    )
                  : displayAwards.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            EmptyStateWidget(
                              icon: Icons.emoji_events_outlined,
                              title: 'Belum ada awards',
                              subtitle:
                                  'Awards untuk $_periodLabel belum tersedia',
                              useLottie: true,
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: displayAwards.length,
                          itemBuilder: (context, index) {
                            return _AwardCard(award: displayAwards[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  static String _monthName(int month) {
    const names = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return names[month - 1];
  }
}

// =============================================================================
// Period filter enum
// =============================================================================

enum _PeriodFilter { month, quarter }

// =============================================================================
// Filter Chip
// =============================================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.forestInk : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Award Card
// =============================================================================

class _AwardCard extends StatelessWidget {
  final AwardModel award;

  const _AwardCard({required this.award});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.agedLinen,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Award type emoji
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.mossAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  award.typeEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Award details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Award type label
                  Text(
                    award.typeLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestInk,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Winner name
                  Text(
                    award.userName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepCharcoal,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    award.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Period + granted by badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.forestInk.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          award.period,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestInk,
                          ),
                        ),
                      ),
                      if (award.grantedBy != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.mossAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Manual',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mossAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Value badge
            if (award.value > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.forestInk,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${award.value}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.agedLinen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
