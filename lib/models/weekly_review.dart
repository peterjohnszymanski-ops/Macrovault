import 'dart:convert';

/// The auto-filled metrics computed for a review week. Kept as a typed object
/// but also serialised to JSON inside the WeeklyReview row.
class WeeklyMetrics {
  const WeeklyMetrics({
    required this.avgKcal,
    required this.avgProtein,
    required this.calorieAdherence, // 0..1, proximity to calorie target
    required this.proteinAdherence, // 0..1, days hitting >=90% protein / days
    required this.daysLogged,
    required this.weekdayAvgKcal,
    required this.weekendAvgKcal,
    required this.trendDeltaKg, // change in weight trend across the week
    required this.measurementDeltas, // site -> cm change
    required this.waterConsistency, // 0..1
  });

  final double avgKcal;
  final double avgProtein;
  final double calorieAdherence;
  final double proteinAdherence;
  final int daysLogged;
  final double weekdayAvgKcal;
  final double weekendAvgKcal;
  final double trendDeltaKg;
  final Map<String, double> measurementDeltas;
  final double waterConsistency;

  double get weekendDriftKcal => weekendAvgKcal - weekdayAvgKcal;

  Map<String, Object?> toMap() => {
        'avgKcal': avgKcal,
        'avgProtein': avgProtein,
        'calorieAdherence': calorieAdherence,
        'proteinAdherence': proteinAdherence,
        'daysLogged': daysLogged,
        'weekdayAvgKcal': weekdayAvgKcal,
        'weekendAvgKcal': weekendAvgKcal,
        'trendDeltaKg': trendDeltaKg,
        'measurementDeltas': measurementDeltas,
        'waterConsistency': waterConsistency,
      };

  factory WeeklyMetrics.fromMap(Map<String, Object?> m) => WeeklyMetrics(
        avgKcal: (m['avgKcal'] as num?)?.toDouble() ?? 0,
        avgProtein: (m['avgProtein'] as num?)?.toDouble() ?? 0,
        calorieAdherence: (m['calorieAdherence'] as num?)?.toDouble() ?? 0,
        proteinAdherence: (m['proteinAdherence'] as num?)?.toDouble() ?? 0,
        daysLogged: (m['daysLogged'] as int?) ?? 0,
        weekdayAvgKcal: (m['weekdayAvgKcal'] as num?)?.toDouble() ?? 0,
        weekendAvgKcal: (m['weekendAvgKcal'] as num?)?.toDouble() ?? 0,
        trendDeltaKg: (m['trendDeltaKg'] as num?)?.toDouble() ?? 0,
        measurementDeltas: ((m['measurementDeltas'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        waterConsistency: (m['waterConsistency'] as num?)?.toDouble() ?? 0,
      );

  static const WeeklyMetrics empty = WeeklyMetrics(
    avgKcal: 0,
    avgProtein: 0,
    calorieAdherence: 0,
    proteinAdherence: 0,
    daysLogged: 0,
    weekdayAvgKcal: 0,
    weekendAvgKcal: 0,
    trendDeltaKg: 0,
    measurementDeltas: {},
    waterConsistency: 0,
  );
}

/// The user's free-text answers to the three weekly prompts + reflection.
class WeeklyAnswers {
  const WeeklyAnswers({
    this.whatWorked = '',
    this.whatHurt = '',
    this.whatToRepeat = '',
    this.reflection = '',
  });

  final String whatWorked;
  final String whatHurt;
  final String whatToRepeat;
  final String reflection;

  Map<String, Object?> toMap() => {
        'whatWorked': whatWorked,
        'whatHurt': whatHurt,
        'whatToRepeat': whatToRepeat,
        'reflection': reflection,
      };

  factory WeeklyAnswers.fromMap(Map<String, Object?> m) => WeeklyAnswers(
        whatWorked: m['whatWorked'] as String? ?? '',
        whatHurt: m['whatHurt'] as String? ?? '',
        whatToRepeat: m['whatToRepeat'] as String? ?? '',
        reflection: m['reflection'] as String? ?? '',
      );
}

class WeeklyReview {
  const WeeklyReview({
    required this.id,
    required this.vaultItemId,
    required this.userId,
    required this.weekStart, // 'yyyy-MM-dd' (Monday)
    required this.metrics,
    required this.answers,
    required this.isBestWeek,
    this.savedCapsuleId,
    required this.createdAt,
  });

  final String id;
  final String vaultItemId;
  final String userId;
  final String weekStart;
  final WeeklyMetrics metrics;
  final WeeklyAnswers answers;
  final bool isBestWeek;
  final String? savedCapsuleId;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'vault_item_id': vaultItemId,
        'user_id': userId,
        'week_start': weekStart,
        'metrics_json': jsonEncode(metrics.toMap()),
        'answers_json': jsonEncode(answers.toMap()),
        'is_best_week': isBestWeek ? 1 : 0,
        'saved_capsule_id': savedCapsuleId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory WeeklyReview.fromMap(Map<String, Object?> m) => WeeklyReview(
        id: m['id'] as String,
        vaultItemId: m['vault_item_id'] as String,
        userId: m['user_id'] as String,
        weekStart: m['week_start'] as String,
        metrics: WeeklyMetrics.fromMap(
            jsonDecode(m['metrics_json'] as String? ?? '{}')
                as Map<String, Object?>),
        answers: WeeklyAnswers.fromMap(
            jsonDecode(m['answers_json'] as String? ?? '{}')
                as Map<String, Object?>),
        isBestWeek: (m['is_best_week'] as int? ?? 0) == 1,
        savedCapsuleId: m['saved_capsule_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['created_at'] as int?) ?? 0),
      );
}
