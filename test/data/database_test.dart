import 'dart:io';

import 'package:fit_lab/core/constants/categories.dart';
import 'package:fit_lab/core/constants/moods.dart';
import 'package:fit_lab/core/utils/image_storage.dart';
import 'package:fit_lab/data/database/app_database.dart';
import 'package:fit_lab/data/models/outfit.dart';
import 'package:fit_lab/data/repositories/outfit_repository.dart';
import 'package:fit_lab/data/repositories/wardrobe_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fixtures.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfiNoIsolate;

  group('migration v2 -> v3', () {
    late Directory dir;
    late String path;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fitlab_mig_');
      path = p.join(dir.path, 'fitlab.db');
      // Recreate the exact schema and data shape the original app wrote.
      final v2 = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) => db.execute('''
            CREATE TABLE clothes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              category TEXT,
              imagePath TEXT,
              mood TEXT
            )
          '''),
        ),
      );
      await v2.insert('clothes', {
        'name': 'Old jeans',
        'category': 'Jeans',
        'imagePath': '/data/cache/a.jpg',
        'mood': 'Clean Girl',
      });
      await v2.insert('clothes', {
        'name': 'Cardi',
        'category': 'top',
        'imagePath': '/data/cache/b.jpg',
        'mood': 'Cozy',
      });
      await v2.close();
    });

    tearDown(() => dir.delete(recursive: true));

    test('keeps existing rows and normalises them', () async {
      final db = await AppDatabase.open(path: path, factory: factory);
      final images = await tempImageStorage();
      final items = await WardrobeRepository(db, images).getAll();

      expect(items, hasLength(2));
      final jeans = items.firstWhere((i) => i.name == 'Old jeans');
      expect(jeans.category, ClothingCategory.bottom);
      expect(jeans.moods, [Mood.cleanGirl]);
      expect(jeans.isFavorite, isFalse);
      expect(jeans.createdAt.year, greaterThan(2000));

      final raw = await db.query('clothes', where: "name = 'Cardi'");
      expect(raw.single['mood'], 'cozy');
      expect(raw.single['category'], 'top');
      await db.close();
    });

    test('creates the outfit tables', () async {
      final db = await AppDatabase.open(path: path, factory: factory);
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final names = tables.map((r) => r['name']).toSet();
      expect(
        names,
        containsAll(['clothes', 'outfits', 'outfit_items', 'wear_log']),
      );
      expect(await db.getVersion(), AppDatabase.version);
      await db.close();
    });
  });

  group('WardrobeRepository', () {
    late Database db;
    late ImageStorage images;
    late WardrobeRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      images = await tempImageStorage();
      repo = WardrobeRepository(db, images);
    });

    tearDown(() => db.close());

    test('insert, read, update, delete', () async {
      final saved = await repo.insert(
        piece('tee', ClothingCategory.top, Mood.minimal),
      );
      expect(saved.id, isNotNull);
      expect((await repo.getAll()).single.name, 'tee');

      await repo.update(saved.copyWith(name: 'white tee', isFavorite: true));
      final updated = (await repo.getAll()).single;
      expect(updated.name, 'white tee');
      expect(updated.isFavorite, isTrue);

      await repo.delete(updated);
      expect(await repo.getAll(), isEmpty);
    });

    test('delete removes the stored photo', () async {
      final source = File(p.join(images.root.path, 'src.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      final stored = await images.persist(source.path);
      final item = await repo.insert(
        piece(
          'tee',
          ClothingCategory.top,
          Mood.minimal,
        ).copyWith(imagePath: stored),
      );
      expect(File(images.resolve(stored)).existsSync(), isTrue);
      await repo.delete(item);
      expect(File(images.resolve(stored)).existsSync(), isFalse);
    });

    test('relocates legacy absolute image paths', () async {
      final cacheDir = await Directory.systemTemp.createTemp('picker_cache_');
      final cached = File(p.join(cacheDir.path, 'cached.png'))
        ..writeAsBytesSync([9, 9, 9]);
      final gone = p.join(cacheDir.path, 'gone.png');
      await repo.insert(
        piece(
          'a',
          ClothingCategory.top,
          Mood.minimal,
        ).copyWith(imagePath: cached.path),
      );
      await repo.insert(
        piece(
          'b',
          ClothingCategory.top,
          Mood.minimal,
        ).copyWith(imagePath: gone),
      );

      expect(await repo.relocateLegacyImages(), 1);
      final items = await repo.getAll();
      final a = items.firstWhere((i) => i.name == 'a');
      final b = items.firstWhere((i) => i.name == 'b');
      expect(p.isAbsolute(a.imagePath), isFalse);
      expect(File(images.resolve(a.imagePath)).readAsBytesSync(), [9, 9, 9]);
      expect(b.imagePath, gone);
    });
  });

  group('OutfitRepository', () {
    late Database db;
    late WardrobeRepository wardrobe;
    late OutfitRepository outfits;

    setUp(() async {
      db = await openTestDatabase();
      wardrobe = WardrobeRepository(db, await tempImageStorage());
      outfits = OutfitRepository(db);
    });

    tearDown(() => db.close());

    test('saves and hydrates looks with items in order', () async {
      final top = await wardrobe.insert(
        piece('top', ClothingCategory.top, Mood.chic),
      );
      final bottom = await wardrobe.insert(
        piece('bottom', ClothingCategory.bottom, Mood.chic),
      );
      await outfits.save(
        Outfit(
          name: 'date night',
          mood: Mood.chic,
          items: [top, bottom],
          createdAt: DateTime(2026),
        ),
      );

      final look = (await outfits.getAll()).single;
      expect(look.name, 'date night');
      expect(look.items.map((i) => i.name), ['top', 'bottom']);
      expect(look.missingCount, 0);
    });

    test('deleting a piece cascades out of saved looks', () async {
      final top = await wardrobe.insert(
        piece('top', ClothingCategory.top, Mood.chic),
      );
      final bottom = await wardrobe.insert(
        piece('bottom', ClothingCategory.bottom, Mood.chic),
      );
      await outfits.save(
        Outfit(
          name: 'look',
          mood: Mood.chic,
          items: [top, bottom],
          createdAt: DateTime(2026),
        ),
      );

      await wardrobe.delete(top);
      final look = (await outfits.getAll()).single;
      expect(look.items.map((i) => i.name), ['bottom']);
      expect(look.missingCount, 1);
    });

    test('favourite, rename, delete and restore', () async {
      final top = await wardrobe.insert(
        piece('top', ClothingCategory.top, Mood.chic),
      );
      final saved = await outfits.save(
        Outfit(
          name: 'look',
          mood: Mood.chic,
          items: [top],
          createdAt: DateTime(2026),
        ),
      );

      await outfits.setFavorite(saved.id!, true);
      await outfits.rename(saved.id!, 'renamed');
      var look = (await outfits.getAll()).single;
      expect(look.isFavorite, isTrue);
      expect(look.name, 'renamed');

      await outfits.delete(saved.id!);
      expect(await outfits.getAll(), isEmpty);

      await outfits.save(look);
      look = (await outfits.getAll()).single;
      expect(look.id, saved.id);
      expect(look.items.single.name, 'top');
    });

    test('deleteAll clears pieces and looks', () async {
      final top = await wardrobe.insert(
        piece('top', ClothingCategory.top, Mood.chic),
      );
      await outfits.save(
        Outfit(
          name: 'look',
          mood: Mood.chic,
          items: [top],
          createdAt: DateTime(2026),
        ),
      );
      await wardrobe.deleteAll();
      expect(await wardrobe.getAll(), isEmpty);
      expect(await outfits.getAll(), isEmpty);
    });
  });
}
