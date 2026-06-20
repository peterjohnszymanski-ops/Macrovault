import 'package:macrovault/data/entry_dao.dart';
import 'package:macrovault/data/food_dao.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/food.dart';
import 'package:macrovault/models/food_entry.dart';
import 'package:macrovault/models/macros.dart';
import 'package:macrovault/models/meal_template.dart';
import 'package:macrovault/models/recipe.dart';
import 'package:uuid/uuid.dart';

/// Orchestrates "logging" — the highest-frequency action. Persists transient
/// remote foods on first use, bumps recency, and writes diary entries.
class LoggingService {
  LoggingService(this.foods, this.entries);

  final FoodDao foods;
  final EntryDao entries;
  final _uuid = const Uuid();

  /// Log a single [food] at [qty] servings. If the food isn't yet in the local
  /// DB (a fresh OFF/USDA result), it's persisted so recents/search work later.
  Future<void> logFood({
    required String userId,
    required String day,
    required MealSlot slot,
    required Food food,
    required double qty,
    required EntrySource source,
  }) async {
    final now = DateTime.now();
    final existing = await foods.getFood(food.id);
    if (existing == null) {
      await foods.upsertFood(food);
    }
    await foods.markUsed(food.id, now,
        qty: qty, mealSlot: slot.storageValue);

    final entry = FoodEntry.fromFood(
      id: _uuid.v4(),
      userId: userId,
      day: day,
      mealSlot: slot,
      food: food,
      qty: qty,
      source: source,
      createdAt: now,
    );
    await entries.insert(entry);
  }

  /// Log all items of a saved meal/usual into [slot] in one shot.
  Future<void> logTemplate({
    required String userId,
    required String day,
    required MealSlot slot,
    required MealTemplate template,
  }) async {
    final now = DateTime.now();
    final toInsert = <FoodEntry>[];
    for (final item in template.items) {
      toInsert.add(FoodEntry(
        id: _uuid.v4(),
        userId: userId,
        day: day,
        mealSlot: slot,
        foodId: item.foodId,
        foodName: item.foodName,
        qty: item.qty,
        snapshotKcal: item.kcal,
        snapshotMacros: item.macros,
        source: EntrySource.template,
        createdAt: now,
      ));
      // Best-effort recency bump for known foods.
      await foods.markUsed(item.foodId, now,
          qty: item.qty, mealSlot: slot.storageValue);
    }
    await entries.insertAll(toInsert);
  }

  /// Quick Add: log raw calories/macros without a food record (MyNetDiary's
  /// "Quick add calories"). No Food row is created.
  Future<void> logQuickAdd({
    required String userId,
    required String day,
    required MealSlot slot,
    required double kcal,
    required Macros macros,
    String label = 'Quick add',
  }) async {
    final now = DateTime.now();
    await entries.insert(FoodEntry(
      id: _uuid.v4(),
      userId: userId,
      day: day,
      mealSlot: slot,
      foodId: 'quickadd:${_uuid.v4()}',
      foodName: label,
      qty: 1,
      snapshotKcal: kcal,
      snapshotMacros: macros,
      source: EntrySource.manual,
      createdAt: now,
    ));
  }

  /// Log one serving of a recipe as a single diary entry.
  Future<void> logRecipeServing({
    required String userId,
    required String day,
    required MealSlot slot,
    required RecipeWithIngredients recipe,
    double servings = 1,
  }) async {
    final now = DateTime.now();
    final entry = FoodEntry(
      id: _uuid.v4(),
      userId: userId,
      day: day,
      mealSlot: slot,
      foodId: 'recipe:${recipe.recipe.id}',
      foodName: recipe.recipe.name,
      qty: servings,
      snapshotKcal: recipe.perServingKcal * servings,
      snapshotMacros: recipe.perServingMacros.scale(servings),
      source: EntrySource.recipe,
      createdAt: now,
    );
    await entries.insert(entry);
  }

  /// Copy a whole day's entries onto another day (powers "copy last good day").
  Future<void> copyDay({
    required String userId,
    required String fromDay,
    required String toDay,
  }) async {
    final src = await entries.entriesForDay(userId, fromDay);
    final now = DateTime.now();
    final copies = src
        .map((e) => e.copyWith(day: toDay))
        .map((e) => FoodEntry(
              id: _uuid.v4(),
              userId: e.userId,
              day: toDay,
              mealSlot: e.mealSlot,
              foodId: e.foodId,
              foodName: e.foodName,
              qty: e.qty,
              snapshotKcal: e.snapshotKcal,
              snapshotMacros: e.snapshotMacros,
              source: e.source,
              createdAt: now,
            ))
        .toList();
    await entries.insertAll(copies);
  }

  /// Create + persist a custom food from raw inputs.
  Future<Food> createCustomFood({
    required String userId,
    required String name,
    String? brand,
    String? barcode,
    required String servingDesc,
    required double servingGrams,
    required double kcal,
    required Macros macros,
  }) async {
    final food = Food(
      id: _uuid.v4(),
      source: FoodSource.custom,
      name: name,
      brand: brand,
      barcode: barcode,
      servingDesc: servingDesc,
      servingGrams: servingGrams,
      kcal: kcal,
      macros: macros,
      ownerUserId: userId,
    );
    await foods.upsertFood(food);
    return food;
  }
}
