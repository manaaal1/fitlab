import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fit_lab/core/constants/categories.dart';
import 'package:fit_lab/core/constants/moods.dart';
import 'package:fit_lab/core/utils/image_storage.dart';
import 'package:fit_lab/data/backup/backup_service.dart';
import 'package:fit_lab/data/database/app_database.dart';
import 'package:fit_lab/data/models/outfit.dart';
import 'package:fit_lab/data/repositories/outfit_repository.dart';
import 'package:fit_lab/data/repositories/wardrobe_repository.dart';
import 'package:fit_lab/providers/wardrobe_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fixtures.dart';

void main() {
  sqfliteFfiInit();

  group('migration v3 -> v4', () {
    test('copies the single mood into moods and adds the wear log', () async {
      final dir = await Directory.systemTemp.createTemp('fitlab_v3_');
      final path = p.join(dir.path, 'fitlab.db');
      final v3 = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE clothes(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL, category TEXT NOT NULL,
                imagePath TEXT NOT NULL, mood TEXT NOT NULL,
                createdAt TEXT NOT NULL,
                isFavorite INTEGER NOT NULL DEFAULT 0,
                colorHex TEXT, notes TEXT)
            ''');
            await db.execute(
              'CREATE TABLE outfits(id INTEGER PRIMARY KEY, name TEXT, '
              'mood TEXT, createdAt TEXT, isFavorite INTEGER, itemCount INTEGER)',
            );
            await db.execute(
              'CREATE TABLE outfit_items(outfitId INTEGER, clothingId INTEGER, '
              'position INTEGER, PRIMARY KEY (outfitId, clothingId))',
            );
          },
        ),
      );
      await v3.insert('clothes', {
        'name': 'Blazer',
        'category': 'outerwear',
        'imagePath': 'a.jpg',
        'mood': 'darkAcademia',
        'createdAt': DateTime(2026).toIso8601String(),
      });
      await v3.close();

      final db = await AppDatabase.open(
        path: path,
        factory: databaseFactoryFfiNoIsolate,
      );
      final repo = WardrobeRepository(db, await tempImageStorage());
      final blazer = (await repo.getAll()).single;
      expect(blazer.moods, [Mood.darkAcademia]);
      expect(blazer.wearCount, 0);
      await repo.markWorn([blazer.id!], DateTime(2026, 5, 1));
      expect((await repo.getAll()).single.wearCount, 1);
      await db.close();
      await dir.delete(recursive: true);
    });
  });

  group('wear log', () {
    late Database db;
    late WardrobeRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = WardrobeRepository(db, await tempImageStorage());
    });
    tearDown(() => db.close());

    test('counts distinct days and tracks the latest', () async {
      final tee = await repo.insert(
        piece('tee', ClothingCategory.top, Mood.minimal),
      );
      await repo.markWorn([tee.id!], DateTime(2026, 9, 1, 8));
      await repo.markWorn([tee.id!], DateTime(2026, 9, 1, 20)); // same day
      await repo.markWorn([tee.id!], DateTime(2026, 9, 14));
      var read = (await repo.getAll()).single;
      expect(read.wearCount, 2);
      expect(read.lastWornOn, DateTime(2026, 9, 14));

      await repo.unmarkWorn([tee.id!], DateTime(2026, 9, 14));
      read = (await repo.getAll()).single;
      expect(read.wearCount, 1);
      expect(read.lastWornOn, DateTime(2026, 9, 1));
    });

    test('deleting a piece removes its wear history', () async {
      final tee = await repo.insert(
        piece('tee', ClothingCategory.top, Mood.minimal),
      );
      await repo.markWorn([tee.id!], DateTime(2026, 9, 1));
      await repo.delete(tee);
      expect(await db.query('wear_log'), isEmpty);
    });
  });

  group('WardrobeProvider wear and forgotten', () {
    test('forgotten = not worn (or added) for 30+ days', () async {
      final db = await openTestDatabase();
      final images = await tempImageStorage();
      final repo = WardrobeRepository(db, images);
      final today = DateTime(2026, 10, 6);
      final provider = WardrobeProvider(
        repo,
        images,
        clock: () => today.add(const Duration(hours: 9)),
      );

      final fresh = await repo.insert(
        piece(
          'new',
          ClothingCategory.top,
          Mood.chic,
          createdAt: DateTime(2026, 10, 1),
        ),
      );
      final neverWorn = await repo.insert(
        piece(
          'old',
          ClothingCategory.top,
          Mood.chic,
          createdAt: DateTime(2026, 6, 1),
        ),
      );
      final wornLongAgo = await repo.insert(
        piece(
          'stale',
          ClothingCategory.top,
          Mood.chic,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      final wornRecently = await repo.insert(
        piece(
          'loved',
          ClothingCategory.top,
          Mood.chic,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      await repo.markWorn([wornLongAgo.id!], DateTime(2026, 8, 1));
      await repo.markWorn([wornRecently.id!], DateTime(2026, 9, 30));
      await provider.load();

      expect(provider.forgotten.map((i) => i.name), ['old', 'stale']);
      expect(provider.isForgotten(provider.byId(fresh.id)!), isFalse);
      expect(provider.isForgotten(provider.byId(neverWorn.id)!), isTrue);

      provider.setForgottenOnly(true);
      expect(provider.filtered.map((i) => i.name), ['old', 'stale']);

      await provider.markWornToday([provider.byId(neverWorn.id)!]);
      expect(provider.wornToday(provider.byId(neverWorn.id)!), isTrue);
      expect(provider.forgotten.map((i) => i.name), ['stale']);

      await provider.unmarkWornToday([provider.byId(neverWorn.id)!]);
      expect(provider.wornToday(provider.byId(neverWorn.id)!), isFalse);
      await db.close();
    });
  });

  group('BackupService', () {
    late Database db;
    late ImageStorage images;
    late WardrobeRepository wardrobe;
    late OutfitRepository outfits;
    late BackupService backup;

    Future<String> photo(List<int> bytes) async {
      final src = File(p.join(images.root.path, 'src-${bytes.first}.png'))
        ..writeAsBytesSync(bytes);
      final stored = await images.persist(src.path);
      src.deleteSync();
      return stored;
    }

    setUp(() async {
      db = await openTestDatabase();
      images = await tempImageStorage();
      wardrobe = WardrobeRepository(db, images);
      outfits = OutfitRepository(db);
      backup = BackupService(db, images);
    });
    tearDown(() => db.close());

    test('round-trips pieces, moods, looks, wear and photos', () async {
      final tee = await wardrobe.insert(
        piece(
          'tee',
          ClothingCategory.top,
          Mood.minimal,
          extraMoods: [Mood.cleanGirl],
          colorHex: 'FFFFFF',
          favorite: true,
        ).copyWith(imagePath: await photo([1, 2, 3])),
      );
      final jeans = await wardrobe.insert(
        piece(
          'jeans',
          ClothingCategory.bottom,
          Mood.minimal,
        ).copyWith(imagePath: await photo([4, 5, 6])),
      );
      await outfits.save(
        Outfit(
          name: 'errands',
          mood: Mood.minimal,
          items: [tee, jeans],
          createdAt: DateTime(2026, 9, 9),
          isFavorite: true,
        ),
      );
      await wardrobe.markWorn([tee.id!], DateTime(2026, 9, 10));

      final zip = await backup.export(appVersion: '1.1.0');
      final manifest = backup.inspect(zip);
      expect(manifest['pieces'], 2);
      expect(manifest['looks'], 1);
      expect(manifest['photos'], 2);
      expect(manifest['appVersion'], '1.1.0');

      // Restore into a different, non-empty device.
      final db2 = await openTestDatabase();
      final images2 = await tempImageStorage();
      final wardrobe2 = WardrobeRepository(db2, images2);
      await wardrobe2.insert(piece('old', ClothingCategory.top, Mood.edgy));
      final summary = await BackupService(db2, images2).restore(zip);
      expect(summary.pieces, 2);
      expect(summary.looks, 1);
      expect(summary.photos, 2);

      final items = await wardrobe2.getAll();
      expect(items.map((i) => i.name).toSet(), {'tee', 'jeans'});
      final tee2 = items.firstWhere((i) => i.name == 'tee');
      expect(tee2.moods, [Mood.cleanGirl, Mood.minimal]);
      expect(tee2.colorHex, 'FFFFFF');
      expect(tee2.isFavorite, isTrue);
      expect(tee2.wearCount, 1);
      expect(File(images2.resolve(tee2.imagePath)).readAsBytesSync(), [
        1,
        2,
        3,
      ]);

      final look = (await OutfitRepository(db2).getAll()).single;
      expect(look.name, 'errands');
      expect(look.items.map((i) => i.name), ['tee', 'jeans']);
      await db2.close();
    });

    test('rejects files that are not FitLab backups', () async {
      expect(
        () => backup.inspect(Uint8List.fromList(utf8.encode('hello'))),
        throwsA(isA<BackupException>()),
      );
      final otherZip = ZipEncoder().encodeBytes(
        Archive()..addFile(ArchiveFile.string('notes.txt', 'hi')),
      );
      expect(() => backup.inspect(otherZip), throwsA(isA<BackupException>()));
    });

    test('rejects backups from a newer app version', () async {
      final zip = ZipEncoder().encodeBytes(
        Archive()..addFile(
          ArchiveFile.string(
            'manifest.json',
            jsonEncode({
              'format': BackupService.format,
              'formatVersion': 1,
              'schemaVersion': AppDatabase.version + 1,
            }),
          ),
        ),
      );
      expect(
        () => backup.inspect(zip),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('a damaged backup leaves the current wardrobe untouched', () async {
      final keep = await wardrobe.insert(
        piece(
          'keep me',
          ClothingCategory.top,
          Mood.chic,
        ).copyWith(imagePath: await photo([9, 9])),
      );
      final zip = ZipEncoder().encodeBytes(
        Archive()
          ..addFile(
            ArchiveFile.string(
              'manifest.json',
              jsonEncode({
                'format': BackupService.format,
                'formatVersion': 1,
                'schemaVersion': AppDatabase.version,
              }),
            ),
          )
          // A piece row missing required columns makes the insert fail.
          ..addFile(
            ArchiveFile.string(
              'data.json',
              jsonEncode({
                'clothes': [
                  {'id': 1, 'imagePath': 'x.png'},
                ],
              }),
            ),
          )
          ..addFile(ArchiveFile.bytes('photos/x.png', [7, 7])),
      );
      await expectLater(backup.restore(zip), throwsA(isA<BackupException>()));
      final items = await wardrobe.getAll();
      expect(items.single.name, 'keep me');
      expect(File(images.resolve(keep.imagePath)).existsSync(), isTrue);
      // Only the original photo remains; the half-restored one was removed.
      expect(images.root.listSync().length, 1);
    });
  });
}
