import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'category_repository.dart';
import '../../services/app_label_helper.dart';
import '../../domain/models/usage_log.dart';
import '../../domain/models/routine_alert.dart';
import '../../domain/repositories/usage_repository_interface.dart';
import '../../domain/services/productivity_score_calculator.dart';
import '../../core/constants/score_weights.dart';

class UsageRepository implements UsageRepositoryInterface {
  final AppDatabase _dbProvider = AppDatabase.instance;
  final CategoryRepository _categoryRepository = CategoryRepository();

  @override
  Future<void> insertUsageLogs(List<UsageLog> logs) async {
    final db = await _dbProvider.database;
    final batch = db.batch();

    for (final log in logs) {
      batch.insert(
        'usage_logs',
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore, // skip if same package+start_time exists
      );
    }
    await batch.commit(noResult: true);

    // ── Backfill stale app_name rows ─────────────────────────────────────────
    // Rows inserted before label resolution was wired have app_name == package_name
    // or app_name == ''. Update them now that we have resolved labels.
    for (final log in logs) {
      if (log.appName.isNotEmpty && log.appName != log.packageName) {
        await db.update(
          'usage_logs',
          {'app_name': log.appName},
          where: "package_name = ? AND (app_name = ? OR app_name = '')",
          whereArgs: [log.packageName, log.packageName],
        );
      }
    }
  }

  /// One-shot fix: updates every row where app_name == package_name (stale)
  /// by copying the best resolved label found for the same package elsewhere
  /// in the table. Safe to call on every app launch — pure SQL, no MethodChannel.
  Future<void> backfillStaleAppNames() async {
    final db = await _dbProvider.database;
    await AppLabelHelper.backfillAllStoredLabels();
    await db.execute(
      "UPDATE usage_logs "
      "SET app_name = COALESCE(("
        "SELECT ul2.app_name FROM usage_logs ul2 "
        "WHERE ul2.package_name = usage_logs.package_name "
        "  AND ul2.app_name != ul2.package_name "
        "  AND ul2.app_name != '' "
        "LIMIT 1"
      "), package_name) "
      "WHERE (app_name = package_name OR app_name = '' OR app_name IS NULL) "
      "  AND EXISTS ("
        "SELECT 1 FROM usage_logs ul3 "
        "WHERE ul3.package_name = usage_logs.package_name "
        "  AND ul3.app_name != ul3.package_name "
        "  AND ul3.app_name != ''"
      ")",
    );
  }

  @override
  Future<List<UsageLog>> getLogsInWindow(DateTime start, DateTime end, [Map<String, String>? categoriesMap]) async {
    final db = await _dbProvider.database;
    final catMap = categoriesMap ?? await getCategoriesMap();

    final maps = await db.query(
      'usage_logs',
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'start_time DESC',
    );

    return maps.map((map) {
      final pkg = map['package_name'] as String;
      final category = catMap[pkg] ?? 'neutral';
      return UsageLog.fromMap(map, category: category);
    }).toList();
  }

  Future<Map<String, String>> getCategoriesMap() async {
    return _categoryRepository.getCategoriesMap();
  }

  @override
  Future<void> insertNotification(RoutineAlert alert) async {
    final db = await _dbProvider.database;
    await db.insert('notifications_log', alert.toMap());
  }

