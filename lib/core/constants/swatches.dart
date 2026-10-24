import 'dart:ui';

/// Colour families used to judge whether two pieces go together.
enum SwatchFamily { neutral, earthy, soft }

/// A preset colour a piece can be tagged with.
class Swatch {
  const Swatch(this.hex, this.name, this.family);

  /// Six-digit RGB hex, no `#`, as stored in the database.
  final String hex;
  final String name;
  final SwatchFamily family;

  Color get color => Color(int.parse('FF$hex', radix: 16));

  static const List<Swatch> all = [
    Swatch('F5F0E8', 'cream', SwatchFamily.neutral),
    Swatch('FFFFFF', 'white', SwatchFamily.neutral),
    Swatch('1F1F1F', 'black', SwatchFamily.neutral),
    Swatch('B9A48C', 'beige', SwatchFamily.neutral),
    Swatch('8A5A44', 'brown', SwatchFamily.neutral),
    Swatch('3F5A7A', 'denim', SwatchFamily.neutral),
    Swatch('6E7F5E', 'olive', SwatchFamily.earthy),
    Swatch('C46A6A', 'rose', SwatchFamily.soft),
    Swatch('E8B4C4', 'pink', SwatchFamily.soft),
    Swatch('9A8FB8', 'lilac', SwatchFamily.soft),
  ];

  static Swatch? byHex(String? hex) {
    if (hex == null) return null;
    final key = hex.toUpperCase();
    for (final s in all) {
      if (s.hex == key) return s;
    }
    return null;
  }

  /// How well two tagged colours sit together, from 0 to 1. Untagged or
  /// neutral pieces go with anything; two accents only pair within a family.
  static double compatibility(String? a, String? b) {
    final sa = byHex(a);
    final sb = byHex(b);
    if (sa == null || sb == null) return 1;
    if (sa.family == SwatchFamily.neutral ||
        sb.family == SwatchFamily.neutral) {
      return 1;
    }
    if (sa.family == sb.family) return 1;
    return clashWeight;
  }

  /// Clashing combinations stay possible, just much less likely.
  static const double clashWeight = 0.15;
}
