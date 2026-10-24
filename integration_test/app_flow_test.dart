// End-to-end flow on a real device or emulator:
//   flutter test integration_test
//
// Uses the platform's real sqflite and file system, with a fresh in-memory
// database so the user's own wardrobe is never touched. The image picker
// can't be automated, so pieces are seeded directly.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fit_lab/app/app.dart';
import 'package:fit_lab/core/constants/categories.dart';
import 'package:fit_lab/core/constants/moods.dart';
import 'package:fit_lab/core/utils/image_storage.dart';
import 'package:fit_lab/data/backup/backup_service.dart';
import 'package:fit_lab/data/database/app_database.dart';
import 'package:fit_lab/data/models/clothing_item.dart';
import 'package:fit_lab/data/repositories/outfit_repository.dart';
import 'package:fit_lab/data/repositories/wardrobe_repository.dart';
import 'package:fit_lab/widgets/clothing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

Future<String> _photo(ImageStorage images, Color color, String name) async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 200, 260), Paint()..color = color);
  final image = await recorder.endRecording().toImage(200, 260);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(
    p.join(images.root.path, name),
  ).writeAsBytes(png!.buffer.asUint8List());
  return name;
}

Future<AppDependencies> _deps() async {
  SharedPreferences.setMockInitialValues({'seen_onboarding': false});
  final prefs = await SharedPreferences.getInstance();
  final tmp = await Directory.systemTemp.createTemp('fitlab_it_');
  final images = ImageStorage(tmp);
  final db = await AppDatabase.open(
    path: inMemoryDatabasePath,
    singleInstance: false,
  );
  final wardrobe = WardrobeRepository(db, images);

  Future<void> add(String name, ClothingCategory c, Color color) async {
    await wardrobe.insert(
      ClothingItem(
        name: name,
        category: c,
        imagePath: await _photo(images, color, '$name.png'),
        moods: const [Mood.cozy],
        createdAt: DateTime.now(),
      ),
    );
  }

  await add('Cream knit', ClothingCategory.top, const Color(0xFFE9DCC9));
  await add('Wide jeans', ClothingCategory.bottom, const Color(0xFF6C7A96));
  await add('Chunky boots', ClothingCategory.shoes, const Color(0xFF5B4636));

  return AppDependencies(
    prefs: prefs,
    images: images,
    wardrobeRepository: wardrobe,
    outfitRepository: OutfitRepository(db),
    backup: BackupService(db, images),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding → wardrobe → generate → save → looks → delete', (
    tester,
  ) async {
    await tester.pumpWidget(FitLabApp(dependencies: await _deps()));
    await tester.pumpAndSettle();

    // Onboarding.
    expect(find.text('build your wardrobe'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Wardrobe shows the seeded pieces.
    expect(find.byType(ClothingCard), findsNWidgets(3));

    // Favourite a piece from its detail screen.
    await tester.tap(find.text('Cream knit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favourite'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Generate a cozy look.
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cozy'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Save look'), findsOneWidget);

    // Save it.
    await tester.ensureVisible(find.text('Save look'));
    await tester.tap(find.text('Save look'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Sunday market');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // It appears under Looks, grouped by mood.
    await tester.tap(find.text('Looks'));
    await tester.pumpAndSettle();
    expect(find.text('Sunday market'), findsOneWidget);
    expect(find.text('Cozy'), findsWidgets);

    // Swipe to delete, then undo.
    await tester.drag(find.text('Sunday market'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sunday market'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Sunday market'), findsOneWidget);
  });
}
