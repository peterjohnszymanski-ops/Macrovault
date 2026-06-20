import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/food_entry.dart';
import 'package:macrovault/models/goal.dart';
import 'package:macrovault/models/macros.dart';
import 'package:macrovault/models/user.dart';
import 'package:macrovault/models/weight_entry.dart';
import 'package:macrovault/state/providers.dart';

/// Everything the dashboard needs for a given day, computed in one pass.
class DashboardData {
  const DashboardData({
    required this.user,
    required this.goal,
    required this.day,
    required this.entriesBySlot,
    required this.consumedKcal,
    required this.consumedMacros,
    required this.waterMl,
    required this.waterGoalMl,
    required this.latestWeight,
    required this.weekTrendDeltaKg,
    required this.daysSinceLastLog,
  });

  final AppUser user;
  final Goal goal;
  final String day;
  final Map<MealSlot, List<FoodEntry>> entriesBySlot;
  final double consumedKcal;
  final Macros consumedMacros;
  final int waterMl;
  final int waterGoalMl;
  final WeightEntry? latestWeight;
  final double weekTrendDeltaKg;
  final int daysSinceLastLog;

  int get caloriesRemaining => (goal.calorieTarget - consumedKcal).round();
  double get proteinProgress =>
      goal.proteinTargetG <= 0 ? 0 : consumedMacros.protein / goal.proteinTargetG;
  double get calorieProgress =>
      goal.calorieTarget <= 0 ? 0 : consumedKcal / goal.calorieTarget;

  /// Show the calm No-Shame Reset prompt after 2+ missed days.
  bool get showResetPrompt => daysSinceLastLog >= 2;

  List<FoodEntry> entries(MealSlot slot) => entriesBySlot[slot] ?? const [];
}

final waterGoalMlProvider = StateProvider<int>((ref) => 2500);

final dashboardProvider =
    FutureProvider.family<DashboardData?, String>((ref, day) async {
  ref.logMutationToken; // re-run after any logging write
  final services = ref.watch(servicesProvider);

  final user = await ref.watch(currentUserProvider.future);
  final goal = await ref.watch(activeGoalProvider.future);
  if (user == null || goal == null) return null;

  final entries = await services.entries.entriesForDay(user.id, day);
  final bySlot = <MealSlot, List<FoodEntry>>{};
  var kcal = 0.0;
  var macros = Macros.zero;
  for (final e in entries) {
    bySlot.putIfAbsent(e.mealSlot, () => []).add(e);
    kcal += e.snapshotKcal;
    macros = macros + e.snapshotMacros;
  }

  final water = await services.body.water(user.id, day);
  final latestWeight = await services.body.latestWeight(user.id);

  // Week trend delta (this week so far).
  final weekStart = Days.weekStartKey(Days.parse(day));
  final weights = await services.body.weights(user.id);
  final weekWeights = weights
      .where((w) =>
          w.day.compareTo(weekStart) >= 0 && w.day.compareTo(day) <= 0)
      .toList();
  final weekDelta = weekWeights.length < 2
      ? 0.0
      : weekWeights.last.trendValueKg - weekWeights.first.trendValueKg;

  // Days since last log (for reset prompt) — only meaningful for "today".
  final lastDay = await services.entries.lastLoggedDay(user.id);
  int sinceLast = 0;
  if (lastDay != null) {
    sinceLast = Days.parse(day).difference(Days.parse(lastDay)).inDays;
    if (sinceLast < 0) sinceLast = 0;
  }

  return DashboardData(
    user: user,
    goal: goal,
    day: day,
    entriesBySlot: bySlot,
    consumedKcal: kcal,
    consumedMacros: macros,
    waterMl: water?.ml ?? 0,
    waterGoalMl: ref.watch(waterGoalMlProvider),
    latestWeight: latestWeight,
    weekTrendDeltaKg: weekDelta,
    daysSinceLastLog: sinceLast,
  );
});
