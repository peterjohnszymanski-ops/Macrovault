/// A weight measurement. [trendValue] is the exponentially-weighted smoothed
/// value computed at insert time — it, not [weight], is shown as the headline.
///
/// Weight is always stored in **kilograms** internally; the UI converts for
/// imperial display.
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.userId,
    required this.day, // 'yyyy-MM-dd'
    required this.weightKg,
    required this.trendValueKg,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String day;
  final double weightKg;
  final double trendValueKg;
  final DateTime createdAt;

  WeightEntry copyWith({double? weightKg, double? trendValueKg}) => WeightEntry(
        id: id,
        userId: userId,
        day: day,
        weightKg: weightKg ?? this.weightKg,
        trendValueKg: trendValueKg ?? this.trendValueKg,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'day': day,
        'weight_kg': weightKg,
        'trend_value_kg': trendValueKg,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory WeightEntry.fromMap(Map<String, Object?> m) => WeightEntry(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        day: m['day'] as String,
        weightKg: (m['weight_kg'] as num).toDouble(),
        trendValueKg: (m['trend_value_kg'] as num).toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['created_at'] as int?) ?? 0),
      );
}
