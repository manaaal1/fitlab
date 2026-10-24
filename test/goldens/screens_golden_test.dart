// Visual regression tests. Rendering differs slightly between operating
// systems, so these are tagged and excluded on CI (Linux). Regenerate with:
//   flutter test --tags golden --update-goldens
@Tags(['golden'])
library;

import 'dart:io';

import 'package:fit_lab/core/constants/categories.dart';
import 'package:fit_lab/core/constants/moods.dart';
import 'package:fit_lab/core/utils/look_image.dart';
import 'package:fit_lab/widgets/clothing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/fixtures.dart';
import '../helpers/golden_helpers.dart';

final _seed = [
  piece('Cream knit', ClothingCategory.top, Mood.cozy, favorite: true),
  piece('Wide leg jeans', ClothingCategory.bottom, Mood.cozy),
  piece('Chunky boots', ClothingCategory.shoes, Mood.cozy),
  piece('Wool coat', ClothingCategory.outerwear, Mood.cozy),
  piece('Silk slip dress', ClothingCategory.dress, Mood.chic),
  piece('Black blazer', ClothingCategory.outerwear, Mood.chic),
  piece('Pleated skirt', ClothingCategory.bottom, Mood.darkAcademia),
  piece('Oxford shirt', ClothingCategory.top, Mood.darkAcademia),
  piece('Tote bag', ClothingCategory.accessory, Mood.minimal),
];

/// flutter_test draws shadows as solid outlines by default. Turn real
/// shadows on for the body only, since the flag must be reset before the
/// framework's end-of-test checks.
void goldenWidgets(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}

void main() {
  goldenWidgets('onboarding', (tester) async {
    await pumpGoldenApp(tester, seed: const [], seenOnboarding: false);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('onboarding.png'),
    );
  });

  goldenWidgets('wardrobe light', (tester) async {
    await pumpGoldenApp(tester, seed: _seed);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('wardrobe_light.png'),
    );
  });

  goldenWidgets('wardrobe dark', (tester) async {
    await pumpGoldenApp(tester, seed: _seed, brightness: Brightness.dark);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('wardrobe_dark.png'),
    );
  });

  goldenWidgets('wardrobe empty', (tester) async {
    await pumpGoldenApp(tester, seed: const []);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('wardrobe_empty.png'),
    );
  });

  goldenWidgets('item detail', (tester) async {
    await pumpGoldenApp(tester, seed: _seed);
    await tester.tap(find.byType(ClothingCard).first);
    await tester.pumpAndSettle();
    await settleImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('item_detail.png'),
    );
  });

  goldenWidgets('add piece dark', (tester) async {
    await pumpGoldenApp(tester, seed: _seed, brightness: Brightness.dark);
    await tester.tap(find.byTooltip('Add a piece'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('add_piece_dark.png'),
    );
  });

  goldenWidgets('generator result', (tester) async {
    await pumpGoldenApp(tester, seed: _seed);
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cozy').last);
    await tester.pumpAndSettle();
    await settleImages(tester);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await settleImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('generator_result.png'),
    );
  });

  goldenWidgets('looks tab', (tester) async {
    await pumpGoldenApp(tester, seed: _seed);
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cozy').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save look'));
    await tester.tap(find.text('Save look'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks'));
    await tester.pumpAndSettle();
    await settleImages(tester);
    // Let the snackbar time out so it doesn't cover the list.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('looks_tab.png'),
    );
  });

  goldenWidgets('wide wardrobe', (tester) async {
    await pumpGoldenApp(
      tester,
      seed: _seed,
      logicalSize: const Size(1280, 800),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('wardrobe_wide.png'),
    );
  });

  goldenWidgets('wide generator', (tester) async {
    await pumpGoldenApp(
      tester,
      seed: _seed,
      logicalSize: const Size(1280, 800),
    );
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chic').last);
    await tester.pumpAndSettle();
    await settleImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('generator_wide.png'),
    );
  });

  goldenWidgets('share card renders a 1080x1350 PNG', (tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      final storage = await tempImageStorage();
      final items = await withFakePhotos(storage, _seed.take(4).toList());
      GoogleFonts.caveat(fontWeight: FontWeight.w700);
      GoogleFonts.poppins(fontStyle: FontStyle.italic);
      GoogleFonts.poppins(fontWeight: FontWeight.w600);
      await GoogleFonts.pendingFonts();
      final png = await LookImage.render(
        title: 'Sunday market',
        mood: Mood.cozy,
        items: items,
        resolvePath: storage.resolve,
        titleStyle: GoogleFonts.caveat(fontWeight: FontWeight.w700),
        bodyStyle: GoogleFonts.poppins(),
      );
      // PNG signature and IHDR width/height.
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      final header = png.buffer.asByteData(16, 8);
      expect(header.getUint32(0), 1080);
      expect(header.getUint32(4), 1350);
      final out = Directory('test/goldens/failures')
        ..createSync(recursive: true);
      File('${out.path}/share_card_preview.png').writeAsBytesSync(png);
    });
  });
}
