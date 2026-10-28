import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

/// Thin wrapper around the `preferences` SQLite table.
/// All user settings are stored as key→value TEXT rows — fully offline.
class PreferencesRepository {
  final AppDatabase _db = AppDatabase.instance;

  // ── Internal helpers ─────────────────────────────────────────────────────────

  Future<String?> _get(String key) async {
    final db = await _db.database;
    final rows = await db.query('preferences',
        where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> _set(String key, String value) async {
    final db = await _db.database;
    await db.insert(
      'preferences',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Quiet Hours ──────────────────────────────────────────────────────────────

  Future<int> getQuietHoursStart() async =>
      int.tryParse(await _get('quiet_hours_start') ?? '22') ?? 22;

  Future<void> setQuietHoursStart(int hour) =>
      _set('quiet_hours_start', hour.toString());

  Future<int> getQuietHoursEnd() async =>
      int.tryParse(await _get('quiet_hours_end') ?? '7') ?? 7;

  Future<void> setQuietHoursEnd(int hour) =>
      _set('quiet_hours_end', hour.toString());

  // ── Per-type Mute Toggles ────────────────────────────────────────────────────

  Future<bool> isDistractionMuted() async =>
      (await _get('mute_distraction')) == 'true';

  Future<void> setDistractionMuted(bool val) =>
      _set('mute_distraction', val.toString());

  Future<bool> isRoutineMuted() async =>
      (await _get('mute_routine')) == 'true';

  Future<void> setRoutineMuted(bool val) =>
      _set('mute_routine', val.toString());

  // ── Max Alerts Per Day ───────────────────────────────────────────────────────

  Future<int> getMaxAlertsPerDay() async =>
      int.tryParse(await _get('max_alerts_day') ?? '20') ?? 20;

  Future<void> setMaxAlertsPerDay(int count) =>
      _set('max_alerts_day', count.toString());

  // ── Early Warning Threshold Pct (default 80%) ───────────────────────────────

  Future<int> getEarlyWarningThresholdPct() async =>
      int.tryParse(await _get('early_warning_threshold_pct') ?? '80') ?? 80;

  Future<void> setEarlyWarningThresholdPct(int pct) =>
      _set('early_warning_threshold_pct', pct.toString());

  // ── Weekly Summary Opt-in ────────────────────────────────────────────────────

  Future<bool> isWeeklySummaryEnabled() async =>
      (await _get('weekly_summary')) == 'true';

  Future<void> setWeeklySummaryEnabled(bool val) =>
      _set('weekly_summary', val.toString());

  // ── Data Retention (0 = unlimited) ──────────────────────────────────────────

  Future<int> getRetentionDays() async =>
      int.tryParse(await _get('retention_days') ?? '90') ?? 90;

  Future<void> setRetentionDays(int days) =>
      _set('retention_days', days.toString());

  // ── Focus Active Flag ────────────────────────────────────────────────────────

  Future<bool> isFocusActive() async =>
      (await _get('focus_active')) == 'true';

  Future<void> setFocusActive(bool val) =>
      _set('focus_active', val.toString());

  // ── Scheduled Timestamps ─────────────────────────────────────────────────────

  Future<DateTime?> getLastPruneTime() async {
    final ms = await _get('last_prune_ms');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(ms));
  }

  Future<void> setLastPruneTime(DateTime dt) =>
      _set('last_prune_ms', dt.millisecondsSinceEpoch.toString());

  Future<DateTime?> getLastWeeklySummaryTime() async {
    final ms = await _get('last_weekly_summary_ms');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(ms));
  }

  Future<void> setLastWeeklySummaryTime(DateTime dt) =>
      _set('last_weekly_summary_ms', dt.millisecondsSinceEpoch.toString());

  // ── App & Category Screen-Time Limits (Minutes) ───────────────────────────

  Future<int?> getAppLimitMinutes(String packageName) async {
    final val = await _get('limit_pkg_$packageName');
    if (val == null) return null;
    return int.tryParse(val);
  }

  Future<void> setAppLimitMinutes(String packageName, int? minutes) async {
    if (minutes == null || minutes <= 0) {
      final db = await _db.database;
      await db.delete('preferences',
          where: 'key = ?', whereArgs: ['limit_pkg_$packageName']);
    } else {
      await _set('limit_pkg_$packageName', minutes.toString());
    }
  }

  Future<int> getCategoryLimitMinutes(String category) async {
    final val = await _get('limit_cat_$category');
    if (val == null) {
      if (category == 'distracting') return 120; // default 2 hours limit
      return 0; // 0 = unlimited
    }
    return int.tryParse(val) ?? 0;
  }

  Future<void> setCategoryLimitMinutes(String category, int minutes) =>
      _set('limit_cat_$category', minutes.toString());
}
