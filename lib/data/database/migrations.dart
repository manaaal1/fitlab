import 'package:sqflite/sqflite.dart';

import '../../core/constants/categories.dart';
import '../../core/constants/moods.dart';

/// Schema for a fresh install at the current version.
Future<void> createSchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE clothes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      imagePath TEXT NOT NULL,
      mood TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      isFavorite INTEGER NOT NULL DEFAULT 0,
      colorHex TEXT,
      notes TEXT,
      moods TEXT NOT NULL DEFAULT ''
    )
  ''');
  await _createOutfitTables(db);
  await _createWearLog(db);
}

/// One row per piece per day it was worn.
Future<void> _createWearLog(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE wear_log(
      clothingId INTEGER NOT NULL REFERENCES clothes(id) ON DELETE CASCADE,
      wornOn TEXT NOT NULL,
      PRIMARY KEY (clothingId, wornOn)
    )
  ''');
}

Future<void> _createOutfitTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE outfits(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      mood TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      isFavorite INTEGER NOT NULL DEFAULT 0,
      itemCount INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE outfit_items(
      outfitId INTEGER NOT NULL REFERENCES outfits(id) ON DELETE CASCADE,
      clothingId INTEGER NOT NULL REFERENCES clothes(id) ON DELETE CASCADE,
      position INTEGER NOT NULL,
      PRIMARY KEY (outfitId, clothingId)
    )
  ''');
}

/// Upgrade steps keyed by the version they upgrade *to*.
final Map<int, Future<void> Function(DatabaseExecutor db)> migrations = {
  3: _migrateToV3,
  4: _migrateToV4,
};

/// v4: pieces can have several moods, and wear history is recorded.
Future<void> _migrateToV4(DatabaseExecutor db) async {
  await db.execute(
    "ALTER TABLE clothes ADD COLUMN moods TEXT NOT NULL DEFAULT ''",
  );
  await db.execute('UPDATE clothes SET moods = mood');
  await _createWearLog(db);
}

/// v1/v2 had a single `clothes(id, name, category, imagePath, mood)` table
/// with free-text categories and mood labels.
Future<void> _migrateToV3(DatabaseExecutor db) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    "ALTER TABLE clothes ADD COLUMN createdAt TEXT NOT NULL DEFAULT ''",
  );
  await db.execute(
    'ALTER TABLE clothes ADD COLUMN isFavorite INTEGER NOT NULL DEFAULT 0',
  );
  await db.execute('ALTER TABLE clothes ADD COLUMN colorHex TEXT');
  await db.execute('ALTER TABLE clothes ADD COLUMN notes TEXT');

  // Normalise free text into the enums the generator understands.
  final rows = await db.query('clothes', columns: ['id', 'category', 'mood']);
  for (final row in rows) {
    await db.update(
      'clothes',
      {
        'category': ClothingCategory.fromString(
          row['category'] as String?,
        ).name,
        'mood': Mood.fromString(row['mood'] as String?).name,
        'createdAt': now,
      },
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  await _createOutfitTables(db);
}
