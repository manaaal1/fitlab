import '../models/clothing_item.dart';
import 'dart:math';

class OutfitService {
  static List<String> getAvailableMoods(List<ClothingItem> wardrobe) {
    final moods = wardrobe.map((item) => item.mood).toSet();

    return moods.toList();
  }

  static List<ClothingItem> generateOutfit({
    required List<ClothingItem> wardrobe,

    required String mood,
  }) {
    final random = Random();

    final matchingItems = wardrobe.where((item) => item.mood == mood).toList();

    final tops = matchingItems
        .where((item) => item.category.toLowerCase() == 'top')
        .toList();

    final bottoms = matchingItems
        .where((item) => item.category.toLowerCase() == 'bottom')
        .toList();

    final outerwear = matchingItems
        .where((item) => item.category.toLowerCase() == 'outerwear')
        .toList();

    final shoes = matchingItems
        .where((item) => item.category.toLowerCase() == 'shoes')
        .toList();

    final outfit = <ClothingItem>[];

    if (tops.isNotEmpty) {
      outfit.add(tops[random.nextInt(tops.length)]);
    }

    if (bottoms.isNotEmpty) {
      outfit.add(bottoms[random.nextInt(bottoms.length)]);
    }

    // optional outerwear
    if (outerwear.isNotEmpty && random.nextBool()) {
      outfit.add(outerwear[random.nextInt(outerwear.length)]);
    }

    if (shoes.isNotEmpty) {
      outfit.add(shoes[random.nextInt(shoes.length)]);
    }

    return outfit;
  }
}
