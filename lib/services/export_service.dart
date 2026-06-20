import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:macrovault/services/photo_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// "Export Everything": packages all data into a ZIP (JSON + CSV + optional
/// photos). Health metrics are never silently embedded in exported images — the
/// images are copied verbatim (already EXIF-stripped) and metrics live only in
/// the JSON/CSV files. Including media is an explicit opt-in.
class ExportService {
  ExportService(this._db, this._photos);

  final Database _db;
  final PhotoStorage _photos;

  static const _allTables = [
    'users',
    'goals',
    'foods',
    'food_entries',
    'meal_templates',
    'recipes',
    'recipe_ingredients',
    'weight_entries',
    'measurement_entries',
    'water_logs',
    'exercise_logs',
    'progress_photos',
    'vault_items',
    'progress_capsules',
    'weekly_reviews',
    'reminders',
  ];

  /// Builds the archive and returns the file path. Set [includeMedia] only after
  /// the user has acknowledged the privacy warning.
  Future<String> buildArchive({required bool includeMedia}) async {
    final archive = Archive();

    // 1. Full JSON dump, one file per table.
    final manifest = <String, Object?>{
      'app': 'MacroVault',
      'schema': 'v1',
      'exportedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
      'includesMedia': includeMedia,
    };
    archive.addFile(_jsonFile('manifest.json', manifest));

    for (final table in _allTables) {
      final rows = await _db.query(table);
      archive.addFile(_jsonFile('data/$table.json', rows));
    }

    // 2. Human-friendly CSVs for the two most-reviewed series.
    archive.addFile(
        _textFile('csv/food_entries.csv', await _foodEntriesCsv()));
    archive.addFile(_textFile('csv/weight.csv', await _weightCsv()));

    // 3. Photos (opt-in only).
    if (includeMedia) {
      final photoRows = await _db.query('progress_photos');
      for (final row in photoRows) {
        final rel = row['relative_path'] as String;
        final file = await _photos.file(rel);
        if (await file.exists()) {
          archive.addFile(ArchiveFile(
              'media/${p.basename(rel)}', await file.length(),
              await file.readAsBytes()));
        }
      }
    }

    final bytes = ZipEncoder().encode(archive)!;
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final outPath = p.join(dir.path, 'macrovault_export_$stamp.zip');
    await File(outPath).writeAsBytes(bytes, flush: true);
    return outPath;
  }

  /// Build + present the OS share sheet so the user controls where it goes.
  Future<void> exportAndShare({required bool includeMedia}) async {
    final path = await buildArchive(includeMedia: includeMedia);
    await Share.shareXFiles([XFile(path)], subject: 'MacroVault export');
  }

  ArchiveFile _jsonFile(String name, Object? content) {
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(content));
    return ArchiveFile(name, bytes.length, bytes);
  }

  ArchiveFile _textFile(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  Future<String> _foodEntriesCsv() async {
    final rows = await _db.query('food_entries', orderBy: 'day ASC');
    final sb = StringBuffer(
        'day,meal_slot,food_name,qty,kcal,protein_g,carb_g,fat_g\n');
    for (final r in rows) {
      sb.writeln([
        r['day'],
        r['meal_slot'],
        _csv(r['food_name']),
        r['qty'],
        r['snapshot_kcal'],
        r['snapshot_protein_g'],
        r['snapshot_carb_g'],
        r['snapshot_fat_g'],
      ].join(','));
    }
    return sb.toString();
  }

  Future<String> _weightCsv() async {
    final rows = await _db.query('weight_entries', orderBy: 'day ASC');
    final sb = StringBuffer('day,weight_kg,trend_value_kg\n');
    for (final r in rows) {
      sb.writeln('${r['day']},${r['weight_kg']},${r['trend_value_kg']}');
    }
    return sb.toString();
  }

  String _csv(Object? v) {
    final s = (v ?? '').toString();
    return s.contains(',') ? '"${s.replaceAll('"', '""')}"' : s;
  }
}
