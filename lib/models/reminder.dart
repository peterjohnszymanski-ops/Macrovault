/// A local reminder preference. Phase 1 stores preferences; OS-level
/// scheduling is wired in services/reminder_service.dart.
enum ReminderType {
  weighIn('weigh_in', 'Weigh-in'),
  logMeals('log_meals', 'Log meals'),
  weeklyReview('weekly_review', 'Weekly review');

  const ReminderType(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static ReminderType fromStorage(String v) =>
      ReminderType.values.firstWhere((e) => e.storageValue == v,
          orElse: () => ReminderType.logMeals);
}

class Reminder {
  const Reminder({
    required this.id,
    required this.userId,
    required this.type,
    required this.hour,
    required this.minute,
    required this.enabled,
    this.quietStartHour = 22,
    this.quietEndHour = 7,
  });

  final String id;
  final String userId;
  final ReminderType type;
  final int hour;
  final int minute;
  final bool enabled;
  final int quietStartHour;
  final int quietEndHour;

  Reminder copyWith({int? hour, int? minute, bool? enabled}) => Reminder(
        id: id,
        userId: userId,
        type: type,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        enabled: enabled ?? this.enabled,
        quietStartHour: quietStartHour,
        quietEndHour: quietEndHour,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'type': type.storageValue,
        'hour': hour,
        'minute': minute,
        'enabled': enabled ? 1 : 0,
        'quiet_start_hour': quietStartHour,
        'quiet_end_hour': quietEndHour,
      };

  factory Reminder.fromMap(Map<String, Object?> m) => Reminder(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        type: ReminderType.fromStorage(m['type'] as String),
        hour: (m['hour'] as int?) ?? 9,
        minute: (m['minute'] as int?) ?? 0,
        enabled: (m['enabled'] as int? ?? 0) == 1,
        quietStartHour: (m['quiet_start_hour'] as int?) ?? 22,
        quietEndHour: (m['quiet_end_hour'] as int?) ?? 7,
      );
}
