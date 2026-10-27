import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'usage_collector_service.dart';
import '../data/repositories/usage_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../domain/models/routine_alert.dart';
import '../domain/models/usage_log.dart';
import '../ai/decision_tree_engine.dart';
import 'notification_service.dart';
import '../domain/services/retention_policy.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartBackgroundService,
      autoStart: true,
      isForegroundMode: true,              // ← FIXED: keeps service alive on Android 8+
      notificationChannelId: 'bg_routine_channel',
      initialNotificationTitle: 'AI Routine Assistant',
      initialNotificationContent: 'Monitoring screen time habits on-device',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
    ),
  );

  // ── FIXED: check isRunning() first — calling startService() when the service is
  // already alive triggers a second startForegroundService() which immediately
  // hits the 5-second ForegroundServiceDidNotStartInTimeException timeout.
  final isRunning = await service.isRunning();
  if (!isRunning) {
    await service.startService();
  }
}

@pragma('vm:entry-point')
void onStartBackgroundService(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  // ── [DEBUG Task2] Confirm isolate booted ─────────────────────────────────
  print('[BackgroundService][DEBUG] ─── ISOLATE STARTED at ${DateTime.now()} ───');

  try {
    // requestPermission: false — background isolate has no Activity context;
    // calling requestNotificationsPermission() throws NPE and blows the
    // Android 5-second startForeground() deadline, crashing the service.
    await NotificationService.instance.initialize(requestPermission: false);
    print('[BackgroundService][DEBUG] NotificationService.initialize() OK');
  } catch (e) {
    print('[BackgroundService][DEBUG] NotificationService.initialize() FAILED: $e');
  }

  final collector = UsageCollectorService();
  final repository = UsageRepository();
  final engine = DecisionTreeEngine();
  final retentionPolicy = RetentionPolicy();
  final prefsRepository = PreferencesRepository();

  int tickCount = 0;

  // Fire once immediately on start so we don't wait 15 min for the first check.
  // [DEBUG Task2]: also confirms the timer starts at all.
  print('[BackgroundService][DEBUG] Timer.periodic registered — waiting for first tick (15 min)...');

  Timer.periodic(const Duration(minutes: 15), (timer) async {
    tickCount++;
    print('[BackgroundService][DEBUG] ─── TICK #$tickCount at ${DateTime.now()} ───');

    // ── Every tick: collect + evaluate Decision Tree patterns ────────────────
    // [DEBUG Task2] Expose whether collectAndSaveLogs succeeds from this isolate.
    // If MethodChannel is broken in background isolate, logs will be empty.
    List<UsageLog> logs;
    try {
      logs = await collector.collectAndSaveLogs(window: const Duration(hours: 24));
      print('[BackgroundService][DEBUG] collectAndSaveLogs returned ${logs.length} sessions');
    } catch (e) {
      print('[BackgroundService][DEBUG] collectAndSaveLogs THREW: $e');
      logs = [];
    }

    if (logs.isNotEmpty) {
      final categories = await repository.getCategoriesMap();
      final alerts = await engine.evaluateUsagePatterns(
        recentLogs: logs,
        appCategories: categories,
      );
      for (final alert in alerts) {
        await repository.insertNotification(alert);
        await NotificationService.instance.showAlertNotification(alert);
      }
    }

    // ── EVALUATE CONFIGURED PER-APP DAILY TIME LIMITS ───────────────────────
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final todayLogs = await repository.getLogsInWindow(startOfDay, endOfDay);

      final Map<String, int> todaySecondsPerPkg = {};
      final Map<String, String> pkgToAppNameMap = {};

      for (final log in todayLogs) {
        todaySecondsPerPkg[log.packageName] =
            (todaySecondsPerPkg[log.packageName] ?? 0) + log.durationSeconds;
        if (log.appName.isNotEmpty) {
          pkgToAppNameMap[log.packageName] = log.appName;
        }
      }

      final categoriesMap = await repository.getCategoriesMap();

      for (final entry in todaySecondsPerPkg.entries) {
        final pkg = entry.key;
        final totalSecs = entry.value;
        final appName = pkgToAppNameMap[pkg] ?? pkg;
        final category = categoriesMap[pkg] ?? 'neutral';

        int limitMins = (await prefsRepository.getAppLimitMinutes(pkg)) ?? 0;
        if (limitMins == 0 && category == 'distracting') {
          limitMins = await prefsRepository.getCategoryLimitMinutes('distracting');
        }

        final usedMins = totalSecs ~/ 60;
        print('[BackgroundService] Evaluating $appName ($pkg): Used ${usedMins}m / Limit ${limitMins}m');

        if (limitMins > 0 && usedMins >= limitMins) {
          print('[BackgroundService] ⚠️ LIMIT EXCEEDED FOR $appName ($pkg)! (Used: ${usedMins}m >= Limit: ${limitMins}m)');

          final alertMessage =
              'Limit Exceeded: You spent ${usedMins}m on $appName today (Limit: ${limitMins}m).';

          final alert = RoutineAlert(
            type: AlertType.distractionAlert,
            packageName: pkg,
            message: alertMessage,
            timestamp: now,
            triggerConditions: {
              'limitMins': limitMins,
              'usedMinsToday': usedMins,
              'decisionRule': 'Configured Daily App Limit Exceeded',
            },
          );

          await repository.insertNotification(alert);

          // Fire local notification
          await NotificationService.instance.showAlertNotification(alert);

          // Trigger native WindowManager overlay nudge if permission is granted
          final hasOverlayPerm = await collector.checkOverlayPermission();
          if (hasOverlayPerm) {
            print('[BackgroundService] Triggering WindowManager overlay for $appName...');
            await collector.showDistractionOverlay(
              appName: appName,
              packageName: pkg,
              overrideNudgeType: 'loss',
            );
          }
        }
      }
    } catch (e) {
      print('[BackgroundService] Error evaluating per-app limits: $e');
    }

    // ── Once a day (~96 ticks at 15-min intervals): prune logs ───────────────
    if (tickCount % 96 == 0) {
      await retentionPolicy.runPruneIfNeeded();
    }

    // ── Daily: check if weekly summary should fire ────────────────────────────
    if (tickCount % 96 == 48) {
      try {
        await NotificationService.instance.showWeeklySummaryNotification();
      } catch (_) {}
    }
  });
}

