import 'package:macrovault/models/macros.dart';

/// One ingredient row within a recipe.
class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.recipeId,
    required this.foodId,
    required this.foodName,
    required this.qty, // servings of the referenced food
    required this.kcal, // total for qty
    required this.macros, // total for qty
  });

  final String id;
  final String recipeId;
  final String foodId;
  final String foodName;
  final double qty;
  final double kcal;
  final Macros macros;

  RecipeIngredient copyWith({double? qty, double? kcal, Macros? macros}) =>
      RecipeIngredient(
        id: id,
        recipeId: recipeId,
        foodId: foodId,
        foodName: foodName,
        qty: qty ?? this.qty,
        kcal: kcal ?? this.kcal,
        macros: macros ?? this.macros,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'recipe_id': recipeId,
        'food_id': foodId,
        'food_name': foodName,
        'qty': qty,
        'kcal': kcal,
        'protein_g': macros.protein,
        'carb_g': macros.carbs,
        'fat_g': macros.fat,
      };

  factory RecipeIngredient.fromMap(Map<String, Object?> m) => RecipeIngredient(
        id: m['id'] as String,
        recipeId: m['recipe_id'] as String,
        foodId: m['food_id'] as String,
        foodName: m['food_name'] as String? ?? 'Ingredient',
        qty: (m['qty'] as num?)?.toDouble() ?? 1,
        kcal: (m['kcal'] as num?)?.toDouble() ?? 0,
        macros: Macros(
          protein: (m['protein_g'] as num?)?.toDouble() ?? 0,
          carbs: (m['carb_g'] as num?)?.toDouble() ?? 0,
          fat: (m['fat_g'] as num?)?.toDouble() ?? 0,
        ),
      );
}

/// A recipe yields [yieldServings] portions. Per-serving macros are derived
/// from the ingredients (see [RecipeWithIngredients]).
class Recipe {
  const Recipe({
    required this.id,
    required this.userId,
    required this.name,
    required this.yieldServings,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final double yieldServings;
  final DateTime createdAt;

  Recipe copyWith({String? name, double? yieldServings}) => Recipe(
        id: id,
        userId: userId,
        name: name ?? this.name,
        yieldServings: yieldServings ?? this.yieldServings,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'yield_servings': yieldServings,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Recipe.fromMap(Map<String, Object?> m) => Recipe(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        name: m['name'] as String,
        yieldServings: (m['yield_servings'] as num?)?.toDouble() ?? 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['created_at'] as int?) ?? 0),
      );
}

/// Convenience aggregate joining a recipe with its ingredients.
class RecipeWithIngredients {
  const RecipeWithIngredients(this.recipe, this.ingredients);

  final Recipe recipe;
  final List<RecipeIngredient> ingredients;

  double get totalKcal => ingredients.fold(0.0, (s, i) => s + i.kcal);
  Macros get totalMacros =>
      ingredients.fold(Macros.zero, (s, i) => s + i.macros);

  double get perServingKcal =>
      recipe.yieldServings <= 0 ? totalKcal : totalKcal / recipe.yieldServings;
  Macros get perServingMacros => recipe.yieldServings <= 0
      ? totalMacros
      : totalMacros.scale(1 / recipe.yieldServings);

  /// True when at least one ingredient came from an estimated source — surfaced
  /// in the UI as "partial estimate".
  bool get isPartialEstimate =>
      ingredients.any((i) => i.kcal == 0 && i.macros.derivedKcal == 0);
}
