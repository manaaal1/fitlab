import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'core/utils/image_storage.dart';
import 'data/backup/backup_service.dart';
import 'data/database/app_database.dart';
import 'data/repositories/outfit_repository.dart';
import 'data/repositories/wardrobe_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts ship in assets/google_fonts, so never download them at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final family in ['poppins', 'caveat']) {
      final text = await rootBundle.loadString(
        'assets/google_fonts/OFL-$family.txt',
      );
      yield LicenseEntryWithLineBreaks(['google_fonts'], text);
    }
  });

  // sqflite has no Windows/Linux implementation; use the FFI backend there.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final prefs = await SharedPreferences.getInstance();
  final images = await ImageStorage.create();
  final db = await AppDatabase.open(path: await AppDatabase.defaultPath());
  final wardrobeRepository = WardrobeRepository(db, images);

  try {
    // One-off move of photos that older builds left in the picker cache.
    await wardrobeRepository.relocateLegacyImages();
  } catch (e) {
    debugPrint('Legacy image reloc'
        '+ation skipped: $e');
  }

  runApp(
    FitLabApp(
      dependencies: AppDependencies(
        prefs: prefs,
        images: images,
        wardrobeRepository: wardrobeRepository,
        outfitRepository: OutfitRepository(db),
        backup: BackupService(db, images),
      ),
    ),
  );
}
