import 'dart:convert';

/// A Progress Capsule: the signature milestone record. Usually created from a
/// Weekly Review with metrics pre-filled, but can be authored manually.
///
/// Private health context lives here as structured fields — never embedded in
/// image metadata. [photoIds] links to ProgressPhoto rows by id.
class ProgressCapsule {
  const ProgressCapsule({
    required this.id,
    required this.vaultItemId,
    required this.userId,
    required this.day,
    this.weightTrendKg,
    this.measurements = const {},
    this.photoIds = const [],
    this.wkAvgKcal,
    this.wkAvgProtein,
    this.macroConsistency,
    this.waterConsistency,
    this.exerciseNotes = '',
    this.moodNotes = '',
    this.whatWorked = '',
    this.whatDidnt = '',
    this.whatToRepeat = '',
    this.tags = const [],
    required this.createdAt,
  });

  final String id;
  final String vaultItemId;
  final String userId;
  final String day;
  final double? weightTrendKg;
  final Map<String, double> measurements; // site -> cm
  final List<String> photoIds;
  final double? wkAvgKcal;
  final double? wkAvgProtein;
  final double? macroConsistency; // 0..1
  final double? waterConsistency; // 0..1
  final String exerciseNotes;
  final String moodNotes;
  final String whatWorked;
  final String whatDidnt;
  final String whatToRepeat;
  final List<String> tags;
  final DateTime createdAt;

  ProgressCapsule copyWith({
    Map<String, double>? measurements,
    List<String>? photoIds,
    String? exerciseNotes,
    String? moodNotes,
    String? whatWorked,
    String? whatDidnt,
    String? whatToRepeat,
    List<String>? tags,
  }) =>
      ProgressCapsule(
        id: id,
        vaultItemId: vaultItemId,
        userId: userId,
        day: day,
        weightTrendKg: weightTrendKg,
        measurements: measurements ?? this.measurements,
        photoIds: photoIds ?? this.photoIds,
        wkAvgKcal: wkAvgKcal,
        wkAvgProtein: wkAvgProtein,
        macroConsistency: macroConsistency,
        waterConsistency: waterConsistency,
        exerciseNotes: exerciseNotes ?? this.exerciseNotes,
        moodNotes: moodNotes ?? this.moodNotes,
        whatWorked: whatWorked ?? this.whatWorked,
        whatDidnt: whatDidnt ?? this.whatDidnt,
        whatToRepeat: whatToRepeat ?? this.whatToRepeat,
        tags: tags ?? this.tags,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'vault_item_id': vaultItemId,
        'user_id': userId,
        'day': day,
        'weight_trend_kg': weightTrendKg,
        'measurements_json': jsonEncode(measurements),
        'photo_ids_json': jsonEncode(photoIds),
        'wk_avg_kcal': wkAvgKcal,
        'wk_avg_protein': wkAvgProtein,
        'macro_consistency': macroConsistency,
        'water_consistency': waterConsistency,
        'exercise_notes': exerciseNotes,
        'mood_notes': moodNotes,
        'what_worked': whatWorked,
        'what_didnt': whatDidnt,
        'what_to_repeat': whatToRepeat,
        'tags_json': jsonEncode(tags),
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ProgressCapsule.fromMap(Map<String, Object?> m) {
    final meas = (jsonDecode(m['measurements_json'] as String? ?? '{}')
            as Map<String, Object?>)
        .map((k, v) => MapEntry(k, (v as num).toDouble()));
    final photos = (jsonDecode(m['photo_ids_json'] as String? ?? '[]')
            as List<Object?>)
        .cast<String>();
    final tags =
        (jsonDecode(m['tags_json'] as String? ?? '[]') as List<Object?>)
            .cast<String>();
    return ProgressCapsule(
      id: m['id'] as String,
      vaultItemId: m['vault_item_id'] as String,
      userId: m['user_id'] as String,
      day: m['day'] as String,
      weightTrendKg: (m['weight_trend_kg'] as num?)?.toDouble(),
      measurements: meas,
      photoIds: photos,
      wkAvgKcal: (m['wk_avg_kcal'] as num?)?.toDouble(),
      wkAvgProtein: (m['wk_avg_protein'] as num?)?.toDouble(),
      macroConsistency: (m['macro_consistency'] as num?)?.toDouble(),
      waterConsistency: (m['water_consistency'] as num?)?.toDouble(),
      exerciseNotes: m['exercise_notes'] as String? ?? '',
      moodNotes: m['mood_notes'] as String? ?? '',
      whatWorked: m['what_worked'] as String? ?? '',
      whatDidnt: m['what_didnt'] as String? ?? '',
      whatToRepeat: m['what_to_repeat'] as String? ?? '',
      tags: tags,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (m['created_at'] as int?) ?? 0),
    );
  }
}

/// Canonical tag suggestions offered in the Capsule editor.
const List<String> kCapsuleTagSuggestions = [
  'cutting',
  'bulking',
  'maintenance',
  'plateau',
  'vacation',
  'high protein',
  'best week',
  'off track',
  'reset week',
  'injury',
  'strength phase',
  'meal prep week',
];
