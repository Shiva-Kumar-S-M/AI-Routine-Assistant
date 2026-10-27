class FocusSession {
  final int? id;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final bool isCompleted;

  FocusSession({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.isCompleted = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'duration_minutes': durationMinutes,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory FocusSession.fromMap(Map<String, dynamic> map) {
    return FocusSession(
      id: map['id'] as int?,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
      durationMinutes: map['duration_minutes'] as int,
      isCompleted: (map['is_completed'] as int) == 1,
    );
  }
}
