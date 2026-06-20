import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/food.dart';
import 'package:macrovault/models/macros.dart';

/// A single logged food on a given day + meal slot.
///
/// Crucially, [snapshotKcal] and [snapshotMacros] are frozen at log time. If the
/// underlying [Food] is later edited, this historical entry is unchanged.
class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.userId,
    required this.day, // 'yyyy-MM-dd'
    required this.mealSlot,
    required this.foodId,
    required this.foodName,
    required this.qty, // number of servings
    required this.snapshotKcal, // total for this entry (qty applied)
    required this.snapshotMacros, // total for this entry (qty applied)
    required this.source,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String day;
  final MealSlot mealSlot;
  final String foodId;
  final String foodName; // denormalised for display without a join
  final double qty;
  final double snapshotKcal;
  final Macros snapshotMacros;
  final EntrySource source;
  final DateTime createdAt;

  /// Build an entry from a [Food] + serving quantity, freezing the snapshot.
  factory FoodEntry.fromFood({
    required String id,
    required String userId,
    required String day,
    required MealSlot mealSlot,
    required Food food,
    required double qty,
    required EntrySource source,
    required DateTime createdAt,
  }) =>
      FoodEntry(
        id: id,
        userId: userId,
        day: day,
        mealSlot: mealSlot,
        foodId: food.id,
        foodName: food.displayName,
        qty: qty,
        snapshotKcal: food.kcal * qty,
        snapshotMacros: food.macros.scale(qty),
        source: source,
        createdAt: createdAt,
      );

  FoodEntry copyWith({
    String? day,
    MealSlot? mealSlot,
    double? qty,
    double? snapshotKcal,
    Macros? snapshotMacros,
  }) =>
      FoodEntry(
        id: id,
        userId: userId,
        day: day ?? this.day,
        mealSlot: mealSlot ?? this.mealSlot,
        foodId: foodId,
        foodName: foodName,
        qty: qty ?? this.qty,
        snapshotKcal: snapshotKcal ?? this.snapshotKcal,
        snapshotMacros: snapshotMacros ?? this.snapshotMacros,
        source: source,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'day': day,
        'meal_slot': mealSlot.storageValue,
        'food_id': foodId,
        'food_name': foodName,
        'qty': qty,
        'snapshot_kcal': snapshotKcal,
        'snapshot_protein_g': snapshotMacros.protein,
        'snapshot_carb_g': snapshotMacros.carbs,
        'snapshot_fat_g': snapshotMacros.fat,
        'source': source.storageValue,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory FoodEntry.fromMap(Map<String, Object?> m) => FoodEntry(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        day: m['day'] as String,
        mealSlot: MealSlot.fromStorage(m['meal_slot'] as String),
        foodId: m['food_id'] as String,
        foodName: m['food_name'] as String? ?? 'Food',
        qty: (m['qty'] as num?)?.toDouble() ?? 1,
        snapshotKcal: (m['snapshot_kcal'] as num?)?.toDouble() ?? 0,
        snapshotMacros: Macros(
          protein: (m['snapshot_protein_g'] as num?)?.toDouble() ?? 0,
          carbs: (m['snapshot_carb_g'] as num?)?.toDouble() ?? 0,
          fat: (m['snapshot_fat_g'] as num?)?.toDouble() ?? 0,
        ),
        source: EntrySource.fromStorage(m['source'] as String? ?? 'manual'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['created_at'] as int?) ?? 0),
      );
}
