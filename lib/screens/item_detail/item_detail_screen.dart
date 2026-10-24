import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/clothing_item.dart';
import '../../providers/wardrobe_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fitlab_image.dart';
import '../../widgets/mood_chip.dart';
import '../item_actions.dart';

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();
    final item = wardrobe.byId(itemId);
    final theme = Theme.of(context);
    final tokens = FitLabColors.of(context);

    // The piece was deleted while this screen was open.
    if (item == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Piece'),
        actions: [
          IconButton(
            tooltip: item.isFavorite ? 'Remove from favourites' : 'Favourite',
            onPressed: () =>
                context.read<WardrobeProvider>().toggleFavorite(item),
            icon: Icon(
              item.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: item.isFavorite ? tokens.favorite : null,
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => ItemActions.openEditor(context, existing: item),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await ItemActions.confirmDelete(context, item)) {
                navigator.pop();
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Hero(
                    tag: 'item-${item.id}',
                    child: FitLabImage(
                      path: item.imagePath,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(item.name, style: theme.textTheme.headlineLarge),
                const SizedBox(height: 4),
                Text(
                  '${item.category.emoji} ${item.category.label}  ·  '
                  'added ${DateFormat.yMMMd().format(item.createdAt)}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final m in item.moods)
                      MoodChip(mood: m, selected: true),
                    if (item.colorHex != null)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse('FF${item.colorHex}', radix: 16),
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.dividerColor),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _wearSummary(item, wardrobe),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            ItemActions.toggleWornToday(context, item),
                        icon: Icon(
                          wardrobe.wornToday(item)
                              ? Icons.check_circle_rounded
                              : Icons.checkroom_outlined,
                        ),
                        label: Text(
                          wardrobe.wornToday(item)
                              ? 'Worn today'
                              : 'Wore this today',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => ItemActions.styleAround(context, item),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Style this piece'),
                      ),
                    ),
                  ],
                ),
                if (item.notes != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.chipBackground,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(item.notes!, style: theme.textTheme.bodyLarge),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _wearSummary(ClothingItem item, WardrobeProvider wardrobe) {
  if (item.lastWornOn == null) {
    return wardrobe.isForgotten(item)
        ? 'never worn yet · give it a spin? 💤'
        : 'not worn yet';
  }
  final days = wardrobe.today.difference(item.lastWornOn!).inDays;
  final when = switch (days) {
    0 => 'today',
    1 => 'yesterday',
    < 30 => '$days days ago',
    _ => 'on ${DateFormat.yMMMd().format(item.lastWornOn!)}',
  };
  final times = item.wearCount == 1 ? 'once' : '${item.wearCount} times';
  return 'worn $times · last worn $when';
}
