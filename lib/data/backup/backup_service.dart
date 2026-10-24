import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/utils/image_storage.dart';
import '../database/app_database.dart';

/// Thrown when a file is not a FitLab backup or can't be restored.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// What a restore brought back.
class RestoreSummary {
  const RestoreSummary({
    required this.pieces,
    required this.looks,
    required this.photos,
  });

  final int pieces;
  final int looks;
  final int photos;
}

/// Exports the whole wardrobe (database rows and photos) to one zip file,
/// and restores it, replacing what's on the device.
///
/// Zip layout:
/// * `manifest.json` – format name, format and schema versions, date, counts
/// * `data.json` – raw rows of every table
/// * `photos/<name>` – each piece's photo, referenced by `imagePath`
class BackupService {
  BackupService(this._db, this._images);

  final Database _db;
  final ImageStorage _images;

  static const String format = 'fitlab-backup';
  static const int formatVersion = 1;

  /// Tables in foreign-key order (parents first).
  static const List<String> tables = [
    'clothes',
    'outfits',
    'outfit_items',
    'wear_log',
  ];

  /// Builds the backup zip in memory.
  Future<Uint8List> export({String? appVersion, DateTime? now}) async {
    final archive = Archive();
    final data = <String, List<Map<String, Object?>>>{};

    for (final table in tables) {
      data[table] = [for (final row in await _db.query(table)) Map.of(row)];
    }

    var photos = 0;
    for (final row in data['clothes']!) {
      final stored = (row['imagePath'] as String?) ?? '';
      final file = File(_images.resolve(stored));
      if (stored.isEmpty || !await file.exists()) {
        row['imagePath'] = '';
        continue;
      }
      // Legacy absolute paths get a stable name inside the zip.
      final name = _images.isLegacyPath(stored)
          ? 'legacy-${row['id']}${p.extension(stored)}'
          : stored;
      archive.addFile(
        ArchiveFile.bytes('photos/$name', await file.readAsBytes()),
      );
      row['imagePath'] = name;
      photos++;
    }

    final manifest = {
      'format': format,
      'formatVersion': formatVersion,
      'schemaVersion': AppDatabase.version,
      'exportedAt': (now ?? DateTime.now()).toIso8601String(),
      'appVersion': ?appVersion,
      'pieces': data['clothes']!.length,
      'looks': data['outfits']!.length,
      'photos': photos,
    };
    archive
      ..addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)))
      ..addFile(ArchiveFile.string('data.json', jsonEncode(data)));
    return ZipEncoder().encodeBytes(archive);
  }

  /// Suggested file name, e.g. `fitlab-backup-2026-10-06.zip`.
  static String fileName(DateTime now) =>
      'fitlab-backup-${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}.zip';

  /// Reads a backup's manifest without changing anything. Throws
  /// [BackupException] when the file is not a usable FitLab backup.
  Map<String, Object?> inspect(Uint8List bytes) {
    final archive = _decode(bytes);
    return _manifest(archive);
  }

  /// Replaces the whole wardrobe with the backup's contents.
  ///
  /// New photos are written first and the database swap happens in one
  /// transaction, so a failure leaves the current wardrobe untouched.
  Future<RestoreSummary> restore(Uint8List bytes) async {
    final archive = _decode(bytes);
    _manifest(archive);
    final data = _data(archive);

    final oldPhotos = [
      for (final row in await _db.query('clothes', columns: ['imagePath']))
        (row['imagePath'] as String?) ?? '',
    ];

    // 1. Write photos under fresh names.
    final written = <String>[];
    final renamed = <String, String>{};
    try {
      for (final row in data['clothes'] ?? const <Map<String, Object?>>[]) {
        final name = (row['imagePath'] as String?) ?? '';
        if (name.isEmpty || renamed.containsKey(name)) continue;
        final entry = archive.findFile('photos/$name');
        if (entry == null) continue;
        final stored = await _images.persistBytes(
          entry.content,
          p.extension(name),
        );
        written.add(stored);
        renamed[name] = stored;
      }

      // 2. Swap the database contents in one transaction.
      await _db.transaction((txn) async {
        for (final table in tables.reversed) {
          await txn.delete(table);
        }
        for (final table in tables) {
          final columns = await _columns(txn, table);
          for (final row in data[table] ?? const <Map<String, Object?>>[]) {
            final clean = {
              for (final e in row.entries)
                if (columns.contains(e.key)) e.key: e.value,
            };
            if (table == 'clothes') {
              clean['imagePath'] = renamed[clean['imagePath']] ?? '';
            }
            await txn.insert(table, clean);
          }
        }
      });
    } catch (e) {
      for (final name in written) {
        await _images.delete(name);
      }
      if (e is BackupException) rethrow;
      throw BackupException('This backup could not be restored ($e).');
    }

    // 3. Only now remove the photos that belonged to the old wardrobe.
    for (final name in oldPhotos) {
      await _images.delete(name);
    }

    return RestoreSummary(
      pieces: data['clothes']?.length ?? 0,
      looks: data['outfits']?.length ?? 0,
      photos: written.length,
    );
  }

  static Archive _decode(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupException('This file is not a FitLab backup.');
    }
  }

  static Map<String, Object?> _manifest(Archive archive) {
    final file = archive.findFile('manifest.json');
    if (file == null) {
      throw const BackupException('This file is not a FitLab backup.');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(file.content));
    } catch (_) {
      throw const BackupException('This backup is damaged.');
    }
    if (json is! Map<String, Object?> || json['format'] != format) {
      throw const BackupException('This file is not a FitLab backup.');
    }
    final fv = json['formatVersion'];
    final sv = json['schemaVersion'];
    if (fv is! int || fv > formatVersion || sv is! int) {
      throw const BackupException(
        'This backup was made by a newer version of FitLab. '
        'Update the app and try again.',
      );
    }
    if (sv > AppDatabase.version) {
      throw const BackupException(
        'This backup was made by a newer version of FitLab. '
        'Update the app and try again.',
      );
    }
    return json;
  }

  static Map<String, List<Map<String, Object?>>> _data(Archive archive) {
    final file = archive.findFile('data.json');
    if (file == null) throw const BackupException('This backup is damaged.');
    try {
      final json = jsonDecode(utf8.decode(file.content)) as Map;
      return {
        for (final table in tables)
          table: [
            for (final row in (json[table] as List? ?? const []))
              Map<String, Object?>.from(row as Map),
          ],
      };
    } catch (_) {
      throw const BackupException('This backup is damaged.');
    }
  }

  static Future<Set<String>> _columns(DatabaseExecutor db, String table) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return {for (final c in info) c['name'] as String};
  }
}
