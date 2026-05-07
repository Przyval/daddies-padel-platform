/// KTA membership tiers, computed client-side from chips balance and session count.
enum KtaTier { bronze, silver, gold, platinum }

extension KtaTierX on KtaTier {
  String get label => switch (this) {
    KtaTier.bronze => 'Bronze',
    KtaTier.silver => 'Silver',
    KtaTier.gold => 'Gold',
    KtaTier.platinum => 'Platinum',
  };

  String get emoji => switch (this) {
    KtaTier.bronze => '\u{1F949}', // bronze medal
    KtaTier.silver => '\u{1F948}', // silver medal
    KtaTier.gold => '\u{1F947}', // gold medal
    KtaTier.platinum => '\u{1F48E}', // gem stone
  };

  /// Tier-specific gradient colors for the KTA card.
  List<int> get gradientHex => switch (this) {
    KtaTier.bronze => [0xFFA67C52, 0xFF8B6239, 0xFF6B4824],
    KtaTier.silver => [0xFFC0C0C0, 0xFFA8A8A8, 0xFF909090],
    KtaTier.gold => [0xFFD4A843, 0xFFC09630, 0xFFA07818],
    KtaTier.platinum => [0xFF2C3E50, 0xFF1A252F, 0xFF0D1117],
  };

  /// Minimum chips required for this tier.
  int get requiredChips => switch (this) {
    KtaTier.bronze => 0,
    KtaTier.silver => 100,
    KtaTier.gold => 500,
    KtaTier.platinum => 2000,
  };

  /// Minimum completed sessions required for this tier.
  int get requiredSessions => switch (this) {
    KtaTier.bronze => 0,
    KtaTier.silver => 5,
    KtaTier.gold => 15,
    KtaTier.platinum => 30,
  };

  /// The next tier, or null if already platinum.
  KtaTier? get nextTier => switch (this) {
    KtaTier.bronze => KtaTier.silver,
    KtaTier.silver => KtaTier.gold,
    KtaTier.gold => KtaTier.platinum,
    KtaTier.platinum => null,
  };
}

/// Computes the KTA tier from a user's stats.
KtaTier computeKtaTier({required int chipsBalance, required int completedSessions}) {
  if (chipsBalance >= 2000 && completedSessions >= 30) return KtaTier.platinum;
  if (chipsBalance >= 500 && completedSessions >= 15) return KtaTier.gold;
  if (chipsBalance >= 100 && completedSessions >= 5) return KtaTier.silver;
  return KtaTier.bronze;
}

/// Computes progress (0.0–1.0) towards the next tier.
/// Returns 1.0 if already platinum.
double computeTierProgress({required int chipsBalance, required int completedSessions}) {
  final current = computeKtaTier(chipsBalance: chipsBalance, completedSessions: completedSessions);
  final next = current.nextTier;
  if (next == null) return 1.0;

  final chipsProgress = (chipsBalance - current.requiredChips) /
      (next.requiredChips - current.requiredChips);
  final sessionProgress = (completedSessions - current.requiredSessions) /
      (next.requiredSessions - current.requiredSessions);

  // Use the minimum of the two (both must be met).
  return ((chipsProgress < sessionProgress ? chipsProgress : sessionProgress)).clamp(0.0, 1.0);
}

/// Parses a KtaTier from a string. Returns null for unknown values.
KtaTier? parseTier(String? value) {
  if (value == null) return null;
  for (final t in KtaTier.values) {
    if (t.name == value) return t;
  }
  return null;
}
