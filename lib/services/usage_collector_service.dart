import 'dart:math';
import 'package:flutter/services.dart';
import '../domain/models/usage_log.dart';
import '../data/repositories/usage_repository.dart';
import '../data/repositories/category_repository.dart';

class UsageCollectorService {
  static const MethodChannel _channel =
      MethodChannel('com.example.ai_routine_assistant/usage');

  final UsageRepository _repository = UsageRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();

  Future<bool> checkPermission() async {
    try {
      final bool hasPermission =
          await _channel.invokeMethod('checkUsagePermission');
      return hasPermission;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> openUsageSettings() async {
    try {
      final bool result =
          await _channel.invokeMethod('openUsageSettings');
      return result;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> checkOverlayPermission() async {
    try {
      final bool hasPermission =
          await _channel.invokeMethod('checkOverlayPermission');
      return hasPermission;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> openOverlaySettings() async {
    try {
      final bool result =
          await _channel.invokeMethod('openOverlaySettings');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// Triggers WindowManager overlay with a psychology-framed nudge
  Future<bool> showDistractionOverlay({
    required String appName,
    required String packageName,
    String? targetProductivePackage,
    String? overrideNudgeType,
  }) async {
    try {
      final nudge = getRandomPsychologyNudge(appName, overrideType: overrideNudgeType);
      final bool result = await _channel.invokeMethod(
        'showDistractionOverlay',
        {
          'appName': appName,
          'packageName': packageName,
          'nudgeType': nudge['type'],
          'nudgeMessage': nudge['message'],
          'targetProductivePackage': targetProductivePackage ?? 'com.android.settings',
        },
      );
      return result;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> hideOverlay() async {
    try {
      final bool result = await _channel.invokeMethod('hideOverlay');
      return result;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> startUsageMonitorService() async {
    try {
      final bool result = await _channel.invokeMethod('startUsageMonitorService');
      return result;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> stopUsageMonitorService() async {
    try {
      final bool result = await _channel.invokeMethod('stopUsageMonitorService');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// Generates rotating psychology-based nudge message
  Map<String, String> getRandomPsychologyNudge(String appName, {String? overrideType}) {
    final nudges = [
      {
        'type': 'loss',
        'message': 'Trading 45 mins of your future goals for short-term scrolling on $appName. Is it worth the exchange?',
      },
      {
        'type': 'identity',
        'message': 'Is opening $appName right now aligned with the focused, disciplined person you are becoming?',
      },
      {
        'type': 'implementation',
        'message': 'When you feel the urge to scroll $appName, pause for 10 seconds and switch to your productive task instead.',
      },
      {
        'type': 'streak',
        'message': 'You have maintained your focus momentum today! Don\'t break your streak with an impulse open of $appName.',
      },
    ];

    if (overrideType != null) {
      final match = nudges.firstWhere((n) => n['type'] == overrideType, orElse: () => nudges.first);
      return match;
    }

    final random = Random();
    return nudges[random.nextInt(nudges.length)];
  }

  /// Queries Android's ApplicationInfo.category for a list of packages
  /// and maps each to productive/distracting/neutral buckets.
  Future<Map<String, String>> classifyPackages(List<String> packages) async {
    try {
      final result = await _channel.invokeMethod<Map>(
        'classifyPackages',
        {'packages': packages},
      );
      if (result == null) return {};
      return result.map((k, v) => MapEntry(k.toString(), v.toString()));
    } on PlatformException {
      return {};
    }
  }

  /// Auto-classifies packages that have usage data but no entry in
  /// app_categories, using Android's ApplicationInfo.category as fallback.
  Future<void> autoClassifyNewPackages(List<UsageLog> logs) async {
    try {
      final uniquePackages = logs.map((l) => l.packageName).toSet();
      if (uniquePackages.isEmpty) return;

      final existingCategories = await _repository.getCategoriesMap();
      final unknownPackages = uniquePackages
          .where((pkg) => !existingCategories.containsKey(pkg))
          .toList();
      if (unknownPackages.isEmpty) return;

      final androidCategories = await classifyPackages(unknownPackages);
      for (final entry in androidCategories.entries) {
        await _categoryRepository.insertAutoCategoryIfAbsent(
          entry.key, entry.value,
        );
      }
    } catch (_) {
      // Non-critical: don't crash the collection flow if classification fails
    }
  }

  Future<List<UsageLog>> collectAndSaveLogs({Duration window = const Duration(hours: 24)}) async {
    final bool hasPermission = await checkPermission();
    if (!hasPermission) return [];

    final now = DateTime.now();
    final startTime = now.subtract(window).millisecondsSinceEpoch;
    final endTime = now.millisecondsSinceEpoch;

    try {
      final List<dynamic>? rawEvents = await _channel.invokeMethod(
        'queryUsageEvents',
        {
          'startTime': startTime,
          'endTime': endTime,
        },
      );

      if (rawEvents == null || rawEvents.isEmpty) return [];

      final List<UsageLog> logs = [];
      for (final event in rawEvents) {
        if (event is Map) {
          final map = Map<String, dynamic>.from(event);
          final pkg = map['packageName']?.toString() ?? '';
          if (pkg.isEmpty) continue;

          final rawAppName = map['appName']?.toString();
          final appName = (rawAppName != null && rawAppName.isNotEmpty)
              ? rawAppName
              : pkg;
          final startTimeMs = (map['startTime'] as num?)?.toInt() ?? 0;
          final endTimeMs = (map['endTime'] as num?)?.toInt() ?? 0;
          final durationSec = (map['durationSeconds'] as num?)?.toInt() ?? 0;

          if (startTimeMs > 0 && endTimeMs >= startTimeMs) {
            logs.add(UsageLog(
              packageName: pkg,
              appName: appName,
              startTime: DateTime.fromMillisecondsSinceEpoch(startTimeMs),
              endTime: DateTime.fromMillisecondsSinceEpoch(endTimeMs),
              durationSeconds: durationSec,
            ));
          }
        }
      }

      await _repository.insertUsageLogs(logs);

      // Auto-classify packages not yet in app_categories using Android's
      // ApplicationInfo.category as a fallback classifier.
      await autoClassifyNewPackages(logs);

      return logs;
    } catch (e) {
      return [];
    }
  }
}