  @override
  Future<List<RoutineAlert>> getRecentNotifications({int limit = 20}) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      'notifications_log',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((map) => RoutineAlert.fromMap(map)).toList();
  }

  /// Paginated version of getRecentNotifications for lazy loading.
  Future<List<RoutineAlert>> getNotificationsPage(
      {int limit = 10, int offset = 0}) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      'notifications_log',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((map) => RoutineAlert.fromMap(map)).toList();
  }

  @override
  Future<Map<String, int>> getCategoryScreenTimeForToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final logs = await getLogsInWindow(startOfDay, endOfDay);
    final Map<String, int> totals = {
      'productive': 0,
      'distracting': 0,
      'neutral': 0,
    };

    for (final log in logs) {
      final cat = totals.containsKey(log.category) ? log.category : 'neutral';
      totals[cat] = (totals[cat] ?? 0) + log.durationSeconds;
    }

    return totals;
  }

  @override
  Future<Map<DateTime, int>> get7DayScreenTimeTrend() async {
    final now = DateTime.now();
    final Map<DateTime, int> dailyTotals = {};
    final categoriesMap = await getCategoriesMap();

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));

      final logs = await getLogsInWindow(day, nextDay, categoriesMap);
      final totalSeconds = logs.fold<int>(0, (sum, log) => sum + log.durationSeconds);
      dailyTotals[day] = totalSeconds;
    }

    return dailyTotals;
  }

  @override
  Future<int> pruneLogsOlderThan({Duration age = const Duration(days: 90)}) async {
    final db = await _dbProvider.database;
    final cutoffMs = DateTime.now().subtract(age).millisecondsSinceEpoch;
    return await db.delete(
      'usage_logs',
      where: 'start_time < ?',
      whereArgs: [cutoffMs],
    );
  }

  /// Returns productive/distracting/neutral totals for a specific calendar day.
  Future<Map<String, int>> getCategoryBreakdownForDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final logs = await getLogsInWindow(startOfDay, endOfDay);
    final Map<String, int> totals = {
      'productive': 0,
      'distracting': 0,
      'neutral': 0,
    };
    for (final log in logs) {
      final cat = totals.containsKey(log.category) ? log.category : 'neutral';
      totals[cat] = (totals[cat] ?? 0) + log.durationSeconds;
    }
    return totals;
  }

  /// Returns top 3 most used apps for today with package, name, category, duration.
  Future<List<Map<String, dynamic>>> getTopAppsForToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final logs = await getLogsInWindow(startOfDay, endOfDay);

    final pkgs = logs.map((l) => l.packageName).toSet().toList();
    final labelMap = await AppLabelHelper.getAppLabels(pkgs);

    // Pre-fetch the best resolved name for every package from the full DB
    // (not just today's window) so stale rows never win over resolved ones.
    final db = await _dbProvider.database;
    final resolvedRows = await db.rawQuery(
      "SELECT package_name, app_name FROM usage_logs "
      "WHERE app_name != package_name AND app_name != '' "
      "GROUP BY package_name",
    );
    final Map<String, String> bestNames = {};
    for (final row in resolvedRows) {
      final pkg = row['package_name'] as String?;
      final name = row['app_name'] as String?;
      if (pkg != null && name != null && name.isNotEmpty) {
        bestNames[pkg] = name;
      }
    }

    final Map<String, Map<String, dynamic>> appUsage = {};
    for (final log in logs) {
      final pkg = log.packageName;
      final displayName = labelMap[pkg] ??
          bestNames[pkg] ??
          (log.appName.isNotEmpty && log.appName != pkg
              ? log.appName
              : AppLabelHelper.cleanPackageName(pkg));

      if (!appUsage.containsKey(pkg)) {
        appUsage[pkg] = {
          'packageName': pkg,
          'appName': displayName,
          'category': log.category,
          'durationSeconds': 0,
        };
      }
      appUsage[pkg]!['durationSeconds'] =
          (appUsage[pkg]!['durationSeconds'] as int) + log.durationSeconds;
    }

    final list = appUsage.values.toList();
    list.sort((a, b) => (b['durationSeconds'] as int).compareTo(a['durationSeconds'] as int));
    return list.take(3).toList();
  }

  /// Returns current productivity streak in consecutive days with score >= 60.
  Future<int> getProductivityStreak() async {
    final now = DateTime.now();
    final categoriesMap = await getCategoriesMap();
    int streak = 0;
    for (int i = 0; i < 30; i++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final logs = await getLogsInWindow(day, nextDay, categoriesMap);
      if (logs.isEmpty && i == 0) continue;
      if (logs.isEmpty) break;

      int productive = 0;
      int distracting = 0;
      for (final log in logs) {
        if (log.category == 'productive') productive += log.durationSeconds;
        if (log.category == 'distracting') distracting += log.durationSeconds;
      }
      final score = ProductivityScoreCalculator.calculateCompositeScore(
        productiveSeconds: productive,
        distractingSeconds: distracting,
        focusMinutesToday: 0,
      );
      if (score >= ScoreWeights.good) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
  }

  /// Scaffold Feature: Get today's reopen/session count for decaying friction delay calculation
  Future<int> getAppReopenCountToday(String packageName) async {
    final db = await _dbProvider.database;
    final now = DateTime.now();
    final startOfDayMs = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM usage_logs WHERE package_name = ? AND start_time >= ?',
      [packageName, startOfDayMs],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Scaffold Feature: Insert post-session emotional check-in log
  Future<void> insertEmotionalLog(dynamic log) async {
    final db = await _dbProvider.database;
    await db.insert('emotional_logs', log.toMap());
  }
}

