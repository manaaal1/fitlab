import 'package:flutter/material.dart';

import '../data/models/clothing_item.dart';
import '../theme/app_theme.dart';
import 'fitlab_image.dart';

/// Height of a [ClothingCard] with a fixed photo height: the photo plus the
/// name/category block, which grows with the user's text size.
double cardExtent(double imageHeight, BuildContext context) =>
    imageHeight + MediaQuery.textScalerOf(context).scale(46) + 30;

class ClothingCard extends StatefulWidget {
  const ClothingCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.heroTag,
    this.fixedImageHeight,
    this.badge,
  });

  final ClothingItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Set only where the card is the source of a Hero flight.
  final Object? heroTag;

  /// Null lets the photo keep its natural aspect ratio (masonry layout).
  final double? fixedImageHeight;

  /// Optional control drawn over the photo's top-left corner.
  final Widget? badge;

  @override
  State<ClothingCard> createState() => _ClothingCardState();
}

class _ClothingCardState extends State<ClothingCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = FitLabColors.of(context);
    final item = widget.item;
    final interactive = widget.onTap != null || widget.onLongPress != null;

    Widget image = FitLabImage(
      path: item.imagePath,
      width: double.infinity,
      height: widget.fixedImageHeight,
      cacheWidth: 600,
    );
    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }

    return Semantics(
      button: interactive,
      label:
          '${item.name}, ${item.category.label}, '
          '${item.moods.map((m) => m.label).join(', ')}'
          '${item.isFavorite ? ', favourite' : ''}',
      excludeSemantics: widget.badge == null,
      child: GestureDetector(
        onTapDown: interactive ? (_) => _setPressed(true) : null,
        onTapUp: interactive ? (_) => _setPressed(false) : null,
        onTapCancel: interactive ? () => _setPressed(false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _setPressed(false);
                widget.onLongPress!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _pressed ? -6 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: tokens.cardShadow,
                blurRadius: _pressed ? 22 : 12,
                offset: Offset(0, _pressed ? 12 : 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    image,
                    if (widget.badge != null)
                      Positioned(top: 6, left: 6, child: widget.badge!),
                    if (item.isFavorite)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.85,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 14,
                            color: tokens.favorite,
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // One dot per mood, overlapping like swatches.
                          SizedBox(
                            width: 8.0 + 5 * (item.moods.take(3).length - 1),
                            height: 8,
                            child: Stack(
                              children: [
                                for (final (i, m) in item.moods.take(3).indexed)
                                  Positioned(
                                    left: 5.0 * i,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: m.color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.colorScheme.surface,
                                          width: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${item.category.emoji} ${item.category.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.subtleText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
