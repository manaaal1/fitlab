import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/moods.dart';
import '../core/utils/image_storage.dart';
import '../core/utils/look_image.dart';
import '../data/models/clothing_item.dart';

/// Renders a look card and opens the system share sheet.
Future<void> shareLook(
  BuildContext context, {
  required String title,
  required Mood mood,
  required List<ClothingItem> items,
}) async {
  final theme = Theme.of(context);
  final images = context.read<ImageStorage>();
  final messenger = ScaffoldMessenger.of(context);

  // iPad needs an anchor for the share popover.
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize
      ? null
      : box.localToGlobal(Offset.zero) & box.size;

  try {
    final png = await LookImage.render(
      title: title,
      mood: mood,
      items: items,
      resolvePath: images.resolve,
      titleStyle: theme.textTheme.headlineLarge,
      bodyStyle: theme.textTheme.bodyLarge,
    );
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'fitlab-look-${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    await file.writeAsBytes(png);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: '$title · my ${mood.label.toLowerCase()} look from FitLab ✷',
        sharePositionOrigin: origin,
      ),
    );
  } catch (e) {
    debugPrint('Sharing look failed: $e');
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not share this look.')),
    );
  }
}
