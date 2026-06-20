import 'package:macrovault/models/enums.dart';

/// A private progress photo. The file at [relativePath] has already had its
/// EXIF/GPS stripped on import (see services/photo_storage.dart) and lives in
/// the app's private documents dir — never the camera roll.
///
/// No weight/calorie/macro data is ever embedded in the image bytes. Any
/// correlation is via the Vault, by date.
class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.userId,
    required this.day,
    required this.pose,
    required this.relativePath, // relative to app documents dir
    this.exifStripped = true,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String day;
  final Pose pose;
  final String relativePath;
  final bool exifStripped;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'day': day,
        'pose': pose.storageValue,
        'relative_path': relativePath,
        'exif_stripped': exifStripped ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ProgressPhoto.fromMap(Map<String, Object?> m) => ProgressPhoto(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        day: m['day'] as String,
        pose: Pose.fromStorage(m['pose'] as String),
        relativePath: m['relative_path'] as String,
        exifStripped: (m['exif_stripped'] as int? ?? 1) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['created_at'] as int?) ?? 0),
      );
}
