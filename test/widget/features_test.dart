import 'dart:io';
import 'dart:ui' as ui;

import 'package:fit_lab/app/app.dart';
import 'package:fit_lab/core/constants/categories.dart';
import 'package:fit_lab/core/constants/moods.dart';
import 'package:fit_lab/data/models/clothing_item.dart';
import 'package:fit_lab/screens/add_edit_clothing/batch_add_screen.dart';
import 'package:fit_lab/widgets/clothing_card.dart';
import 'package:fit_lab/widgets/mood_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fixtures.dart';

late AppDependencies _deps;

Future<void> pumpApp(
  WidgetTester tester, {
  List<ClothingItem> seed = const [],
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    _deps = await testDependencies(seed: seed);
    await tester.pumpWidget(
      FitLabApp(
        dependencies: _deps,
        useGoogleFonts: false,
        generatorRevealDelay: Duration.zero,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

/// Lets real database and file work finish, then settles the UI. Keeps
/// going while a progress spinner shows, since it never stops animating.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

bool moodSelected(WidgetTester tester, Mood mood) => tester
    .widgetList<MoodChip>(find.byType(MoodChip))
    .any((c) => c.mood == mood && c.selected);

void main() {
  final recent = DateTime.now().subtract(const Duration(days: 2));

  testWidgets('a piece can have several moods', (tester) async {
    await pumpApp(
      tester,
      seed: [piece('Tee', ClothingCategory.top, Mood.casual)],
    );
    await tester.tap(find.byTooltip('Add a piece'));
    await tester.pumpAndSettle();

    expect(moodSelected(tester, Mood.casual), isTrue);
    await tester.ensureVisible(find.text('Chic'));
    await tester.tap(find.text('Chic'));
    await tester.pumpAndSettle();
    expect(moodSelected(tester, Mood.casual), isTrue);
    expect(moodSelected(tester, Mood.chic), isTrue);

    // Deselecting works, but the last mood can't be removed.
    await tester.tap(find.text('Casual'));
    await tester.pumpAndSettle();
    expect(moodSelected(tester, Mood.casual), isFalse);
    await tester.tap(find.text('Chic'));
    await tester.pumpAndSettle();
    expect(moodSelected(tester, Mood.chic), isTrue);
  });

  testWidgets('"Style this piece" opens the generator with it pinned', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: [
        piece(
          'Silk blouse',
          ClothingCategory.top,
          Mood.chic,
          createdAt: recent,
        ),
        piece('Black trousers', ClothingCategory.bottom, Mood.chic),
        piece('Pleated skirt', ClothingCategory.bottom, Mood.chic),
      ],
    );

    await tester.tap(find.text('Silk blouse'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Style this piece'));
    await tester.tap(find.text('Style this piece'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.text('choose a mood'), findsOneWidget);
    expect(find.text('Silk blouse'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    expect(find.text('Shuffle rest'), findsOneWidget);

    // Shuffling keeps the pinned blouse.
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.text('Shuffle rest'));
      await tester.tap(find.text('Shuffle rest'));
      await tester.pumpAndSettle();
      expect(find.text('Silk blouse'), findsOneWidget);
    }

    // Unpinning restores the plain Shuffle button.
    await tester.tap(find.byTooltip('Unpin piece'));
    await tester.pumpAndSettle();
    expect(find.text('Shuffle'), findsOneWidget);
  });

  testWidgets('pieces with several moods ask which mood to style', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: [
        piece(
          'White tee',
          ClothingCategory.top,
          Mood.minimal,
          extraMoods: [Mood.sporty],
          createdAt: recent,
        ),
        piece('Joggers', ClothingCategory.bottom, Mood.sporty),
      ],
    );
    await tester.tap(find.text('White tee'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Style this piece'));
    await tester.tap(find.text('Style this piece'));
    await tester.pumpAndSettle();
    expect(find.text('style it for which mood?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Sporty'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.textContaining('your sporty look'), findsOneWidget);
    expect(find.text('Joggers'), findsOneWidget);
  });

  testWidgets('"Wore this today" records and undoes a wear', (tester) async {
    await pumpApp(
      tester,
      seed: [
        piece('Cardigan', ClothingCategory.top, Mood.cozy, createdAt: recent),
      ],
    );
    await tester.tap(find.text('Cardigan'));
    await tester.pumpAndSettle();
    expect(find.text('not worn yet'), findsOneWidget);

    await tester.ensureVisible(find.text('Wore this today'));
    await tester.tap(find.text('Wore this today'));
    await settle(tester);
    expect(find.text('Worn today'), findsOneWidget);
    expect(find.text('worn once · last worn today'), findsOneWidget);

    await tester.tap(find.text('Worn today'));
    await settle(tester);
    expect(find.text('Wore this today'), findsOneWidget);
  });

  testWidgets('forgotten pieces get a banner and a filter', (tester) async {
    await pumpApp(
      tester,
      seed: [
        piece('Old scarf', ClothingCategory.accessory, Mood.vintage),
        piece('Old boots', ClothingCategory.shoes, Mood.vintage),
        piece('New top', ClothingCategory.top, Mood.vintage, createdAt: recent),
      ],
    );

    expect(find.text("2 pieces you haven't worn in a month"), findsOneWidget);
    await tester.tap(find.text("2 pieces you haven't worn in a month"));
    await tester.pumpAndSettle();
    expect(find.byType(ClothingCard), findsNWidgets(2));
    expect(find.text('New top'), findsNothing);
    expect(find.text('Forgotten'), findsOneWidget);

    await tester.tap(find.byTooltip('Show all pieces'));
    await tester.pumpAndSettle();
    expect(find.byType(ClothingCard), findsNWidgets(3));
  });

  testWidgets('batch add saves several pieces at once', (tester) async {
    await pumpApp(
      tester,
      seed: [
        piece('Tee', ClothingCategory.top, Mood.casual, createdAt: recent),
      ],
    );

    late List<String> photos;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('fitlab_batch_');
      photos = [];
      for (var i = 0; i < 2; i++) {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 20, 20),
          Paint()..color = const Color(0xFF3F5A7A),
        );
        final img = await recorder.endRecording().toImage(20, 20);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        final f = File(p.join(dir.path, 'p$i.png'))
          ..writeAsBytesSync(png!.buffer.asUint8List());
        photos.add(f.path);
      }
    });

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BatchAddScreen(
          photoPaths: photos,
          initialMoods: const {Mood.streetwear},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add 2 Pieces'), findsOneWidget);
    expect(moodSelected(tester, Mood.streetwear), isTrue);

    // Saving without categories explains what's missing.
    await tester.ensureVisible(find.text('Add 2 pieces'));
    await tester.tap(find.text('Add 2 pieces'));
    await tester.pumpAndSettle();
    expect(find.text('pick a category for 2 pieces'), findsOneWidget);

    await tester.ensureVisible(find.text('Bottom').first);
    await tester.tap(find.text('Bottom').first);
    await tester.ensureVisible(find.text('Shoes').last);
    await tester.tap(find.text('Shoes').last);
    await tester.enterText(find.byType(TextField).first, 'Cargo pants');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add 2 pieces'));
    await tester.tap(find.text('Add 2 pieces'));
    await settle(tester);
    await settle(tester);

    expect(find.byType(ClothingCard), findsNWidgets(3));
    expect(find.text('Cargo pants'), findsOneWidget);
    expect(find.text('Shoes'), findsWidgets); // unnamed piece uses category
    expect(find.text('2 pieces added to your wardrobe ♡'), findsOneWidget);
  });

  testWidgets('settings offer backup and restore', (tester) async {
    await pumpApp(
      tester,
      seed: [piece('Tee', ClothingCategory.top, Mood.chic)],
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Back up wardrobe'), findsOneWidget);
    expect(find.text('Restore from backup'), findsOneWidget);
  });
}
