import '../../core/constants/score_weights.dart';

/// Stateless calculator for the composite Productivity Score (0–100).
///
/// Weights and thresholds are externalized in [ScoreWeights] so the
/// algorithm can be re-tuned without touching this class.
class ProductivityScoreCalculator {
  ProductivityScoreCalculator._();

  // ── Composite (3-signal) score ───────────────────────────────────────────────

  /// Calculates a weighted composite score from three signals:
  ///   - **Distraction ratio** (45 %): share of screen-time that was distracting.
  ///   - **Focus time** (35 %): completed Pomodoro minutes vs. 120-minute target.
  ///   - **Routine adherence** (20 %): how consistently expected routines fired.
  static int calculateCompositeScore({
    required int productiveSeconds,
    required int distractingSeconds,
    required int focusMinutesToday,
    int routineAdherencePercent = 50,
  }) {
    final totalSeconds = productiveSeconds + distractingSeconds;

    // 1. Distraction ratio → 0 % distraction = 100 pts, 100 % = 0 pts
    final double distractionScore;
    if (totalSeconds == 0) {
      distractionScore = 50.0; // neutral when no data
    } else {
      final ratio = distractingSeconds / totalSeconds;
      distractionScore = (1.0 - ratio) * 100.0;
    }

    // 2. Focus time → capped at [ScoreWeights.targetFocusMinutes]
    final capped =
        focusMinutesToday.clamp(0, ScoreWeights.targetFocusMinutes.toInt());
    final double focusScore =
        (capped / ScoreWeights.targetFocusMinutes) * 100.0;

    // 3. Routine adherence (0–100 %)
    final double routineScore = routineAdherencePercent.toDouble();

    // Weighted sum
    final composite = (distractionScore * ScoreWeights.distractionRatio) +
        (focusScore * ScoreWeights.focusTime) +
        (routineScore * ScoreWeights.routineAdherence);

    return composite.round().clamp(0, 100);
  }

  // ── Score description ────────────────────────────────────────────────────────

  /// Returns a human-readable label derived from [ScoreWeights] thresholds —
  /// the same thresholds that drive notification decisions.
  static String getScoreDescription(int score) {
    if (score >= ScoreWeights.exceptional) return 'Exceptional Focus';
    if (score >= ScoreWeights.good) return 'Good Balance';
    if (score >= ScoreWeights.moderate) return 'Moderate Productivity';
    return 'High Distraction Level';
  }

  // ── Legacy 2-signal formula (kept for backward compatibility) ────────────────

  @Deprecated('Use calculateCompositeScore with all three signals instead.')
  static int calculateScore({
    required int productiveSeconds,
    required int distractingSeconds,
  }) {
    final total = productiveSeconds + distractingSeconds;
    if (total == 0) return 50;
    return ((productiveSeconds / total) * 100).round().clamp(0, 100);
  }
}
