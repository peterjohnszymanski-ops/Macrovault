import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/models/food_entry.dart';
import 'package:macrovault/models/goal.dart';
import 'package:macrovault/models/weekly_review.dart';
import 'package:macrovault/models/weight_entry.dart';

/// Pure computation of a week's auto-filled metrics. No I/O — the caller
/// gathers data via DAOs and passes it in (see services/weekly_builder.dart).
class WeeklyMetricsCalculator {
  WeeklyMetricsCalculator._();

  static WeeklyMetrics compute({
    required String weekStartKey,
    required Goal goal,
    required List<FoodEntry> weekEntries,
    required List<WeightEntry> weekWeights, // chronological, trend-bearing
    required Map<String, double> measurementStart, // site -> cm at week start
    required Map<String, double> measurementEnd, // site -> cm at week end
    required Map<String, int> waterByDay, // day -> ml
    required int waterGoalMl,
  }) {
    final days = Days.weekDays(weekStartKey);

    // Per-day totals.
    final kcalByDay = <String, double>{};
    final proteinByDay = <String, double>{};
    for (final e in weekEntries) {
      kcalByDay[e.day] = (kcalByDay[e.day] ?? 0) + e.snapshotKcal;
      proteinByDay[e.day] =
          (proteinByDay[e.day] ?? 0) + e.snapshotMacros.protein;
    }

    final loggedDays = kcalByDay.keys.where((d) => kcalByDay[d]! > 0).toList();
    final daysLogged = loggedDays.length;

    double mean(Iterable<double> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

    final avgKcal = mean(loggedDays.map((d) => kcalByDay[d]!));
    final avgProtein = mean(loggedDays.map((d) => proteinByDay[d] ?? 0));

    // Weekday vs weekend averages.
    final weekdayKcal = <double>[];
    final weekendKcal = <double>[];
    for (final d in loggedDays) {
      (Days.isWeekend(d) ? weekendKcal : weekdayKcal).add(kcalByDay[d]!);
    }

    // Calorie adherence: 1.0 at target, decaying with distance (±30% → ~0).
    double calorieAdherence = 0;
    if (daysLogged > 0 && goal.calorieTarget > 0) {
      final dist = (avgKcal - goal.calorieTarget).abs() / goal.calorieTarget;
      calorieAdherence = (1 - dist / 0.3).clamp(0, 1).toDouble();
    }

    // Protein adherence: fraction of logged days hitting ≥90% of target.
    final proteinThreshold = goal.proteinTargetG * 0.9;
    final proteinHitDays = loggedDays
        .where((d) => (proteinByDay[d] ?? 0) >= proteinThreshold)
        .length;
    final proteinAdherence =
        daysLogged == 0 ? 0.0 : proteinHitDays / daysLogged;

    // Trend delta across the week.
    final trendDelta = weekWeights.length < 2
        ? 0.0
        : weekWeights.last.trendValueKg - weekWeights.first.trendValueKg;

    // Measurement deltas (only sites present at both ends).
    final measurementDeltas = <String, double>{};
    for (final site in measurementEnd.keys) {
      if (measurementStart.containsKey(site)) {
        measurementDeltas[site] = measurementEnd[site]! - measurementStart[site]!;
      }
    }

    // Water consistency: fraction of days meeting the water goal.
    int waterMetDays = 0;
    for (final d in days) {
      if ((waterByDay[d] ?? 0) >= waterGoalMl && waterGoalMl > 0) {
        waterMetDays++;
      }
    }
    final waterConsistency = waterGoalMl <= 0 ? 0.0 : waterMetDays / 7;

    return WeeklyMetrics(
      avgKcal: avgKcal,
      avgProtein: avgProtein,
      calorieAdherence: calorieAdherence,
      proteinAdherence: proteinAdherence.toDouble(),
      daysLogged: daysLogged,
      weekdayAvgKcal: mean(weekdayKcal),
      weekendAvgKcal: mean(weekendKcal),
      trendDeltaKg: trendDelta,
      measurementDeltas: measurementDeltas,
      waterConsistency: waterConsistency,
    );
  }

  /// Best-week heuristic: strong adherence on both calories and protein, plus
  /// trend moving the "right way" for the goal.
  static bool isBestWeek(WeeklyMetrics m, Goal goal) {
    final adherenceStrong =
        m.calorieAdherence >= 0.8 && m.proteinAdherence >= 0.8;
    final trendRight = switch (goal.type.name) {
      'lose' => m.trendDeltaKg < 0,
      'gain' => m.trendDeltaKg > 0,
      _ => m.trendDeltaKg.abs() < 0.3, // maintain/recomp: roughly stable
    };
    return adherenceStrong && trendRight && m.daysLogged >= 5;
  }
}
