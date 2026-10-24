import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/categories.dart';
import '../../core/constants/moods.dart';
import '../../core/utils/color_detector.dart';
import '../../data/models/clothing_item.dart';
import '../../providers/wardrobe_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/category_picker.dart';
import '../../widgets/form_parts.dart';

/// One photo's details while batch-adding.
class _Draft {
  _Draft(this.path) : name = TextEditingController();

  final String path;
  final TextEditingController name;
  ClothingCategory? category;
  String? colorHex;
}

/// Adds several pieces at once: shared moods, then a name, category and
/// colour per photo.
class BatchAddScreen extends StatefulWidget {
  const BatchAddScreen({
    super.key,
    required this.photoPaths,
    this.initialMoods = const {},
    this.initialCategory,
  });

  static const int maxPhotos = 20;

  final List<String> photoPaths;
  final Set<Mood> initialMoods;
  final ClothingCategory? initialCategory;

  @override
  State<BatchAddScreen> createState() => _BatchAddScreenState();
}

class _BatchAddScreenState extends State<BatchAddScreen> {
  late final List<_Draft> _drafts;
  late Set<Mood> _moods;
  bool _submitted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _moods = widget.initialMoods.isEmpty ? {Mood.casual} : widget.initialMoods;
    _drafts = [
      for (final path in widget.photoPaths)
        _Draft(path)..category = widget.initialCategory,
    ];
    for (final d in _drafts) {
      ColorDetector.fromFile(d.path).then((swatch) {
        if (!mounted || swatch == null || d.colorHex != null) return;
        setState(() => d.colorHex = swatch.hex);
      });
    }
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.name.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_drafts.any((d) => d.category == null)) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _saving = true);
    final wardrobe = context.read<WardrobeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final now = DateTime.now();

    final pieces = [
      for (var i = 0; i < _drafts.length; i++)
        ClothingItem(
          name: _drafts[i].name.text.trim().isEmpty
              ? _drafts[i].category!.label
              : _drafts[i].name.text.trim(),
          category: _drafts[i].category!,
          imagePath: '',
          moods: _moods.toList(),
          // Keep the chosen order in the newest-first grid.
          createdAt: now.add(Duration(milliseconds: _drafts.length - i)),
          colorHex: _drafts[i].colorHex,
        ),
    ];

    try {
      await wardrobe.addAll(pieces, [for (final d in _drafts) d.path]);
      HapticFeedback.lightImpact();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${pieces.length} pieces added to your wardrobe ♡'),
        ),
      );
      navigator.pop();
    } catch (e) {
      debugPrint('Batch add failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save these pieces. Try again.'),
        ),
      );
    }
  }

  void _remove(_Draft draft) {
    setState(() => _drafts.remove(draft));
    draft.name.dispose();
    if (_drafts.isEmpty) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = _drafts.where((d) => d.category == null).length;

    return Scaffold(
      appBar: AppBar(title: Text('Add ${_drafts.length} Pieces')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Moods', trailing: 'for every piece'),
                  MoodMultiPicker(
                    selected: _moods,
                    onChanged: (m) => setState(() => _moods = m),
                  ),
                  const SizedBox(height: 24),
                  for (final draft in _drafts) ...[
                    _DraftCard(
                      key: ObjectKey(draft),
                      draft: draft,
                      showError: _submitted && draft.category == null,
                      onChanged: () => setState(() {}),
                      onRemove: _saving ? null : () => _remove(draft),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_submitted && missing > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'pick a category for $missing '
                        'piece${missing == 1 ? '' : 's'}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : Text('Add ${_drafts.length} pieces'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    super.key,
    required this.draft,
    required this.showError,
    required this.onChanged,
    required this.onRemove,
  });

  final _Draft draft;
  final bool showError;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = FitLabColors.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: showError ? theme.colorScheme.error : Colors.transparent,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(draft.path),
                  width: 88,
                  height: 110,
                  fit: BoxFit.cover,
                  cacheWidth: 264,
                  errorBuilder: (_, _, _) => Container(
                    width: 88,
                    height: 110,
                    color: tokens.imagePlaceholder,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: draft.name,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: draft.category?.label ?? 'optional',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove photo',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CategoryPicker(
            selected: draft.category,
            onChanged: (c) {
              draft.category = c;
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          SwatchPicker(
            size: 30,
            selected: draft.colorHex,
            onChanged: (hex) {
              draft.colorHex = hex;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}
