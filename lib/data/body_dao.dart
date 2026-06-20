import 'package:macrovault/domain/trend.dart';
import 'package:macrovault/models/body_logs.dart';
import 'package:macrovault/models/weight_entry.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Weight, measurements, water, and exercise.
class BodyDao {
  BodyDao(this._db);
  final Database _db;

  // --- Weight (with trend rebuild) ---
  Future<List<WeightEntry>> weights(String userId) async {
    final rows = await _db.query('weight_entries',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'day ASC');
    return rows.map(WeightEntry.fromMap).toList();
  }

  Future<WeightEntry?> latestWeight(String userId) async {
    final rows = await _db.query('weight_entries',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'day DESC',
        limit: 1);
    return rows.isEmpty ? null : WeightEntry.fromMap(rows.first);
  }

  /// Upsert one weigh-in for a day, then rebuild the whole trend series so the
  /// EWMA stays correct even for out-of-order or edited entries.
  Future<void> upsertWeight(WeightEntry entry) async {
    await _db.transaction((txn) async {
      await txn.insert(
        'weight_entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final rows = await txn.query('weight_entries',
          where: 'user_id = ?', whereArgs: [entry.userId], orderBy: 'day ASC');
      final chronological = rows.map(WeightEntry.fromMap).toList();
      final rebuilt = Trend.rebuildEntries(chronological);
      for (final e in rebuilt) {
        await txn.update('weight_entries', {'trend_value_kg': e.trendValueKg},
            where: 'id = ?', whereArgs: [e.id]);
      }
    });
  }

  Future<void> deleteWeight(String id, String userId) async {
    await _db.transaction((txn) async {
      await txn.delete('weight_entries', where: 'id = ?', whereArgs: [id]);
      final rows = await txn.query('weight_entries',
          where: 'user_id = ?', whereArgs: [userId], orderBy: 'day ASC');
      final rebuilt = Trend.rebuildEntries(rows.map(WeightEntry.fromMap).toList());
      for (final e in rebuilt) {
        await txn.update('weight_entries', {'trend_value_kg': e.trendValueKg},
            where: 'id = ?', whereArgs: [e.id]);
      }
    });
  }

  // --- Measurements ---
  Future<List<MeasurementEntry>> measurements(String userId,
      {String? site}) async {
    final rows = await _db.query(
      'measurement_entries',
      where: site == null ? 'user_id = ?' : 'user_id = ? AND site = ?',
      whereArgs: site == null ? [userId] : [userId, site],
      orderBy: 'day ASC',
    );
    return rows.map(MeasurementEntry.fromMap).toList();
  }

  Future<void> insertMeasurement(MeasurementEntry m) async {
    await _db.insert('measurement_entries', m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteMeasurement(String id) async {
    await _db.delete('measurement_entries', where: 'id = ?', whereArgs: [id]);
  }

  // --- Water (one row per day) ---
  Future<WaterLog?> water(String userId, String day) async {
    final rows = await _db.query('water_logs',
        where: 'user_id = ? AND day = ?', whereArgs: [userId, day], limit: 1);
    return rows.isEmpty ? null : WaterLog.fromMap(rows.first);
  }

  Future<void> upsertWater(WaterLog w) async {
    await _db.insert('water_logs', w.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, int>> waterInRange(
      String userId, String start, String end) async {
    final rows = await _db.query('water_logs',
        where: 'user_id = ? AND day >= ? AND day <= ?',
        whereArgs: [userId, start, end]);
    return {for (final r in rows) r['day'] as String: r['ml'] as int};
  }

  // --- Exercise ---
  Future<List<ExerciseLog>> exercise(String userId, String day) async {
    final rows = await _db.query('exercise_logs',
        where: 'user_id = ? AND day = ?',
        whereArgs: [userId, day],
        orderBy: 'created_at ASC');
    return rows.map(ExerciseLog.fromMap).toList();
  }

  Future<List<ExerciseLog>> exerciseInRange(
      String userId, String start, String end) async {
    final rows = await _db.query('exercise_logs',
        where: 'user_id = ? AND day >= ? AND day <= ?',
        whereArgs: [userId, start, end]);
    return rows.map(ExerciseLog.fromMap).toList();
  }

  Future<void> insertExercise(ExerciseLog e) async {
    await _db.insert('exercise_logs', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteExercise(String id) async {
    await _db.delete('exercise_logs', where: 'id = ?', whereArgs: [id]);
  }
}
