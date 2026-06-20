import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/food.dart';
import 'package:macrovault/models/goal.dart';
import 'package:macrovault/models/meal_template.dart';
import 'package:macrovault/models/user.dart';
import 'package:macrovault/state/app_services.dart';

/// Injected in main() via ProviderScope override. Reading it before override
/// throws by design.
final servicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('servicesProvider must be overridden'),
);

/// The single local user (null until onboarding completes).
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  return ref.watch(servicesProvider).profile.getUser();
});

/// The active nutrition goal.
final activeGoalProvider = FutureProvider<Goal?>((ref) async {
  // Re-run whenever the user changes (e.g. after onboarding).
  ref.watch(currentUserProvider);
  return ref.watch(servicesProvider).profile.getActiveGoal();
});

/// The day currently shown on the dashboard / diary. Defaults to today.
final selectedDayProvider = StateProvider<String>((ref) => Days.today());

/// Recently/frequently eaten foods for the quick-log surface.
final recentsProvider = FutureProvider<List<Food>>((ref) async {
  ref.watch(_logMutationProvider);
  return ref.watch(servicesProvider).foods.recents();
});

/// Meal-aware recents: foods you usually log at [slot] surface first.
final recentsForMealProvider =
    FutureProvider.family<List<Food>, MealSlot>((ref, slot) async {
  ref.watch(_logMutationProvider);
  return ref.watch(servicesProvider).foods.recentsForMeal(slot.storageValue);
});

/// Starred foods.
final favoritesProvider = FutureProvider<List<Food>>((ref) async {
  ref.watch(_logMutationProvider);
  return ref.watch(servicesProvider).foods.favorites();
});

/// The user's "usual" meals (one-tap log).
final usualsProvider = FutureProvider<List<MealTemplate>>((ref) async {
  ref.watch(_logMutationProvider);
  return ref.watch(servicesProvider).foods.usuals();
});

/// All saved meal templates.
final templatesProvider = FutureProvider<List<MealTemplate>>((ref) async {
  ref.watch(_logMutationProvider);
  return ref.watch(servicesProvider).foods.templates();
});

/// A monotonically-increasing token bumped after any write that should refresh
/// day/dashboard/recents views. Cheaper and more predictable than scattering
/// invalidate() calls. Call `ref.read(logMutationProvider.notifier).bump()`.
final _logMutationProvider = StateProvider<int>((ref) => 0);

extension LogMutation on WidgetRef {
  void bumpLogMutation() =>
      read(_logMutationProvider.notifier).state++;
}

extension LogMutationRef on Ref {
  void bumpLogMutation() => read(_logMutationProvider.notifier).state++;
  int get logMutationToken => watch(_logMutationProvider);
}
