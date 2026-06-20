import 'package:macrovault/models/enums.dart';

/// Computes calorie + macro targets from user stats and a goal.
///
/// Uses Mifflin–St Jeor for BMR, an activity multiplier for TDEE, then adjusts
/// for the weekly rate (≈7700 kcal per kg). Protein is set per kg of bodyweight
/// (goal-dependent), fat as a share of calories, carbs as the remainder.
class TargetResult {
  const TargetResult({
    required this.calorieTarget,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    required this.tdee,
    required this.warning,
  });

  final int calorieTarget;
  final double proteinG;
  final double carbG;
  final double fatG;
  final int tdee;
  final String? warning;
}

class Targets {
  Targets._();

  static const double _kcalPerKg = 7700;

  /// Mifflin–St Jeor basal metabolic rate.
  static double bmr({
    required Sex sex,
    required double weightKg,
    required double heightCm,
    required int ageYears,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
    return sex == Sex.male ? base + 5 : base - 161;
  }

  static TargetResult compute({
    required Sex sex,
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required GoalType goal,
    required ActivityLevel activity,
    required double weeklyRateKg,
  }) {
    final tdee = bmr(
          sex: sex,
          weightKg: weightKg,
          heightCm: heightCm,
          ageYears: ageYears,
        ) *
        activity.multiplier;

    // Daily calorie delta implied by the weekly rate.
    final dailyDelta = (weeklyRateKg * _kcalPerKg) / 7;
    var calories = tdee + dailyDelta;

    String? warning;
    // Safety floor — never prescribe dangerously low intake.
    final floor = sex == Sex.male ? 1500.0 : 1200.0;
    if (calories < floor) {
      calories = floor;
      warning =
          'Your target rate would put calories below a safe floor. Capped at '
          '${floor.round()} kcal — consider a gentler rate.';
    }

    // Protein per kg by goal.
    final proteinPerKg = switch (goal) {
      GoalType.recomp => 2.2,
      GoalType.gain => 2.0,
      GoalType.lose => 2.0, // protein high in a deficit to preserve muscle
      GoalType.maintain => 1.8,
    };
    final proteinG = proteinPerKg * weightKg;

    // Fat at 25% of calories.
    final fatKcal = calories * 0.25;
    final fatG = fatKcal / 9;

    // Carbs as the remainder.
    final remainingKcal = calories - (proteinG * 4) - fatKcal;
    final carbG = (remainingKcal / 4).clamp(0, double.infinity).toDouble();

    return TargetResult(
      calorieTarget: calories.round(),
      proteinG: proteinG,
      carbG: carbG,
      fatG: fatG,
      tdee: tdee.round(),
      warning: warning,
    );
  }

  /// Suggested default weekly rate (kg) for a goal — used to pre-fill onboarding.
  static double defaultWeeklyRate(GoalType goal) => switch (goal) {
        GoalType.lose => -0.5,
        GoalType.gain => 0.25,
        GoalType.recomp => 0.0,
        GoalType.maintain => 0.0,
      };
}
