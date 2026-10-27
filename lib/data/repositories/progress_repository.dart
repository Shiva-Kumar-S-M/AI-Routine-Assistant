import 'dart:convert';
import 'dart:math';
import '../database/app_database.dart';
import '../../domain/models/user_progress.dart';
import '../../domain/models/badge_item.dart';
import '../../domain/models/weekly_recap.dart';

class LevelUpResult {
  final int oldLevel;
  final int newLevel;
  final String title;

  const LevelUpResult({
    required this.oldLevel,
    required this.newLevel,
    required this.title,
  });
}

class ProgressRepository {
  final AppDatabase _db = AppDatabase.instance;
  final Random _random = Random();

  Future<UserProgress> getUserProgress() async {
    final db = await _db.database;
    final rows = await db.query('user_progress', where: 'id = ?', whereArgs: [1], limit: 1);
    if (rows.isEmpty) {
      return const UserProgress(
        xp: 0,
        level: 1,
        streakDays: 0,
        streakFreezes: 0,
        timeReclaimedSeconds: 0,
      );
    }
    return UserProgress.fromMap(rows.first);
  }

  Future<LevelUpResult?> addXp(int amount, String source, String description) async {
    final db = await _db.database;

    // Log transaction
    await db.insert('xp_transactions', {
      'amount': amount,
      'source': source,
      'description': description,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final current = await getUserProgress();
    final newXp = current.xp + amount;
    final newLevel = UserProgress.calculateLevelForXp(newXp);
    final didLevelUp = newLevel > current.level;

    await db.update(
      'user_progress',
      {
        'xp': newXp,
        'level': newLevel,
      },
      where: 'id = ?',
      whereArgs: [1],
    );

    if (didLevelUp) {
      return LevelUpResult(
        oldLevel: current.level,
        newLevel: newLevel,
        title: current.copyWith(level: newLevel).levelTitle,
      );
    }
    return null;
  }

  /// Synchronizes actions logged by native UsageMonitorService into the XP/Badge system
  Future<LevelUpResult?> syncFromUnrewardedInterventions() async {
    final db = await _db.database;
    final unrewarded = await db.query(
      'notifications_log',
      where: "rewarded = 0 AND type IN ('turn_back', 'bypass', 'brain_challenge')",
      orderBy: 'timestamp ASC',
    );

    LevelUpResult? lastLevelUp;

    for (final row in unrewarded) {
      final id = row['id'] as int;
      final type = row['type'] as String;
      final pkg = row['package_name'] as String;
      final conditionsRaw = row['trigger_conditions'] as String?;
      Map<String, dynamic> conditions = {};
      if (conditionsRaw != null && conditionsRaw.isNotEmpty) {
        try {
          conditions = jsonDecode(conditionsRaw);
        } catch (_) {}
      }

      final hook = conditions['hook']?.toString() ?? 'loss';
      final usedMins = (conditions['usedMins'] as num?)?.toInt() ?? 0;
      final limitMins = (conditions['limitMins'] as num?)?.toInt() ?? 0;

      if (type == 'turn_back') {
        final res = await recordTurnBack(
          packageName: pkg,
          usedMins: usedMins,
          limitMins: limitMins,
          hookType: hook,
        );
        if (res != null) lastLevelUp = res;
      } else if (type == 'bypass') {
        await recordBypass(
          packageName: pkg,
          usedMins: usedMins,
          limitMins: limitMins,
          hookType: hook,
        );
      } else if (type == 'brain_challenge') {
        final res = await addXp(15, 'brain_challenge', 'Accepted Brain Challenge instead of scrolling');
        if (res != null) lastLevelUp = res;
        await _advanceBadgeProgress('quiz_master', 1);
      }

      await db.update(
        'notifications_log',
        {'rewarded': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    return lastLevelUp;
  }

  /// Records a successful turn-back intervention (+20 XP, bonus roll, time saved calculation)
  Future<LevelUpResult?> recordTurnBack({
    required String packageName,
    required int usedMins,
    required int limitMins,
    required String hookType,
  }) async {
    final db = await _db.database;

    // 1. Log hook feedback for optimization
    await db.insert('hook_feedback', {
      'package_name': packageName,
      'hook_type': hookType,
      'action': 'turn_back',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // 2. Estimate reclaimed time using user's average session length on that app
    final avgRow = await db.rawQuery(
      'SELECT AVG(duration_seconds) as avg_sec FROM usage_logs WHERE package_name = ?',
      [packageName],
    );
    final rawAvg = (avgRow.isNotEmpty ? avgRow.first['avg_sec'] as num? : null)?.toInt();
    final reclaimedSec = (rawAvg != null && rawAvg > 120) ? rawAvg : 900; // default to 15 min if sparse

    await db.rawUpdate(
      'UPDATE user_progress SET time_reclaimed_seconds = time_reclaimed_seconds + ? WHERE id = 1',
      [reclaimedSec],
    );

    // 3. Award XP (+20 base + 15% surprise bonus chance)
    int xpToAward = 20;
    String xpNote = 'Turned back from distraction';
    if (_random.nextDouble() < 0.15) {
      xpToAward += 15;
      xpNote = '⚡ Surprise Focus Bonus! Turned back from distraction';
    }

    final levelUp = await addXp(xpToAward, 'turn_back', xpNote);

    // 4. Update Badges
    final reclaimedMins = reclaimedSec ~/ 60;
    await _advanceBadgeProgress('first_turn_back', 1);
    await _advanceBadgeProgress('turn_back_5', 1);
    await _advanceBadgeProgress('turn_back_20', 1);
    await _advanceBadgeProgress('reclaim_1h', reclaimedMins);
    await _advanceBadgeProgress('reclaim_5h', reclaimedMins);

    // Check night owl badge (if between 11 PM and 5 AM)
    final currentHour = DateTime.now().hour;
    if (currentHour >= 23 || currentHour < 5) {
      await _advanceBadgeProgress('night_owl_beaten', 1);
    }

    return levelUp;
  }

  Future<void> recordBypass({
    required String packageName,
    required int usedMins,
    required int limitMins,
    required String hookType,
  }) async {
    final db = await _db.database;
    await db.insert('hook_feedback', {
      'package_name': packageName,
      'hook_type': hookType,
      'action': 'bypass',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<LevelUpResult?> recordFocusCompletion(int durationMinutes) async {
    final levelUp = await addXp(30, 'focus_session', 'Completed $durationMinutes min Focus Session');
    await _advanceBadgeProgress('focus_novice', 1);
    await _advanceBadgeProgress('focus_master', 1);
    return levelUp;
  }

  Future<LevelUpResult?> recordBrainChallengeCompletion(int score) async {
    // Score-based XP scaling: 10 to 40 XP
    final xp = (10 + (score * 3)).clamp(10, 40);
    final levelUp = await addXp(xp, 'brain_challenge', 'Completed Brain Challenge (Score: $score)');
    await _advanceBadgeProgress('quiz_master', 1);
    return levelUp;
  }

  /// Calculates Daily Goal progress for the goal ring
  Future<Map<String, dynamic>> getDailyGoalProgress() async {
    final progress = await getUserProgress();
    final db = await _db.database;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    if (progress.dailyGoalType == 'turn_backs') {
      final rows = await db.rawQuery(
        "SELECT COUNT(*) as count FROM notifications_log WHERE type = 'turn_back' AND timestamp >= ?",
        [todayMidnight],
      );
      final current = (rows.first['count'] as num?)?.toInt() ?? 0;
      final target = progress.dailyGoalTarget;
      final percent = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
      return {
        'type': 'turn_backs',
        'current': current,
        'target': target,
        'percent': percent,
        'label': '$current / $target Turn-backs',
        'isAchieved': current >= target,
      };
    } else {
      // Distracting minutes goal (stay under target)
      final rows = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(ul.duration_seconds), 0) as total_sec
        FROM usage_logs ul
        INNER JOIN app_categories ac ON ul.package_name = ac.package_name
        WHERE ac.category = 'distracting' AND ul.start_time >= ?
        ''',
        [todayMidnight],
      );
      final currentMins = ((rows.first['total_sec'] as num?)?.toInt() ?? 0) ~/ 60;
      final targetMins = progress.dailyGoalTarget;
      final percent = targetMins > 0 ? (currentMins / targetMins).clamp(0.0, 1.0) : 0.0;
      return {
        'type': 'distracting_minutes',
        'current': currentMins,
        'target': targetMins,
        'percent': percent,
        'label': '${currentMins}m / ${targetMins}m Max Distraction',
        'isAchieved': currentMins <= targetMins,
      };
    }
  }

  Future<void> updateDailyGoal(String type, int target) async {
    final db = await _db.database;
    await db.update(
      'user_progress',
      {
        'daily_goal_type': type,
        'daily_goal_target': target,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// Evaluates and advances streaks and streak freezes
  Future<void> syncDailyStreak() async {
    final db = await _db.database;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final yesterdayMidnight = DateTime(now.year, now.month, now.day - 1).millisecondsSinceEpoch;

    // Check if limits were breached yesterday
    final yesterdayBypasses = await db.rawQuery(
      "SELECT COUNT(*) as count FROM notifications_log WHERE type = 'bypass' AND timestamp >= ? AND timestamp < ?",
      [yesterdayMidnight, todayMidnight],
    );
    final hadBypassYesterday = ((yesterdayBypasses.first['count'] as num?)?.toInt() ?? 0) > 0;

    final progress = await getUserProgress();

    if (!hadBypassYesterday) {
      // Under limit yesterday -> increment streak!
      final newStreak = progress.streakDays + 1;
      int newFreezes = progress.streakFreezes;

      // Every 7 days, earn a streak freeze
      if (newStreak % 7 == 0) {
        newFreezes++;
      }

      await db.update(
        'user_progress',
        {
          'streak_days': newStreak,
          'streak_freezes': newFreezes,
        },
        where: 'id = ?',
        whereArgs: [1],
      );

      await _advanceBadgeProgress('streak_3', newStreak);
      await _advanceBadgeProgress('streak_7', newStreak);
      if (newStreak >= 7) {
        await _advanceBadgeProgress('perfect_week', 7);
      }
    } else {
      // Bypassed yesterday: consume a freeze if available, else reset
      if (progress.streakFreezes > 0) {
        await db.update(
          'user_progress',
          {'streak_freezes': progress.streakFreezes - 1},
          where: 'id = ?',
          whereArgs: [1],
        );
      } else {
        await db.update(
          'user_progress',
          {'streak_days': 0},
          where: 'id = ?',
          whereArgs: [1],
        );
      }
    }
  }

  Future<List<BadgeItem>> getBadges() async {
    final db = await _db.database;
    final maps = await db.query('badges', orderBy: 'is_unlocked DESC, current_progress DESC');
    return maps.map((m) => BadgeItem.fromMap(m)).toList();
  }

  Future<void> _advanceBadgeProgress(String badgeId, int increment) async {
    final db = await _db.database;
    final rows = await db.query('badges', where: 'id = ?', whereArgs: [badgeId], limit: 1);
    if (rows.isEmpty) return;

    final badge = BadgeItem.fromMap(rows.first);
    if (badge.isUnlocked) return;

    final newProgress = badge.currentProgress + increment;
    final isNowUnlocked = newProgress >= badge.maxProgress;

    await db.update(
      'badges',
      {
        'current_progress': newProgress,
        'is_unlocked': isNowUnlocked ? 1 : 0,
        'unlocked_at': isNowUnlocked ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [badgeId],
    );
  }

  /// Weekly Recap Aggregator
  Future<WeeklyRecap> getWeeklyRecap() async {
    final db = await _db.database;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;

    // 1. Wins (Turn-backs + completed focus sessions)
    final turnBacksRow = await db.rawQuery(
      "SELECT COUNT(*) as count FROM notifications_log WHERE type = 'turn_back' AND timestamp >= ?",
      [sevenDaysAgo],
    );
    final focusRow = await db.rawQuery(
      'SELECT COUNT(*) as count FROM focus_sessions WHERE is_completed = 1 AND start_time >= ?',
      [sevenDaysAgo],
    );
    final totalWins = ((turnBacksRow.first['count'] as num?)?.toInt() ?? 0) +
        ((focusRow.first['count'] as num?)?.toInt() ?? 0);

    // 2. XP gained this week
    final xpRow = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total_xp FROM xp_transactions WHERE timestamp >= ?',
      [sevenDaysAgo],
    );
    final xpGained = (xpRow.first['total_xp'] as num?)?.toInt() ?? 0;

    // 3. Time reclaimed this week (sum of turn_back average savings)
    final turnBackCount = (turnBacksRow.first['count'] as num?)?.toInt() ?? 0;
    final timeReclaimedMins = turnBackCount * 15;

    // 4. Best day of week
    final bestDayRow = await db.rawQuery(
      '''
      SELECT strftime('%w', start_time / 1000, 'unixepoch', 'localtime') as day_of_week,
             SUM(duration_seconds) as total_sec
      FROM usage_logs
      WHERE start_time >= ?
      GROUP BY day_of_week
      ORDER BY total_sec ASC
      LIMIT 1
      ''',
      [sevenDaysAgo],
    );
    final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    String bestDayName = 'Friday';
    if (bestDayRow.isNotEmpty) {
      final dowIndex = int.tryParse(bestDayRow.first['day_of_week']?.toString() ?? '5') ?? 5;
      bestDayName = dayNames[dowIndex % 7];
    }

    // 5. Smart Algorithmic Tip
    String smartTip = 'Keep your phone face-down during focus intervals to boost your win rate.';
    if (totalWins >= 5) {
      smartTip = 'Outstanding momentum! You resisted $totalWins distraction traps this week. Consistency is becoming your superpower.';
    } else if (turnBackCount == 0) {
      smartTip = 'Tip: When the overlay appears, pause for 3 deep breaths before deciding. Pausing cuts impulses by 60%.';
    }

    return WeeklyRecap(
      winsCount: totalWins,
      xpGained: xpGained,
      timeReclaimedMinutes: timeReclaimedMins,
      bestDayName: bestDayName,
      smartTip: smartTip,
    );
  }

  /// Decision Tree Hook Optimization:
  /// Evaluates which hook frame yields the highest turn-back win rate for this user/app.
  Future<String> getBestHookForApp(String packageName) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT hook_type,
             SUM(CASE WHEN action = 'turn_back' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) as win_rate
      FROM hook_feedback
      WHERE package_name = ?
      GROUP BY hook_type
      HAVING COUNT(*) >= 2
      ORDER BY win_rate DESC
      LIMIT 1
      ''',
      [packageName],
    );

    if (rows.isNotEmpty) {
      return rows.first['hook_type'] as String;
    }

    // Default fallback order
    const defaultHooks = ['loss', 'future_self', 'streak', 'goal', 'social_proof'];
    return defaultHooks[_random.nextInt(defaultHooks.length)];
  }
}
