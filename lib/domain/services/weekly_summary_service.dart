import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/usage_repository.dart';
import '../../data/repositories/focus_repository.dart';
import 'productivity_score_calculator.dart';

/// Immutable result object returned by [WeeklySummaryService.computeSummary].
class WeeklySummaryData {
  final int averageScore;
  final String trendLabel; // e.g. "Improving"
  final int totalFocusMinutes;
  final List<int> dailyScores; // 7 entries, oldest first

  const WeeklySummaryData({
    required this.averageScore,
    required this.trendLabel,
    required this.totalFocusMinutes,
    required this.dailyScores,
  });
}

/// Computes the weekly productivity summary and manages the opt-in preference.
///
/// The service is intentionally decoupled from [NotificationService] — it only
/// produces data; the notification layer decides how to display it.
class WeeklySummaryService {
  final PreferencesRepository _prefs;
  final UsageRepository _usageRepo;
  final FocusRepository _focusRepo;

  WeeklySummaryService({
    PreferencesRepository? prefs,
    UsageRepository? usageRepo,
    FocusRepository? focusRepo,
  })  : _prefs = prefs ?? PreferencesRepository(),
        _usageRepo = usageRepo ?? UsageRepository(),
        _focusRepo = focusRepo ?? FocusRepository();

  Future<bool> isEnabled() => _prefs.isWeeklySummaryEnabled();
  Future<void> setEnabled(bool val) => _prefs.setWeeklySummaryEnabled(val);

  /// Returns true if opt-in is on AND ≥7 days have passed since last summary.
  Future<bool> shouldSendSummary() async {
    if (!await isEnabled()) return false;
    final last = await _prefs.getLastWeeklySummaryTime();
    if (last == null) return true;
    return DateTime.now().difference(last).inDays >= 7;
  }

  /// Computes data for the past 7 days. Marks the summary as sent on success.
  Future<WeeklySummaryData> computeSummary() async {
    final now = DateTime.now();
    final dailyScores = <int>[];
    int totalFocusMinutes = 0;

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));

      final logs = await _usageRepo.getLogsInWindow(day, nextDay);
      int productive = 0, distracting = 0;
      for (final log in logs) {
        if (log.category == 'productive') productive += log.durationSeconds;
        if (log.category == 'distracting') distracting += log.durationSeconds;
      }

      final sessions = await _focusRepo.getSessionsInWindow(day, nextDay);
      final focusMin = sessions
          .where((s) => s.isCompleted)
          .fold(0, (s, e) => s + e.durationMinutes);
      totalFocusMinutes += focusMin;

      dailyScores.add(ProductivityScoreCalculator.calculateCompositeScore(
        productiveSeconds: productive,
        distractingSeconds: distracting,
        focusMinutesToday: focusMin,
      ));
    }

    final avgScore = dailyScores.isNotEmpty
        ? dailyScores.fold(0, (a, b) => a + b) ~/ dailyScores.length
        : 50;

    // Trend: compare first half vs second half of the week
    String trendLabel = 'Steady';
    if (dailyScores.length >= 4) {
      final half = dailyScores.length ~/ 2;
      final firstHalfAvg =
          dailyScores.take(half).fold(0, (a, b) => a + b) ~/ half;
      final secondHalfAvg =
          dailyScores.skip(half).fold(0, (a, b) => a + b) ~/
              (dailyScores.length - half);
      if (secondHalfAvg > firstHalfAvg + 5) {
        trendLabel = 'Improving';
      } else if (secondHalfAvg < firstHalfAvg - 5) {
        trendLabel = 'Declining';
      }
    }

    await _prefs.setLastWeeklySummaryTime(now);

    return WeeklySummaryData(
      averageScore: avgScore,
      trendLabel: trendLabel,
      totalFocusMinutes: totalFocusMinutes,
      dailyScores: dailyScores,
    );
  }
}
