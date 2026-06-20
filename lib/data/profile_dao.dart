import 'package:macrovault/models/goal.dart';
import 'package:macrovault/models/reminder.dart';
import 'package:macrovault/models/user.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// User profile, active goal, and reminders.
class ProfileDao {
  ProfileDao(this._db);
  final Database _db;

  // --- User ---
  Future<AppUser?> getUser() async {
    final rows = await _db.query('users', limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<void> upsertUser(AppUser user) async {
    await _db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Goal ---
  Future<Goal?> getActiveGoal() async {
    final rows = await _db.query('goals',
        where: 'active = 1', orderBy: 'start_date DESC', limit: 1);
    if (rows.isEmpty) return null;
    return Goal.fromMap(rows.first);
  }

  /// Insert a new goal, deactivating any previous active goal.
  Future<void> setActiveGoal(Goal goal) async {
    await _db.transaction((txn) async {
      await txn.update('goals', {'active': 0},
          where: 'user_id = ?', whereArgs: [goal.userId]);
      await txn.insert('goals', goal.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> updateGoal(Goal goal) async {
    await _db.update('goals', goal.toMap(),
        where: 'id = ?', whereArgs: [goal.id]);
  }

  // --- Reminders ---
  Future<List<Reminder>> getReminders() async {
    final rows = await _db.query('reminders');
    return rows.map(Reminder.fromMap).toList();
  }

  Future<void> upsertReminder(Reminder r) async {
    await _db.insert('reminders', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
