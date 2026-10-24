import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../core/utils/image_storage.dart';
import '../models/clothing_item.dart';

class WardrobeRepository {
  WardrobeRepository(this._db, this._images);

  final Database _db;
  final ImageStorage _images;

  static const _table = 'clothes';

  /// Every piece, newest first, with wear history aggregated in.
  Future<List<ClothingItem>> getAll() async {
    final rows = await _db.rawQuery('''
      SELECT c.*, w.lastWornOn AS lastWornOn, w.wearCount AS wearCount
      FROM clothes c
      LEFT JOIN (
        SELECT clothingId, MAX(wornOn) AS lastWornOn, COUNT(*) AS wearCount
        FROM wear_log
        GROUP BY clothingId
      ) w ON w.clothingId = c.id
      ORDER BY c.createdAt DESC, c.id DESC
    ''');
    return rows.map(ClothingItem.fromMap).toList();
  }

  /// Records that each piece was worn on [day]. Wearing the same piece
  /// twice on one day counts once.
  Future<void> markWorn(Iterable<int> clothingIds, DateTime day) async {
    final batch = _db.batch();
    for (final id in clothingIds) {
      batch.insert('wear_log', {
        'clothingId': id,
        'wornOn': dayKey(day),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  /// Removes the wear record for [day] (undo for "wore this today").
  Future<void> unmarkWorn(Iterable<int> clothingIds, DateTime day) async {
    final batch = _db.batch();
    for (final id in clothingIds) {
      batch.delete(
        'wear_log',
        where: 'clothingId = ? AND wornOn = ?',
        whereArgs: [id, dayKey(day)],
      );
    }
    await batch.commit(noResult: true);
  }

  /// `yyyy-mm-dd`, which sorts correctly as text.
  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  Future<ClothingItem> insert(ClothingItem item) async {
    final map = item.toMap()..remove('id');
    final id = await _db.insert(_table, map);
    return item.copyWith(id: id);
  }

  Future<void> update(ClothingItem item) async {
    await _db.update(
      _table,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Deletes the row (cascading out of saved looks) and its photo.
  Future<void> delete(ClothingItem item) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [item.id]);
    await _images.delete(item.imagePath);
  }

  /// Removes every piece, every saved look and every stored photo.
  Future<void> deleteAll() async {
    final items = await getAll();
    await _db.transaction((txn) async {
      await txn.delete('wear_log');
      await txn.delete('outfit_items');
      await txn.delete('outfits');
      await txn.delete(_table);
    });
    for (final item in items) {
      await _images.delete(item.imagePath);
    }
  }

  /// Copies photos that older versions referenced in the picker cache into
  /// FitLab's own folder. Rows whose source file is already gone keep their
  /// path and render a placeholder.
  Future<int> relocateLegacyImages() async {
    var moved = 0;
    for (final item in await getAll()) {
      if (!_images.isLegacyPath(item.imagePath)) continue;
      if (!await File(item.imagePath).exists()) continue;
      final stored = await _images.persist(item.imagePath);
      await update(item.copyWith(imagePath: stored));
      moved++;
    }
    return moved;
  }
}
