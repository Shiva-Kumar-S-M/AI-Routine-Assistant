import '../database/app_database.dart';
import '../../domain/models/focus_session.dart';
import '../../domain/repositories/focus_repository_interface.dart';

class FocusRepository implements FocusRepositoryInterface {
  final AppDatabase _dbProvider = AppDatabase.instance;

  @override
  Future<int> insertFocusSession(FocusSession session) async {
    final db = await _dbProvider.database;
    return await db.insert('focus_sessions', session.toMap());
  }

  @override
  Future<List<FocusSession>> getRecentSessions({int limit = 10}) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      'focus_sessions',
      orderBy: 'start_time DESC',
      limit: limit,
    );
    return maps.map((map) => FocusSession.fromMap(map)).toList();
  }

  @override
  Future<List<FocusSession>> getSessionsInWindow(
      DateTime start, DateTime end) async {
    final db = await _dbProvider.database;
    final maps = await db.query(
      'focus_sessions',
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'start_time DESC',
    );
    return maps.map((map) => FocusSession.fromMap(map)).toList();
  }

  @override
  Future<int> getTodayCompletedMinutes() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final sessions = await getSessionsInWindow(startOfDay, endOfDay);
    int total = 0;
    for (final s in sessions) {
      if (s.isCompleted) total += s.durationMinutes;
    }
    return total;
  }
}

