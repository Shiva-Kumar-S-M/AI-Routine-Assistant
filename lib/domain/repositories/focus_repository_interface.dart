import '../models/focus_session.dart';

abstract class FocusRepositoryInterface {
  Future<int> insertFocusSession(FocusSession session);
  Future<List<FocusSession>> getRecentSessions({int limit = 10});
  Future<List<FocusSession>> getSessionsInWindow(DateTime start, DateTime end);
  Future<int> getTodayCompletedMinutes();
}
