import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/models/user_model.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/models/cashflow_model.dart';
import 'package:daddies_app/models/chips_transaction_model.dart';
import 'package:daddies_app/models/slot_model.dart';

// =============================================================================
// Shared helpers
// =============================================================================

/// Standard month labels in Indonesian abbreviated form.
const _monthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Ags',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Wraps chart content in a consistent card container with title.
class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Empty state placeholder shown when chart data is empty.
class _EmptyChartState extends StatelessWidget {
  const _EmptyChartState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      child: Center(
        child: Text(
          'Belum ada data',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 1. MemberGrowthChart
// =============================================================================

/// Line chart showing cumulative member count over the last 6 months.
///
/// Groups [users] by their [UserModel.createdAt] month and plots the running
/// total as a smooth line.
class MemberGrowthChart extends StatelessWidget {
  final List<UserModel> users;

  const MemberGrowthChart({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Pertumbuhan Anggota',
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (users.isEmpty) return const _EmptyChartState();

    final now = DateTime.now();
    // Generate the last 6 months (inclusive of current month).
    final months = List.generate(6, (i) {
      final dt = DateTime(now.year, now.month - (5 - i));
      return DateTime(dt.year, dt.month);
    });

    // Count users created on or before each month boundary.
    final spots = <FlSpot>[];
    for (var i = 0; i < months.length; i++) {
      final endOfMonth = DateTime(months[i].year, months[i].month + 1, 0, 23, 59, 59);
      final count = users
          .where((u) =>
              !u.isDeleted &&
              u.createdAt.isBefore(endOfMonth.add(const Duration(seconds: 1))))
          .length;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final ceilingY = maxY < 5 ? 5.0 : (maxY * 1.2).ceilToDouble();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: ceilingY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ceilingY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.divider.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= months.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _monthLabels[months[idx].month - 1],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: ceilingY / 4,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.forestInk,
              getTooltipItems: (spots) => spots.map((spot) {
                final month = months[spot.x.toInt()];
                final label = '${_monthLabels[month.month - 1]} ${month.year}';
                return LineTooltipItem(
                  '$label\n${spot.y.toInt()} anggota',
                  const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.forestInk,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.forestInk,
                  strokeWidth: 2,
                  strokeColor: AppColors.surfaceElevated,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.forestInk.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 2. SessionUtilizationChart
// =============================================================================

/// Bar chart showing session fill rate for the last 10 sessions.
///
/// Each bar represents (actual registered players / maxPlayers) as a
/// percentage. Pass [sessions] and [slots] so the widget can compute
/// the player count per session.
class SessionUtilizationChart extends StatelessWidget {
  final List<SessionModel> sessions;
  final List<SlotModel> slots;

  const SessionUtilizationChart({
    super.key,
    required this.sessions,
    required this.slots,
  });

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Utilisasi Sesi',
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (sessions.isEmpty) return const _EmptyChartState();

    // Sort by date descending, take last 10.
    final sorted = List<SessionModel>.from(sessions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = sorted.take(10).toList().reversed.toList();

    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < recent.length; i++) {
      final session = recent[i];
      final playerCount = slots
          .where((s) =>
              s.sessionId == session.id &&
              !s.isDeleted &&
              s.status != SlotStatus.waitlist)
          .length;
      final fillRate = session.maxPlayers > 0
          ? (playerCount / session.maxPlayers * 100).clamp(0.0, 100.0)
          : 0.0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: fillRate,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              color: fillRate >= 80
                  ? AppColors.success
                  : fillRate >= 50
                      ? AppColors.mossAccent
                      : AppColors.clayRed,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.divider.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= recent.length) {
                    return const SizedBox.shrink();
                  }
                  final session = recent[idx];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('d/M').format(session.date),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.forestInk,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final session = recent[group.x];
                final playerCount = slots
                    .where((s) =>
                        s.sessionId == session.id &&
                        !s.isDeleted &&
                        s.status != SlotStatus.waitlist)
                    .length;
                return BarTooltipItem(
                  '${session.title}\n$playerCount/${session.maxPlayers} pemain',
                  const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          barGroups: barGroups,
        ),
      ),
    );
  }
}

// =============================================================================
// 3. RevenueChart
// =============================================================================

/// Line chart showing monthly revenue (income) trend over the last 6 months.
///
/// Aggregates [cashflows] of type [CashFlowType.income] by month.
class RevenueChart extends StatelessWidget {
  final List<CashFlowModel> cashflows;

  const RevenueChart({super.key, required this.cashflows});

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Tren Pendapatan',
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    final incomeFlows = cashflows
        .where((c) => !c.isDeleted && c.type == CashFlowType.income)
        .toList();

    if (incomeFlows.isEmpty) return const _EmptyChartState();

    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final dt = DateTime(now.year, now.month - (5 - i));
      return DateTime(dt.year, dt.month);
    });

    final rupiah = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final spots = <FlSpot>[];
    for (var i = 0; i < months.length; i++) {
      final monthStart = months[i];
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1);
      final total = incomeFlows
          .where((c) =>
              c.createdAt.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              c.createdAt.isBefore(monthEnd))
          .fold<int>(0, (sum, c) => sum + c.amount);
      spots.add(FlSpot(i.toDouble(), total.toDouble()));
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final ceilingY = maxY < 100000 ? 100000.0 : (maxY * 1.2).ceilToDouble();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: ceilingY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ceilingY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.divider.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= months.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _monthLabels[months[idx].month - 1],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: ceilingY / 4,
                getTitlesWidget: (value, meta) {
                  String label;
                  if (value >= 1000000) {
                    label = '${(value / 1000000).toStringAsFixed(1)}jt';
                  } else if (value >= 1000) {
                    label = '${(value / 1000).toStringAsFixed(0)}rb';
                  } else {
                    label = value.toInt().toString();
                  }
                  return Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.success,
              getTooltipItems: (spots) => spots.map((spot) {
                final month = months[spot.x.toInt()];
                final label = '${_monthLabels[month.month - 1]} ${month.year}';
                return LineTooltipItem(
                  '$label\n${rupiah.format(spot.y.toInt())}',
                  const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.success,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.success,
                  strokeWidth: 2,
                  strokeColor: AppColors.surfaceElevated,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.success.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 4. ChipsEconomyChart
// =============================================================================

/// Pie chart showing chips distribution by [ChipsSource] type.
///
/// Only counts positive-amount (earned) transactions so the pie reflects
/// where chips originate from.
class ChipsEconomyChart extends StatelessWidget {
  final List<ChipsTransactionModel> transactions;

  const ChipsEconomyChart({super.key, required this.transactions});

  /// Human-readable labels for each [ChipsSource].
  static const _sourceLabels = {
    ChipsSource.sessionAttendance: 'Kehadiran',
    ChipsSource.matchWin: 'Menang',
    ChipsSource.matchDraw: 'Seri',
    ChipsSource.streak3: 'Streak 3',
    ChipsSource.streak5: 'Streak 5',
    ChipsSource.ratingGiven: 'Rating',
    ChipsSource.firstSession: 'Sesi Pertama',
    ChipsSource.stakeWin: 'Stake Win',
    ChipsSource.stakeLoss: 'Stake Loss',
    ChipsSource.redemption: 'Redemption',
    ChipsSource.adminAdjust: 'Admin',
    ChipsSource.welcomeBonus: 'Welcome Bonus',
    ChipsSource.referralBonus: 'Referral',
  };

  /// Rotating palette for pie sections.
  static const _sectionColors = [
    AppColors.forestInk,
    AppColors.mossAccent,
    AppColors.clayRed,
    AppColors.success,
    Color(0xFFD4A843), // warning
    Color(0xFF3D6B8E), // statusPaid
    Color(0xFFC4885B), // bronze accent
    Color(0xFF6E7F6A), // moss duplicate fallback
  ];

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Ekonomi Chips',
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    // Only consider earned (positive) non-deleted transactions.
    final earned = transactions
        .where((t) => !t.isDeleted && t.amount > 0)
        .toList();

    if (earned.isEmpty) return const _EmptyChartState();

    // Aggregate total chips by source.
    final bySource = <ChipsSource, int>{};
    for (final tx in earned) {
      bySource[tx.source] = (bySource[tx.source] ?? 0) + tx.amount;
    }

    // Sort descending by amount.
    final sorted = bySource.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final grandTotal = sorted.fold<int>(0, (sum, e) => sum + e.value);

    final sections = <PieChartSectionData>[];
    final legendItems = <_LegendItem>[];

    for (var i = 0; i < sorted.length; i++) {
      final entry = sorted[i];
      final color = _sectionColors[i % _sectionColors.length];
      final percentage = grandTotal > 0 ? (entry.value / grandTotal * 100) : 0.0;

      sections.add(
        PieChartSectionData(
          value: entry.value.toDouble(),
          color: color,
          radius: 50,
          title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
      );

      legendItems.add(_LegendItem(
        color: color,
        label: _sourceLabels[entry.key] ?? entry.key.name,
        value: entry.value,
        percentage: percentage,
      ));
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 36,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(enabled: true),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: legendItems.map((item) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${item.label} (${item.value})',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Internal model for legend display.
class _LegendItem {
  final Color color;
  final String label;
  final int value;
  final double percentage;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.percentage,
  });
}
