import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/usage_repository.dart';

/// Supported raw-log retention windows.
enum RetentionOption {
  days30(30, '30 days'),
  days60(60, '60 days'),
  days90(90, '90 days'),
  unlimited(0, 'Unlimited');

  final int days;
  final String label;
  const RetentionOption(this.days, this.label);
}

/// Policy object that decides when to prune and delegates the actual delete
/// to [UsageRepository].  All logic lives here — swap the retention algorithm
/// without touching the repository or the UI.
class RetentionPolicy {
  final PreferencesRepository _prefs;
  final UsageRepository _repo;

  RetentionPolicy({
    PreferencesRepository? prefs,
    UsageRepository? repo,
  })  : _prefs = prefs ?? PreferencesRepository(),
        _repo = repo ?? UsageRepository();

  Future<RetentionOption> getCurrentOption() async {
    final days = await _prefs.getRetentionDays();
    return RetentionOption.values.firstWhere(
      (o) => o.days == days,
      orElse: () => RetentionOption.days90,
    );
  }

  Future<void> setOption(RetentionOption option) =>
      _prefs.setRetentionDays(option.days);

  /// Prunes old logs only if:
  ///   1. retention is not unlimited, AND
  ///   2. the last prune was ≥ 24 hours ago (rate-limits repeated background calls).
  ///
  /// Returns the number of rows deleted (0 if skipped).
  Future<int> runPruneIfNeeded() async {
    final option = await getCurrentOption();
    if (option == RetentionOption.unlimited) return 0;

    final lastPrune = await _prefs.getLastPruneTime();
    final now = DateTime.now();
    if (lastPrune != null && now.difference(lastPrune).inHours < 24) return 0;

    final pruned =
        await _repo.pruneLogsOlderThan(age: Duration(days: option.days));
    await _prefs.setLastPruneTime(now);
    return pruned;
  }
}
