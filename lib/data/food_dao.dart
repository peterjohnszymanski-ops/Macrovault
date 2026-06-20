import 'package:macrovault/models/food.dart';
import 'package:macrovault/models/meal_template.dart';
import 'package:macrovault/models/recipe.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Foods, meal templates / "usuals", and recipes.
class FoodDao {
  FoodDao(this._db);
  final Database _db;

  // --- Foods ---
  Future<void> upsertFood(Food food) async {
    await _db.insert('foods', food.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Food?> getFood(String id) async {
    final rows = await _db.query('foods', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Food.fromMap(rows.first);
  }

  Future<Food?> findByBarcode(String barcode) async {
    final rows = await _db
        .query('foods', where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    return rows.isEmpty ? null : Food.fromMap(rows.first);
  }

  /// Local search: personal + recently used foods. Favorites first, then the
  /// most-used/most-recent — exactly the MyNetDiary feel where a food you've
  /// logged before floats to the top of results.
  /// Public DB results are merged in by the food API layer, not here.
  Future<List<Food>> searchLocal(String query, {int limit = 30}) async {
    final like = '%${query.trim()}%';
    final rows = await _db.query(
      'foods',
      where: query.trim().isEmpty ? null : 'name LIKE ? OR brand LIKE ?',
      whereArgs: query.trim().isEmpty ? null : [like, like],
      orderBy:
          'is_favorite DESC, use_count DESC, last_used_at DESC, name ASC',
      limit: limit,
    );
    return rows.map(Food.fromMap).toList();
  }

  /// Most-recently and most-frequently eaten foods for the quick-log surface.
  Future<List<Food>> recents({int limit = 20}) async {
    final rows = await _db.query(
      'foods',
      where: 'last_used_at IS NOT NULL',
      orderBy: 'last_used_at DESC',
      limit: limit,
    );
    return rows.map(Food.fromMap).toList();
  }

  /// Meal-aware recents: foods you usually eat at [slot] rank first, then your
  /// other recents. Mirrors MyNetDiary surfacing your breakfast foods when you
  /// open breakfast.
  Future<List<Food>> recentsForMeal(String slot, {int limit = 25}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT * FROM foods
      WHERE last_used_at IS NOT NULL
      ORDER BY (last_meal_slot = ?) DESC, is_favorite DESC, last_used_at DESC
      LIMIT ?
      ''',
      [slot, limit],
    );
    return rows.map(Food.fromMap).toList();
  }

  /// Starred foods.
  Future<List<Food>> favorites({int limit = 50}) async {
    final rows = await _db.query('foods',
        where: 'is_favorite = 1',
        orderBy: 'last_used_at DESC, name ASC',
        limit: limit);
    return rows.map(Food.fromMap).toList();
  }

  Future<void> setFavorite(String foodId, bool value) async {
    await _db.update('foods', {'is_favorite': value ? 1 : 0},
        where: 'id = ?', whereArgs: [foodId]);
  }

  /// Bump recency/frequency when a food is logged, and remember the portion +
  /// meal slot so next time it pre-fills your usual amount in the right place.
  Future<void> markUsed(
    String foodId,
    DateTime at, {
    double? qty,
    String? mealSlot,
  }) async {
    await _db.rawUpdate(
      '''
      UPDATE foods
      SET last_used_at = ?,
          use_count = use_count + 1,
          last_qty = COALESCE(?, last_qty),
          last_meal_slot = COALESCE(?, last_meal_slot)
      WHERE id = ?
      ''',
      [at.millisecondsSinceEpoch, qty, mealSlot, foodId],
    );
  }

  Future<void> deleteFood(String id) async {
    await _db.delete('foods', where: 'id = ?', whereArgs: [id]);
  }

  // --- Meal templates / usuals ---
  Future<List<MealTemplate>> templates() async {
    final rows = await _db.query('meal_templates', orderBy: 'created_at DESC');
    return rows.map(MealTemplate.fromMap).toList();
  }

  Future<List<MealTemplate>> usuals() async {
    final rows = await _db.query('meal_templates',
        where: 'usual_slot IS NOT NULL', orderBy: 'created_at DESC');
    return rows.map(MealTemplate.fromMap).toList();
  }

  Future<void> upsertTemplate(MealTemplate t) async {
    await _db.insert('meal_templates', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTemplate(String id) async {
    await _db.delete('meal_templates', where: 'id = ?', whereArgs: [id]);
  }

  // --- Recipes ---
  Future<List<Recipe>> recipes() async {
    final rows = await _db.query('recipes', orderBy: 'created_at DESC');
    return rows.map(Recipe.fromMap).toList();
  }

  Future<RecipeWithIngredients?> recipeWithIngredients(String recipeId) async {
    final r =
        await _db.query('recipes', where: 'id = ?', whereArgs: [recipeId]);
    if (r.isEmpty) return null;
    final ing = await _db.query('recipe_ingredients',
        where: 'recipe_id = ?', whereArgs: [recipeId]);
    return RecipeWithIngredients(
      Recipe.fromMap(r.first),
      ing.map(RecipeIngredient.fromMap).toList(),
    );
  }

  Future<void> saveRecipe(
      Recipe recipe, List<RecipeIngredient> ingredients) async {
    await _db.transaction((txn) async {
      await txn.insert('recipes', recipe.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('recipe_ingredients',
          where: 'recipe_id = ?', whereArgs: [recipe.id]);
      for (final i in ingredients) {
        await txn.insert('recipe_ingredients', i.toMap());
      }
    });
  }

  Future<void> deleteRecipe(String id) async {
    await _db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }
}
