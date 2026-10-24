import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../../core/constants/categories.dart';
import '../../providers/wardrobe_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/clothing_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/mood_chip.dart';
import '../../widgets/signature_footer.dart';
import '../item_actions.dart';

/// Responsive column count for the masonry grid.
int columnsForWidth(double width) => (width / 170).floor().clamp(2, 6);

class WardrobeTab extends StatelessWidget {
  const WardrobeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();

    if (wardrobe.isLoading && wardrobe.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (wardrobe.error != null && wardrobe.items.isEmpty) {
      return EmptyState(
        emoji: '🧵',
        title: 'something got tangled',
        subtitle: wardrobe.error!,
        actionLabel: 'Try again',
        onAction: wardrobe.load,
      );
    }
    if (wardrobe.items.isEmpty) {
      return EmptyState(
        emoji: '👗',
        title: 'your wardrobe is feeling a little empty ♡',
        subtitle:
            'add your favourite pieces to start building outfits and aesthetics.',
        actionLabel: 'Add your first piece',
        onAction: () => ItemActions.openEditor(context),
      );
    }

    final items = wardrobe.filtered;

    return Column(
      children: [
        const _FilterBar(),
        Expanded(
          child: items.isEmpty
              ? EmptyState(
                  emoji: '🔍',
                  title: wardrobe.moodFilter != null
                      ? 'nothing in ${wardrobe.moodFilter!.label} yet ♡'
                      : 'no pieces match',
                  subtitle: 'try a different mood, category or search.',
                  actionLabel: 'Clear filters',
                  onAction: wardrobe.clearFilters,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return RefreshIndicator(
                      onRefresh: wardrobe.load,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          if (!wardrobe.hasFilters &&
                              wardrobe.forgotten.isNotEmpty)
                            SliverToBoxAdapter(
                              child: _ForgottenBanner(
                                count: wardrobe.forgotten.length,
                                onTap: () => wardrobe.setForgottenOnly(true),
                              ),
                            ),
                          if (wardrobe.forgottenOnly)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  8,
                                ),
                                child: Text(
                                  'not worn in a month, longest-forgotten '
                                  'first. tap one and choose "Style this '
                                  'piece" for ideas.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                            sliver: SliverMasonryGrid.count(
                              crossAxisCount: columnsForWidth(
                                constraints.maxWidth,
                              ),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return FadeSlideIn(
                                  key: ValueKey(item.id),
                                  onceKey: 'grid-${item.id}',
                                  delay: Duration(
                                    milliseconds: 40 * index.clamp(0, 12),
                                  ),
                                  child: ClothingCard(
                                    item: item,
                                    heroTag: 'item-${item.id}',
                                    onTap: () =>
                                        ItemActions.openDetail(context, item),
                                    onLongPress: () =>
                                        ItemActions.showQuickActions(
                                          context,
                                          item,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SliverToBoxAdapter(
                            // Room so the FAB never covers the last row.
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 64),
                              child: SignatureFooter(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Nudge toward pieces that haven't been worn in a while.
class _ForgottenBanner extends StatelessWidget {
  const _ForgottenBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = FitLabColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: tokens.chipBackground,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Text('💤', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "$count piece${count == 1 ? '' : 's'} you haven't worn "
                    'in a month',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.chipForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: tokens.subtleText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatefulWidget {
  const _FilterBar();

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  late final TextEditingController _search;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: context.read<WardrobeProvider>().query,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) context.read<WardrobeProvider>().setQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();
    final tokens = FitLabColors.of(context);

    // Keep the field in sync when filters are cleared elsewhere.
    if (wardrobe.query.isEmpty &&
        _search.text.isNotEmpty &&
        !(_debounce?.isActive ?? false)) {
      _search.clear();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search your wardrobe',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              wardrobe.setQuery('');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: wardrobe.favoritesOnly
                    ? 'Show all pieces'
                    : 'Show favourites only',
                isSelected: wardrobe.favoritesOnly,
                onPressed: () =>
                    wardrobe.setFavoritesOnly(!wardrobe.favoritesOnly),
                icon: const Icon(Icons.favorite_border_rounded),
                selectedIcon: Icon(
                  Icons.favorite_rounded,
                  color: tokens.favorite,
                ),
              ),
              PopupMenuButton<int>(
                tooltip: 'Filter by category',
                initialValue: wardrobe.categoryFilter?.index ?? -1,
                // -1 means "all"; a null value would count as a cancel.
                onSelected: (i) => wardrobe.setCategoryFilter(
                  i < 0 ? null : ClothingCategory.values[i],
                ),
                icon: Badge(
                  isLabelVisible: wardrobe.categoryFilter != null,
                  smallSize: 8,
                  child: const Icon(Icons.tune_rounded),
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: -1, child: Text('All categories')),
                  for (final c in ClothingCategory.values)
                    PopupMenuItem(
                      value: c.index,
                      child: Text('${c.emoji}  ${c.label}'),
                    ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            // Let the selected chip's glow show instead of being boxed in.
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            children: [
              MoodChip(
                mood: null,
                selected: wardrobe.moodFilter == null,
                onTap: () => wardrobe.setMoodFilter(null),
              ),
              if (wardrobe.forgottenOnly) ...[
                const SizedBox(width: 8),
                InputChip(
                  avatar: const Text('💤'),
                  label: const Text('Forgotten'),
                  onDeleted: () => wardrobe.setForgottenOnly(false),
                  deleteButtonTooltipMessage: 'Show all pieces',
                ),
              ],
              for (final mood in wardrobe.moodsPresent) ...[
                const SizedBox(width: 8),
                MoodChip(
                  mood: mood,
                  selected: wardrobe.moodFilter == mood,
                  onTap: () => wardrobe.setMoodFilter(
                    wardrobe.moodFilter == mood ? null : mood,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
