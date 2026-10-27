import '../domain/models/usage_log.dart';
import '../domain/models/routine_alert.dart';

abstract class RoutineEngine {
  /// Evaluates recent usage logs and category mappings to detect distraction threshold
  /// breaches and daily routine patterns.
  Future<List<RoutineAlert>> evaluateUsagePatterns({
    required List<UsageLog> recentLogs,
    required Map<String, String> appCategories,
  });
}
