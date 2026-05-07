import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/features/finance/providers/finance_provider.dart';

/// Grouped bar chart showing monthly income vs expense.
class FinanceBarChart extends StatelessWidget {
  final List<MonthlyFinance> data;

  const FinanceBarChart({super.key, required this.data});

  static const _monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static final _compactFormat = NumberFormat.compactCurrency(
    locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text('Belum ada data keuangan', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
        ),
      );
    }

    final maxVal = data.fold<int>(0, (max, m) {
      final highest = m.income > m.expense ? m.income : m.expense;
      return highest > max ? highest : max;
    });

    if (maxVal == 0) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(child: Text('Semua nilai 0', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _LegendDot(color: AppColors.success, label: 'Pemasukan'),
            const SizedBox(width: 16),
            _LegendDot(color: AppColors.clayRed, label: 'Pengeluaran'),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal.toDouble() * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = rodIndex == 0 ? 'Pemasukan' : 'Pengeluaran';
                      return BarTooltipItem(
                        '$label\n${_compactFormat.format(rod.toY.toInt())}',
                        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _monthNames[data[idx].month],
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            _compactFormat.format(value.toInt()),
                            style: const TextStyle(fontSize: 9, color: AppColors.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.divider.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                barGroups: data.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.income.toDouble(),
                        color: AppColors.success,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                      BarChartRodData(
                        toY: entry.value.expense.toDouble(),
                        color: AppColors.clayRed,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
    ]);
  }
}
