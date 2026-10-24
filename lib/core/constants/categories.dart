/// The kinds of pieces the outfit generator understands.
/// Stored in the database by [Enum.name].
enum ClothingCategory {
  top('Top', '👚'),
  bottom('Bottom', '👖'),
  dress('Dress', '👗'),
  outerwear('Outerwear', '🧥'),
  shoes('Shoes', '👟'),
  accessory('Accessory', '👜');

  const ClothingCategory(this.label, this.emoji);

  final String label;
  final String emoji;

  static const Map<String, ClothingCategory> _synonyms = {
    // tops
    'top': top, 'tops': top, 'shirt': top, 'tshirt': top, 'tee': top,
    'blouse': top, 'sweater': top, 'jumper': top, 'hoodie': top,
    'cardigan': top, 'tank': top, 'tanktop': top, 'croptop': top,
    'polo': top, 'sweatshirt': top, 'knit': top, 'bodysuit': top,
    // bottoms
    'bottom': bottom, 'bottoms': bottom, 'jeans': bottom, 'pants': bottom,
    'trousers': bottom, 'skirt': bottom, 'shorts': bottom,
    'leggings': bottom, 'joggers': bottom, 'sweatpants': bottom,
    // dresses
    'dress': dress, 'dresses': dress, 'jumpsuit': dress, 'romper': dress,
    'gown': dress, 'abaya': dress,
    // outerwear
    'outerwear': outerwear, 'jacket': outerwear, 'coat': outerwear,
    'blazer': outerwear, 'trench': outerwear, 'parka': outerwear,
    'puffer': outerwear, 'vest': outerwear,
    // shoes
    'shoes': shoes, 'shoe': shoes, 'sneakers': shoes, 'trainers': shoes,
    'boots': shoes, 'heels': shoes, 'sandals': shoes, 'flats': shoes,
    'loafers': shoes, 'mules': shoes,
    // accessories
    'accessory': accessory, 'accessories': accessory, 'bag': accessory,
    'purse': accessory, 'hat': accessory, 'cap': accessory,
    'scarf': accessory, 'belt': accessory, 'jewelry': accessory,
    'jewellery': accessory, 'necklace': accessory, 'earrings': accessory,
    'sunglasses': accessory, 'watch': accessory,
  };

  /// Parses the stored enum name, and maps legacy free-text categories
  /// (e.g. "Jeans", "T-Shirt") onto a known category. Falls back to [top].
  static ClothingCategory fromString(String? raw) {
    final key = (raw ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final direct = _synonyms[key];
    if (direct != null) return direct;
    for (final entry in _synonyms.entries) {
      if (key.contains(entry.key) && entry.key.length > 2) return entry.value;
    }
    return ClothingCategory.top;
  }
}
