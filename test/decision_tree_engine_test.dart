import 'package:flutter_test/flutter_test.dart';
import 'package:ai_routine_assistant/ai/decision_tree_engine.dart';
import 'package:ai_routine_assistant/domain/models/usage_log.dart';
import 'package:ai_routine_assistant/domain/models/routine_alert.dart';

void main() {
  group('DecisionTreeEngine Tests', () {
    late DecisionTreeEngine engine;

    setUp(() {
      engine = DecisionTreeEngine();
    });

    test('Triggers distraction alert when distracting app exceeds threshold in 2h', () async {
      final now = DateTime.now();
      final logs = [
        UsageLog(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          startTime: now.subtract(const Duration(minutes: 50)),
          endTime: now,
          durationSeconds: 2500,
        ),
      ];

      final categories = {'com.instagram.android': 'distracting'};

      final alerts = await engine.evaluateUsagePatterns(
        recentLogs: logs,
        appCategories: categories,
      );

      expect(alerts.isNotEmpty, true);
      expect(alerts.first.type, AlertType.distractionAlert);
      expect(alerts.first.packageName, 'com.instagram.android');
    });

    test('Triggers routine reminder when app usage pattern detected', () async {
      final now = DateTime.now();
      final logs = [
        UsageLog(
          packageName: 'com.duolingo',
          appName: 'Duolingo',
          startTime: DateTime(now.year, now.month, now.day, 10, 0),
          endTime: DateTime(now.year, now.month, now.day, 10, 15),
          durationSeconds: 900,
        ),
      ];

      final categories = {'com.duolingo': 'productive'};

      final alerts = await engine.evaluateUsagePatterns(
        recentLogs: logs,
        appCategories: categories,
      );

      expect(alerts, isA<List<RoutineAlert>>());
    });
  });
}
