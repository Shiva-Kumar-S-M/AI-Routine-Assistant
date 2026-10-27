import '../models/usage_log.dart';
import '../models/routine_alert.dart';

abstract class UsageRepositoryInterface {
  Future<void> insertUsageLogs(List<UsageLog> logs);
  Future<List<UsageLog>> getLogsInWindow(DateTime start, DateTime end);
  Future<void> insertNotification(RoutineAlert alert);
  Future<List<RoutineAlert>> getRecentNotifications({int limit = 20});
  Future<Map<String, int>> getCategoryScreenTimeForToday();
  Future<Map<DateTime, int>> get7DayScreenTimeTrend();
  Future<int> pruneLogsOlderThan({Duration age = const Duration(days: 90)});
}
