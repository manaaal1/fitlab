import 'dart:math';

import '../core/constants/categories.dart';
import '../core/constants/moods.dart';
import '../core/constants/swatches.dart';
import '../data/models/clothing_item.dart';

class GenerationResult {
  const GenerationResult({required this.items, required this.missing});

  /// Pieces in display order: top/dress, bottom, outerwear, shoes, accessory.
  final List<ClothingItem> items;

  /// Core categories the mood needs before a complete look is possible.
  final List<ClothingCategory> missing;

  bool get isEmpty => items.isEmpty;
  bool get isComplete => items.isNotEmpty && missing.isEmpty;

  Set<int> get ids => {for (final i in items) ?i.id};
}

/// Builds looks from a wardrobe. Pure Dart, so it is deterministic under a
/// seeded [Random] and easy to unit test.
class OutfitGenerator {
  const OutfitGenerator._();

  static const double outerwearChance = 0.4;
  static const double accessoryChance = 0.5;
  static const int shuffleAttempts = 6;

  static int countFor(List<ClothingItem> wardrobe, Mood mood) =>
      wardrobe.where((i) => i.hasMood(mood)).length;

  /// Picks either a top + bottom or a dress, then optionally layers
  /// outerwear, shoes and an accessory.
  ///
  /// * [locked] pieces always stay in the look and decide their slot (a
  ///   locked dress means a dress look, a locked top means separates).
  /// * Colour-tagged pieces favour combinations that go together.
  /// * [avoidIds] re-rolls a few times so Shuffle doesn't repeat itself.
  static GenerationResult generate({
    required List<ClothingItem> wardrobe,
    required Mood mood,
    Random? random,
    Set<int>? avoidIds,
    List<ClothingItem> locked = const [],
  }) {
    final rng = random ?? Random();
    final lockedIds = {for (final i in locked) ?i.id};
    final pool = <ClothingCategory, List<ClothingItem>>{};
    for (final item in wardrobe) {
      if (item.hasMood(mood) && !lockedIds.contains(item.id)) {
        pool.putIfAbsent(item.category, () => []).add(item);
      }
    }
    final lockedBy = <ClothingCategory, ClothingItem>{
      for (final item in locked.reversed) item.category: item,
    };

    var result = _attempt(pool, lockedBy, rng);
    if (avoidIds != null && avoidIds.isNotEmpty) {
      for (var i = 0; i < shuffleAttempts; i++) {
        if (!_sameSet(result.ids, avoidIds)) break;
        result = _attempt(pool, lockedBy, rng);
      }
    }
    return result;
  }

  static GenerationResult _attempt(
    Map<ClothingCategory, List<ClothingItem>> pool,
    Map<ClothingCategory, ClothingItem> locked,
    Random rng,
  ) {
    List<ClothingItem> of(ClothingCategory c) => pool[c] ?? const [];
    bool has(ClothingCategory c) => locked.containsKey(c) || of(c).isNotEmpty;

    final items = <ClothingItem>[];
    final missing = <ClothingCategory>[];

    void fill(ClothingCategory c) {
      final fixed = locked[c];
      if (fixed != null) {
        items.add(fixed);
      } else {
        items.add(_pickMatching(of(c), items, rng));
      }
    }

    final canSeparates =
        has(ClothingCategory.top) && has(ClothingCategory.bottom);
    final bool useDress;
    if (locked.containsKey(ClothingCategory.dress)) {
      useDress = true;
    } else if (locked.containsKey(ClothingCategory.top) ||
        locked.containsKey(ClothingCategory.bottom)) {
      useDress = false;
    } else {
      useDress =
          has(ClothingCategory.dress) && (!canSeparates || rng.nextBool());
    }

    if (useDress) {
      fill(ClothingCategory.dress);
    } else {
      for (final c in [ClothingCategory.top, ClothingCategory.bottom]) {
        if (has(c)) {
          fill(c);
        } else {
          missing.add(c);
        }
      }
    }

    // Optional layers: always included when locked, otherwise by chance.
    void maybe(ClothingCategory c, double chance) {
      if (locked.containsKey(c)) {
        fill(c);
      } else if (of(c).isNotEmpty && rng.nextDouble() < chance) {
        fill(c);
      }
    }

    maybe(ClothingCategory.outerwear, outerwearChance);
    maybe(ClothingCategory.shoes, 1);
    maybe(ClothingCategory.accessory, accessoryChance);

    return GenerationResult(items: items, missing: missing);
  }

  /// Weighted random pick that favours colours going with [chosen].
  static ClothingItem _pickMatching(
    List<ClothingItem> candidates,
    List<ClothingItem> chosen,
    Random rng,
  ) {
    final weights = [
      for (final c in candidates)
        chosen.fold<double>(
          1,
          (w, p) => w * Swatch.compatibility(c.colorHex, p.colorHex),
        ),
    ];
    final total = weights.fold<double>(0, (a, b) => a + b);
    var r = rng.nextDouble() * total;
    for (var i = 0; i < candidates.length; i++) {
      r -= weights[i];
      if (r < 0) return candidates[i];
    }
    return candidates.last;
  }

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}
