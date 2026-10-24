import 'package:flutter/foundation.dart';

import '../core/constants/categories.dart';
import '../core/constants/moods.dart';
import '../core/utils/image_storage.dart';
import '../data/models/clothing_item.dart';
import '../data/repositories/wardrobe_repository.dart';

class WardrobeProvider extends ChangeNotifier {
  WardrobeProvider(this._repo, this._images, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final WardrobeRepository _repo;
  final ImageStorage _images;
  final DateTime Function() _clock;

  /// A piece is "forgotten" after this long without being worn.
  static const forgottenAfter = Duration(days: 30);

  List<ClothingItem> _items = const [];
  bool _isLoading = true;
  String? _error;

  Mood? _moodFilter;
  ClothingCategory? _categoryFilter;
  bool _favoritesOnly = false;
  bool _forgottenOnly = false;
  String _query = '';

  List<ClothingItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Mood? get moodFilter => _moodFilter;
  ClothingCategory? get categoryFilter => _categoryFilter;
  bool get favoritesOnly => _favoritesOnly;
  bool get forgottenOnly => _forgottenOnly;
  String get query => _query;

  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  bool get hasFilters =>
      _moodFilter != null ||
      _categoryFilter != null ||
      _favoritesOnly ||
      _forgottenOnly ||
      _query.isNotEmpty;

  bool wornToday(ClothingItem item) => item.lastWornOn == today;

  /// Not worn for [forgottenAfter], or never worn and owned that long.
  bool isForgotten(ClothingItem item) {
    final since = item.lastWornOn ?? item.createdAt;
    return today.difference(since) >= forgottenAfter;
  }

  List<ClothingItem> get forgotten => _items.where(isForgotten).toList()
    ..sort(
      (a, b) =>
          (a.lastWornOn ?? a.createdAt).compareTo(b.lastWornOn ?? b.createdAt),
    );

  List<ClothingItem> get filtered {
    final q = _query.trim().toLowerCase();
    final list = _items.where((item) {
      if (_moodFilter != null && !item.hasMood(_moodFilter!)) return false;
      if (_categoryFilter != null && item.category != _categoryFilter) {
        return false;
      }
      if (_favoritesOnly && !item.isFavorite) return false;
      if (_forgottenOnly && !isForgotten(item)) return false;
      if (q.isNotEmpty &&
          !item.name.toLowerCase().contains(q) &&
          !(item.notes ?? '').toLowerCase().contains(q) &&
          !item.category.label.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
    if (_forgottenOnly) {
      // Longest-forgotten first, so the nudge is most useful.
      list.sort(
        (a, b) => (a.lastWornOn ?? a.createdAt).compareTo(
          b.lastWornOn ?? b.createdAt,
        ),
      );
    }
    return list;
  }

  /// Moods that have at least one piece, in enum order.
  List<Mood> get moodsPresent {
    final present = {for (final i in _items) ...i.moods};
    return Mood.values.where(present.contains).toList();
  }

  ClothingItem? byId(int? id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _repo.getAll();
      _error = null;
    } catch (e) {
      _error = 'Could not load your wardrobe.';
      debugPrint('Wardrobe load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Copies the picked photo into app storage, then saves the piece.
  Future<ClothingItem> add(ClothingItem draft, String sourceImagePath) async {
    final saved = await _insert(draft, sourceImagePath);
    await load();
    return saved;
  }

  /// Saves several pieces in one go (multi-photo add). Each draft is paired
  /// with the photo at the same index.
  Future<List<ClothingItem>> addAll(
    List<ClothingItem> drafts,
    List<String> sourceImagePaths,
  ) async {
    assert(drafts.length == sourceImagePaths.length);
    final saved = <ClothingItem>[];
    for (var i = 0; i < drafts.length; i++) {
      saved.add(await _insert(drafts[i], sourceImagePaths[i]));
    }
    await load();
    return saved;
  }

  Future<ClothingItem> _insert(ClothingItem draft, String source) async {
    final stored = await _images.persist(source);
    return _repo.insert(draft.copyWith(imagePath: stored));
  }

  /// Saves edits. When [newSourceImagePath] is given the old photo is
  /// replaced and deleted.
  Future<void> update(ClothingItem item, {String? newSourceImagePath}) async {
    var toSave = item;
    final previous = byId(item.id);
    if (newSourceImagePath != null) {
      toSave = item.copyWith(
        imagePath: await _images.persist(newSourceImagePath),
      );
    }
    await _repo.update(toSave);
    if (newSourceImagePath != null && previous != null) {
      await _images.delete(previous.imagePath);
    }
    await load();
  }

  Future<void> toggleFavorite(ClothingItem item) async {
    await _repo.update(item.copyWith(isFavorite: !item.isFavorite));
    await load();
  }

  /// Records that these pieces were worn today.
  Future<void> markWornToday(Iterable<ClothingItem> pieces) async {
    await _repo.markWorn(_ids(pieces), today);
    await load();
  }

  /// Undoes today's wear record for these pieces.
  Future<void> unmarkWornToday(Iterable<ClothingItem> pieces) async {
    await _repo.unmarkWorn(_ids(pieces), today);
    await load();
  }

  static List<int> _ids(Iterable<ClothingItem> pieces) => [
    for (final p in pieces) ?p.id,
  ];

  Future<void> delete(ClothingItem item) async {
    await _repo.delete(item);
    await load();
  }

  Future<void> clearAll() async {
    await _repo.deleteAll();
    clearFilters();
    await load();
  }

  void setMoodFilter(Mood? mood) {
    _moodFilter = mood;
    notifyListeners();
  }

  void setCategoryFilter(ClothingCategory? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void setFavoritesOnly(bool value) {
    _favoritesOnly = value;
    notifyListeners();
  }

  void setForgottenOnly(bool value) {
    _forgottenOnly = value;
    notifyListeners();
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  void clearFilters() {
    _moodFilter = null;
    _categoryFilter = null;
    _favoritesOnly = false;
    _forgottenOnly = false;
    _query = '';
    notifyListeners();
  }
}
