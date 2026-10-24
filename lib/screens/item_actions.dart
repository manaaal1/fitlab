import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/categories.dart';
import '../core/constants/moods.dart';
import '../data/models/clothing_item.dart';
import '../providers/outfits_provider.dart';
import '../providers/style_request.dart';
import '../providers/wardrobe_provider.dart';
import '../theme/app_theme.dart';
import 'add_edit_clothing/add_edit_clothing_screen.dart';
import 'item_detail/item_detail_screen.dart';

/// Navigation and confirmation flows shared by several screens.
class ItemActions {
  const ItemActions._();

  static Future<void> openEditor(
    BuildContext context, {
    ClothingItem? existing,
    List<Mood>? initialMoods,
    ClothingCategory? initialCategory,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddEditClothingScreen(
          existing: existing,
          initialMoods: initialMoods,
          initialCategory: initialCategory,
        ),
      ),
    );
  }

  static Future<void> openDetail(BuildContext context, ClothingItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ItemDetailScreen(itemId: item.id!),
      ),
    );
  }

  /// Toggles today's wear record for one piece.
  static Future<void> toggleWornToday(
    BuildContext context,
    ClothingItem item,
  ) async {
    final wardrobe = context.read<WardrobeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (wardrobe.wornToday(item)) {
      await wardrobe.unmarkWornToday([item]);
    } else {
      HapticFeedback.lightImpact();
      await wardrobe.markWornToday([item]);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Logged "${item.name}" as worn today ✷')),
        );
    }
  }

  /// Opens the generator with a look built around [item]. When the piece
  /// has several moods, asks which one first.
  static Future<void> styleAround(
    BuildContext context,
    ClothingItem item,
  ) async {
    var mood = item.primaryMood;
    if (item.moods.length > 1) {
      final picked = await showModalBottomSheet<Mood>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'style it for which mood?',
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
              ),
              for (final m in item.moods)
                ListTile(
                  leading: Text(m.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(m.label),
                  onTap: () => Navigator.pop(sheetContext, m),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (picked == null) return;
      mood = picked;
    }
    if (!context.mounted) return;
    context.read<StyleRequestController>().request(
      StyleRequest(piece: item, mood: mood),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Returns true when the piece was deleted.
  static Future<bool> confirmDelete(
    BuildContext context,
    ClothingItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this piece?'),
        content: Text(
          '"${item.name}" will be removed from your wardrobe and from any '
          'saved looks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final outfits = context.read<OutfitsProvider>();
    await context.read<WardrobeProvider>().delete(item);
    await outfits.load();
    messenger.showSnackBar(SnackBar(content: Text('Removed "${item.name}"')));
    return true;
  }

  static Future<void> showQuickActions(
    BuildContext context,
    ClothingItem item,
  ) {
    HapticFeedback.lightImpact();
    final tokens = FitLabColors.of(context);
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                item.name,
                style: Theme.of(sheetContext).textTheme.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: Icon(
                item.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: tokens.favorite,
              ),
              title: Text(
                item.isFavorite
                    ? 'Remove from favourites'
                    : 'Add to favourites',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                context.read<WardrobeProvider>().toggleFavorite(item);
              },
            ),
            ListTile(
              leading: Icon(
                context.read<WardrobeProvider>().wornToday(item)
                    ? Icons.check_circle_rounded
                    : Icons.checkroom_outlined,
              ),
              title: Text(
                context.read<WardrobeProvider>().wornToday(item)
                    ? 'Worn today · tap to undo'
                    : 'Wore this today',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                toggleWornToday(context, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Style this piece'),
              onTap: () {
                Navigator.pop(sheetContext);
                styleAround(context, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit piece'),
              onTap: () {
                Navigator.pop(sheetContext);
                openEditor(context, existing: item);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: const Text('Remove from wardrobe'),
              onTap: () {
                Navigator.pop(sheetContext);
                confirmDelete(context, item);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
