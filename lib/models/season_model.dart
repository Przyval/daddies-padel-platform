/// Client-side season model for quarterly leaderboard filtering.
///
/// Seasons are derived from calendar quarters — no Firestore collection needed.
/// Q1: Jan–Mar, Q2: Apr–Jun, Q3: Jul–Sep, Q4: Oct–Dec.
library;

class Season {
  final String id; // e.g. "2026-Q1"
  final String name; // e.g. "Q1 2026"
  final DateTime startDate;
  final DateTime endDate;

  const Season({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  /// Whether [date] falls within this season.
  bool contains(DateTime date) =>
      !date.isBefore(startDate) && date.isBefore(endDate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Season && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

/// Helper for generating and querying seasons.
class SeasonHelper {
  SeasonHelper._();

  /// Returns the season containing [date].
  static Season seasonForDate(DateTime date) {
    final year = date.year;
    final quarter = ((date.month - 1) ~/ 3) + 1;
    return _buildSeason(year, quarter);
  }

  /// Returns the current season.
  static Season currentSeason() => seasonForDate(DateTime.now());

  /// Returns all seasons from [startYear] to current year (inclusive).
  ///
  /// Default starts from 2025 (platform launch year).
  static List<Season> allSeasons({int startYear = 2025}) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentQuarter = ((now.month - 1) ~/ 3) + 1;

    final seasons = <Season>[];
    for (int year = startYear; year <= currentYear; year++) {
      final maxQ = (year == currentYear) ? currentQuarter : 4;
      for (int q = 1; q <= maxQ; q++) {
        seasons.add(_buildSeason(year, q));
      }
    }

    return seasons.reversed.toList(); // most recent first
  }

  static Season _buildSeason(int year, int quarter) {
    final startMonth = (quarter - 1) * 3 + 1;
    final endMonth = startMonth + 3;

    final startDate = DateTime(year, startMonth, 1);
    final endDate = endMonth > 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, endMonth, 1);

    return Season(
      id: '$year-Q$quarter',
      name: 'Q$quarter $year',
      startDate: startDate,
      endDate: endDate,
    );
  }
}
