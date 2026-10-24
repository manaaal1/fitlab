import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:fit_lab/app/app.dart';
import 'package:fit_lab/core/utils/image_storage.dart';
import 'package:fit_lab/data/models/clothing_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

import 'fixtures.dart';

bool _fontsLoaded = false;

/// Loads every font in the asset FontManifest (Material icons) plus the
/// bundled Google Fonts, so goldens show real glyphs instead of boxes.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  GoogleFonts.config.allowRuntimeFetching = false;
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

/// Writes simple "garment" placeholder photos with varied aspect ratios so
/// the masonry grid looks realistic, and returns items pointing at them.
Future<List<ClothingItem>> withFakePhotos(
  ImageStorage images,
  List<ClothingItem> items,
) async {
  final rng = Random(7);
  final out = <ClothingItem>[];
  for (final item in items) {
    final w = 300;
    final h = [300, 380, 420, 340, 460][rng.nextInt(5)];
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final base = item.primaryMood.color;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w.toDouble(), h.toDouble()),
          [base, Color.lerp(base, const Color(0xFF3B2A1E), 0.35)!],
        ),
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.48),
      w * 0.26,
      Paint()..color = const Color(0x33FFFFFF),
    );
    final image = await recorder.endRecording().toImage(w, h);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final name = 'fake-${item.name.replaceAll(' ', '_')}.png';
    await File(
      p.join(images.root.path, name),
    ).writeAsBytes(png!.buffer.asUint8List());
    out.add(item.copyWith(imagePath: name));
  }
  return out;
}

/// Pumps the real app with fonts, fake photos and a seeded database.
Future<void> pumpGoldenApp(
  WidgetTester tester, {
  required List<ClothingItem> seed,
  Size logicalSize = const Size(412, 892),
  Brightness brightness = Brightness.light,
  bool seenOnboarding = true,
}) async {
  tester.view.physicalSize = logicalSize * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  await tester.runAsync(() async {
    await loadAppFonts();
    final storage = await tempImageStorage();
    final items = await withFakePhotos(storage, seed);
    await warmImageCache(storage.root.path);
    final deps = await testDependencies(
      seed: items,
      seenOnboarding: seenOnboarding,
      images: storage,
    );
    await tester.pumpWidget(
      FitLabApp(dependencies: deps, generatorRevealDelay: Duration.zero),
    );
    await GoogleFonts.pendingFonts();
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await settleImages(tester);
}

/// Decodes every photo in [dir] into the image cache using real async I/O,
/// at each size the app asks for (full, grid 600px, thumbnail 240px).
/// Loads started later inside the fake test clock would never finish.
Future<void> warmImageCache(String dir) async {
  for (final file in Directory(dir).listSync().whereType<File>()) {
    final base = FileImage(file);
    for (final provider in <ImageProvider>[
      base,
      ResizeImage(base, width: 600),
      ResizeImage(base, width: 240),
    ]) {
      final done = Completer<void>();
      final stream = provider.resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, _) {
          if (!done.isCompleted) done.complete();
          stream.removeListener(listener);
        },
        onError: (Object e, _) {
          if (!done.isCompleted) done.completeError(e);
        },
      );
      stream.addListener(listener);
      await done.future;
    }
  }
}

/// Settles animations; photos are already in the cache.
Future<void> settleImages(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}
