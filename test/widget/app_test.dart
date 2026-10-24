import 'package:fit_lab/app/app.dart';
import 'package:fit_lab/core/constants/categories.dart';
import 'package:fit_lab/core/constants/moods.dart';
import 'package:fit_lab/data/models/clothing_item.dart';
import 'package:fit_lab/screens/home/wardrobe_tab.dart';
import 'package:fit_lab/widgets/clothing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';

/// Pumps the real app over an in-memory database. Database work runs in
/// [WidgetTester.runAsync] because sqflite uses real async I/O.
Future<void> pumpApp(
  WidgetTester tester, {
  List<ClothingItem> seed = const [],
  bool seenOnboarding = true,
  Size size = const Size(420, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.runAsync(() async {
    final deps = await testDependencies(
      seed: seed,
      seenOnboarding: seenOnboarding,
    );
    await tester.pumpWidget(
      FitLabApp(
        dependencies: deps,
        useGoogleFonts: false,
        generatorRevealDelay: Duration.zero,
      ),
    );
    // Let the providers' initial loads finish.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

final _seed = [
  piece('Cream knit', ClothingCategory.top, Mood.cozy, favorite: true),
  piece('Wide jeans', ClothingCategory.bottom, Mood.cozy),
  piece('Silk slip', ClothingCategory.dress, Mood.chic),
  piece('Chunky boots', ClothingCategory.shoes, Mood.cozy),
];

void main() {
  test('grid columns scale with width', () {
    expect(columnsForWidth(360), 2);
    expect(columnsForWidth(600), 3);
    expect(columnsForWidth(1400), 6);
  });

  testWidgets('first launch shows onboarding, then the empty wardrobe', (
    tester,
  ) async {
    await pumpApp(tester, seenOnboarding: false);
    expect(find.text('build your wardrobe'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('your wardrobe is feeling a little empty ♡'), findsOne);
    expect(find.text('Add your first piece'), findsOneWidget);
  });

  testWidgets('wardrobe shows every piece with mood filters', (tester) async {
    await pumpApp(tester, seed: _seed);

    expect(find.byType(ClothingCard), findsNWidgets(4));
    expect(find.text('Cozy'), findsOneWidget);
    expect(find.text('Chic'), findsOneWidget);

    await tester.tap(find.text('Chic'));
    await tester.pumpAndSettle();
    expect(find.byType(ClothingCard), findsOneWidget);
    expect(find.text('Silk slip'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.byType(ClothingCard), findsNWidgets(4));
  });

  testWidgets('search and favourites narrow the grid', (tester) async {
    await pumpApp(tester, seed: _seed);

    await tester.enterText(find.byType(TextField), 'jeans');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byType(ClothingCard), findsOneWidget);
    expect(find.text('Wide jeans'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('no pieces match'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.byType(ClothingCard), findsNWidgets(4));

    await tester.tap(find.byTooltip('Show favourites only'));
    await tester.pumpAndSettle();
    expect(find.byType(ClothingCard), findsOneWidget);
    expect(find.text('Cream knit'), findsOneWidget);
  });

  testWidgets('add screen validates required fields', (tester) async {
    await pumpApp(tester, seed: _seed);

    await tester.tap(find.byTooltip('Add a piece'));
    await tester.pumpAndSettle();
    expect(find.text('Add Piece'), findsOneWidget);

    await tester.ensureVisible(find.text('Add to wardrobe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to wardrobe'));
    await tester.pumpAndSettle();

    expect(find.text('Give this piece a name'), findsOneWidget);
    expect(find.text('Pick a category'), findsOneWidget);
    expect(find.text('Add a photo of this piece'), findsOneWidget);
  });

  testWidgets('generator builds a look for an available mood', (tester) async {
    await pumpApp(tester, seed: _seed);

    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    expect(find.text('choose a mood'), findsOneWidget);

    // Edgy has no pieces, so its chip is disabled and does nothing.
    await tester.tap(find.text('Edgy'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('your next favourite outfit awaits ✷'), findsOneWidget);

    await tester.tap(find.text('Cozy').last);
    await tester.pumpAndSettle();

    expect(find.text('🍂 your cozy look'), findsOneWidget);
    expect(find.text('Cream knit'), findsOneWidget);
    expect(find.text('Wide jeans'), findsOneWidget);
    expect(find.text('Chunky boots'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Save look'), findsOneWidget);
  });

  testWidgets('a saved look appears on the Looks tab grouped by mood', (
    tester,
  ) async {
    await pumpApp(tester, seed: _seed);

    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cozy').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save look'));
    await tester.tap(find.text('Save look'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Sunday market');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved "Sunday market" to your looks ♡'), findsOneWidget);

    await tester.tap(find.text('Looks'));
    await tester.pumpAndSettle();
    expect(find.text('Sunday market'), findsOneWidget);
    expect(find.textContaining('3 pieces'), findsOneWidget);
  });

  testWidgets('generator explains what is missing', (tester) async {
    await pumpApp(
      tester,
      seed: [piece('Hoodie', ClothingCategory.top, Mood.sporty)],
    );

    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sporty'));
    await tester.pumpAndSettle();

    expect(
      find.text('add a bottom for Sporty to complete this look'),
      findsOneWidget,
    );
  });

  testWidgets('looks tab starts empty and links to the generator', (
    tester,
  ) async {
    await pumpApp(tester, seed: _seed);

    await tester.tap(find.text('Looks'));
    await tester.pumpAndSettle();
    expect(find.text('no saved looks yet'), findsOneWidget);

    await tester.tap(find.text('Generate a look'));
    await tester.pumpAndSettle();
    expect(find.text('choose a mood'), findsOneWidget);
  });

  testWidgets('wide screens use a navigation rail', (tester) async {
    await pumpApp(tester, seed: _seed, size: const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('dark theme renders the wardrobe', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester, seed: _seed);

    final context = tester.element(find.byType(ClothingCard).first);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
