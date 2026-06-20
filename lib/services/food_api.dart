import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/food.dart';
import 'package:macrovault/models/macros.dart';
import 'package:uuid/uuid.dart';

/// Remote food lookups: Open Food Facts (branded/barcode) primary, USDA
/// FoodData Central (generic) fallback. The only network calls in the app.
///
/// Results are returned as transient [Food] objects (source off/usda). They are
/// only persisted to the local DB once the user actually logs them.
class FoodApi {
  FoodApi({http.Client? client, this.usdaApiKey = 'DEMO_KEY'})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String usdaApiKey;
  final _uuid = const Uuid();

  static const _offBase = 'https://world.openfoodfacts.org';
  static const _usdaBase = 'https://api.nal.usda.gov/fdc/v1';

  /// Look up a single product by barcode (Open Food Facts).
  Future<Food?> byBarcode(String barcode) async {
    final uri = Uri.parse('$_offBase/api/v2/product/$barcode.json'
        '?fields=product_name,brands,nutriments,serving_size,serving_quantity');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, Object?>;
      if (body['status'] != 1) return null;
      final product = body['product'] as Map<String, Object?>;
      return _offProductToFood(product, barcode);
    } catch (_) {
      return null; // offline / malformed → caller falls back to "create custom"
    }
  }

  /// Free-text search. Tries Open Food Facts first, then USDA.
  Future<List<Food>> search(String query, {int limit = 20}) async {
    final off = await _searchOff(query, limit: limit);
    if (off.isNotEmpty) return off;
    return _searchUsda(query, limit: limit);
  }

  Future<List<Food>> _searchOff(String query, {int limit = 20}) async {
    final uri = Uri.parse('$_offBase/cgi/search.pl'
        '?search_terms=${Uri.encodeQueryComponent(query)}'
        '&search_simple=1&action=process&json=1&page_size=$limit'
        '&fields=code,product_name,brands,nutriments,serving_size');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, Object?>;
      final products = (body['products'] as List<Object?>? ?? []);
      return products
          .map((p) {
            final map = p as Map<String, Object?>;
            return _offProductToFood(map, map['code'] as String?);
          })
          .whereType<Food>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Food>> _searchUsda(String query, {int limit = 20}) async {
    final uri = Uri.parse('$_usdaBase/foods/search'
        '?api_key=$usdaApiKey'
        '&query=${Uri.encodeQueryComponent(query)}'
        '&pageSize=$limit&dataType=Foundation,SR%20Legacy');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, Object?>;
      final foods = (body['foods'] as List<Object?>? ?? []);
      return foods
          .map((f) => _usdaFoodToFood(f as Map<String, Object?>))
          .whereType<Food>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  // --- Mappers ---

  Food? _offProductToFood(Map<String, Object?> product, String? barcode) {
    final name = (product['product_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final nutr = (product['nutriments'] as Map<String, Object?>?) ?? {};

    // OFF nutriments are per 100 g. Convert to a per-serving figure when a
    // serving size is known, else present per-100g as the serving.
    double per100(String key) =>
        (nutr['${key}_100g'] as num?)?.toDouble() ?? 0;

    final servingG = (product['serving_quantity'] as num?)?.toDouble();
    final factor = (servingG != null && servingG > 0) ? servingG / 100.0 : 1.0;
    final servingDesc = servingG != null
        ? '1 serving (${servingG.round()} g)'
        : '100 g';

    return Food(
      id: _uuid.v4(),
      source: FoodSource.off,
      name: name,
      brand: (product['brands'] as String?)?.split(',').first.trim(),
      barcode: barcode,
      servingDesc: servingDesc,
      servingGrams: servingG ?? 100,
      kcal: per100('energy-kcal') * factor,
      macros: Macros(
        protein: per100('proteins') * factor,
        carbs: per100('carbohydrates') * factor,
        fat: per100('fat') * factor,
      ),
    );
  }

  Food? _usdaFoodToFood(Map<String, Object?> f) {
    final name = (f['description'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final nutrients = (f['foodNutrients'] as List<Object?>? ?? []);
    double byName(List<String> needles) {
      for (final n in nutrients) {
        final m = n as Map<String, Object?>;
        final nm = (m['nutrientName'] as String? ?? '').toLowerCase();
        if (needles.any(nm.contains)) {
          return (m['value'] as num?)?.toDouble() ?? 0;
        }
      }
      return 0;
    }

    // USDA search nutrients are per 100 g.
    return Food(
      id: _uuid.v4(),
      source: FoodSource.usda,
      name: name,
      brand: f['brandOwner'] as String?,
      barcode: null,
      servingDesc: '100 g',
      servingGrams: 100,
      kcal: byName(['energy']),
      macros: Macros(
        protein: byName(['protein']),
        carbs: byName(['carbohydrate']),
        fat: byName(['total lipid', 'fat']),
      ),
    );
  }

  void dispose() => _client.close();
}
