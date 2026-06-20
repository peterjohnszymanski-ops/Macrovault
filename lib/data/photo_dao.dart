import 'package:macrovault/models/progress_photo.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Progress photo records (the image bytes live on disk; this stores metadata).
class PhotoDao {
  PhotoDao(this._db);
  final Database _db;

  Future<List<ProgressPhoto>> all(String userId) async {
    final rows = await _db.query('progress_photos',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'day DESC');
    return rows.map(ProgressPhoto.fromMap).toList();
  }

  Future<List<ProgressPhoto>> forDay(String userId, String day) async {
    final rows = await _db.query('progress_photos',
        where: 'user_id = ? AND day = ?', whereArgs: [userId, day]);
    return rows.map(ProgressPhoto.fromMap).toList();
  }

  Future<List<ProgressPhoto>> byIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await _db.query('progress_photos',
        where: 'id IN ($placeholders)', whereArgs: ids);
    return rows.map(ProgressPhoto.fromMap).toList();
  }

  Future<void> insert(ProgressPhoto p) async {
    await _db.insert('progress_photos', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    await _db.delete('progress_photos', where: 'id = ?', whereArgs: [id]);
  }
}
