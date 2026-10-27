class UsageLog {
  final int? id;
  final String packageName;
  final String appName;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final String category;

  UsageLog({
    this.id,
    required this.packageName,
    required this.appName,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    this.category = 'neutral',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'package_name': packageName,
      'app_name': appName,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'duration_seconds': durationSeconds,
    };
  }

  factory UsageLog.fromMap(Map<String, dynamic> map, {String category = 'neutral'}) {
    final pkg = map['package_name'] as String;
    // Defensive fallback: older DB rows may have NULL or empty app_name.
    final rawAppName = map['app_name'] as String?;
    final resolvedAppName =
        (rawAppName != null && rawAppName.isNotEmpty) ? rawAppName : pkg;
    return UsageLog(
      id: map['id'] as int?,
      packageName: pkg,
      appName: resolvedAppName,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
      durationSeconds: map['duration_seconds'] as int,
      category: category,
    );
  }
}
