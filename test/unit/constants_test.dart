import 'package:fit_lab/core/constants/categories.dart';
import 'package:fit_lab/core/constants/moods.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mood.fromString', () {
    test('parses enum names', () {
      expect(Mood.fromString('darkAcademia'), Mood.darkAcademia);
    });

    test('parses legacy labels case-insensitively', () {
      expect(Mood.fromString('Clean Girl'), Mood.cleanGirl);
      expect(Mood.fromString('soft girl'), Mood.softGirl);
      expect(Mood.fromString('DARK ACADEMIA'), Mood.darkAcademia);
    });

    test('falls back to casual for unknown or null', () {
      expect(Mood.fromString('galactic'), Mood.casual);
      expect(Mood.fromString(null), Mood.casual);
    });

    test('every mood has a contrasting text colour', () {
      for (final mood in Mood.values) {
        expect(mood.onColor, isNot(mood.color));
      }
    });
  });

  group('ClothingCategory.fromString', () {
    test('parses enum names', () {
      for (final c in ClothingCategory.values) {
        expect(ClothingCategory.fromString(c.name), c);
      }
    });

    test('maps legacy free text via synonyms', () {
      const cases = {
        'Top': ClothingCategory.top,
        'T-Shirt': ClothingCategory.top,
        'Jeans': ClothingCategory.bottom,
        'mini skirt': ClothingCategory.bottom,
        'Denim Jacket': ClothingCategory.outerwear,
        'Sneakers': ClothingCategory.shoes,
        'Tote bag': ClothingCategory.accessory,
        'Maxi Dress': ClothingCategory.dress,
      };
      cases.forEach((raw, expected) {
        expect(ClothingCategory.fromString(raw), expected, reason: raw);
      });
    });

    test('falls back to top', () {
      expect(ClothingCategory.fromString('???'), ClothingCategory.top);
      expect(ClothingCategory.fromString(null), ClothingCategory.top);
    });
  });
}
