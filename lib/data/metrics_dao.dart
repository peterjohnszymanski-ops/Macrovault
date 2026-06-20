import 'package:macrovault/models/metric.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Progress metrics: max lifts, body fat, and any custom measures the user adds.
class MetricsDao {
  MetricsDao(this._db);
  final Database _db;

  /// All definitions: built-ins (from code) + the user's custom ones.
  Future<List<MetricDef>> defs() async {
    final rows = await _db.query('metric_defs', where: 'builtin = 0');
    final custom = rows.map(MetricDef.fromMap).toList();
    return [...kBuiltinMetrics, ...custom];
  }

  Future<void> addCustomDef(MetricDef def) async {
    await _db.insert('metric_defs', def.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MetricEntry>> series(String metricKey) async {
    final rows = await _db.query('metric_entries',
        where: 'metric_key = ?', whereArgs: [metricKey], orderBy: 'day ASC');
    return rows.map(MetricEntry.fromMap).toList();
  }

  /// One entry per metric per day (latest wins).
  Future<void> upsertEntry(MetricEntry e) async {
    await _db.transaction((txn) async {
      await txn.delete('metric_entries',
          where: 'metric_key = ? AND day = ? AND user_id = ?',
          whereArgs: [e.metricKey, e.day, e.userId]);
      await txn.insert('metric_entries', e.toMap());
    });
  }

  Future<void> deleteEntry(String id) async {
    await _db.delete('metric_entries', where: 'id = ?', whereArgs: [id]);
  }

  /// Latest recorded value for a metric (for the stat cards).
  Future<MetricEntry?> latest(String metricKey) async {
    final rows = await _db.query('metric_entries',
        where: 'metric_key = ?',
        whereArgs: [metricKey],
        orderBy: 'day DESC',
        limit: 1);
    return rows.isEmpty ? null : MetricEntry.fromMap(rows.first);
  }

  Future<void> deleteMetric(String key) async {
    await _db.transaction((txn) async {
      await txn
          .delete('metric_entries', where: 'metric_key = ?', whereArgs: [key]);
      await txn.delete('metric_defs', where: 'key = ?', whereArgs: [key]);
    });
  }
}
