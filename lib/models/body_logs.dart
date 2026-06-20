/// Body-measurement, water, and exercise log models.

class MeasurementEntry {
  const MeasurementEntry({
    required this.id,
    required this.userId,
    required this.day,
    required this.site, // 'waist', 'hips', 'chest', 'arm_l', custom...
    required this.valueCm,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String day;
  final String site;
  final double valueCm;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'day': day,
        'site': site,
        'value_cm': valueCm,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory MeasurementEntry.fromMap(Map<String, Object?> m) => MeasurementEntry(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        day: m['day'] as String,
        site: m['site'] as String,
        valueCm: (m['value_cm'] as num).toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['created_at'] as int?) ?? 0),
      );
}

/// Default measurement sites offered in the UI.
const List<String> kDefaultMeasurementSites = [
  'waist',
  'hips',
  'chest',
  'arm_l',
  'arm_r',
  'thigh_l',
  'thigh_r',
  'neck',
];

class WaterLog {
  const WaterLog({
    required this.id,
    required this.userId,
    required this.day,
    required this.ml,
  });

  final String id;
  final String userId;
  final String day;
  final int ml;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'day': day,
        'ml': ml,
      };

  factory WaterLog.fromMap(Map<String, Object?> m) => WaterLog(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        day: m['day'] as String,
        ml: (m['ml'] as int?) ?? 0,
      );
}

class ExerciseLog {
  const ExerciseLog({
    required this.id,
    required this.userId,
    required this.day,
    required this.type,
    required this.durationMin,
    required this.note,
    this.countsTowardBudget = false, // never credit calories by default
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String day;
  final String type;
  final int durationMin;
  final String note;
  final bool countsTowardBudget;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'day': day,
        'type': type,
        'duration_min': durationMin,
        'note': note,
        'counts_toward_budget': countsTowardBudget ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ExerciseLog.fromMap(Map<String, Object?> m) => ExerciseLog(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        day: m['day'] as String,
        type: m['type'] as String? ?? 'workout',
        durationMin: (m['duration_min'] as int?) ?? 0,
        note: m['note'] as String? ?? '',
        countsTowardBudget: (m['counts_toward_budget'] as int? ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['created_at'] as int?) ?? 0),
      );
}
