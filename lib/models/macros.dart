import 'dart:convert';

/// A simple value object for a macronutrient triple (grams).
///
/// Calories are derived (4/4/9) when not provided explicitly so that any
/// component can be reasoned about consistently.
class Macros {
  const Macros({
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  final double protein;
  final double carbs;
  final double fat;

  /// Derived calorie estimate using Atwater factors (4/4/9 kcal per gram).
  double get derivedKcal => protein * 4 + carbs * 4 + fat * 9;

  Macros operator +(Macros other) => Macros(
        protein: protein + other.protein,
        carbs: carbs + other.carbs,
        fat: fat + other.fat,
      );

  Macros scale(double factor) => Macros(
        protein: protein * factor,
        carbs: carbs * factor,
        fat: fat * factor,
      );

  Map<String, Object?> toMap() => {
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory Macros.fromMap(Map<String, Object?> m) => Macros(
        protein: (m['protein'] as num?)?.toDouble() ?? 0,
        carbs: (m['carbs'] as num?)?.toDouble() ?? 0,
        fat: (m['fat'] as num?)?.toDouble() ?? 0,
      );

  String toJson() => jsonEncode(toMap());

  factory Macros.fromJson(String? s) {
    if (s == null || s.isEmpty) return const Macros();
    return Macros.fromMap(jsonDecode(s) as Map<String, Object?>);
  }

  static const Macros zero = Macros();
}
