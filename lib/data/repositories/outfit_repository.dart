import 'package:sqflite/sqflite.dart';

import '../models/clothing_item.dart';
import '../models/outfit.dart';

class OutfitRepository {
  OutfitRepository(this._db);

  final Database _db;

  Future<List<Outfit>> getAll() async {
    final outfitRows = await _db.query(
      'outfits',
      orderBy: 'createdAt DESC, id DESC',
    );
    final itemRows = await _db.rawQuery('''
      SELECT oi.outfitId AS outfitId, c.*
      FROM outfit_items oi
      JOIN clothes c ON c.id = oi.clothingId
      ORDER BY oi.outfitId, oi.position
    ''');

    final itemsByOutfit = <int, List<ClothingItem>>{};
    for (final row in itemRows) {
      itemsByOutfit
          .putIfAbsent(row['outfitId'] as int, () => [])
          .add(ClothingItem.fromMap(row));
    }

    return outfitRows
        .map((row) => Outfit.fromMap(row, itemsByOutfit[row['id']] ?? []))
        .toList();
  }

  /// Inserts the look and its pieces. Keeps [Outfit.id] when present so an
  /// undone delete restores the same record.
  Future<Outfit> save(Outfit outfit) async {
    final id = await _db.transaction((txn) async {
      final id = await txn.insert('outfits', outfit.toMap());
      for (var i = 0; i < outfit.items.length; i++) {
        await txn.insert('outfit_items', {
          'outfitId': id,
          'clothingId': outfit.items[i].id,
          'position': i,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      return id;
    });
    return outfit.copyWith(id: id);
  }

  Future<void> delete(int id) async {
    await _db.delete('outfits', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setFavorite(int id, bool isFavorite) async {
    await _db.update(
      'outfits',
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> rename(int id, String name) async {
    await _db.update(
      'outfits',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
