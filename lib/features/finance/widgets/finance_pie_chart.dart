import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:daddies_app/core/theme/app_colors.dart';

/// Pie chart showing expense category breakdown.
class FinancePieChart extends StatelessWidget {
  final Map<String, int> categoryBreakdown;

  const FinancePieChart({super.key, required this.categoryBreakdown});

  static const _categoryColors = [
    AppColors.forestInk,
    AppColors.mossAccent,
    AppColors.clayRed,
    Color(0xFF60A5FA),
    Color(0xFFFBBF24),
    Color(0xFF34D399),
    Color(0xFF9F7AEA),
    Color(0xFFF472B6),
  ];

  @override
  Widget build(BuildContext context) {
    if (categoryBreakdown.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text('Belum ada pengeluaran', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
        ),
      );
    }

    final total = categoryBreakdown.values.fold<int>(0, (s, v) => s + v);
    final entries = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: entries.asMap().entries.map((entry) {
                  final color = _categoryColors[entry.key % _categoryColors.length];
                  final pct = total > 0 ? (entry.value.value / total * 100) : 0.0;
                  return PieChartSectionData(
                    value: entry.value.value.toDouble(),
                    color: color,
                    radius: 40,
                    title: pct >= 10 ? '${pct.round()}%' : '',
                    titleStyle: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 12, runSpacing: 6,
            children: entries.asMap().entries.map((entry) {
              final color = _categoryColors[entry.key % _categoryColors.length];
              final pct = total > 0 ? (entry.value.value / total * 100).round() : 0;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Text(
                  '${entry.value.key} ($pct%)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                ),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }
}
