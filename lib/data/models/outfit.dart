import '../../core/constants/moods.dart';
import 'clothing_item.dart';

/// A saved look: a named set of wardrobe pieces for one mood.
class Outfit {
  const Outfit({
    this.id,
    required this.name,
    required this.mood,
    required this.items,
    required this.createdAt,
    this.isFavorite = false,
    int? savedItemCount,
  }) : savedItemCount = savedItemCount ?? items.length;

  final int? id;
  final String name;
  final Mood mood;

  /// Pieces still in the wardrobe, in display order.
  final List<ClothingItem> items;
  final DateTime createdAt;
  final bool isFavorite;

  /// How many pieces the look had when it was saved.
  final int savedItemCount;

  /// Pieces that were deleted from the wardrobe after the look was saved.
  int get missingCount =>
      (savedItemCount - items.length).clamp(0, savedItemCount);

  Outfit copyWith({int? id, String? name, bool? isFavorite}) => Outfit(
    id: id ?? this.id,
    name: name ?? this.name,
    mood: mood,
    items: items,
    createdAt: createdAt,
    isFavorite: isFavorite ?? this.isFavorite,
    savedItemCount: savedItemCount,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'mood': mood.name,
    'createdAt': createdAt.toIso8601String(),
    'isFavorite': isFavorite ? 1 : 0,
    'itemCount': savedItemCount,
  };

  factory Outfit.fromMap(Map<String, Object?> map, List<ClothingItem> items) {
    return Outfit(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      mood: Mood.fromString(map['mood'] as String?),
      items: items,
      createdAt:
          DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isFavorite: (map['isFavorite'] as int? ?? 0) == 1,
      savedItemCount: map['itemCount'] as int? ?? items.length,
    );
  }
}
