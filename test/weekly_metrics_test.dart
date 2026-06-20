import 'package:flutter_test/flutter_test.dart';
import 'package:macrovault/domain/weekly_metrics.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/food_entry.dart';
import 'package:macrovault/models/goal.dart';
import 'package:macrovault/models/macros.dart';
import 'package:macrovault/models/weight_entry.dart';

FoodEntry _entry(String day, double kcal, double protein) => FoodEntry(
      id: '$day-$kcal',
      userId: 'u',
      day: day,
      mealSlot: MealSlot.dinner,
      foodId: 'f',
      foodName: 'Test',
      qty: 1,
      snapshotKcal: kcal,
      snapshotMacros: Macros(protein: protein, carbs: 0, fat: 0),
      source: EntrySource.manual,
      createdAt: DateTime(2026, 6, 8),
    );

void main() {
  // 2026-06-08 is a Monday; 13/14 are the weekend.
  const weekStart = '2026-06-08';
  final goal = Goal(
    id: 'g',
    userId: 'u',
    type: GoalType.lose,
    activityLevel: ActivityLevel.moderate,
    weeklyRateKg: -0.5,
    calorieTarget: 2000,
    proteinTargetG: 150,
    carbTargetG: 180,
    fatTargetG: 60,
    startDate: DateTime(2026, 6, 1),
    active: true,
  );

  test('computes averages, adherence and weekend split', () {
    final days = [
      '2026-06-08',
      '2026-06-09',
      '2026-06-10',
      '2026-06-11',
      '2026-06-12',
      '2026-06-13', // Sat
      '2026-06-14', // Sun
    ];
    final entries = [
      for (final d in days)
        _entry(d, d.endsWith('13') || d.endsWith('14') ? 2600 : 2000, 160),
    ];

    final m = WeeklyMetricsCalculator.compute(
      weekStartKey: weekStart,
      goal: goal,
      weekEntries: entries,
      weekWeights: const [],
      measurementStart: const {},
      measurementEnd: const {},
      waterByDay: const {},
      waterGoalMl: 2500,
    );

    expect(m.daysLogged, 7);
    expect(m.weekdayAvgKcal, closeTo(2000, 0.1));
    expect(m.weekendAvgKcal, closeTo(2600, 0.1));
    expect(m.weekendDriftKcal, closeTo(600, 0.1));
    // Protein 160 ≥ 90% of 150 target on every day → full adherence.
    expect(m.proteinAdherence, 1.0);
  });

  test('best week requires adherence, trend direction and 5+ logged days', () {
    final days = List.generate(7, (i) => '2026-06-${(8 + i).toString().padLeft(2, '0')}');
    final entries = [for (final d in days) _entry(d, 2000, 160)];
    final weights = [
      WeightEntry(
          id: 'w1',
          userId: 'u',
          day: '2026-06-08',
          weightKg: 90,
          trendValueKg: 90,
          createdAt: DateTime(2026, 6, 8)),
      WeightEntry(
          id: 'w2',
          userId: 'u',
          day: '2026-06-14',
          weightKg: 89.5,
          trendValueKg: 89.6,
          createdAt: DateTime(2026, 6, 14)),
    ];

    final m = WeeklyMetricsCalculator.compute(
      weekStartKey: weekStart,
      goal: goal,
      weekEntries: entries,
      weekWeights: weights,
      measurementStart: const {},
      measurementEnd: const {},
      waterByDay: const {},
      waterGoalMl: 2500,
    );

    expect(m.trendDeltaKg, lessThan(0)); // moving down for a loss goal
    expect(WeeklyMetricsCalculator.isBestWeek(m, goal), isTrue);
  });
}
