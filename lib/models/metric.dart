/// A tracked progress metric (a max lift, estimated body fat, a custom measure)
/// and its time-series points. Weight has its own table; everything else lives
/// here so the Progress screen can overlay them on one timeline.

class MetricDef {
  const MetricDef({
    required this.key,
    required this.name,
    required this.unit,
    required this.higherIsBetter,
    this.builtin = false,
  });

  final String key;
  final String name;
  final String unit; // 'kg', 'lb', '%', 'reps', ...
  final bool higherIsBetter;
  final bool builtin;

  Map<String, Object?> toMap() => {
        'key': key,
        'name': name,
        'unit': unit,
        'higher_is_better': higherIsBetter ? 1 : 0,
        'builtin': builtin ? 1 : 0,
      };

  factory MetricDef.fromMap(Map<String, Object?> m) => MetricDef(
        key: m['key'] as String,
        name: m['name'] as String,
        unit: m['unit'] as String? ?? '',
        higherIsBetter: (m['higher_is_better'] as int? ?? 1) == 1,
        builtin: (m['builtin'] as int? ?? 0) == 1,
      );
}

class MetricEntry {
  const MetricEntry({
    required this.id,
    required this.userId,
    required this.metricKey,
    required this.day,
    required this.value,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String metricKey;
  final String day;
  final double value;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'metric_key': metricKey,
        'day': day,
        'value': value,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory MetricEntry.fromMap(Map<String, Object?> m) => MetricEntry(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        metricKey: m['metric_key'] as String,
        day: m['day'] as String,
        value: (m['value'] as num).toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['created_at'] as int?) ?? 0),
      );
}

/// Built-in metrics offered out of the box. The 'weight' series is special —
/// it's sourced from the weight-trend table, not metric_entries.
const String kWeightMetricKey = 'weight';

const List<MetricDef> kBuiltinMetrics = [
  MetricDef(
      key: 'bench',
      name: 'Bench press 1RM',
      unit: 'kg',
      higherIsBetter: true,
      builtin: true),
  MetricDef(
      key: 'squat',
      name: 'Squat 1RM',
      unit: 'kg',
      higherIsBetter: true,
      builtin: true),
  MetricDef(
      key: 'deadlift',
      name: 'Deadlift 1RM',
      unit: 'kg',
      higherIsBetter: true,
      builtin: true),
  MetricDef(
      key: 'bodyfat',
      name: 'Body fat',
      unit: '%',
      higherIsBetter: false,
      builtin: true),
];
