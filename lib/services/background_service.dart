import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'usage_collector_service.dart';
import '../data/repositories/usage_repository.dart';
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

