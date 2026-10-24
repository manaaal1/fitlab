import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns the folder where wardrobe photos live.
///
/// Photos are copied here when picked, so they survive the OS clearing the
/// image picker's cache. Only the file name is stored in the database; the
/// absolute path is rebuilt at read time because the app container path can
/// change between launches on iOS.
class ImageStorage {
  ImageStorage(this.root);

  final Directory root;

  static Future<ImageStorage> create() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'wardrobe'));
    await dir.create(recursive: true);
    return ImageStorage(dir);
  }

  /// Legacy rows stored absolute paths into the picker cache.
  bool isLegacyPath(String stored) => p.isAbsolute(stored);

  /// Absolute path to read the image from.
  String resolve(String stored) {
    if (stored.isEmpty || p.isAbsolute(stored)) return stored;
    return p.join(root.path, stored);
  }

  /// Copies [sourcePath] into the storage folder and returns the stored name.
  Future<String> persist(String sourcePath) async {
    final name = _newName(p.extension(sourcePath));
    await File(sourcePath).copy(p.join(root.path, name));
    return name;
  }

  /// Writes raw image bytes (e.g. from a backup) and returns the stored name.
  Future<String> persistBytes(List<int> bytes, String extension) async {
    final name = _newName(extension);
    await File(p.join(root.path, name)).writeAsBytes(bytes, flush: true);
    return name;
  }

  static String _newName(String extension) {
    final ext = extension.toLowerCase();
    return '${DateTime.now().microsecondsSinceEpoch}'
        '-${Random().nextInt(1 << 32).toRadixString(16)}'
        '${ext.isEmpty ? '.jpg' : ext}';
  }

  /// Deletes a stored image. Legacy absolute paths are left alone because
  /// FitLab does not own those files.
  Future<void> delete(String stored) async {
    if (stored.isEmpty || p.isAbsolute(stored)) return;
    final file = File(p.join(root.path, stored));
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Best effort: an orphaned file is harmless.
    }
  }
}
