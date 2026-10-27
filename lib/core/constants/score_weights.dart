/// Defines the weights and thresholds used by [ProductivityScoreCalculator].
/// All weights must sum to exactly 1.0.
/// Adjust values here to retune the composite score algorithm.
class ScoreWeights {
  ScoreWeights._();

  // ── Composite Score Weights ──────────────────────────────────────────────────

  /// How much the distraction ratio affects the score (distracting / total time).
  static const double distractionRatio = 0.45;

  /// How much completed Pomodoro focus-time contributes.
  static const double focusTime = 0.35;

  /// How much routine adherence (consistent detected routines) contributes.
  static const double routineAdherence = 0.20;

  // ── Focus Time Benchmark ─────────────────────────────────────────────────────

  /// Minutes of completed focus sessions considered "perfect" (earns full weight).
  static const double targetFocusMinutes = 120.0;

  // ── Score Band Thresholds ────────────────────────────────────────────────────
  // Used identically by ScoreCalculator labels AND notification engine thresholds.

  /// Score >= this → "Exceptional Focus"
  static const int exceptional = 80;

  /// Score >= this → "Good Balance"
  static const int good = 60;

  /// Score >= this → "Moderate Productivity"
  static const int moderate = 40;

  /// Score < [moderate] → "High Distraction Level"
}
