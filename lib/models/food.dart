import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/macros.dart';

/// A food definition. Nutrition is stored per *serving*; [servingGrams] lets us
/// convert between servings and grams for scaling.
///
/// Editing a Food never rewrites history because [FoodEntry] freezes a nutrition
/// snapshot at log time (see FoodEntry).
class Food {
  const Food({
    required this.id,
    required this.source,
    required this.name,
    this.brand,
    this.barcode,
    required this.servingDesc,
    required this.servingGrams,
    required this.kcal,
    required this.macros,
    this.ownerUserId,
    this.lastUsedAt,
    this.useCount = 0,
    this.lastQty = 1,
    this.lastMealSlot,
    this.isFavorite = false,
  });

  final String id;
  final FoodSource source;
  final String name;
  final String? brand;
  final String? barcode;
  final String servingDesc; // e.g. "1 cup (240 ml)"
  final double servingGrams;
  final double kcal; // per serving
  final Macros macros; // per serving
  final String? ownerUserId; // null for public/verified foods
  final DateTime? lastUsedAt; // drives "recently eaten" ranking
  final int useCount; // drives "frequently eaten" ranking
  final double lastQty; // remembers your last portion (MyNetDiary-style)
  final MealSlot? lastMealSlot; // which meal you usually log this into
  final bool isFavorite; // starred foods rank to the top

  bool get isEstimated => source.isEstimated;
  bool get isCustom => source == FoodSource.custom;

  String get displayName =>
      brand == null || brand!.isEmpty ? name : '$name · $brand';

  Food copyWith({
    String? name,
    String? brand,
    String? barcode,
    String? servingDesc,
    double? servingGrams,
    double? kcal,
    Macros? macros,
    DateTime? lastUsedAt,
    int? useCount,
    double? lastQty,
    MealSlot? lastMealSlot,
    bool? isFavorite,
  }) =>
      Food(
        id: id,
        source: source,
        name: name ?? this.name,
        brand: brand ?? this.brand,
        barcode: barcode ?? this.barcode,
        servingDesc: servingDesc ?? this.servingDesc,
        servingGrams: servingGrams ?? this.servingGrams,
        kcal: kcal ?? this.kcal,
        macros: macros ?? this.macros,
        ownerUserId: ownerUserId,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        useCount: useCount ?? this.useCount,
        lastQty: lastQty ?? this.lastQty,
        lastMealSlot: lastMealSlot ?? this.lastMealSlot,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'source': source.storageValue,
        'name': name,
        'brand': brand,
        'barcode': barcode,
        'serving_desc': servingDesc,
        'serving_grams': servingGrams,
        'kcal': kcal,
        'protein_g': macros.protein,
        'carb_g': macros.carbs,
        'fat_g': macros.fat,
        'is_estimated': isEstimated ? 1 : 0,
        'owner_user_id': ownerUserId,
        'last_used_at': lastUsedAt?.millisecondsSinceEpoch,
        'use_count': useCount,
        'last_qty': lastQty,
        'last_meal_slot': lastMealSlot?.storageValue,
        'is_favorite': isFavorite ? 1 : 0,
      };

  factory Food.fromMap(Map<String, Object?> m) => Food(
        id: m['id'] as String,
        source: FoodSource.fromStorage(m['source'] as String),
        name: m['name'] as String,
        brand: m['brand'] as String?,
        barcode: m['barcode'] as String?,
        servingDesc: m['serving_desc'] as String? ?? '1 serving',
        servingGrams: (m['serving_grams'] as num?)?.toDouble() ?? 100,
        kcal: (m['kcal'] as num?)?.toDouble() ?? 0,
        macros: Macros(
          protein: (m['protein_g'] as num?)?.toDouble() ?? 0,
          carbs: (m['carb_g'] as num?)?.toDouble() ?? 0,
          fat: (m['fat_g'] as num?)?.toDouble() ?? 0,
        ),
        ownerUserId: m['owner_user_id'] as String?,
        lastUsedAt: (m['last_used_at'] as int?) != null
            ? DateTime.fromMillisecondsSinceEpoch(m['last_used_at'] as int)
            : null,
        useCount: (m['use_count'] as int?) ?? 0,
        lastQty: (m['last_qty'] as num?)?.toDouble() ?? 1,
        lastMealSlot: (m['last_meal_slot'] as String?) != null
            ? MealSlot.fromStorage(m['last_meal_slot'] as String)
            : null,
        isFavorite: (m['is_favorite'] as int? ?? 0) == 1,
      );
}
