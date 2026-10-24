import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/moods.dart';
import '../../data/models/outfit.dart';
import '../../providers/outfits_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fitlab_image.dart';
import 'outfit_detail_screen.dart';

class LooksTab extends StatelessWidget {
  const LooksTab({super.key, this.onGoToGenerator});

  final VoidCallback? onGoToGenerator;

  @override
  Widget build(BuildContext context) {
    final looks = context.watch<OutfitsProvider>();

    if (looks.isLoading && looks.outfits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (looks.outfits.isEmpty) {
      return EmptyState(
        emoji: '📌',
        title: 'no saved looks yet',
        subtitle:
            'generate an outfit you love and tap "Save look" to keep '
            'it here, grouped by mood.',
        actionLabel: onGoToGenerator == null ? null : 'Generate a look',
        onAction: onGoToGenerator,
      );
    }

    final groups = looks.byMood;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: CustomScrollView(
          slivers: [
            for (final entry in groups.entries) ...[
              SliverToBoxAdapter(
                child: _MoodHeader(mood: entry.key, count: entry.value.length),
              ),
              SliverList.separated(
                itemCount: entry.value.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _OutfitTile(outfit: entry.value[i]),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _MoodHeader extends StatelessWidget {
  const _MoodHeader({required this.mood, required this.count});

  final Mood mood;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: mood.color.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Text(mood.emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Text(mood.label, style: theme.textTheme.headlineSmall),
            const SizedBox(width: 8),
            Text('$count', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _OutfitTile extends StatelessWidget {
  const _OutfitTile({required this.outfit});

  final Outfit outfit;

  Future<void> _delete(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final provider = context.read<OutfitsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await provider.delete(outfit);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${outfit.name}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => provider.restore(outfit),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = FitLabColors.of(context);

    return Dismissible(
      key: ValueKey('outfit-${outfit.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: DecoratedBox(
        // Opaque card colour under the shadow so the tile stays white.
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: tokens.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OutfitDetailScreen(outfitId: outfit.id!),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              outfit.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _subtitle(outfit),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.subtleText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: outfit.isFavorite
                            ? 'Remove from favourites'
                            : 'Favourite',
                        onPressed: () => context
                            .read<OutfitsProvider>()
                            .toggleFavorite(outfit),
                        icon: Icon(
                          outfit.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: outfit.isFavorite ? tokens.favorite : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 96,
                    child: outfit.items.isEmpty
                        ? Center(
                            child: Text(
                              'all pieces from this look were removed',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: outfit.items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: FitLabImage(
                                path: outfit.items[i].imagePath,
                                width: 80,
                                height: 96,
                                cacheWidth: 240,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _subtitle(Outfit outfit) {
    final date = DateFormat.yMMMd().format(outfit.createdAt);
    final pieces =
        '${outfit.items.length} '
        'piece${outfit.items.length == 1 ? '' : 's'}';
    final missing = outfit.missingCount == 0
        ? ''
        : '  ·  ${outfit.missingCount} no longer in wardrobe';
    return '$pieces  ·  $date$missing';
  }
}
