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
      version: 1,
      onCreate: _createDB,
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
        trigger_conditions TEXT
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

    // 7. emotional_logs table (Post-session emotional trigger log)
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
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
