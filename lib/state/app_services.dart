import 'package:macrovault/data/body_dao.dart';
import 'package:macrovault/data/database.dart';
import 'package:macrovault/data/entry_dao.dart';
import 'package:macrovault/data/food_dao.dart';
import 'package:macrovault/data/metrics_dao.dart';
import 'package:macrovault/data/photo_dao.dart';
import 'package:macrovault/data/profile_dao.dart';
import 'package:macrovault/data/vault_dao.dart';
import 'package:macrovault/services/export_service.dart';
import 'package:macrovault/services/food_api.dart';
import 'package:macrovault/services/key_service.dart';
import 'package:macrovault/services/logging_service.dart';
import 'package:macrovault/services/photo_storage.dart';
import 'package:macrovault/services/vault_lock_service.dart';
import 'package:macrovault/services/vision_food_service.dart';
import 'package:macrovault/services/weekly_builder.dart';

/// A composition root holding every DAO and service. Built once in main() after
/// the encrypted DB is open, then injected via Riverpod (see providers.dart).
class AppServices {
  AppServices._({
    required this.database,
    required this.profile,
    required this.foods,
    required this.entries,
    required this.body,
    required this.photos,
    required this.vault,
    required this.metrics,
    required this.foodApi,
    required this.photoStorage,
    required this.vaultLock,
    required this.keyService,
    required this.logging,
    required this.weeklyBuilder,
    required this.export,
    required this.vision,
  });

  final AppDatabase database;
  final ProfileDao profile;
  final FoodDao foods;
  final EntryDao entries;
  final BodyDao body;
  final PhotoDao photos;
  final VaultDao vault;
  final MetricsDao metrics;
  final FoodApi foodApi;
  final PhotoStorage photoStorage;
  final VaultLockService vaultLock;
  final KeyService keyService;
  final LoggingService logging;
  final WeeklyBuilder weeklyBuilder;
  final ExportService export;
  final VisionFoodService vision;

  /// Opens the encrypted DB and assembles all collaborators.
  static Future<AppServices> bootstrap() async {
    final keyService = KeyService();
    final dbKey = await keyService.getOrCreateDbKey();
    final database = await AppDatabase.open(password: dbKey);

    final profile = ProfileDao(database.db);
    final foods = FoodDao(database.db);
    final entries = EntryDao(database.db);
    final body = BodyDao(database.db);
    final photos = PhotoDao(database.db);
    final vault = VaultDao(database.db);
    final metrics = MetricsDao(database.db);

    final photoStorage = PhotoStorage();

    return AppServices._(
      database: database,
      profile: profile,
      foods: foods,
      entries: entries,
      body: body,
      photos: photos,
      vault: vault,
      metrics: metrics,
      foodApi: FoodApi(),
      photoStorage: photoStorage,
      vaultLock: VaultLockService(),
      keyService: keyService,
      logging: LoggingService(foods, entries),
      weeklyBuilder: WeeklyBuilder(
        profile: profile,
        entries: entries,
        body: body,
        vault: vault,
      ),
      export: ExportService(database.db, photoStorage),
      vision: VisionFoodService(),
    );
  }

  static const _tables = [
    'food_entries',
    'foods',
    'meal_templates',
    'recipe_ingredients',
    'recipes',
    'weight_entries',
    'measurement_entries',
    'water_logs',
    'exercise_logs',
    'progress_photos',
    'progress_capsules',
    'weekly_reviews',
    'vault_items',
    'metric_entries',
    'metric_defs',
    'reminders',
    'goals',
    'users',
  ];

  /// Erases every row and deletes all stored photos. The encrypted DB file and
  /// its key remain (a fresh, empty schema) so the app falls back to onboarding.
  Future<void> wipeAllData() async {
    final photoRows = await database.db.query('progress_photos');
    for (final row in photoRows) {
      await photoStorage.deleteFile(row['relative_path'] as String);
    }
    await database.db.transaction((txn) async {
      for (final t in _tables) {
        await txn.delete(t);
      }
    });
  }

  /// For tests: build over an already-open (in-memory) database.
  static AppServices forDatabase(AppDatabase database) {
    final profile = ProfileDao(database.db);
    final foods = FoodDao(database.db);
    final entries = EntryDao(database.db);
    final body = BodyDao(database.db);
    final photos = PhotoDao(database.db);
    final vault = VaultDao(database.db);
    final photoStorage = PhotoStorage();
    return AppServices._(
      database: database,
      profile: profile,
      foods: foods,
      entries: entries,
      body: body,
      photos: photos,
      vault: vault,
      metrics: metrics,
      foodApi: FoodApi(),
      photoStorage: photoStorage,
      vaultLock: VaultLockService(),
      keyService: KeyService(),
      logging: LoggingService(foods, entries),
      weeklyBuilder: WeeklyBuilder(
        profile: profile,
        entries: entries,
        body: body,
        vault: vault,
      ),
      export: ExportService(database.db, photoStorage),
      vision: VisionFoodService(),
    );
  }
}
