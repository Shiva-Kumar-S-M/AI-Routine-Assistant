import 'dart:convert';
import '../data/database/app_database.dart';

class SecurityService {
  final AppDatabase _dbProvider = AppDatabase.instance;

  /// Pure local JSON data export of all sandboxed SQLite tables
  Future<String> exportAppDataAsJson() async {
    final db = await _dbProvider.database;

    final usageLogs = await db.query('usage_logs', limit: 100);
    final appCategories = await db.query('app_categories');
    final routines = await db.query('routines');
    final notifications = await db.query('notifications_log');
    final focusSessions = await db.query('focus_sessions');

    final Map<String, dynamic> exportMap = {
      'exported_at': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      'privacy_guarantee': '100% on-device sandboxed data',
      'tables': {
        'usage_logs': usageLogs,
        'app_categories': appCategories,
        'routines': routines,
        'notifications_log': notifications,
        'focus_sessions': focusSessions,
      }
    };

    return const JsonEncoder.withIndent('  ').convert(exportMap);
  }
}
