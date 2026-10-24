import 'package:fit_lab/core/constants/categories.dart';
import 'package:fit_lab/core/constants/moods.dart';
import 'package:fit_lab/data/models/clothing_item.dart';
import 'package:fit_lab/data/models/outfit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final item = ClothingItem(
    id: 7,
    name: 'Cream cardigan',
    category: ClothingCategory.top,
    imagePath: 'abc.jpg',
    moods: [Mood.minimal, Mood.cozy],
    createdAt: DateTime(2026, 3, 4, 5, 6),
    isFavorite: true,
    colorHex: 'F5F0E8',
    notes: 'oversized',
  );

  test('ClothingItem round-trips through a map', () {
    expect(ClothingItem.fromMap(item.toMap()), item);
  });

  test('ClothingItem stores enums by name', () {
    final map = item.toMap();
    expect(map['category'], 'top');
    expect(map['mood'], 'cozy');
    expect(map['moods'], 'cozy,minimal');
    expect(map['isFavorite'], 1);
  });

  test('ClothingItem reads legacy v2 rows', () {
    final legacy = ClothingItem.fromMap({
      'id': 1,
      'name': 'Old jeans',
      'category': 'Jeans',
      'imagePath': '/cache/x.jpg',
      'mood': 'Clean Girl',
    });
    expect(legacy.category, ClothingCategory.bottom);
    expect(legacy.moods, [Mood.cleanGirl]);
    expect(legacy.isFavorite, isFalse);
  });

  test('moods are deduplicated, ordered and never empty', () {
    final p = ClothingItem(
      name: 'x',
      category: ClothingCategory.top,
      imagePath: '',
      moods: [Mood.edgy, Mood.casual, Mood.edgy],
      createdAt: DateTime(2026),
    );
    expect(p.moods, [Mood.casual, Mood.edgy]);
    expect(p.primaryMood, Mood.casual);
    expect(
      ClothingItem(
        name: 'y',
        category: ClothingCategory.top,
        imagePath: '',
        moods: const [],
        createdAt: DateTime(2026),
      ).moods,
      [Mood.casual],
    );
  });

  test('wear aggregates are read but not written', () {
    final row = {...item.toMap(), 'lastWornOn': '2026-09-30', 'wearCount': 4};
    final read = ClothingItem.fromMap(row);
    expect(read.lastWornOn, DateTime(2026, 9, 30));
    expect(read.wearCount, 4);
    expect(read.toMap().containsKey('wearCount'), isFalse);
  });

  test('Outfit reports pieces deleted since saving', () {
    final outfit = Outfit.fromMap(
      {
        'id': 1,
        'name': 'look',
        'mood': 'cozy',
        'createdAt': DateTime(2026).toIso8601String(),
        'isFavorite': 0,
        'itemCount': 3,
      },
      [item],
    );
    expect(outfit.missingCount, 2);
    expect(outfit.toMap()['itemCount'], 3);
  });
}
