import 'routine_engine.dart';
import '../domain/models/usage_log.dart';
import '../domain/models/routine_alert.dart';

class DecisionTreeEngine implements RoutineEngine {
  @override
  Future<List<RoutineAlert>> evaluateUsagePatterns({
    required List<UsageLog> recentLogs,
    required Map<String, String> appCategories,
  }) async {
    final List<RoutineAlert> alerts = [];
    final now = DateTime.now();

    if (recentLogs.isEmpty) return alerts;

    // Feature 1: Compute 2-hour rolling distraction usage per package
    final windowStart = now.subtract(const Duration(hours: 2));
    final Map<String, int> rollingDistractionMap = {};

    for (final log in recentLogs) {
      if (log.startTime.isAfter(windowStart)) {
        final category = appCategories[log.packageName] ?? 'neutral';
        if (category == 'distracting') {
          rollingDistractionMap[log.packageName] =
              (rollingDistractionMap[log.packageName] ?? 0) + log.durationSeconds;
        }
      }
    }

    // Feature 2: App hour-slot day frequency (past 7 days)
    final Map<String, Map<int, Set<int>>> appSlotDayTracker = {};
    for (final log in recentLogs) {
      final daysAgo = now.difference(log.startTime).inDays;
      if (daysAgo <= 7) {
        final hourSlot = log.startTime.hour;
        appSlotDayTracker.putIfAbsent(log.packageName, () => {});
        appSlotDayTracker[log.packageName]!.putIfAbsent(hourSlot, () => {});
        appSlotDayTracker[log.packageName]![hourSlot]!.add(daysAgo);
      }
    }

    // Evaluate each recent log through Decision Tree classifier rules
    for (final log in recentLogs) {
      final category = appCategories[log.packageName] ?? 'neutral';
      final categoryCode = category == 'productive' ? 0 : (category == 'distracting' ? 2 : 1);

      final rollingDistraction2h = rollingDistractionMap[log.packageName] ?? 0;
      final daysUsedThisHour = appSlotDayTracker[log.packageName]?[log.startTime.hour]?.length ?? 1;

      final predictedClass = _predictDecisionTree(
        hourOfDay: log.startTime.hour,
        durationSeconds: log.durationSeconds,
        categoryCode: categoryCode,
        rollingDistraction2h: rollingDistraction2h,
        daysUsedThisHour: daysUsedThisHour,
      );

      if (predictedClass == 1) {
        // Distraction Alert
        final minutesUsed = (rollingDistraction2h / 60).round();
        final alertMessage =
            'Distraction Alert: $minutesUsed mins spent on ${log.appName} in past 2h.';
        
        // Avoid duplicate alerts for same app in recent output
        if (!alerts.any((a) => a.packageName == log.packageName && a.type == AlertType.distractionAlert)) {
          alerts.add(
            RoutineAlert(
              type: AlertType.distractionAlert,
              packageName: log.packageName,
              message: alertMessage,
              timestamp: now,
              triggerConditions: {
                'hourOfDay': log.startTime.hour,
                'durationMins': (log.durationSeconds / 60).round(),
                'categoryCode': categoryCode,
                'categoryLabel': category,
                'rolling2hDistractionMins': minutesUsed,
                'daysUsedThisHourSlot': daysUsedThisHour,
                'decisionRule': rollingDistraction2h > 2392
                    ? '2h Rolling Distraction Threshold (>=40m)'
                    : 'Single Long Session Threshold (>=60m)',
                'treeDepth': 6,
              },
            ),
          );
        }
      } else if (predictedClass == 2) {
        // Routine Reminder
        final timeFormatted = '${log.startTime.hour.toString().padLeft(2, '0')}:00';
        final alertMessage =
            'Routine Detected: Consistent usage of ${log.appName} around $timeFormatted.';
        
        if (!alerts.any((a) => a.packageName == log.packageName && a.type == AlertType.routineReminder)) {
          alerts.add(
            RoutineAlert(
              type: AlertType.routineReminder,
              packageName: log.packageName,
              message: alertMessage,
              timestamp: now,
              triggerConditions: {
                'hourOfDay': log.startTime.hour,
                'durationMins': (log.durationSeconds / 60).round(),
                'categoryCode': categoryCode,
                'categoryLabel': category,
                'daysUsedThisHourSlot': daysUsedThisHour,
                'decisionRule': 'Frequency rule: Used $daysUsedThisHour/7 days at $timeFormatted',
                'treeDepth': 6,
              },
            ),
          );
        }
      }
    }

    return alerts;
  }

  /// DecisionTreeClassifier logic compiled from scikit-learn training (max_depth 6)
  int _predictDecisionTree({
    required int hourOfDay,
    required int durationSeconds,
    required int categoryCode,
    required int rollingDistraction2h,
    required int daysUsedThisHour,
  }) {
    if (categoryCode <= 1.5) {
      if (hourOfDay <= 7.5) {
        return 0; // No Alert
      } else {
        if (daysUsedThisHour <= 2.5) {
          return 0;
        } else {
          if (durationSeconds <= 298.0) {
            return 0;
          } else {
            if (hourOfDay <= 22.5) {
              return 2; // Routine Reminder
            } else {
              return 0;
            }
          }
        }
      }
    } else {
      // Distracting app (categoryCode > 1.5)
      if (rollingDistraction2h > 2392.0) {
        return 1; // Distraction Alert
      } else {
        if (durationSeconds > 3595.5) {
          return 1; // Distraction Alert (long single session)
        } else {
          if (hourOfDay <= 7.5) {
            return 0;
          } else {
            if (daysUsedThisHour <= 2.5) {
              return 0;
            } else {
              if (durationSeconds <= 676.5) {
                return 0;
              } else {
                return 2; // Routine Reminder
              }
            }
          }
        }
      }
    }
  }
}
