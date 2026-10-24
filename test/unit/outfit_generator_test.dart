import 'dart:math';

import 'package:fit_lab/core/constants/categories.dart';
import 'package:fit_lab/core/constants/moods.dart';
import 'package:fit_lab/domain/outfit_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';

void main() {
  final top = piece('tee', ClothingCategory.top, Mood.cozy);
  final top2 = piece('knit', ClothingCategory.top, Mood.cozy);
  final bottom = piece('jeans', ClothingCategory.bottom, Mood.cozy);
  final bottom2 = piece('skirt', ClothingCategory.bottom, Mood.cozy);
  final dress = piece('slip dress', ClothingCategory.dress, Mood.cozy);
  final coat = piece('coat', ClothingCategory.outerwear, Mood.cozy);
  final boots = piece('boots', ClothingCategory.shoes, Mood.cozy);
  final bag = piece('bag', ClothingCategory.accessory, Mood.cozy);
  final otherMood = piece('blazer', ClothingCategory.top, Mood.chic);

  test('only uses pieces from the requested mood', () {
    for (var seed = 0; seed < 50; seed++) {
      final r = OutfitGenerator.generate(
        wardrobe: [top, bottom, otherMood],
        mood: Mood.cozy,
        random: Random(seed),
      );
      expect(r.items.every((i) => i.hasMood(Mood.cozy)), isTrue);
    }
  });

  test('top + bottom gives a complete look', () {
    final r = OutfitGenerator.generate(
      wardrobe: [top, bottom],
      mood: Mood.cozy,
      random: Random(1),
    );
    expect(r.items, [top, bottom]);
    expect(r.isComplete, isTrue);
  });

  test('a dress alone is a complete look', () {
    final r = OutfitGenerator.generate(
      wardrobe: [dress, boots],
      mood: Mood.cozy,
      random: Random(1),
    );
    expect(r.items, [dress, boots]);
    expect(r.missing, isEmpty);
  });

  test('never combines a dress with separates', () {
    var dressLooks = 0;
    for (var seed = 0; seed < 100; seed++) {
      final r = OutfitGenerator.generate(
        wardrobe: [top, bottom, dress],
        mood: Mood.cozy,
        random: Random(seed),
      );
      final cats = r.items.map((i) => i.category).toSet();
      if (cats.contains(ClothingCategory.dress)) {
        dressLooks++;
        expect(cats.contains(ClothingCategory.top), isFalse);
        expect(cats.contains(ClothingCategory.bottom), isFalse);
      }
      expect(r.isComplete, isTrue);
    }
    expect(dressLooks, inInclusiveRange(25, 75));
  });

  test('reports missing core categories', () {
    final r = OutfitGenerator.generate(
      wardrobe: [top, boots],
      mood: Mood.cozy,
      random: Random(1),
    );
    expect(r.missing, [ClothingCategory.bottom]);
    expect(r.isComplete, isFalse);
    expect(r.items, containsAll([top, boots]));
  });

  test('empty mood yields an empty result needing top and bottom', () {
    final r = OutfitGenerator.generate(wardrobe: [otherMood], mood: Mood.cozy);
    expect(r.isEmpty, isTrue);
    expect(r.missing, [ClothingCategory.top, ClothingCategory.bottom]);
  });

  test('optional layers appear sometimes but not always', () {
    var withCoat = 0;
    var withBag = 0;
    for (var seed = 0; seed < 200; seed++) {
      final r = OutfitGenerator.generate(
        wardrobe: [top, bottom, coat, boots, bag],
        mood: Mood.cozy,
        random: Random(seed),
      );
      if (r.items.contains(coat)) withCoat++;
      if (r.items.contains(bag)) withBag++;
      expect(r.items, contains(boots));
    }
    expect(withCoat, inInclusiveRange(40, 120));
    expect(withBag, inInclusiveRange(60, 140));
  });

  test('is deterministic for a seeded random', () {
    final wardrobe = [top, top2, bottom, bottom2, coat, boots, bag];
    final a = OutfitGenerator.generate(
      wardrobe: wardrobe,
      mood: Mood.cozy,
      random: Random(42),
    );
    final b = OutfitGenerator.generate(
      wardrobe: wardrobe,
      mood: Mood.cozy,
      random: Random(42),
    );
    expect(a.items, b.items);
  });

  test('shuffle avoids repeating the previous look when possible', () {
    final wardrobe = [top, top2, bottom, bottom2];
    var repeats = 0;
    for (var seed = 0; seed < 100; seed++) {
      final first = OutfitGenerator.generate(
        wardrobe: wardrobe,
        mood: Mood.cozy,
        random: Random(seed),
      );
      final next = OutfitGenerator.generate(
        wardrobe: wardrobe,
        mood: Mood.cozy,
        random: Random(seed + 1000),
        avoidIds: first.ids,
      );
      if (next.ids.length == first.ids.length &&
          next.ids.containsAll(first.ids)) {
        repeats++;
      }
    }
    // Four possible looks and six re-rolls: a repeat should be very rare.
    expect(repeats, lessThan(5));
  });

  test('countFor counts pieces per mood', () {
    expect(OutfitGenerator.countFor([top, bottom, otherMood], Mood.cozy), 2);
    expect(OutfitGenerator.countFor([top, bottom, otherMood], Mood.edgy), 0);
  });
}
