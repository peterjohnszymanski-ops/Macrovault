import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/macros.dart';

/// A nutrition goal: targets the dashboard measures against.
///
/// Only one goal is [active] at a time. History is retained so the Vault can
/// reference which goal was in force during a given phase.
class Goal {
  const Goal({
    required this.id,
    required this.userId,
    required this.type,
    required this.activityLevel,
    required this.weeklyRateKg, // negative = loss, positive = gain
    required this.calorieTarget,
    required this.proteinTargetG,
    required this.carbTargetG,
    required this.fatTargetG,
    required this.startDate,
    required this.active,
  });

  final String id;
  final String userId;
  final GoalType type;
  final ActivityLevel activityLevel;
  final double weeklyRateKg;
  final int calorieTarget;
  final double proteinTargetG;
  final double carbTargetG;
  final double fatTargetG;
  final DateTime startDate;
  final bool active;

  Macros get macroTargets =>
      Macros(protein: proteinTargetG, carbs: carbTargetG, fat: fatTargetG);

  Goal copyWith({
    GoalType? type,
    ActivityLevel? activityLevel,
    double? weeklyRateKg,
    int? calorieTarget,
    double? proteinTargetG,
    double? carbTargetG,
    double? fatTargetG,
    bool? active,
  }) =>
      Goal(
        id: id,
        userId: userId,
        type: type ?? this.type,
        activityLevel: activityLevel ?? this.activityLevel,
        weeklyRateKg: weeklyRateKg ?? this.weeklyRateKg,
        calorieTarget: calorieTarget ?? this.calorieTarget,
        proteinTargetG: proteinTargetG ?? this.proteinTargetG,
        carbTargetG: carbTargetG ?? this.carbTargetG,
        fatTargetG: fatTargetG ?? this.fatTargetG,
        startDate: startDate,
        active: active ?? this.active,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'type': type.storageValue,
        'activity_level': activityLevel.storageValue,
        'weekly_rate_kg': weeklyRateKg,
        'calorie_target': calorieTarget,
        'protein_target_g': proteinTargetG,
        'carb_target_g': carbTargetG,
        'fat_target_g': fatTargetG,
        'start_date': startDate.millisecondsSinceEpoch,
        'active': active ? 1 : 0,
      };

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        type: GoalType.fromStorage(m['type'] as String),
        activityLevel:
            ActivityLevel.fromStorage(m['activity_level'] as String),
        weeklyRateKg: (m['weekly_rate_kg'] as num?)?.toDouble() ?? 0,
        calorieTarget: (m['calorie_target'] as int?) ?? 2000,
        proteinTargetG: (m['protein_target_g'] as num?)?.toDouble() ?? 150,
        carbTargetG: (m['carb_target_g'] as num?)?.toDouble() ?? 200,
        fatTargetG: (m['fat_target_g'] as num?)?.toDouble() ?? 60,
        startDate: DateTime.fromMillisecondsSinceEpoch(
            (m['start_date'] as int?) ?? 0),
        active: (m['active'] as int? ?? 0) == 1,
      );
}
