import 'package:collection/collection.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/data/body_dao.dart';
import 'package:macrovault/data/entry_dao.dart';
import 'package:macrovault/data/profile_dao.dart';
import 'package:macrovault/data/vault_dao.dart';
import 'package:macrovault/domain/weekly_metrics.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/progress_capsule.dart';
import 'package:macrovault/models/vault_item.dart';
import 'package:macrovault/models/weekly_review.dart';
import 'package:uuid/uuid.dart';

/// Gathers the data for a review week and computes its metrics; also turns a
/// completed review into a saved Capsule (the Vault's "save moment").
class WeeklyBuilder {
  WeeklyBuilder({
    required this.profile,
    required this.entries,
    required this.body,
    required this.vault,
    this.waterGoalMl = 2500,
  });

  final ProfileDao profile;
  final EntryDao entries;
  final BodyDao body;
  final VaultDao vault;
  final int waterGoalMl;
  final _uuid = const Uuid();

  Future<({WeeklyMetrics metrics, bool isBestWeek})> buildMetrics({
    required String userId,
    required String weekStartKey,
  }) async {
    final goal = await profile.getActiveGoal();
    if (goal == null) {
      return (metrics: WeeklyMetrics.empty, isBestWeek: false);
    }
    final weekEnd = Days.addDays(weekStartKey, 6);

    final weekEntries =
        await entries.entriesInRange(userId, weekStartKey, weekEnd);

    final allWeights = await body.weights(userId);
    final weekWeights = allWeights
        .where((w) => w.day.compareTo(weekStartKey) >= 0 &&
            w.day.compareTo(weekEnd) <= 0)
        .toList();

    // Measurements: latest on/before start vs latest on/before end, per site.
    final allMeas = await body.measurements(userId);
    final bySite = groupBy(allMeas, (m) => m.site);
    final measStart = <String, double>{};
    final measEnd = <String, double>{};
    bySite.forEach((site, list) {
      list.sort((a, b) => a.day.compareTo(b.day));
      final start =
          list.lastWhereOrNull((m) => m.day.compareTo(weekStartKey) <= 0);
      final end = list.lastWhereOrNull((m) => m.day.compareTo(weekEnd) <= 0);
      if (start != null) measStart[site] = start.valueCm;
      if (end != null) measEnd[site] = end.valueCm;
    });

    final water = await body.waterInRange(userId, weekStartKey, weekEnd);

    final metrics = WeeklyMetricsCalculator.compute(
      weekStartKey: weekStartKey,
      goal: goal,
      weekEntries: weekEntries,
      weekWeights: weekWeights,
      measurementStart: measStart,
      measurementEnd: measEnd,
      waterByDay: water,
      waterGoalMl: waterGoalMl,
    );
    final best = WeeklyMetricsCalculator.isBestWeek(metrics, goal);
    return (metrics: metrics, isBestWeek: best);
  }

  /// Persist the review and (by default) a Capsule built from it.
  Future<WeeklyReview> saveReview({
    required String userId,
    required String weekStartKey,
    required WeeklyMetrics metrics,
    required WeeklyAnswers answers,
    required bool isBestWeek,
    required bool saveCapsule,
    List<String> capsulePhotoIds = const [],
    List<String> capsuleTags = const [],
  }) async {
    final now = DateTime.now();
    final reviewVaultItemId = _uuid.v4();
    final reviewId = _uuid.v4();

    String? capsuleId;
    if (saveCapsule) {
      capsuleId = await _saveCapsuleFromReview(
        userId: userId,
        day: Days.addDays(weekStartKey, 6),
        metrics: metrics,
        answers: answers,
        isBestWeek: isBestWeek,
        photoIds: capsulePhotoIds,
        tags: capsuleTags,
        now: now,
      );
    }

    final review = WeeklyReview(
      id: reviewId,
      vaultItemId: reviewVaultItemId,
      userId: userId,
      weekStart: weekStartKey,
      metrics: metrics,
      answers: answers,
      isBestWeek: isBestWeek,
      savedCapsuleId: capsuleId,
      createdAt: now,
    );
    final reviewItem = VaultItem(
      id: reviewVaultItemId,
      userId: userId,
      type: VaultItemType.weeklyReview,
      day: weekStartKey,
      title: isBestWeek
          ? 'Best week · ${Days.prettyMonthDay(weekStartKey)}'
          : 'Weekly review · ${Days.prettyMonthDay(weekStartKey)}',
      refId: reviewId,
      createdAt: now,
    );
    await vault.insertReview(reviewItem, review);
    return review;
  }

  Future<String> _saveCapsuleFromReview({
    required String userId,
    required String day,
    required WeeklyMetrics metrics,
    required WeeklyAnswers answers,
    required bool isBestWeek,
    required List<String> photoIds,
    required List<String> tags,
    required DateTime now,
  }) async {
    final latestWeight = await body.latestWeight(userId);
    final vaultItemId = _uuid.v4();
    final capsuleId = _uuid.v4();
    final effectiveTags = [
      ...tags,
      if (isBestWeek && !tags.contains('best week')) 'best week',
    ];

    final capsule = ProgressCapsule(
      id: capsuleId,
      vaultItemId: vaultItemId,
      userId: userId,
      day: day,
      weightTrendKg: latestWeight?.trendValueKg,
      measurements: const {},
      photoIds: photoIds,
      wkAvgKcal: metrics.avgKcal,
      wkAvgProtein: metrics.avgProtein,
      macroConsistency: metrics.calorieAdherence,
      waterConsistency: metrics.waterConsistency,
      whatWorked: answers.whatWorked,
      whatDidnt: answers.whatHurt,
      whatToRepeat: answers.whatToRepeat,
      moodNotes: answers.reflection,
      tags: effectiveTags,
      createdAt: now,
    );
    final item = VaultItem(
      id: vaultItemId,
      userId: userId,
      type: VaultItemType.capsule,
      day: day,
      title: isBestWeek
          ? 'Best week capsule · ${Days.prettyMonthDay(day)}'
          : 'Capsule · ${Days.prettyMonthDay(day)}',
      refId: capsuleId,
      createdAt: now,
    );
    await vault.insertCapsule(item, capsule);
    return capsuleId;
  }
}
