import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Every style vibe FitLab knows about. Single source of truth for labels,
/// emoji and colours. Stored in the database by [Enum.name].
enum Mood {
  casual('Casual', '☕', Color(0xFFD9C2A7)),
  cozy('Cozy', '🍂', Color(0xFFC49A6C)),
  classy('Classy', '🪩', Color(0xFFBFA2DB)),
  cleanGirl('Clean Girl', '✨', Color(0xFFE7DCCF)),
  softGirl('Soft Girl', '🎀', Color(0xFFF4C6D7)),
  streetwear('Streetwear', '🧢', Color(0xFFA0AEC0)),
  minimal('Minimal', '🤍', Color(0xFFEAEAEA)),
  darkAcademia('Dark Academia', '🖤', Color(0xFF6B4F4F)),
  feminine('Feminine', '🌷', Color(0xFFFFD6E0)),
  chic('Chic', '🕶', Color(0xFFCDB4DB)),
  vintage('Vintage', '📻', Color(0xFFD4A373)),
  sporty('Sporty', '🎧', Color(0xFFA8DADC)),
  edgy('Edgy', '⛓', Color(0xFF7D8597)),
  artsy('Artsy', '🎨', Color(0xFFF6BD60)),
  modest('Modest', '🕊', Color(0xFFB8C0A5));

  const Mood(this.label, this.emoji, this.color);

  final String label;
  final String emoji;
  final Color color;

  /// Readable text colour to place on top of [color].
  Color get onColor => AppTheme.contrastOn(color);

  /// Parses both the current storage format (`cleanGirl`) and the legacy
  /// label format (`Clean Girl`). Unknown values fall back to [Mood.casual].
  static Mood fromString(String? raw) {
    final key = _normalise(raw);
    for (final mood in Mood.values) {
      if (_normalise(mood.name) == key || _normalise(mood.label) == key) {
        return mood;
      }
    }
    return Mood.casual;
  }

  static String _normalise(String? value) =>
      (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
}
