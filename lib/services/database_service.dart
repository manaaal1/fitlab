import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/clothing_item.dart';

class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await initDatabase();

    return _database!;
  }

  static Future<Database> initDatabase() async {
    String path = join(await getDatabasesPath(), 'fitlab.db');

    return await openDatabase(
      path,
      version: 2,

      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE clothes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            category TEXT,
            imagePath TEXT,
            mood TEXT
          )
        ''');
      },
    );
  }

  // INSERT ITEM
  static Future<void> insertClothing(ClothingItem item) async {
    final db = await database;

    await db.insert('clothes', item.toMap());
  }

  // GET ALL ITEMS
  static Future<List<ClothingItem>> getClothingItems() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query('clothes');

    return List.generate(maps.length, (i) {
      return ClothingItem.fromMap(maps[i]);
    });
  }

  static Future<void> deleteClothing(int id) async {
    final db = await database;

    await db.delete('clothing', where: 'id = ?', whereArgs: [id]);
  }
}
