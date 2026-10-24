import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/models/clothing_item.dart';
import '../constants/moods.dart';

/// Draws a shareable 4:5 "look card" (Pinterest-friendly) as PNG bytes.
///
/// Rendering happens on a [ui.Canvas] rather than by screenshotting the
/// screen, so the image is identical no matter what is scrolled into view.
class LookImage {
  const LookImage._();

  static const Size size = Size(1080, 1350);
  static const double _pad = 72;

  static const Color _paper = Color(0xFFFDFBF7);
  static const Color _ink = Color(0xFF2B2420);
  static const Color _muted = Color(0xFF7A6E66);
  static const Color _placeholder = Color(0xFFEDE5DC);

  /// [titleStyle] and [bodyStyle] carry the font families (pass the app's
  /// theme styles so the card matches the UI). [resolvePath] turns a stored
  /// image path into a readable file path.
  static Future<Uint8List> render({
    required String title,
    required Mood mood,
    required List<ClothingItem> items,
    required String Function(String stored) resolvePath,
    TextStyle? titleStyle,
    TextStyle? bodyStyle,
  }) async {
    final photos = await Future.wait(
      items.map((i) => _decode(resolvePath(i.imagePath))),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);

    // Background with a soft mood-tinted wash at the top.
    canvas.drawRect(Offset.zero & size, Paint()..color = _paper);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 420),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 420), [
          mood.color.withValues(alpha: 0.45),
          _paper,
        ]),
    );

    var y = _pad;

    // Mood label.
    final moodPainter = _text(
      '${mood.emoji}  ${mood.label.toUpperCase()}',
      (bodyStyle ?? const TextStyle()).copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        letterSpacing: 4,
        color: _ink.withValues(alpha: 0.75),
      ),
      size.width - _pad * 2,
    );
    moodPainter.paint(canvas, Offset(_pad, y));
    y += moodPainter.height + 12;

    // Title.
    final titlePainter = _text(
      title,
      (titleStyle ?? const TextStyle()).copyWith(
        fontSize: 96,
        fontWeight: FontWeight.w700,
        height: 1.05,
        color: _ink,
      ),
      size.width - _pad * 2,
      maxLines: 2,
    );
    titlePainter.paint(canvas, Offset(_pad, y));
    y += titlePainter.height + 40;

    // Footer (drawn first so the grid knows how much room is left).
    final footer = _text(
      'curated with FitLab ♡',
      (bodyStyle ?? const TextStyle()).copyWith(
        fontSize: 28,
        fontStyle: FontStyle.italic,
        color: _muted,
      ),
      size.width - _pad * 2,
    );
    final footerTop = size.height - _pad - footer.height;
    footer.paint(canvas, Offset((size.width - footer.width) / 2, footerTop));

    // Photo grid.
    final grid = Rect.fromLTRB(_pad, y, size.width - _pad, footerTop - 40);
    _paintGrid(canvas, grid, photos);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    for (final p in photos) {
      p?.dispose();
    }
    return bytes!.buffer.asUint8List();
  }

  static void _paintGrid(Canvas canvas, Rect area, List<ui.Image?> photos) {
    if (photos.isEmpty) return;
    const gap = 24.0;
    final n = photos.length;
    final columns = n == 1 ? 1 : (n <= 4 ? 2 : 3);
    final rows = (n / columns).ceil();
    final cellW = (area.width - gap * (columns - 1)) / columns;
    final cellH = math.min(
      (area.height - gap * (rows - 1)) / rows,
      cellW * 1.4,
    );
    final gridH = cellH * rows + gap * (rows - 1);
    final top = area.top + (area.height - gridH) / 2;

    for (var i = 0; i < n; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      // Centre a short last row.
      final inRow = row == rows - 1 ? n - row * columns : columns;
      final rowW = cellW * inRow + gap * (inRow - 1);
      final left = area.left + (area.width - rowW) / 2;
      final cell = Rect.fromLTWH(
        left + col * (cellW + gap),
        top + row * (cellH + gap),
        cellW,
        cellH,
      );
      final rrect = RRect.fromRectAndRadius(cell, const Radius.circular(36));

      canvas.drawRRect(
        rrect.shift(const Offset(0, 10)),
        Paint()
          ..color = const Color(0x22000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.save();
      canvas.clipRRect(rrect);
      final photo = photos[i];
      if (photo == null) {
        canvas.drawRect(cell, Paint()..color = _placeholder);
      } else {
        canvas.drawImageRect(
          photo,
          _coverSource(photo, cell.size),
          cell,
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      canvas.restore();
    }
  }

  /// Source rect that crops [image] to fill [target] (BoxFit.cover).
  static Rect _coverSource(ui.Image image, Size target) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final scale = math.max(target.width / iw, target.height / ih);
    final w = target.width / scale;
    final h = target.height / scale;
    return Rect.fromLTWH((iw - w) / 2, (ih - h) / 2, w, h);
  }

  static Future<ui.Image?> _decode(String path) async {
    try {
      final file = File(path);
      if (path.isEmpty || !await file.exists()) return null;
      final codec = await ui.instantiateImageCodec(
        await file.readAsBytes(),
        targetWidth: 900,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static TextPainter _text(
    String text,
    TextStyle style,
    double maxWidth, {
    int maxLines = 1,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }
}
