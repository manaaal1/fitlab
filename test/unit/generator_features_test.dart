import 'dart:math';

import 'package:fit_lab/core/constants/categories.dart';
import 'package:fit_lab/core/constants/moods.dart';
import 'package:fit_lab/core/constants/swatches.dart';
import 'package:fit_lab/domain/outfit_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';

void main() {
  group('lock and shuffle', () {
    final tops = [
      for (var i = 0; i < 4; i++)
        piece('top$i', ClothingCategory.top, Mood.chic),
    ];
    final bottoms = [
      for (var i = 0; i < 4; i++)
        piece('bottom$i', ClothingCategory.bottom, Mood.chic),
    ];
    final dress = piece('dress', ClothingCategory.dress, Mood.chic);
    final coat = piece('coat', ClothingCategory.outerwear, Mood.chic);
    final bag = piece('bag', ClothingCategory.accessory, Mood.chic);
    final wardrobe = [...tops, ...bottoms, dress, coat, bag];

    test('a locked piece is in every look', () {
      for (var seed = 0; seed < 60; seed++) {
        final r = OutfitGenerator.generate(
          wardrobe: wardrobe,
          mood: Mood.chic,
          random: Random(seed),
          locked: [tops[2]],
        );
        expect(r.items, contains(tops[2]));
        expect(r.items.where((i) => i.category == ClothingCategory.top), [
          tops[2],
        ]);
      }
    });

    test('a locked top or bottom means separates, never a dress', () {
      for (var seed = 0; seed < 60; seed++) {
        final r = OutfitGenerator.generate(
          wardrobe: wardrobe,
          mood: Mood.chic,
          random: Random(seed),
          locked: [bottoms[1]],
        );
        expect(r.items, isNot(contains(dress)));
        expect(r.isComplete, isTrue);
      }
    });

    test('a locked dress means a dress look', () {
      for (var seed = 0; seed < 60; seed++) {
        final r = OutfitGenerator.generate(
          wardrobe: wardrobe,
          mood: Mood.chic,
          random: Random(seed),
          locked: [dress],
        );
        expect(r.items.first, dress);
        expect(r.items.any((i) => i.category == ClothingCategory.top), isFalse);
      }
    });

    test('locked optional layers always appear', () {
      for (var seed = 0; seed < 60; seed++) {
        final r = OutfitGenerator.generate(
          wardrobe: wardrobe,
          mood: Mood.chic,
          random: Random(seed),
          locked: [coat, bag],
        );
        expect(r.items, containsAll([coat, bag]));
      }
    });

    test('shuffling with a lock changes the rest', () {
      final first = OutfitGenerator.generate(
        wardrobe: wardrobe,
        mood: Mood.chic,
        random: Random(3),
        locked: [tops[0]],
      );
      var changed = 0;
      for (var seed = 10; seed < 40; seed++) {
        final next = OutfitGenerator.generate(
          wardrobe: wardrobe,
          mood: Mood.chic,
          random: Random(seed),
          locked: [tops[0]],
          avoidIds: first.ids,
        );
        expect(next.items, contains(tops[0]));
        if (!(next.ids.length == first.ids.length &&
            next.ids.containsAll(first.ids))) {
          changed++;
        }
      }
      expect(changed, greaterThan(25));
    });

    test('a locked piece from another mood is still used', () {
      final cozyKnit = piece('knit', ClothingCategory.top, Mood.cozy);
      final r = OutfitGenerator.generate(
        wardrobe: [...wardrobe, cozyKnit],
        mood: Mood.chic,
        random: Random(1),
        locked: [cozyKnit],
      );
      expect(r.items.first, cozyKnit);
    });
  });

  group('multiple moods', () {
    test('a piece with two moods is used for both', () {
      final tee = piece(
        'tee',
        ClothingCategory.top,
        Mood.minimal,
        extraMoods: [Mood.cleanGirl],
      );
      final jeans = piece(
        'jeans',
        ClothingCategory.bottom,
        Mood.minimal,
        extraMoods: [Mood.cleanGirl],
      );
      for (final mood in [Mood.minimal, Mood.cleanGirl]) {
        final r = OutfitGenerator.generate(
          wardrobe: [tee, jeans],
          mood: mood,
          random: Random(1),
        );
        expect(r.items, [tee, jeans]);
      }
      expect(OutfitGenerator.countFor([tee, jeans], Mood.cleanGirl), 2);
      expect(OutfitGenerator.countFor([tee, jeans], Mood.edgy), 0);
    });
  });

  group('colour matching', () {
    test('compatibility rules', () {
      const olive = '6E7F5E', rose = 'C46A6A', pink = 'E8B4C4';
      const black = '1F1F1F';
      expect(Swatch.compatibility(null, rose), 1);
      expect(Swatch.compatibility(black, rose), 1);
      expect(Swatch.compatibility(rose, pink), 1);
      expect(Swatch.compatibility(olive, rose), Swatch.clashWeight);
      expect(Swatch.compatibility('ABCDEF', rose), 1); // unknown tag
    });

    test('clashing accents are much rarer than matching ones', () {
      final roseTop = piece(
        'rose top',
        ClothingCategory.top,
        Mood.artsy,
        colorHex: 'C46A6A',
      );
      final pinkSkirt = piece(
        'pink skirt',
        ClothingCategory.bottom,
        Mood.artsy,
        colorHex: 'E8B4C4',
      );
      final oliveSkirt = piece(
        'olive skirt',
        ClothingCategory.bottom,
        Mood.artsy,
        colorHex: '6E7F5E',
      );
      var pink = 0, olive = 0;
      for (var seed = 0; seed < 400; seed++) {
        final r = OutfitGenerator.generate(
          wardrobe: [roseTop, pinkSkirt, oliveSkirt],
          mood: Mood.artsy,
          random: Random(seed),
        );
        if (r.items.contains(pinkSkirt)) pink++;
        if (r.items.contains(oliveSkirt)) olive++;
      }
      // Weights 1 : 0.15, so roughly 87% vs 13%.
      expect(pink, greaterThan(300));
      expect(olive, inInclusiveRange(20, 90));
    });
  });
}
