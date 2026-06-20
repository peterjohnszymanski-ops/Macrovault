import 'package:macrovault/models/enums.dart';

/// The single local user (Phase 1 is single-profile; [id] is reserved so a
/// future multi-profile mode is a non-breaking change).
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.units,
    required this.sex,
    required this.birthYear,
    required this.heightCm,
    required this.vaultLockEnabled,
    required this.aiConsent,
    this.aiProxyUrl,
    required this.createdAt,
  });

  final String id;
  final String name;
  final Units units;
  final Sex sex;
  final int birthYear;
  final double heightCm;
  final bool vaultLockEnabled;
  final bool aiConsent; // opt-in; gates the food-photo AI.
  final String? aiProxyUrl; // user's vision proxy endpoint (never an API key).
  final DateTime createdAt;

  /// The food-photo AI is usable only when explicitly enabled with an endpoint.
  bool get aiPhotoReady =>
      aiConsent && (aiProxyUrl?.trim().isNotEmpty ?? false);

  int get ageYears => DateTime.now().year - birthYear;

  AppUser copyWith({
    String? name,
    Units? units,
    Sex? sex,
    int? birthYear,
    double? heightCm,
    bool? vaultLockEnabled,
    bool? aiConsent,
    String? aiProxyUrl,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        units: units ?? this.units,
        sex: sex ?? this.sex,
        birthYear: birthYear ?? this.birthYear,
        heightCm: heightCm ?? this.heightCm,
        vaultLockEnabled: vaultLockEnabled ?? this.vaultLockEnabled,
        aiConsent: aiConsent ?? this.aiConsent,
        aiProxyUrl: aiProxyUrl ?? this.aiProxyUrl,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'units': units.storageValue,
        'sex': sex.storageValue,
        'birth_year': birthYear,
        'height_cm': heightCm,
        'vault_lock_enabled': vaultLockEnabled ? 1 : 0,
        'ai_consent': aiConsent ? 1 : 0,
        'ai_proxy_url': aiProxyUrl,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory AppUser.fromMap(Map<String, Object?> m) => AppUser(
        id: m['id'] as String,
        name: m['name'] as String? ?? 'You',
        units: Units.fromStorage(m['units'] as String? ?? 'metric'),
        sex: Sex.fromStorage(m['sex'] as String? ?? 'male'),
        birthYear: (m['birth_year'] as int?) ?? 1990,
        heightCm: (m['height_cm'] as num?)?.toDouble() ?? 175,
        vaultLockEnabled: (m['vault_lock_enabled'] as int? ?? 0) == 1,
        aiConsent: (m['ai_consent'] as int? ?? 0) == 1,
        aiProxyUrl: m['ai_proxy_url'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['created_at'] as int?) ?? 0),
      );
}
