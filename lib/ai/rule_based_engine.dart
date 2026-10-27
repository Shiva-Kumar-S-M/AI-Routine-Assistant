import 'routine_engine.dart';
import '../domain/models/usage_log.dart';
import '../domain/models/routine_alert.dart';

class RuleBasedEngine implements RoutineEngine {
  // Threshold Rule 1: > 40 minutes (2400 seconds) of distracting app in rolling 2 hours
  static const int distractionThresholdSeconds = 40 * 60;
  static const Duration rollingWindowDuration = Duration(hours: 2);

  @override
  Future<List<RoutineAlert>> evaluateUsagePatterns({
    required List<UsageLog> recentLogs,
    required Map<String, String> appCategories,
  }) async {
    final List<RoutineAlert> alerts = [];
    final now = DateTime.now();

    // --- RULE 1: Distraction Threshold Check ---
    final windowStart = now.subtract(rollingWindowDuration);
    final Map<String, int> distractingAppUsage = {};

    for (final log in recentLogs) {
      if (log.startTime.isAfter(windowStart)) {
        final category = appCategories[log.packageName] ?? 'neutral';
        if (category == 'distracting') {
          distractingAppUsage[log.packageName] =
              (distractingAppUsage[log.packageName] ?? 0) + log.durationSeconds;
        }
      }
    }

    distractingAppUsage.forEach((packageName, totalSeconds) {
      if (totalSeconds >= distractionThresholdSeconds) {
        final minutesUsed = (totalSeconds / 60).round();
        alerts.add(
          RoutineAlert(
            type: AlertType.distractionAlert,
            packageName: packageName,
            message:
                'Distraction Alert: You spent $minutesUsed mins on $packageName in the last 2 hours.',
            timestamp: now,
            triggerConditions: {
              'rolling2hDistractionMins': minutesUsed,
              'thresholdMins': 40,
              'decisionRule': 'Rule-Based: 2h rolling usage >= 40m',
            },
          ),
        );
      }
    });

    // --- RULE 2: Routine Pattern Check ---
    // Detect if same app is used around the same time slot (within 1-hour bucket) on 3+ consecutive days
    final Map<String, Map<int, Set<int>>> appSlotDayTracker = {}; 
    // Format: packageName -> { timeSlotIndex -> Set of relative day indices }

    for (final log in recentLogs) {
      final daysAgo = now.difference(log.startTime).inDays;
      if (daysAgo <= 7) {
        final hourSlot = log.startTime.hour; // 0..23 bucket
        appSlotDayTracker.putIfAbsent(log.packageName, () => {});
        appSlotDayTracker[log.packageName]!.putIfAbsent(hourSlot, () => {});
        appSlotDayTracker[log.packageName]![hourSlot]!.add(daysAgo);
      }
    }

    appSlotDayTracker.forEach((packageName, slotMap) {
      slotMap.forEach((hourSlot, daysSet) {
        // Check for 3+ distinct days
        if (daysSet.length >= 3) {
          final timeFormatted = '${hourSlot.toString().padLeft(2, '0')}:00';
          alerts.add(
            RoutineAlert(
              type: AlertType.routineReminder,
              packageName: packageName,
              message:
                  'Routine Detected: You consistently use $packageName around $timeFormatted.',
              timestamp: now,
              triggerConditions: {
                'hourSlot': hourSlot,
                'daysUsedThisHourSlot': daysSet.length,
                'decisionRule': 'Rule-Based: Habitual usage detected on ${daysSet.length}/7 days at $timeFormatted',
              },
            ),
          );
        }
      });
    });

    return alerts;
  }
}
