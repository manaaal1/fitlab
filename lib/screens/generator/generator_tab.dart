import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../core/constants/moods.dart';
import '../../data/models/clothing_item.dart';
import '../../domain/outfit_generator.dart';
import '../../providers/outfits_provider.dart';
import '../../providers/style_request.dart';
import '../../providers/wardrobe_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/clothing_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/mood_chip.dart';
import '../item_actions.dart';
import '../share_look.dart';

class GeneratorTab extends StatefulWidget {
  const GeneratorTab({
    super.key,
    this.revealDelay = defaultRevealDelay,
    this.random,
  });

  static const defaultRevealDelay = Duration(milliseconds: 750);

  final Duration revealDelay;
  final Random? random;

  @override
  State<GeneratorTab> createState() => _GeneratorTabState();
}

class _GeneratorTabState extends State<GeneratorTab> {
  Mood? _mood;
  GenerationResult? _result;
  bool _generating = false;

  /// Pieces the user pinned; Shuffle keeps them and re-rolls the rest.
  final Set<int> _locked = {};

  /// Increments per request so a slow, superseded request is ignored.
  int _generation = 0;

  Future<void> _generate(
    Mood mood, {
    bool shuffle = false,
    ClothingItem? around,
  }) async {
    final wardrobeProvider = context.read<WardrobeProvider>();
    final wardrobe = wardrobeProvider.items;
    final avoid = shuffle ? _result?.ids : null;
    final token = ++_generation;

    HapticFeedback.mediumImpact();
    setState(() {
      // A new mood (or a new "style this piece") starts with fresh locks.
      if (!shuffle) _locked.clear();
      if (around?.id != null) _locked.add(around!.id!);
      _mood = mood;
      _generating = true;
    });
    final locked = [for (final id in _locked) ?wardrobeProvider.byId(id)];

    if (widget.revealDelay > Duration.zero) {
      await Future<void>.delayed(widget.revealDelay);
    }
    if (!mounted || token != _generation) return;

    setState(() {
      _result = OutfitGenerator.generate(
        wardrobe: wardrobe,
        mood: mood,
        random: widget.random,
        avoidIds: avoid,
        locked: locked,
      );
      _generating = false;
    });
  }

