import '../../core/constants/categories.dart';
import '../../core/constants/moods.dart';

class ClothingItem {
  ClothingItem({
    this.id,
    required this.name,
    required this.category,
    required this.imagePath,
    required List<Mood> moods,
    required this.createdAt,
    this.isFavorite = false,
    this.colorHex,
    this.notes,
    this.lastWornOn,
    this.wearCount = 0,
  }) : moods = normaliseMoods(moods);

  final int? id;
  final String name;
  final ClothingCategory category;

  /// File name inside the app's image folder, or a legacy absolute path.
  /// Resolve with `ImageStorage.resolve` before reading.
  final String imagePath;

  /// Every mood this piece suits, in enum order. Never empty.
  final List<Mood> moods;
  final DateTime createdAt;
  final bool isFavorite;
  final String? colorHex;
  final String? notes;

  /// Most recent day this piece was worn (date only), from the wear log.
  final DateTime? lastWornOn;

  /// How many distinct days this piece was worn, from the wear log.
  final int wearCount;

  /// The first mood, used where a single colour or label is needed.
  Mood get primaryMood => moods.first;

  bool hasMood(Mood mood) => moods.contains(mood);

  /// Deduplicates, sorts into enum order, and guarantees at least one mood.
  static List<Mood> normaliseMoods(Iterable<Mood> moods) {
    final set = moods.toSet();
    final sorted = Mood.values.where(set.contains).toList(growable: false);
    return sorted.isEmpty ? const [Mood.casual] : sorted;
  }

  ClothingItem copyWith({
    int? id,
    String? name,
    ClothingCategory? category,
    String? imagePath,
    List<Mood>? moods,
    bool? isFavorite,
    String? colorHex,
    DateTime? lastWornOn,
    int? wearCount,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      moods: moods ?? this.moods,
      createdAt: createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      colorHex: colorHex ?? this.colorHex,
      notes: notes,
      lastWornOn: lastWornOn ?? this.lastWornOn,
      wearCount: wearCount ?? this.wearCount,
    );
  }

  /// Columns of the `clothes` table. Wear data lives in `wear_log`.
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'category': category.name,
    'imagePath': imagePath,
    // `mood` is kept (primary mood) so older readers still find a value.
    'mood': primaryMood.name,
    'moods': moods.map((m) => m.name).join(','),
    'createdAt': createdAt.toIso8601String(),
    'isFavorite': isFavorite ? 1 : 0,
    'colorHex': colorHex,
    'notes': notes,
  };

  /// Reads a `clothes` row, optionally joined with `lastWornOn` and
  /// `wearCount` aggregates from the wear log.
  factory ClothingItem.fromMap(Map<String, Object?> map) {
    final rawMoods = (map['moods'] as String?)?.trim() ?? '';
    final moods = rawMoods.isEmpty
        ? [Mood.fromString(map['mood'] as String?)]
        : rawMoods.split(',').map(Mood.fromString).toList();
    return ClothingItem(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      category: ClothingCategory.fromString(map['category'] as String?),
      imagePath: (map['imagePath'] as String?) ?? '',
      moods: moods,
      createdAt:
          DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isFavorite: (map['isFavorite'] as int? ?? 0) == 1,
      colorHex: map['colorHex'] as String?,
      notes: map['notes'] as String?,
      lastWornOn: DateTime.tryParse((map['lastWornOn'] as String?) ?? ''),
      wearCount: map['wearCount'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ClothingItem &&
      other.id == id &&
      other.name == name &&
      other.category == category &&
      other.imagePath == imagePath &&
      _sameMoods(other.moods, moods) &&
      other.createdAt == createdAt &&
      other.isFavorite == isFavorite &&
      other.colorHex == colorHex &&
      other.notes == notes &&
      other.lastWornOn == lastWornOn &&
      other.wearCount == wearCount;

  static bool _sameMoods(List<Mood> a, List<Mood> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    imagePath,
    Object.hashAll(moods),
    createdAt,
    isFavorite,
    colorHex,
    notes,
    lastWornOn,
    wearCount,
  );
}
