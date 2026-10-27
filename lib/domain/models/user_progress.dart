class UserProgress {
  final int xp;
  final int level;
  final int streakDays;
  final int streakFreezes;
  final int timeReclaimedSeconds;
  final String dailyGoalType; // 'turn_backs' or 'distracting_minutes'
  final int dailyGoalTarget;

  const UserProgress({
    required this.xp,
    required this.level,
    required this.streakDays,
    required this.streakFreezes,
    required this.timeReclaimedSeconds,
    this.dailyGoalType = 'turn_backs',
    this.dailyGoalTarget = 3,
  });

  static const List<int> levelThresholds = [
    0,     // Level 1: Distracted Dabbler
    100,   // Level 2: Focus Apprentice
    250,   // Level 3: Attention Guardian
    500,   // Level 4: Habit Sculptor
    850,   // Level 5: Flow State Seeker
    1300,  // Level 6: Discipline Adept
    1900,  // Level 7: Dopamine Resetter
    2600,  // Level 8: Mind Master
  ];

  static const List<String> levelTitles = [
    'Distracted Dabbler',
    'Focus Apprentice',
    'Attention Guardian',
    'Habit Sculptor',
    'Flow State Seeker',
    'Discipline Adept',
    'Dopamine Resetter',
    'Mind Master',
  ];

  String get levelTitle {
    final idx = (level - 1).clamp(0, levelTitles.length - 1);
    return levelTitles[idx];
  }

  int get xpForCurrentLevel {
    final idx = (level - 1).clamp(0, levelThresholds.length - 1);
    return levelThresholds[idx];
  }

  int get xpForNextLevel {
    if (level >= levelThresholds.length) {
      return levelThresholds.last + (level - levelThresholds.length + 1) * 1000;
    }
    return levelThresholds[level];
  }

  double get levelProgress {
    final currentBase = xpForCurrentLevel;
    final nextTarget = xpForNextLevel;
    if (nextTarget <= currentBase) return 1.0;
    final progress = (xp - currentBase) / (nextTarget - currentBase);
    return progress.clamp(0.0, 1.0);
  }

  int get xpRemainingToNext {
    final nextTarget = xpForNextLevel;
    return (nextTarget - xp).clamp(0, nextTarget);
  }

  String get formattedTimeReclaimed {
    final mins = timeReclaimedSeconds ~/ 60;
    if (mins < 60) {
      return '${mins}m';
    }
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    return '${hours}h ${remMins}m';
  }

  static int calculateLevelForXp(int xp) {
    for (int i = levelThresholds.length - 1; i >= 0; i--) {
      if (xp >= levelThresholds[i]) {
        return i + 1;
      }
    }
    return 1;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'xp': xp,
      'level': level,
      'streak_days': streakDays,
      'streak_freezes': streakFreezes,
      'time_reclaimed_seconds': timeReclaimedSeconds,
      'daily_goal_type': dailyGoalType,
      'daily_goal_target': dailyGoalTarget,
    };
  }

  factory UserProgress.fromMap(Map<String, dynamic> map) {
    return UserProgress(
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      level: (map['level'] as num?)?.toInt() ?? 1,
      streakDays: (map['streak_days'] as num?)?.toInt() ?? 0,
      streakFreezes: (map['streak_freezes'] as num?)?.toInt() ?? 0,
      timeReclaimedSeconds: (map['time_reclaimed_seconds'] as num?)?.toInt() ?? 0,
      dailyGoalType: map['daily_goal_type'] as String? ?? 'turn_backs',
      dailyGoalTarget: (map['daily_goal_target'] as num?)?.toInt() ?? 3,
    );
  }

  UserProgress copyWith({
    int? xp,
    int? level,
    int? streakDays,
    int? streakFreezes,
    int? timeReclaimedSeconds,
    String? dailyGoalType,
    int? dailyGoalTarget,
  }) {
    return UserProgress(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      streakDays: streakDays ?? this.streakDays,
      streakFreezes: streakFreezes ?? this.streakFreezes,
      timeReclaimedSeconds: timeReclaimedSeconds ?? this.timeReclaimedSeconds,
      dailyGoalType: dailyGoalType ?? this.dailyGoalType,
      dailyGoalTarget: dailyGoalTarget ?? this.dailyGoalTarget,
    );
  }
}