  void _toggleLock(ClothingItem item) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_locked.remove(item.id)) _locked.add(item.id!);
    });
  }

  /// Acts on a "style this piece" request from a piece's detail screen.
  void _consumeStyleRequest() {
    final request = context.read<StyleRequestController>().take();
    if (request == null || !mounted) return;
    _generate(request.mood, around: request.piece);
  }

  Future<void> _toggleWornToday(List<ClothingItem> items) async {
    final wardrobe = context.read<WardrobeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final allWorn = items.every(wardrobe.wornToday);
    if (allWorn) {
      await wardrobe.unmarkWornToday(items);
    } else {
      HapticFeedback.lightImpact();
      await wardrobe.markWornToday(items);
      messenger.showSnackBar(
        const SnackBar(content: Text('Logged as worn today ✷')),
      );
    }
  }

  Future<void> _saveLook(List<ClothingItem> items) async {
    final mood = _mood!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameLookDialog(initial: '${mood.label} look'),
    );
    if (name == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await context.read<OutfitsProvider>().save(
      name: name,
      mood: mood,
      items: items,
    );
    HapticFeedback.lightImpact();
    messenger.showSnackBar(
      SnackBar(content: Text('Saved "$name" to your looks ♡')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();
    if (context.watch<StyleRequestController>().pending != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _consumeStyleRequest(),
      );
    }

    if (!wardrobe.isLoading && wardrobe.items.isEmpty) {
      return EmptyState(
        emoji: '✨',
        title: 'nothing to style yet',
        subtitle:
            'add a few pieces to your wardrobe and FitLab will curate '
            'looks for every mood.',
        actionLabel: 'Add a piece',
        onAction: () => ItemActions.openEditor(context),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final picker = _MoodPicker(
          items: wardrobe.items,
          selected: _mood,
          onSelected: (m) => _generate(m),
        );
        final result = _buildResult(context, wardrobe, wide);

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 340,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 12, 24),
                  child: picker,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, pane) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: pane.maxHeight),
                      child: Align(
                        alignment: _hasLook
                            ? Alignment.topCenter
                            : Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: result,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              picker,
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 320),
                child: Center(child: result),
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _hasLook => !_generating && _result != null && _mood != null;

  Widget _buildResult(
    BuildContext context,
    WardrobeProvider wardrobe,
    bool wide,
  ) {
    final theme = Theme.of(context);

    if (_generating) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_mood?.emoji ?? '✷', style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 16),
              AnimatedTextKit(
                key: ValueKey(_generation),
                isRepeatingAnimation: false,
                animatedTexts: [
                  TypewriterAnimatedText(
                    'curating your vibe ✷',
                    speed: const Duration(milliseconds: 32),
                    textStyle: theme.textTheme.headlineMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final result = _result;
    if (result == null || _mood == null) {
      return const EmptyState(
        scrollable: false,
        emoji: '🪄',
        title: 'your next favourite outfit awaits ✷',
        subtitle:
            'choose a mood and FitLab will curate a look from your '
            'wardrobe.',
      );
    }

    // Drop pieces deleted since the look was generated.
    final items = [for (final i in result.items) ?wardrobe.byId(i.id)];

    if (items.isEmpty) {
      return EmptyState(
        scrollable: false,
        emoji: _mood!.emoji,
        title: 'not enough pieces for ${_mood!.label} yet',
        subtitle:
            'add a ${result.missing.map((c) => c.label.toLowerCase()).join(' and a ')} '
            'or a dress with the ${_mood!.label} mood to build a look.',
        actionLabel: 'Add a piece',
        onAction: () => ItemActions.openEditor(
          context,
          initialMoods: [_mood!],
          initialCategory: result.missing.firstOrNull,
        ),
      );
    }

    final columns = wide ? 3 : 2;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 24 : 0,
        wide ? 16 : 0,
        wide ? 24 : 0,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_mood!.emoji} your ${_mood!.label.toLowerCase()} look',
                  style: theme.textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          if (items.length > 1) ...[
            const SizedBox(height: 6),
            Text(
              _locked.isEmpty
                  ? 'tap the pin on a piece to keep it, then shuffle the rest.'
                  : 'pinned pieces stay when you shuffle.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (result.missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            _MissingHint(mood: _mood!, result: result),
          ],
          const SizedBox(height: 12),
          GridView.builder(
            key: ValueKey('look-$_generation'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: cardExtent(170, context),
            ),
            itemBuilder: (context, index) => FadeSlideIn(
              delay: Duration(milliseconds: 90 * index),
              child: ClothingCard(
                item: items[index],
                fixedImageHeight: 170,
                onTap: () => ItemActions.openDetail(context, items[index]),
                badge: _PinButton(
                  pinned: _locked.contains(items[index].id),
                  onPressed: () => _toggleLock(items[index]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _generate(_mood!, shuffle: true),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: Text(_locked.isEmpty ? 'Shuffle' : 'Shuffle rest'),
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (buttonContext) => IconButton.outlined(
                  tooltip: 'Share look',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => shareLook(
                    buttonContext,
                    title: '${_mood!.label} look',
                    mood: _mood!,
                    items: items,
                  ),
                  icon: const Icon(Icons.ios_share_rounded),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _saveLook(items),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save look'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              final worn = items.every(wardrobe.wornToday);
              return TextButton.icon(
                onPressed: () => _toggleWornToday(items),
                icon: Icon(
                  worn ? Icons.check_circle_rounded : Icons.checkroom_outlined,
                ),
                label: Text(
                  worn ? 'Worn today · tap to undo' : 'Wearing this today',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Small round pin toggle drawn over a generated piece.
class _PinButton extends StatelessWidget {
  const _PinButton({required this.pinned, required this.onPressed});

  final bool pinned;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: pinned ? scheme.primary : scheme.surface.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: pinned ? 'Unpin piece' : 'Pin piece',
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 18,
              color: pinned ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodPicker extends StatelessWidget {
  const _MoodPicker({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<ClothingItem> items;
  final Mood? selected;
  final ValueChanged<Mood> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('choose a mood', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'moods without pieces are dimmed.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mood in Mood.values)
              Builder(
                builder: (context) {
                  final count = OutfitGenerator.countFor(items, mood);
                  final chip = MoodChip(
                    mood: mood,
                    selected: selected == mood,
                    count: count,
                    enabled: count > 0,
                    onTap: () => onSelected(mood),
                  );
                  return count > 0
                      ? chip
                      : Tooltip(
                          message: 'Add ${mood.label} pieces to unlock',
                          child: chip,
                        );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _MissingHint extends StatelessWidget {
  const _MissingHint({required this.mood, required this.result});

  final Mood mood;
  final GenerationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = FitLabColors.of(context);
    final missing = result.missing.first;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: mood.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(missing.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'add a ${missing.label.toLowerCase()} for ${mood.label} to '
              'complete this look',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.chipForeground,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ItemActions.openEditor(
              context,
              initialMoods: [mood],
              initialCategory: missing,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _NameLookDialog extends StatefulWidget {
  const _NameLookDialog({required this.initial});

  final String initial;

  @override
  State<_NameLookDialog> createState() => _NameLookDialogState();
}

class _NameLookDialogState extends State<_NameLookDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    Navigator.pop(context, name.isEmpty ? widget.initial : name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this look'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(hintText: 'e.g. sunday market'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
