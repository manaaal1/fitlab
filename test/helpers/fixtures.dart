import 'dart:io';
import 'dart:math';
import 'package:fit_lab/app/app.dart';
import 'package:fit_lab/core/constants/categories.dart';
import 'package:fit_lab/core/constants/moods.dart';
import 'package:fit_lab/core/utils/image_storage.dart';
import 'package:fit_lab/data/backup/backup_service.dart';
import 'package:fit_lab/data/database/app_database.dart';
import 'package:fit_lab/data/models/clothing_item.dart';
import 'package:fit_lab/data/repositories/outfit_repository.dart';
import 'package:fit_lab/data/repositories/wardrobe_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _seq = 0;

ClothingItem piece(
  String name,
  ClothingCategory category,
  Mood mood, {
  int? id,
  bool favorite = false,
  List<Mood> extraMoods = const [],
  String? colorHex,
  DateTime? createdAt,
}) {
  _seq++;
  return ClothingItem(
    id: id ?? _seq,
    name: name,
    category: category,
    imagePath: 'missing-$name.jpg',
    moods: [mood, ...extraMoods],
    createdAt: createdAt ?? DateTime(2026, 1, 1).add(Duration(minutes: _seq)),
    isFavorite: favorite,
    colorHex: colorHex,
  );
}

Future<Database> openTestDatabase() {
  sqfliteFfiInit();
  return AppDatabase.open(
    path: inMemoryDatabasePath,
    factory: databaseFactoryFfiNoIsolate,
    // A fresh in-memory database per call, never a cached shared one.
    singleInstance: false,
  );
}

Future<ImageStorage> tempImageStorage() async {
  final dir = await Directory.systemTemp.createTemp('fitlab_test_');
  return ImageStorage(dir);
}

/// App dependencies backed by an in-memory database, seeded with [seed]
/// pieces (ids are reassigned by the database).
Future<AppDependencies> testDependencies({
  List<ClothingItem> seed = const [],
  bool seenOnboarding = true,
  ImageStorage? images,
}) async {
  SharedPreferences.setMockInitialValues({'seen_onboarding': seenOnboarding});
  final prefs = await SharedPreferences.getInstance();
  final db = await openTestDatabase();
  images ??= await tempImageStorage();
  final wardrobe = WardrobeRepository(db, images);
  for (final item in seed) {
    final map = item.toMap()..remove('id');
    await db.insert('clothes', map);
  }
  return AppDependencies(
    prefs: prefs,
    images: images,
    wardrobeRepository: wardrobe,
    outfitRepository: OutfitRepository(db),
    backup: BackupService(db, images),
    generatorRandom: Random(9),
    clock: () => DateTime(2026, 10, 6),
  );
}
