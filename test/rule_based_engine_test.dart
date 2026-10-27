import 'package:flutter_test/flutter_test.dart';
import 'package:ai_routine_assistant/ai/rule_based_engine.dart';
import 'package:ai_routine_assistant/domain/models/usage_log.dart';
import 'package:ai_routine_assistant/domain/models/routine_alert.dart';

void main() {
  group('RuleBasedEngine Unit Tests', () {
    final engine = RuleBasedEngine();
    final categories = {
      'com.instagram.android': 'distracting',
      'com.google.android.apps.docs': 'productive',
    };

    test('Triggers distraction alert when app usage exceeds 40 minutes in window', () async {
      final now = DateTime.now();
      final logs = [
        UsageLog(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          startTime: now.subtract(const Duration(minutes: 50)),
          endTime: now.subtract(const Duration(minutes: 5)),
          durationSeconds: 45 * 60, // 45 minutes
        ),
      ];

      final alerts = await engine.evaluateUsagePatterns(
        recentLogs: logs,
        appCategories: categories,
      );

      expect(alerts.length, equals(1));
      expect(alerts.first.type, equals(AlertType.distractionAlert));
      expect(alerts.first.packageName, equals('com.instagram.android'));
    });

    test('Does not trigger distraction alert when usage is below threshold', () async {
      final now = DateTime.now();
      final logs = [
        UsageLog(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          startTime: now.subtract(const Duration(minutes: 20)),
          endTime: now.subtract(const Duration(minutes: 5)),
          durationSeconds: 15 * 60, // 15 minutes
        ),
      ];

      final alerts = await engine.evaluateUsagePatterns(
        recentLogs: logs,
        appCategories: categories,
      );

      final distractionAlerts = alerts.where((a) => a.type == AlertType.distractionAlert).toList();
      expect(distractionAlerts.isEmpty, isTrue);
    });

    test('Detects routine pattern across 3 consecutive days at same hour slot', () async {
      final now = DateTime.now();
      const targetHour = 14; // 2 PM slot

      final day1 = DateTime(now.year, now.month, now.day, targetHour).subtract(const Duration(days: 1));
      final day2 = DateTime(now.year, now.month, now.day, targetHour).subtract(const Duration(days: 2));
      final day3 = DateTime(now.year, now.month, now.day, targetHour).subtract(const Duration(days: 3));

      final logs = [
        UsageLog(
          packageName: 'com.google.android.apps.docs',
          appName: 'Google Docs',
          startTime: day1,
          endTime: day1.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
        ),
        UsageLog(
          packageName: 'com.google.android.apps.docs',
          appName: 'Google Docs',
          startTime: day2,
          endTime: day2.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
        ),
        UsageLog(
          packageName: 'com.google.android.apps.docs',
          appName: 'Google Docs',
          startTime: day3,
          endTime: day3.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
        ),
      ];

      final alerts = await engine.evaluateUsagePatterns(
        recentLogs: logs,
        appCategories: categories,
      );

      final routineReminders = alerts.where((a) => a.type == AlertType.routineReminder).toList();
      expect(routineReminders.isNotEmpty, isTrue);
      expect(routineReminders.first.packageName, equals('com.google.android.apps.docs'));
    });
  });
}
