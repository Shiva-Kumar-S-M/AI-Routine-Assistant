enum BrainGymGameMode {
  mathSprint,
  numberSequence,
  logicGrid,
  memoryFlash;

  String get id {
    switch (this) {
      case BrainGymGameMode.mathSprint:
        return 'math_sprint';
      case BrainGymGameMode.numberSequence:
        return 'number_sequence';
      case BrainGymGameMode.logicGrid:
        return 'logic_grid';
      case BrainGymGameMode.memoryFlash:
        return 'memory_flash';
    }
  }

  String get title {
    switch (this) {
      case BrainGymGameMode.mathSprint:
        return 'Math Sprint';
      case BrainGymGameMode.numberSequence:
        return 'Number Sequence';
      case BrainGymGameMode.logicGrid:
        return 'Logic Matrix';
      case BrainGymGameMode.memoryFlash:
        return 'Memory Flash';
    }
  }

  String get subtitle {
    switch (this) {
      case BrainGymGameMode.mathSprint:
        return '60s mental arithmetic with combo multipliers';
      case BrainGymGameMode.numberSequence:
        return 'Deduce the missing step in mathematical patterns';
      case BrainGymGameMode.logicGrid:
        return 'Spot patterns, odd ones out & symbolic analogies';
      case BrainGymGameMode.memoryFlash:
        return 'Memorize and repeat escalating spatial sequences';
    }
  }
}

class BrainQuestion {
  final String prompt;
  final String answer;
  final List<String> options;
  final String? hint;
  final int difficulty;

  const BrainQuestion({
    required this.prompt,
    required this.answer,
    this.options = const [],
    this.hint,
    this.difficulty = 1,
  });
}

class BrainGymScore {
  final int? id;
  final String gameMode;
  final int score;
  final double accuracyPercent;
  final int totalQuestions;
  final int correctAnswers;
  final int maxCombo;
  final DateTime timestamp;
  final bool isDailyChallenge;

  const BrainGymScore({
    this.id,
    required this.gameMode,
    required this.score,
    required this.accuracyPercent,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.maxCombo,
    required this.timestamp,
    this.isDailyChallenge = false,
  });

  String get modeDisplayName {
    switch (gameMode) {
      case 'math_sprint':
        return 'Math Sprint';
      case 'number_sequence':
        return 'Number Sequence';
      case 'logic_grid':
        return 'Logic Grid';
      case 'memory_flash':
        return 'Memory Flash';
      default:
        return gameMode;
    }
  }

  double get accuracy => accuracyPercent;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'game_mode': gameMode,
      'score': score,
      'accuracy_percent': accuracyPercent,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'max_combo': maxCombo,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'is_daily_challenge': isDailyChallenge ? 1 : 0,
    };
  }

  factory BrainGymScore.fromMap(Map<String, dynamic> map) {
    return BrainGymScore(
      id: map['id'] as int?,
      gameMode: map['game_mode'] as String,
      score: (map['score'] as num).toInt(),
      accuracyPercent: (map['accuracy_percent'] as num).toDouble(),
      totalQuestions: (map['total_questions'] as num).toInt(),
      correctAnswers: (map['correct_answers'] as num).toInt(),
      maxCombo: (map['max_combo'] as num).toInt(),
      timestamp: DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as num).toInt()),
      isDailyChallenge: (map['is_daily_challenge'] as num?)?.toInt() == 1,
    );
  }
}

class BrainGymProfile {
  final int skillRating;
  final String? dailyChallengeCompletedDate;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final int gamesPlayed;
  final int streakDays;

  const BrainGymProfile({
    this.skillRating = 1000,
    this.dailyChallengeCompletedDate,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.gamesPlayed = 0,
    this.streakDays = 0,
  });

  factory BrainGymProfile.initial() => const BrainGymProfile();

  String get skillTier {
    if (skillRating < 1050) return 'Novice Mind';
    if (skillRating < 1180) return 'Agile Thinker';
    if (skillRating < 1350) return 'Sharp Analyst';
    if (skillRating < 1550) return 'Master Strategist';
    return 'Grandmaster Intellect';
  }

  bool get isDailyChallengeCompletedToday {
    if (dailyChallengeCompletedDate == null) return false;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return dailyChallengeCompletedDate == todayStr;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'skill_rating': skillRating,
      'daily_challenge_completed_date': dailyChallengeCompletedDate,
      'sound_enabled': soundEnabled ? 1 : 0,
      'haptics_enabled': hapticsEnabled ? 1 : 0,
    };
  }

  factory BrainGymProfile.fromMap(Map<String, dynamic> map, {int gamesPlayed = 0, int streakDays = 0}) {
    return BrainGymProfile(
      skillRating: (map['skill_rating'] as num?)?.toInt() ?? 1000,
      dailyChallengeCompletedDate: map['daily_challenge_completed_date'] as String?,
      soundEnabled: (map['sound_enabled'] as num?)?.toInt() == 1,
      hapticsEnabled: (map['haptics_enabled'] as num?)?.toInt() == 1,
      gamesPlayed: gamesPlayed,
      streakDays: streakDays,
    );
  }

  BrainGymProfile copyWith({
    int? skillRating,
    String? dailyChallengeCompletedDate,
    bool? soundEnabled,
    bool? hapticsEnabled,
    int? gamesPlayed,
    int? streakDays,
  }) {
    return BrainGymProfile(
      skillRating: skillRating ?? this.skillRating,
      dailyChallengeCompletedDate: dailyChallengeCompletedDate ?? this.dailyChallengeCompletedDate,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      streakDays: streakDays ?? this.streakDays,
    );
  }
}
