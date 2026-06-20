import 'package:macrovault/models/food_entry.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Food diary entries.
class EntryDao {
  EntryDao(this._db);
  final Database _db;

  Future<List<FoodEntry>> entriesForDay(String userId, String day) async {
    final rows = await _db.query(
      'food_entries',
      where: 'user_id = ? AND day = ?',
      whereArgs: [userId, day],
      orderBy: 'created_at ASC',
    );
    return rows.map(FoodEntry.fromMap).toList();
  }

  Future<List<FoodEntry>> entriesInRange(
      String userId, String startDay, String endDay) async {
    final rows = await _db.query(
      'food_entries',
      where: 'user_id = ? AND day >= ? AND day <= ?',
      whereArgs: [userId, startDay, endDay],
      orderBy: 'day ASC, created_at ASC',
    );
    return rows.map(FoodEntry.fromMap).toList();
  }

  Future<void> insert(FoodEntry e) async {
    await _db.insert('food_entries', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertAll(List<FoodEntry> entries) async {
    final batch = _db.batch();
    for (final e in entries) {
      batch.insert('food_entries', e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> update(FoodEntry e) async {
    await _db.update('food_entries', e.toMap(),
        where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> delete(String id) async {
    await _db.delete('food_entries', where: 'id = ?', whereArgs: [id]);
  }

  /// The most recent day on which anything was logged (for No-Shame Reset).
  Future<String?> lastLoggedDay(String userId) async {
    final rows = await _db.query(
      'food_entries',
      columns: ['day'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'day DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['day'] as String;
  }

  /// Distinct days with at least one entry within a range (for adherence math).
  Future<Set<String>> loggedDaysInRange(
      String userId, String startDay, String endDay) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT day FROM food_entries WHERE user_id = ? AND day >= ? AND day <= ?',
      [userId, startDay, endDay],
    );
    return rows.map((r) => r['day'] as String).toSet();
  }
}
