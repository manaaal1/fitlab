import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/outfit.dart';
import '../../providers/outfits_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/clothing_card.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/mood_chip.dart';
import '../item_actions.dart';
import '../share_look.dart';

class OutfitDetailScreen extends StatelessWidget {
  const OutfitDetailScreen({super.key, required this.outfitId});

  final int outfitId;

  Future<void> _rename(BuildContext context, Outfit outfit) async {
    final controller = TextEditingController(text: outfit.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename look'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await context.read<OutfitsProvider>().rename(outfit, name.trim());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OutfitsProvider>();
    final outfit = provider.outfits.where((o) => o.id == outfitId).firstOrNull;
    final theme = Theme.of(context);
    final tokens = FitLabColors.of(context);

    if (outfit == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Look'),
        actions: [
          if (outfit.items.isNotEmpty)
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: 'Share look',
                onPressed: () => shareLook(
                  buttonContext,
                  title: outfit.name,
                  mood: outfit.mood,
                  items: outfit.items,
                ),
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ),
          IconButton(
            tooltip: 'Rename',
            onPressed: () => _rename(context, outfit),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: outfit.isFavorite ? 'Remove from favourites' : 'Favourite',
            onPressed: () => provider.toggleFavorite(outfit),
            icon: Icon(
              outfit.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: outfit.isFavorite ? tokens.favorite : null,
            ),
          ),
          IconButton(
            tooltip: 'Delete look',
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await provider.delete(outfit);
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Deleted "${outfit.name}"'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => provider.restore(outfit),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(outfit.name, style: theme.textTheme.headlineLarge),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            MoodChip(mood: outfit.mood, selected: true),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat.yMMMd().format(outfit.createdAt),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        if (outfit.items.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final wardrobe = context
                                  .watch<WardrobeProvider>();
                              final pieces = [
                                for (final i in outfit.items)
                                  ?wardrobe.byId(i.id),
                              ];
                              final worn =
                                  pieces.isNotEmpty &&
                                  pieces.every(wardrobe.wornToday);
                              return OutlinedButton.icon(
                                onPressed: pieces.isEmpty
                                    ? null
                                    : () => worn
                                          ? wardrobe.unmarkWornToday(pieces)
                                          : wardrobe.markWornToday(pieces),
                                icon: Icon(
                                  worn
                                      ? Icons.check_circle_rounded
                                      : Icons.checkroom_outlined,
                                ),
                                label: Text(
                                  worn
                                      ? 'Worn today · tap to undo'
                                      : 'Wore this look today',
                                ),
                              );
                            },
                          ),
                        ],
                        if (outfit.missingCount > 0) ...[
                          const SizedBox(height: 12),
                          Text(
                            '${outfit.missingCount} '
                            'piece${outfit.missingCount == 1 ? ' is' : 's are'} '
                            'no longer in your wardrobe.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverGrid.builder(
                    itemCount: outfit.items.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 240,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: cardExtent(180, context),
                    ),
                    itemBuilder: (context, i) => FadeSlideIn(
                      delay: Duration(milliseconds: 70 * i),
                      child: ClothingCard(
                        item: outfit.items[i],
                        fixedImageHeight: 180,
                        onTap: () =>
                            ItemActions.openDetail(context, outfit.items[i]),
                      ),
                    ),
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
