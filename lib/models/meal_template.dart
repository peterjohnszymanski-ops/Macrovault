import 'dart:convert';

import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/macros.dart';

/// One line in a saved meal (template or "usual").
class MealItem {
  const MealItem({
    required this.foodId,
    required this.foodName,
    required this.qty,
    required this.kcal,
    required this.macros,
  });

  final String foodId;
  final String foodName;
  final double qty;
  final double kcal; // total for qty
  final Macros macros; // total for qty

  Map<String, Object?> toMap() => {
        'foodId': foodId,
        'foodName': foodName,
        'qty': qty,
        'kcal': kcal,
        ...macros.toMap(),
      };

  factory MealItem.fromMap(Map<String, Object?> m) => MealItem(
        foodId: m['foodId'] as String,
        foodName: m['foodName'] as String? ?? 'Food',
        qty: (m['qty'] as num?)?.toDouble() ?? 1,
        kcal: (m['kcal'] as num?)?.toDouble() ?? 0,
        macros: Macros.fromMap(m),
      );
}

/// A reusable saved meal. When [usualSlot] is non-null it is the user's
/// "usual breakfast/lunch/dinner" — surfaced for one-tap logging.
class MealTemplate {
  const MealTemplate({
    required this.id,
    required this.userId,
    required this.name,
    required this.items,
    this.usualSlot,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final List<MealItem> items;
  final MealSlot? usualSlot;
  final DateTime createdAt;

  double get totalKcal => items.fold(0.0, (s, i) => s + i.kcal);
  Macros get totalMacros =>
      items.fold(Macros.zero, (s, i) => s + i.macros);

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'items_json': jsonEncode(items.map((e) => e.toMap()).toList()),
        'usual_slot': usualSlot?.storageValue,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory MealTemplate.fromMap(Map<String, Object?> m) {
    final raw = jsonDecode(m['items_json'] as String? ?? '[]') as List<Object?>;
    return MealTemplate(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      name: m['name'] as String,
      items: raw
          .map((e) => MealItem.fromMap(e as Map<String, Object?>))
          .toList(growable: false),
      usualSlot: (m['usual_slot'] as String?) != null
          ? MealSlot.fromStorage(m['usual_slot'] as String)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (m['created_at'] as int?) ?? 0),
    );
  }
}
