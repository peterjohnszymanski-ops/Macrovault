import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/progress_capsule.dart';
import 'package:macrovault/models/vault_item.dart';
import 'package:macrovault/models/weekly_review.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// The Progress Vault: items, capsules, and weekly reviews.
class VaultDao {
  VaultDao(this._db);
  final Database _db;

  // --- Vault items (timeline) ---
  Future<List<VaultItem>> items(String userId, {String? tag}) async {
    final rows = await _db.query('vault_items',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'day DESC');
    final items = rows.map(VaultItem.fromMap).toList();
    if (tag == null) return items;
    // Tag filtering only applies to capsules; resolve them.
    final capsules = await capsulesByTag(userId, tag);
    final capsuleVaultIds = capsules.map((c) => c.vaultItemId).toSet();
    return items.where((i) => capsuleVaultIds.contains(i.id)).toList();
  }

  Future<List<VaultItem>> search(String userId, String query) async {
    final like = '%${query.trim()}%';
    final rows = await _db.query('vault_items',
        where: 'user_id = ? AND title LIKE ?',
        whereArgs: [userId, like],
        orderBy: 'day DESC');
    return rows.map(VaultItem.fromMap).toList();
  }

  // --- Capsules ---
  Future<ProgressCapsule?> capsule(String id) async {
    final rows =
        await _db.query('progress_capsules', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : ProgressCapsule.fromMap(rows.first);
  }

  Future<ProgressCapsule?> capsuleByVaultItem(String vaultItemId) async {
    final rows = await _db.query('progress_capsules',
        where: 'vault_item_id = ?', whereArgs: [vaultItemId]);
    return rows.isEmpty ? null : ProgressCapsule.fromMap(rows.first);
  }

  Future<List<ProgressCapsule>> capsules(String userId) async {
    final rows = await _db.query('progress_capsules',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'day DESC');
    return rows.map(ProgressCapsule.fromMap).toList();
  }

  Future<List<ProgressCapsule>> capsulesByTag(String userId, String tag) async {
    // tags are stored as a JSON array string; a LIKE match on the quoted tag is
    // sufficient for the modest data volumes here.
    final rows = await _db.query('progress_capsules',
        where: 'user_id = ? AND tags_json LIKE ?',
        whereArgs: [userId, '%"$tag"%'],
        orderBy: 'day DESC');
    return rows.map(ProgressCapsule.fromMap).toList();
  }

  /// Insert a capsule together with its backing vault item, atomically.
  Future<String> insertCapsule(VaultItem item, ProgressCapsule capsule) async {
    await _db.transaction((txn) async {
      await txn.insert('vault_items', item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('progress_capsules', capsule.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return capsule.id;
  }

  Future<void> updateCapsule(ProgressCapsule capsule) async {
    await _db.update('progress_capsules', capsule.toMap(),
        where: 'id = ?', whereArgs: [capsule.id]);
  }

  /// Deleting the vault item cascades to its capsule/review.
  Future<void> deleteVaultItem(String vaultItemId) async {
    await _db
        .delete('vault_items', where: 'id = ?', whereArgs: [vaultItemId]);
  }

  // --- Weekly reviews ---
  Future<WeeklyReview?> reviewForWeek(String userId, String weekStart) async {
    final rows = await _db.query('weekly_reviews',
        where: 'user_id = ? AND week_start = ?',
        whereArgs: [userId, weekStart],
        limit: 1);
    return rows.isEmpty ? null : WeeklyReview.fromMap(rows.first);
  }

  Future<List<WeeklyReview>> reviews(String userId) async {
    final rows = await _db.query('weekly_reviews',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'week_start DESC');
    return rows.map(WeeklyReview.fromMap).toList();
  }

  Future<void> insertReview(VaultItem item, WeeklyReview review) async {
    await _db.transaction((txn) async {
      await txn.insert('vault_items', item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('weekly_reviews', review.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// All capsules that carry the "best week" semantics, for best-week detection.
  Future<List<WeeklyReview>> bestWeeks(String userId) async {
    final rows = await _db.query('weekly_reviews',
        where: 'user_id = ? AND is_best_week = 1',
        whereArgs: [userId],
        orderBy: 'week_start DESC');
    return rows.map(WeeklyReview.fromMap).toList();
  }

  Future<int> countByType(String userId, VaultItemType type) async {
    final res = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM vault_items WHERE user_id = ? AND type = ?',
      [userId, type.storageValue],
    );
    return (res.first['c'] as int?) ?? 0;
  }
}
