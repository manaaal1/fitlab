import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../constants/swatches.dart';

/// Suggests which preset [Swatch] a clothing photo is, so users don't have
/// to tag colours by hand.
class ColorDetector {
  const ColorDetector._();

  /// Decodes [path] at a small size and runs [dominantSwatch]. Returns null
  /// when the photo can't be read or no colour clearly dominates.
  static Future<Swatch?> fromFile(String path) async {
    try {
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
        targetWidth: 64,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = image.width;
      final h = image.height;
      image.dispose();
      if (data == null) return null;
      return dominantSwatch(data.buffer.asUint8List(), w, h);
    } catch (_) {
      return null;
    }
  }

  /// Pure analysis of RGBA pixels (row-major, 4 bytes each).
  ///
  /// Looks at the centre of the frame, where the garment usually is, and
  /// ignores pixels close to the border colour when the border is uniform
  /// (a plain backdrop). The winning swatch must cover a fair share of the
  /// remaining pixels.
  static Swatch? dominantSwatch(Uint8List rgba, int width, int height) {
    if (width < 4 || height < 4 || rgba.length < width * height * 4) {
      return null;
    }

    // Background estimate from the outer ring.
    final border = <List<int>>[];
    for (var x = 0; x < width; x++) {
      border
        ..add(_px(rgba, width, x, 0))
        ..add(_px(rgba, width, x, height - 1));
    }
    for (var y = 0; y < height; y++) {
      border
        ..add(_px(rgba, width, 0, y))
        ..add(_px(rgba, width, width - 1, y));
    }
    final opaqueBorder = border.where((p) => p[3] > 128).toList();
    List<int>? background;
    if (opaqueBorder.length > border.length / 2) {
      final mean = List<double>.filled(3, 0);
      for (final p in opaqueBorder) {
        for (var c = 0; c < 3; c++) {
          mean[c] += p[c] / opaqueBorder.length;
        }
      }
      final spread =
          opaqueBorder
              .map((p) => _distance(p, mean.map((v) => v.round()).toList()))
              .reduce((a, b) => a + b) /
          opaqueBorder.length;
      // Only treat the border as a backdrop when it's fairly uniform.
      if (spread < 60) background = mean.map((v) => v.round()).toList();
    }

    final counts = <Swatch, int>{};
    var considered = 0;
    final x0 = (width * 0.15).floor(), x1 = (width * 0.85).ceil();
    final y0 = (height * 0.1).floor(), y1 = (height * 0.9).ceil();
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final p = _px(rgba, width, x, y);
        if (p[3] <= 128) continue;
        if (background != null && _distance(p, background) < 70) continue;
        considered++;
        final s = nearest(p);
        counts[s] = (counts[s] ?? 0) + 1;
      }
    }
    if (considered < 20 || counts.isEmpty) return null;

    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.value / considered >= 0.3 ? best.key : null;
  }

  /// Closest preset swatch to an RGB(A) pixel.
  static Swatch nearest(List<int> rgb) {
    Swatch? best;
    var bestD = double.infinity;
    for (final s in Swatch.all) {
      final c = s.color;
      final d = _distance(rgb, [
        (c.r * 255).round(),
        (c.g * 255).round(),
        (c.b * 255).round(),
      ]);
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best!;
  }

  static List<int> _px(Uint8List rgba, int width, int x, int y) {
    final i = (y * width + x) * 4;
    return [rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]];
  }

  /// "Redmean" colour distance: cheap and closer to perception than RGB.
  static double _distance(List<int> a, List<int> b) {
    final rMean = (a[0] + b[0]) / 2;
    final dr = (a[0] - b[0]).toDouble();
    final dg = (a[1] - b[1]).toDouble();
    final db = (a[2] - b[2]).toDouble();
    return math.sqrt(
      (2 + rMean / 256) * dr * dr +
          4 * dg * dg +
          (2 + (255 - rMean) / 256) * db * db,
    );
  }
}
