import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Opens and migrates the encrypted SQLite database.
///
/// The [password] is the SQLCipher key, generated once and held in the iOS
/// Keychain (see services/key_service.dart). Without it the file is unreadable.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const int _schemaVersion = 1;
  static const String _fileName = 'macrovault.db';

  static Future<AppDatabase> open({required String password}) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _fileName);
    final db = await openDatabase(
      path,
      password: password,
      version: _schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return AppDatabase._(db);
  }

  /// In-memory database for tests (no encryption needed).
  static Future<AppDatabase> openInMemory() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: _schemaVersion,
      onConfigure: (db) async =>
          db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        units TEXT NOT NULL,
        sex TEXT NOT NULL,
        birth_year INTEGER NOT NULL,
        height_cm REAL NOT NULL,
        vault_lock_enabled INTEGER NOT NULL DEFAULT 0,
        ai_consent INTEGER NOT NULL DEFAULT 0,
        ai_proxy_url TEXT,
        created_at INTEGER NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        activity_level TEXT NOT NULL,
        weekly_rate_kg REAL NOT NULL,
        calorie_target INTEGER NOT NULL,
        protein_target_g REAL NOT NULL,
        carb_target_g REAL NOT NULL,
        fat_target_g REAL NOT NULL,
        start_date INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )''');

    batch.execute('''
      CREATE TABLE foods (
        id TEXT PRIMARY KEY,
        source TEXT NOT NULL,
        name TEXT NOT NULL,
        brand TEXT,
        barcode TEXT,
        serving_desc TEXT NOT NULL,
        serving_grams REAL NOT NULL,
        kcal REAL NOT NULL,
        protein_g REAL NOT NULL,
        carb_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        is_estimated INTEGER NOT NULL DEFAULT 0,
        owner_user_id TEXT,
        last_used_at INTEGER,
        use_count INTEGER NOT NULL DEFAULT 0,
        last_qty REAL NOT NULL DEFAULT 1,
        last_meal_slot TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0
      )''');
    batch.execute('CREATE INDEX idx_foods_name ON foods(name)');
    batch.execute('CREATE INDEX idx_foods_barcode ON foods(barcode)');
    batch.execute('CREATE INDEX idx_foods_recent ON foods(last_used_at)');
    batch.execute('CREATE INDEX idx_foods_favorite ON foods(is_favorite)');

    batch.execute('''
      CREATE TABLE food_entries (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        day TEXT NOT NULL,
        meal_slot TEXT NOT NULL,
        food_id TEXT NOT NULL,
        food_name TEXT NOT NULL,
        qty REAL NOT NULL,
        snapshot_kcal REAL NOT NULL,
        snapshot_protein_g REAL NOT NULL,
        snapshot_carb_g REAL NOT NULL,
        snapshot_fat_g REAL NOT NULL,
        source TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )''');
    batch.execute(
        'CREATE INDEX idx_entries_user_day ON food_entries(user_id, day)');

    batch.execute('''
      CREATE TABLE meal_templates (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        items_json TEXT NOT NULL,
        usual_slot TEXT,
        created_at INTEGER NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE recipes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        yield_servings REAL NOT NULL,
        created_at INTEGER NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE recipe_ingredients (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        food_id TEXT NOT NULL,
        food_name TEXT NOT NULL,
        qty REAL NOT NULL,
        kcal REAL NOT NULL,
        protein_g REAL NOT NULL,
        carb_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      )''');
    batch.execute(
        'CREATE INDEX idx_ingredients_recipe ON recipe_ingredients(recipe_id)');

    batch.execute('''
      CREATE TABLE weight_entries (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        day TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        trend_value_kg REAL NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(user_id, day)
      )''');

    batch.execute('''
      CREATE TABLE measurement_entries (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        day TEXT NOT NULL,
        site TEXT NOT NULL,
        value_cm REAL NOT NULL,
        created_at INTEGER NOT NULL
      )''');
    batch.execute(
        'CREATE INDEX idx_meas_user_site ON measurement_entries(user_id, site)');

    batch.execute('''
      CREATE TABLE water_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        day TEXT NOT NULL,
        ml INTEGER NOT NULL DEFAULT 0,
        UNIQUE(user_id, day)
      )''');

    batch.execute('''
      CREATE TABLE exercise_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        day TEXT NOT NULL,
        type TEXT NOT NULL,
        duration_min INTEGER NOT NULL,
        note TEXT NOT NULL,
        counts_toward_budget INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE progress_photos (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        day TEXT NOT NULL,
        pose TEXT NOT NULL,
        relative_path TEXT NOT NULL,
        exif_stripped INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      )''');
    batch.execute(
        'CREATE INDEX idx_photos_user_day ON progress_photos(user_id, day)');

    batch.execute('''
      CREATE TABLE vault_items (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        day TEXT NOT NULL,
        title TEXT NOT NULL,
        ref_id TEXT,
        created_at INTEGER NOT NULL
      )''');
    batch.execute(
        'CREATE INDEX idx_vault_user_day ON vault_items(user_id, day)');

    batch.execute('''
      CREATE TABLE progress_capsules (
        id TEXT PRIMARY KEY,
        vault_item_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        day TEXT NOT NULL,
        weight_trend_kg REAL,
        measurements_json TEXT NOT NULL DEFAULT '{}',
        photo_ids_json TEXT NOT NULL DEFAULT '[]',
        wk_avg_kcal REAL,
        wk_avg_protein REAL,
        macro_consistency REAL,
        water_consistency REAL,
        exercise_notes TEXT NOT NULL DEFAULT '',
        mood_notes TEXT NOT NULL DEFAULT '',
        what_worked TEXT NOT NULL DEFAULT '',
        what_didnt TEXT NOT NULL DEFAULT '',
        what_to_repeat TEXT NOT NULL DEFAULT '',
        tags_json TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL,
        FOREIGN KEY (vault_item_id) REFERENCES vault_items(id) ON DELETE CASCADE
      )''');

    batch.execute('''
      CREATE TABLE weekly_reviews (
        id TEXT PRIMARY KEY,
        vault_item_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        week_start TEXT NOT NULL,
        metrics_json TEXT NOT NULL,
        answers_json TEXT NOT NULL,
        is_best_week INTEGER NOT NULL DEFAULT 0,
        saved_capsule_id TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (vault_item_id) REFERENCES vault_items(id) ON DELETE CASCADE
      )''');

    batch.execute('''
      CREATE TABLE metric_defs (
        key TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        higher_is_better INTEGER NOT NULL DEFAULT 1,
        builtin INTEGER NOT NULL DEFAULT 0
      )''');

    batch.execute('''
      CREATE TABLE metric_entries (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        metric_key TEXT NOT NULL,
        day TEXT NOT NULL,
        value REAL NOT NULL,
        created_at INTEGER NOT NULL
      )''');
    batch.execute(
        'CREATE INDEX idx_metrics_key_day ON metric_entries(metric_key, day)');

    batch.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 0,
        quiet_start_hour INTEGER NOT NULL DEFAULT 22,
        quiet_end_hour INTEGER NOT NULL DEFAULT 7
      )''');

    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // No migrations yet — schema v1. Future versions add ALTER statements here,
    // guarded by `if (oldVersion < N)`.
  }
}
