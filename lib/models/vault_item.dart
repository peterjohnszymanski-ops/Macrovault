import 'package:macrovault/models/enums.dart';

/// The polymorphic base record for everything stored in the Progress Vault.
/// [refId] points at the specialised row (a capsule, a weekly review, etc.).
class VaultItem {
  const VaultItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.day,
    required this.title,
    required this.refId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final VaultItemType type;
  final String day;
  final String title;
  final String? refId;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'type': type.storageValue,
        'day': day,
        'title': title,
        'ref_id': refId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory VaultItem.fromMap(Map<String, Object?> m) => VaultItem(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        type: VaultItemType.fromStorage(m['type'] as String),
        day: m['day'] as String,
        title: m['title'] as String? ?? 'Vault item',
        refId: m['ref_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['created_at'] as int?) ?? 0),
      );
}
