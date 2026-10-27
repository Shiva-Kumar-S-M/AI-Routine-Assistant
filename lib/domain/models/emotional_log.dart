class EmotionalLog {
  final int? id;
  final int? usageLogId;
  final String packageName;
  final String triggerEmotion; // 'bored', 'anxious', 'habit', 'needed_it'
  final DateTime timestamp;

  EmotionalLog({
    this.id,
    this.usageLogId,
    required this.packageName,
    required this.triggerEmotion,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (usageLogId != null) 'usage_log_id': usageLogId,
      'package_name': packageName,
      'trigger_emotion': triggerEmotion,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory EmotionalLog.fromMap(Map<String, dynamic> map) {
    return EmotionalLog(
      id: map['id'] as int?,
      usageLogId: map['usage_log_id'] as int?,
      packageName: map['package_name'] as String,
      triggerEmotion: map['trigger_emotion'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}
