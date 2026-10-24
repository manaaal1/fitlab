import 'dart:typed_data';

import 'package:fit_lab/core/constants/swatches.dart';
import 'package:fit_lab/core/utils/color_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [w]×[h] image filled with [background], with a centred rectangle of
/// [garment] covering [coverage] of each side.
Uint8List photo(
  List<int> background,
  List<int> garment, {
  int w = 40,
  int h = 50,
  double coverage = 0.6,
}) {
  final bytes = Uint8List(w * h * 4);
  final x0 = (w * (1 - coverage) / 2).round(), x1 = w - x0;
  final y0 = (h * (1 - coverage) / 2).round(), y1 = h - y0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final inside = x >= x0 && x < x1 && y >= y0 && y < y1;
      final c = inside ? garment : background;
      final i = (y * w + x) * 4;
      bytes
        ..[i] = c[0]
        ..[i + 1] = c[1]
        ..[i + 2] = c[2]
        ..[i + 3] = 255;
    }
  }
  return bytes;
}

void main() {
  const white = [250, 250, 250];

  Swatch? detect(List<int> bg, List<int> fg) =>
      ColorDetector.dominantSwatch(photo(bg, fg), 40, 50);

  test('finds the garment colour on a plain backdrop', () {
    expect(detect(white, [200, 60, 60])?.name, 'rose');
    expect(detect(white, [60, 90, 130])?.name, 'denim');
    expect(detect(white, [110, 125, 90])?.name, 'olive');
    expect(detect(white, [25, 25, 25])?.name, 'black');
  });

  test('ignores the backdrop even when it is a swatch colour', () {
    // Black jumper on a cream wall: cream must not win.
    expect(detect([245, 240, 232], [30, 30, 30])?.name, 'black');
  });

  test('works for white clothes on a dark backdrop', () {
    expect(detect([30, 30, 30], [252, 252, 252])?.name, 'white');
  });

  test('returns null when no colour dominates', () {
    final w = 40, h = 50;
    final bytes = Uint8List(w * h * 4);
    const palette = [
      [200, 60, 60],
      [60, 90, 130],
      [110, 125, 90],
      [232, 180, 196],
      [154, 143, 184],
    ];
    for (var i = 0; i < w * h; i++) {
      final c = palette[i % palette.length];
      bytes
        ..[i * 4] = c[0]
        ..[i * 4 + 1] = c[1]
        ..[i * 4 + 2] = c[2]
        ..[i * 4 + 3] = 255;
    }
    expect(ColorDetector.dominantSwatch(bytes, w, h), isNull);
  });

  test('handles tiny or transparent images', () {
    expect(ColorDetector.dominantSwatch(Uint8List(16), 2, 2), isNull);
    expect(
      ColorDetector.dominantSwatch(Uint8List(40 * 50 * 4), 40, 50),
      isNull,
    );
  });

  test('nearest maps exact swatch colours to themselves', () {
    for (final s in Swatch.all) {
      final c = s.color;
      expect(
        ColorDetector.nearest([
          (c.r * 255).round(),
          (c.g * 255).round(),
          (c.b * 255).round(),
        ]),
        s,
      );
    }
  });
}
