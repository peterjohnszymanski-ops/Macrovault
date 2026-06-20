import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Imports progress photos privately:
///  1. decode the source bytes,
///  2. re-encode to JPEG (this drops ALL EXIF/GPS metadata),
///  3. write into the app's private documents dir under `photos/`.
///
/// The image never touches the camera roll, and no health metrics are ever
/// embedded in the bytes.
class PhotoStorage {
  PhotoStorage();
  final _uuid = const Uuid();

  static const _subdir = 'photos';

  Future<Directory> _photosDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _subdir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Imports [sourcePath] (e.g. from image_picker), stripping metadata.
  /// Returns the path *relative* to the app documents dir, which is what gets
  /// persisted in the DB (absolute paths can change between launches on iOS).
  Future<String> importStripped(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unsupported image format');
    }
    // Re-encoding produces a clean JPEG with no EXIF/GPS payload.
    final clean = img.encodeJpg(decoded, quality: 88);

    final dir = await _photosDir();
    final fileName = '${_uuid.v4()}.jpg';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(clean, flush: true);
    return p.join(_subdir, fileName);
  }

  /// Resolve a stored relative path back to an absolute path for display.
  Future<String> absolutePath(String relativePath) async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, relativePath);
  }

  Future<File> file(String relativePath) async =>
      File(await absolutePath(relativePath));

  Future<void> deleteFile(String relativePath) async {
    final f = await file(relativePath);
    if (await f.exists()) await f.delete();
  }
}
