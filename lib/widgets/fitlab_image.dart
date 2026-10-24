import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/image_storage.dart';
import '../theme/app_theme.dart';

/// Shows a wardrobe photo, with a soft placeholder when the file is missing.
class FitLabImage extends StatelessWidget {
  const FitLabImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.placeholderAspectRatio = 0.8,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Decode width in physical pixels; keeps grid thumbnails light on memory.
  final int? cacheWidth;

  /// Used for the placeholder when the real image cannot be read.
  final double placeholderAspectRatio;

  @override
  Widget build(BuildContext context) {
    final resolved = context.read<ImageStorage>().resolve(path);
    if (resolved.isEmpty) return _placeholder(context);
    return Image.file(
      File(resolved),
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (context, _, _) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final tokens = FitLabColors.of(context);
    final box = Container(
      width: width,
      height: height,
      color: tokens.imagePlaceholder,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: tokens.subtleText,
        semanticLabel: 'Photo unavailable',
      ),
    );
    if (height != null) return box;
    return AspectRatio(aspectRatio: placeholderAspectRatio, child: box);
  }
}
