import 'dart:math';
import '../database/app_database.dart';
import '../../domain/models/brain_gym_models.dart';
import 'progress_repository.dart';

class BrainGymResultSummary {
  final int score;
  final double accuracyPercent;
  final int correctAnswers;
  final int totalQuestions;
  final int maxCombo;
  final int xpAwarded;
  final int oldRating;
  final int newRating;
  final bool isNewPersonalBest;
  final LevelUpResult? levelUpResult;

  const BrainGymResultSummary({
    required this.score,
    required this.accuracyPercent,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.maxCombo,
    required this.xpAwarded,
    required this.oldRating,
    required this.newRating,
    required this.isNewPersonalBest,
    this.levelUpResult,
  });

  int get ratingDelta => newRating - oldRating;
}

class BrainGymRepository {
  final AppDatabase _db = AppDatabase.instance;
  final ProgressRepository _progressRepo = ProgressRepository();

  Future<BrainGymProfile> getProfile() async {
    final db = await _db.database;
    final rows = await db.query('brain_gym_profile', where: 'id = ?', whereArgs: [1], limit: 1);
    
    // Total games played count
    final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM brain_gym_scores');
    final gamesPlayed = (countRes.first['cnt'] as num?)?.toInt() ?? 0;

    // Daily play streak calculation
    final datesRes = await db.rawQuery('''
      SELECT DISTINCT DATE(timestamp / 1000, 'unixepoch', 'localtime') as play_date
      FROM brain_gym_scores
      ORDER BY play_date DESC
    ''');
    int streak = 0;
    if (datesRes.isNotEmpty) {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yestStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final firstDate = datesRes.first['play_date'] as String?;
      if (firstDate == todayStr || firstDate == yestStr) {
        streak = datesRes.length;
      }
    }

    if (rows.isEmpty) {
      return BrainGymProfile(gamesPlayed: gamesPlayed, streakDays: streak);
    }
    return BrainGymProfile.fromMap(rows.first, gamesPlayed: gamesPlayed, streakDays: streak);
  }

  Future<List<BrainGymScore>> getHighScores({int limit = 10}) async {
    return getLeaderboard(limit: limit);
  }

  Future<void> updateSound(bool enabled) async {
    final db = await _db.database;
    await db.update(
      'brain_gym_profile',
      {'sound_enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<void> updateHaptics(bool enabled) async {
    final db = await _db.database;
    await db.update(
      'brain_gym_profile',
      {'haptics_enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<BrainGymResultSummary> recordGameResult({
    required BrainGymGameMode mode,
    required int score,
    required int correctAnswers,
    required int totalQuestions,
    required int maxCombo,
    bool isDailyChallenge = false,
  }) async {
    final db = await _db.database;
    final accuracy = totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100.0 : 0.0;

    // Check previous personal best
    final pbRows = await db.query(
      'brain_gym_scores',
      columns: ['MAX(score) as max_score'],
      where: 'game_mode = ?',
      whereArgs: [mode.id],
    );
    final prevPb = (pbRows.first['max_score'] as num?)?.toInt() ?? 0;
    final isPb = score > prevPb;

    // Insert score record
    final scoreRecord = BrainGymScore(
      gameMode: mode.id,
      score: score,
      accuracyPercent: accuracy,
      totalQuestions: totalQuestions,
      correctAnswers: correctAnswers,
      maxCombo: maxCombo,
      timestamp: DateTime.now(),
      isDailyChallenge: isDailyChallenge,
    );
    await db.insert('brain_gym_scores', scoreRecord.toMap());

    // Update ELO Skill Rating
    final profile = await getProfile();
    final oldRating = profile.skillRating;

    // ELO Delta: Based on accuracy, combo, and baseline threshold
    int delta = 0;
    if (accuracy >= 80.0) {
      delta = (score / 15).clamp(5, 32).toInt() + (maxCombo >= 5 ? 5 : 0);
    } else if (accuracy >= 50.0) {
      delta = (score / 30).clamp(1, 15).toInt();
    } else {
      delta = -((100 - accuracy) / 10).clamp(4, 20).toInt();
    }

    final newRating = max(600, oldRating + delta);

    String? dailyDate;
    if (isDailyChallenge) {
      final now = DateTime.now();
      dailyDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    await db.update(
      'brain_gym_profile',
      {
        'skill_rating': newRating,
        if (dailyDate != null) 'daily_challenge_completed_date': dailyDate,
      },
      where: 'id = ?',
      whereArgs: [1],
    );

    // Award XP to Stage 2 Journey System (+10 to +40 XP based on score)
    final levelUp = await _progressRepo.recordBrainChallengeCompletion(score);
    final xpAwarded = (10 + (score * 3)).clamp(10, 40);

    return BrainGymResultSummary(
      score: score,
      accuracyPercent: accuracy,
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
      maxCombo: maxCombo,
      xpAwarded: xpAwarded,
      oldRating: oldRating,
      newRating: newRating,
      isNewPersonalBest: isPb,
      levelUpResult: levelUp,
    );
  }

  Future<Map<String, int>> getPersonalBests() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT game_mode, MAX(score) as best_score
      FROM brain_gym_scores
      GROUP BY game_mode
    ''');

    final map = <String, int>{};
    for (final r in rows) {
      final mode = r['game_mode'] as String?;
      final best = (r['best_score'] as num?)?.toInt() ?? 0;
      if (mode != null) {
        map[mode] = best;
      }
    }
    return map;
  }

  Future<List<BrainGymScore>> getLeaderboard({String? modeId, int limit = 10}) async {
    final db = await _db.database;
    final rows = await db.query(
      'brain_gym_scores',
      where: modeId != null ? 'game_mode = ?' : null,
      whereArgs: modeId != null ? [modeId] : null,
      orderBy: 'score DESC, accuracy_percent DESC',
      limit: limit,
    );
    return rows.map((e) => BrainGymScore.fromMap(e)).toList();
  }
}
