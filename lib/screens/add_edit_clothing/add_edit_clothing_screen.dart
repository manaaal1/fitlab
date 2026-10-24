import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/categories.dart';
import '../../core/constants/moods.dart';
import '../../core/constants/swatches.dart';
import '../../core/utils/color_detector.dart';
import '../../data/models/clothing_item.dart';
import '../../providers/outfits_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/category_picker.dart';
import '../../widgets/fitlab_image.dart';
import '../../widgets/form_parts.dart';
import 'batch_add_screen.dart';

class AddEditClothingScreen extends StatefulWidget {
  const AddEditClothingScreen({
    super.key,
    this.existing,
    this.initialMoods,
    this.initialCategory,
  });

  final ClothingItem? existing;
  final List<Mood>? initialMoods;
  final ClothingCategory? initialCategory;

  @override
  State<AddEditClothingScreen> createState() => _AddEditClothingScreenState();
}

class _AddEditClothingScreenState extends State<AddEditClothingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _notes;
  final _picker = ImagePicker();

  /// Freshly picked photo, not yet copied into app storage.
  String? _pickedPath;
  ClothingCategory? _category;
  late Set<Mood> _moods;
  String? _colorHex;

  /// Set when the colour came from photo analysis rather than a tap.
  Swatch? _detected;
  bool _isFavorite = false;

  bool _saving = false;
  bool _submitted = false;

  bool get _isEditing => widget.existing != null;
  bool get _hasImage => _pickedPath != null || _isEditing;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? widget.initialCategory;
    _moods = {...?e?.moods ?? widget.initialMoods};
    if (_moods.isEmpty) _moods = {Mood.casual};
    _colorHex = e?.colorHex;
    _isFavorite = e?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _chooseImage() async {
    final canUseCamera = _picker.supportsImageSource(ImageSource.camera);
    final source = canUseCamera
        ? await showModalBottomSheet<ImageSource>(
            context: context,
            builder: (sheetContext) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Choose from gallery'),
                    onTap: () =>
                        Navigator.pop(sheetContext, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Take a photo'),
                    onTap: () =>
                        Navigator.pop(sheetContext, ImageSource.camera),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          )
        : ImageSource.gallery;
    if (source == null) return;

    try {
      // New pieces from the gallery may pick several photos at once; more
      // than one moves to the batch screen.
      if (!_isEditing && source == ImageSource.gallery) {
        final images = await _picker.pickMultiImage(
          maxWidth: 1600,
          imageQuality: 85,
          limit: BatchAddScreen.maxPhotos,
        );
        if (images.isEmpty || !mounted) return;
        if (images.length > 1) {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => BatchAddScreen(
                photoPaths: [for (final i in images) i.path],
                initialMoods: _moods,
                initialCategory: _category,
              ),
            ),
          );
          return;
        }
        await _onPhotoPicked(images.single.path);
        return;
      }
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      await _onPhotoPicked(image.path);
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code.contains('denied')
                ? 'FitLab needs photo access to add pieces. You can allow it in Settings.'
                : 'Could not open the photo picker.',
          ),
        ),
      );
    }
  }

  /// Shows the photo and suggests its colour unless the user chose one.
  Future<void> _onPhotoPicked(String path) async {
    setState(() => _pickedPath = path);
    if (_colorHex != null && _detected == null) return;
    final swatch = await ColorDetector.fromFile(path);
    if (!mounted || _pickedPath != path || swatch == null) return;
    setState(() {
      _detected = swatch;
      _colorHex = swatch.hex;
    });
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final formValid = _formKey.currentState!.validate();
    if (!formValid || !_hasImage || _category == null) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _saving = true);
    final wardrobe = context.read<WardrobeProvider>();
    final outfits = context.read<OutfitsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notes = _notes.text.trim();

    final item = ClothingItem(
      id: widget.existing?.id,
      name: _name.text.trim(),
      category: _category!,
      imagePath: widget.existing?.imagePath ?? '',
      moods: _moods.toList(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      isFavorite: _isFavorite,
      colorHex: _colorHex,
      notes: notes.isEmpty ? null : notes,
    );

    try {
      if (_isEditing) {
        await wardrobe.update(item, newSourceImagePath: _pickedPath);
        await outfits.load();
      } else {
        await wardrobe.add(item, _pickedPath!);
      }
      HapticFeedback.lightImpact();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Saved changes to "${item.name}"'
                : '"${item.name}" added to your wardrobe ♡',
          ),
        ),
      );
      navigator.pop();
    } catch (e) {
      debugPrint('Saving piece failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save this piece. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = FitLabColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Piece' : 'Add Piece'),
        actions: [
          IconButton(
            tooltip: _isFavorite ? 'Remove from favourites' : 'Favourite',
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
            icon: Icon(
              _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _isFavorite ? tokens.favorite : null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              // Not a lazy ListView: off-screen fields must stay mounted so
              // the form validates all of them.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ImageBox(
                      pickedPath: _pickedPath,
                      storedPath: widget.existing?.imagePath,
                      showError: _submitted && !_hasImage,
                      onTap: _saving ? null : _chooseImage,
                    ),
                    if (!_isEditing && _pickedPath == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'tip: pick several photos to add them all at once.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.subtleText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 40,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. cream knit cardigan',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Give this piece a name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    SectionLabel(
                      'Category',
                      error: _submitted && _category == null
                          ? 'Pick a category'
                          : null,
                    ),
                    CategoryPicker(
                      selected: _category,
                      onChanged: (c) => setState(() => _category = c),
                    ),
                    const SizedBox(height: 24),
                    const SectionLabel('Moods', trailing: 'pick all that fit'),
                    MoodMultiPicker(
                      selected: _moods,
                      onChanged: (m) => setState(() => _moods = m),
                    ),
                    const SizedBox(height: 24),
                    SectionLabel(
                      'Colour (optional)',
                      trailing: _detected != null && _colorHex == _detected!.hex
                          ? 'detected: ${_detected!.name}'
                          : null,
                    ),
                    SwatchPicker(
                      selected: _colorHex,
                      onChanged: (hex) => setState(() {
                        _colorHex = hex;
                        _detected = null;
                      }),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      minLines: 2,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'brand, size, styling ideas…',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          : Text(
                              _isEditing ? 'Save changes' : 'Add to wardrobe',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageBox extends StatelessWidget {
  const _ImageBox({
    required this.pickedPath,
    required this.storedPath,
    required this.showError,
    required this.onTap,
  });

  final String? pickedPath;
  final String? storedPath;
  final bool showError;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = FitLabColors.of(context);
    final hasImage = pickedPath != null || storedPath != null;

    Widget content;
    if (pickedPath != null) {
      content = Image.file(File(pickedPath!), fit: BoxFit.cover);
    } else if (storedPath != null) {
      content = FitLabImage(path: storedPath!, height: 280);
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 44,
            color: showError ? theme.colorScheme.error : tokens.subtleText,
          ),
          const SizedBox(height: 12),
          Text(
            showError ? 'Add a photo of this piece' : 'Tap to add a photo',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: showError ? theme.colorScheme.error : null,
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: hasImage ? 'Change photo' : 'Add photo',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 280,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tokens.chipBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: showError ? theme.colorScheme.error : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (hasImage)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FilledButton.tonalIcon(
                    onPressed: onTap,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Change'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
