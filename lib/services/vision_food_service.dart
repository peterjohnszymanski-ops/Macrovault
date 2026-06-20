import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:macrovault/models/macros.dart';

/// One food the vision model thinks it sees, pending user confirmation.
class ParsedFoodItem {
  ParsedFoodItem({
    required this.name,
    required this.kcal,
    required this.macros,
    required this.confidence,
    this.selected = true,
  });

  final String name;
  double kcal;
  Macros macros;
  final double confidence; // 0..1
  bool selected;
}

/// Food-photo recognition.
///
/// Privacy contract: this is the ONLY path that sends a photo off-device, and
/// only when the user has opted in AND configured a proxy URL. The app never
/// holds an API key — the user's proxy is responsible for calling a vision
/// model (e.g. Claude) server-side. Results are ALWAYS confirmed by the user
/// before anything is written to the diary.
///
/// Expected proxy contract:
///   POST <proxyUrl>
///   body: {"image_base64": "...", "mime": "image/jpeg", "meal": "lunch"}
///   200 response: {"items": [
///     {"name": "Grilled chicken", "kcal": 240, "protein_g": 44,
///      "carb_g": 0, "fat_g": 6, "confidence": 0.82}, ...]}
class VisionFoodService {
  VisionFoodService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<ParsedFoodItem>> recognize({
    required String proxyUrl,
    required String imagePath,
    required String mealSlot,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final res = await _client
        .post(
          Uri.parse(proxyUrl),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'image_base64': base64Encode(bytes),
            'mime': 'image/jpeg',
            'meal': mealSlot,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw VisionException('Vision proxy returned ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, Object?>;
    final items = (body['items'] as List<Object?>? ?? []);
    return items.map((e) {
      final m = e as Map<String, Object?>;
      return ParsedFoodItem(
        name: (m['name'] as String?)?.trim().isNotEmpty == true
            ? m['name'] as String
            : 'Food',
        kcal: (m['kcal'] as num?)?.toDouble() ?? 0,
        macros: Macros(
          protein: (m['protein_g'] as num?)?.toDouble() ?? 0,
          carbs: (m['carb_g'] as num?)?.toDouble() ?? 0,
          fat: (m['fat_g'] as num?)?.toDouble() ?? 0,
        ),
        confidence: (m['confidence'] as num?)?.toDouble() ?? 0.5,
      );
    }).toList();
  }

  void dispose() => _client.close();
}

class VisionException implements Exception {
  VisionException(this.message);
  final String message;
  @override
  String toString() => message;
}
