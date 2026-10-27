import 'dart:convert';

enum AlertType {
  distractionAlert,
  routineReminder,
}

class RoutineAlert {
  final int? id;
  final AlertType type;
  final String packageName;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? triggerConditions;

  RoutineAlert({
    this.id,
    required this.type,
    required this.packageName,
    required this.message,
    required this.timestamp,
    this.triggerConditions,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type == AlertType.distractionAlert ? 'distraction_alert' : 'routine_reminder',
      'package_name': packageName,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      if (triggerConditions != null) 'trigger_conditions': jsonEncode(triggerConditions),
    };
  }

  factory RoutineAlert.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? conditions;
    if (map['trigger_conditions'] != null) {
      try {
        if (map['trigger_conditions'] is String) {
          conditions = Map<String, dynamic>.from(jsonDecode(map['trigger_conditions'] as String));
        } else if (map['trigger_conditions'] is Map) {
          conditions = Map<String, dynamic>.from(map['trigger_conditions'] as Map);
        }
      } catch (_) {}
    }

    return RoutineAlert(
      id: map['id'] as int?,
      type: map['type'] == 'distraction_alert'
          ? AlertType.distractionAlert
          : AlertType.routineReminder,
      packageName: map['package_name'] as String,
      message: map['message'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      triggerConditions: conditions,
    );
  }
}

