import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'seed_data.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ai_routine_assistant.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. usage_logs table
    await db.execute('''
      CREATE TABLE usage_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL
      )
    ''');

    // UNIQUE index on usage_logs(package_name, start_time) — prevents duplicate inserts on reload
    await db.execute('''
      CREATE UNIQUE INDEX idx_usage_unique ON usage_logs (package_name, start_time)
    ''');

    // 2. app_categories table
    await db.execute('''
      CREATE TABLE app_categories (
        package_name TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        is_custom INTEGER DEFAULT 0
      )
    ''');

    // 3. routines table
    await db.execute('''
      CREATE TABLE routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        time_of_day_minute INTEGER NOT NULL,
        confidence_score REAL NOT NULL,
        detected_at INTEGER NOT NULL
      )
    ''');

    // 4. notifications_log table
    await db.execute('''
      CREATE TABLE notifications_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        package_name TEXT NOT NULL,
        message TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        trigger_conditions TEXT,
        rewarded INTEGER DEFAULT 0
      )
    ''');

    // 5. preferences table
    await db.execute('''
      CREATE TABLE preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 6. focus_sessions table
    await db.execute('''
      CREATE TABLE focus_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        duration_minutes INTEGER NOT NULL,
        is_completed INTEGER NOT NULL
      )
    ''');

    // 7. emotional_logs table
    await db.execute('''
      CREATE TABLE emotional_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usage_log_id INTEGER,
        package_name TEXT NOT NULL,
        trigger_emotion TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // Seed default app categories
    final batch = db.batch();
    defaultAppCategories.forEach((pkg, cat) {
      batch.insert(
        'app_categories',
        {
          'package_name': pkg,
          'category': cat,
          'is_custom': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit();

    // Stage 2: Dopamine / Journey Tables
    await _createJourneyTables(db);

    // Stage 3: Brain Gym Tables
    await _createBrainGymTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createJourneyTables(db);

      // Add rewarded column to notifications_log if it doesn't exist
      try {
        await db.execute('ALTER TABLE notifications_log ADD COLUMN rewarded INTEGER DEFAULT 0');
      } catch (_) {
        // Column may already exist
      }
    }
    if (oldVersion < 3) {
      await _createBrainGymTables(db);
    }
  }

  Future<void> _createJourneyTables(Database db) async {
    // 8. user_progress table (singleton row id=1)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_progress (
        id INTEGER PRIMARY KEY,
        xp INTEGER DEFAULT 0,
        level INTEGER DEFAULT 1,
        streak_days INTEGER DEFAULT 0,
        streak_freezes INTEGER DEFAULT 0,
        time_reclaimed_seconds INTEGER DEFAULT 0,
        daily_goal_type TEXT DEFAULT 'turn_backs',
        daily_goal_target INTEGER DEFAULT 3
      )
    ''');

    await db.execute('''
      INSERT OR IGNORE INTO user_progress (
        id, xp, level, streak_days, streak_freezes, time_reclaimed_seconds, daily_goal_type, daily_goal_target
      ) VALUES (1, 0, 1, 0, 0, 0, 'turn_backs', 3)
    ''');

    // 9. badges table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS badges (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        icon_name TEXT NOT NULL,
        category TEXT NOT NULL,
        max_progress INTEGER NOT NULL,
        current_progress INTEGER DEFAULT 0,
        is_unlocked INTEGER DEFAULT 0,
        unlocked_at INTEGER
      )
    ''');

    // 10. xp_transactions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS xp_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        source TEXT NOT NULL,
        description TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 11. hook_feedback table (Decision Tree hook optimization)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hook_feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        hook_type TEXT NOT NULL,
        action TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // Seed default 12 badges
    final badgeBatch = db.batch();
    for (final b in _defaultBadges) {
      badgeBatch.insert(
        'badges',
        b,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await badgeBatch.commit(noResult: true);
  }

  Future<void> _createBrainGymTables(Database db) async {
    // 12. brain_gym_scores table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS brain_gym_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_mode TEXT NOT NULL,
        score INTEGER NOT NULL,
        accuracy_percent REAL NOT NULL,
        total_questions INTEGER NOT NULL,
        correct_answers INTEGER NOT NULL,
        max_combo INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        is_daily_challenge INTEGER DEFAULT 0
      )
    ''');

    // 13. brain_gym_profile table (singleton row id=1)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS brain_gym_profile (
        id INTEGER PRIMARY KEY,
        skill_rating INTEGER DEFAULT 1000,
        daily_challenge_completed_date TEXT,
        sound_enabled INTEGER DEFAULT 1,
        haptics_enabled INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      INSERT OR IGNORE INTO brain_gym_profile (
        id, skill_rating, daily_challenge_completed_date, sound_enabled, haptics_enabled
      ) VALUES (1, 1000, NULL, 1, 1)
    ''');
  }

  static const List<Map<String, dynamic>> _defaultBadges = [
    {
      'id': 'first_turn_back',
      'title': 'First Turn-Back',
      'description': 'Resisted the impulse and turned back from an overlay',
      'icon_name': 'shield',
      'category': 'willpower',
      'max_progress': 1,
      'current_progress': 0,
      'is_unlocked': 0,
    },
    {
      'id': 'turn_back_5',
      'title': 'Focus Defender',
      'description': 'Turned back from distraction 5 times',
      'icon_name': 'shield_check',
      'category': 'willpower',
      'max_progress': 5,
      'current_progress': 0,
      'is_unlocked': 0,
    },
    {
      'id': 'turn_back_20',
      'title': 'Attention Guardian',
      'description': 'Turned back from distraction 20 times',
      'icon_name': 'verified_user',
      'category': 'willpower',
      'max_progress': 20,
      'current_progress': 0,
      'is_unlocked': 0,
    },
    {
      'id': 'streak_3',
      'title': 'Momentum Starter',
      'description': 'Stayed under daily limits for 3 days in a row',
      'icon_name': 'local_fire_department',
      'category': 'streak',
      'max_progress': 3,
      'current_progress': 0,
      'is_unlocked': 0,
    },
    {
      'id': 'streak_7',
      'title': 'Week of Willpower',
      'description': '7-day streak under limits. Earned a Streak Freeze!',
      'icon_name': 'bolt',
      'category': 'streak',
      'max_progress': 7,
      'current_progress': 0,
      'is_unlocked': 0,
    },
    {
      'id': 'perfect_week',
      'title': 'Perfect Week',
      'description': '7 full days without a single limit bypass',
      'icon_name': 'military_tech',
      'category': 'streak',
      'max_progress': 7,
      'current_progress': 0,
      'is_unlocked': 0,
    },
    {
      'id': 'night_owl_beaten',
      'title': 'Night Owl Beaten',
      'description': 'Resisted late-night scrolling past 11:00 PM',
      'icon_name': 'bedtime',
      'category': 'willpower',
      'max_progress': 1,
      'current_progress': 0,
      'is_unlocked': 0,
    },
    {
      'id': 'focus_novice',
      'title': 'Focus Novice',
      'description': 'Completed your first 25m Pomodoro focus session',
      'icon_name': 'timer',
      'category': 'focus',
      'max_progress': 1,
      'current_progress': 0,
      'is_unlocked': 0,
    },
    {
      'id': 'focus_master',
      'title': 'Deep Work Dynamo',
      'description': 'Completed 10 deep focus sessions',
      'icon_name': 'all_inclusive',
      'category': 'focus',
      'max_progress': 10,
      'current_progress': 0,
      'is_unlocked': 0,
    },
    {
      'id': 'reclaim_1h',
      'title': 'Hour Reclaimed',
      'description': 'Saved 60 total minutes by turning back from scrolling',
      'icon_name': 'hourglass_bottom',
      'category': 'time',
      'max_progress': 60,
      'current_progress': 0,
      'is_unlocked': 0,
    },
    {
      'id': 'reclaim_5h',
      'title': 'Time Billionaire',
      'description': 'Reclaimed 300 minutes (5 full hours) of your life',
      'icon_name': 'savings',
      'category': 'time',
      'max_progress': 300,
      'current_progress': 0,
      'is_unlocked': 0,
    },
    {
      'id': 'quiz_master',
      'title': 'Mental Athlete',
      'description': 'Completed your first fast-paced Brain Challenge',
      'icon_name': 'psychology',
      'category': 'focus',
      'max_progress': 1,
      'current_progress': 0,
      'is_unlocked': 0,
    },
  ];

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
