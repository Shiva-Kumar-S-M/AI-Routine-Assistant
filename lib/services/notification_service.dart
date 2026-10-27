import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../domain/models/routine_alert.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/database/app_database.dart';
import '../domain/services/weekly_summary_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final PreferencesRepository _prefs = PreferencesRepository();

  NotificationService._init();

  // ── Initialisation ────────────────────────────────────────────────────────────

  Future<void> initialize({bool requestPermission = true}) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'bg_routine_channel',
          'Background Assistant Service',
          description:
              'Notification for active background routine assistant service',
          importance: Importance.low,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'distraction_alerts',
          'Distraction Alerts',
          description: 'Notifications for screen time distraction limits',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'routine_reminders',
          'Routine Reminders',
          description:
              'Notifications for detected app routine patterns',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'weekly_summary',
          'Weekly Summary',
          description: 'Weekly productivity summary notification',
          importance: Importance.defaultImportance,
        ),
      );
      // Only request permission from the main isolate — calling this from the
      // background isolate throws NPE (no Activity context) and causes
      // ForegroundServiceDidNotStartInTimeException.
      if (requestPermission) {
        await androidPlugin.requestNotificationsPermission();
      }
    }
  }

  // ── Gate: enforce all notification policies ───────────────────────────────────

  Future<bool> _shouldShow(RoutineAlert alert) async {
    // ── [DEBUG Task2] Notification gate check ──────────────────────────────────
    print('[NotificationService][DEBUG] _shouldShow called for type=${alert.type.name} pkg=${alert.packageName}');

    // 1. Per-type mute toggle
    if (alert.type == AlertType.distractionAlert &&
        await _prefs.isDistractionMuted()) {
      print('[NotificationService][DEBUG] BLOCKED: distractionMuted=true');
      return false;
    }
    if (alert.type == AlertType.routineReminder &&
        await _prefs.isRoutineMuted()) {
      print('[NotificationService][DEBUG] BLOCKED: routineMuted=true');
      return false;
    }

    // 2. Suppress distraction alerts while focus session is active
    if (alert.type == AlertType.distractionAlert &&
        await _prefs.isFocusActive()) {
      print('[NotificationService][DEBUG] BLOCKED: focusActive=true');
      return false;
    }

    // 3. Quiet hours check
    final now = DateTime.now().hour;
    final quietStart = await _prefs.getQuietHoursStart();
    final quietEnd = await _prefs.getQuietHoursEnd();
    print('[NotificationService][DEBUG] QuietHours check: currentHour=$now, start=$quietStart, end=$quietEnd');
    if (_isInQuietHours(now, quietStart, quietEnd)) {
      print('[NotificationService][DEBUG] BLOCKED: currentHour=$now is inside quiet window $quietStart→$quietEnd');
      return false;
    }

    // 4. Max alerts per day
    final maxAlerts = await _prefs.getMaxAlertsPerDay();
    final db = await AppDatabase.instance.database;
    final today = DateTime.now();
    final startOfDayMs =
        DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM notifications_log WHERE timestamp >= ?',
        [startOfDayMs]);
    final count = result.first['cnt'] as int? ?? 0;
    print('[NotificationService][DEBUG] MaxAlerts check: todayCount=$count / max=$maxAlerts');
    if (count >= maxAlerts) {
      print('[NotificationService][DEBUG] BLOCKED: daily alert cap reached ($count >= $maxAlerts)');
      return false;
    }

    print('[NotificationService][DEBUG] PASSED all gates — notification will fire');
    return true;
  }

  /// Returns true if [currentHour] falls within the quiet hours window.
  bool _isInQuietHours(int currentHour, int startHour, int endHour) {
    if (startHour == endHour) return false; // no quiet hours configured
    if (startHour < endHour) {
      // Same-day window: e.g. 9→17
      return currentHour >= startHour && currentHour < endHour;
    } else {
      // Overnight window: e.g. 22→7
      return currentHour >= startHour || currentHour < endHour;
    }
  }

  // ── Public show methods ───────────────────────────────────────────────────────

  Future<void> showAlertNotification(RoutineAlert alert) async {
    if (!await _shouldShow(alert)) return;

    final isDistraction = alert.type == AlertType.distractionAlert;
    final channelId =
        isDistraction ? 'distraction_alerts' : 'routine_reminders';
    final channelName =
        isDistraction ? 'Distraction Alerts' : 'Routine Reminders';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      isDistraction ? 'Distraction Warning' : 'Routine Detected',
      alert.message,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Shows the weekly summary notification (only called when opt-in is enabled).
  Future<void> showWeeklySummaryNotification() async {
    final summarySvc = WeeklySummaryService();
    if (!await summarySvc.shouldSendSummary()) return;

    final data = await summarySvc.computeSummary();

    const androidDetails = AndroidNotificationDetails(
      'weekly_summary',
      'Weekly Summary',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    await _plugin.show(
      99999, // fixed ID so it replaces itself each week
      'Weekly Productivity Summary',
      'Avg score: ${data.averageScore}/100 · Focus: ${data.totalFocusMinutes}m · ${data.trendLabel}',
      const NotificationDetails(android: androidDetails),
    );
  }
}
