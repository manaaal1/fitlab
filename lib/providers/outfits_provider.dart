import 'package:flutter/foundation.dart';

import '../core/constants/moods.dart';
import '../data/models/clothing_item.dart';
import '../data/models/outfit.dart';
import '../data/repositories/outfit_repository.dart';

class OutfitsProvider extends ChangeNotifier {
  OutfitsProvider(this._repo);

  final OutfitRepository _repo;

  List<Outfit> _outfits = const [];
  bool _isLoading = true;
  String? _error;

  List<Outfit> get outfits => _outfits;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Looks grouped by mood (enum order), favourites first within a group.
  Map<Mood, List<Outfit>> get byMood {
    final grouped = <Mood, List<Outfit>>{};
    for (final mood in Mood.values) {
      final looks = _outfits.where((o) => o.mood == mood).toList()
        ..sort((a, b) {
          if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });
      if (looks.isNotEmpty) grouped[mood] = looks;
    }
    return grouped;
  }

  Future<void> load() async {
    try {
      _outfits = await _repo.getAll();
      _error = null;
    } catch (e) {
      _error = 'Could not load your saved looks.';
      debugPrint('Outfits load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Outfit> save({
    required String name,
    required Mood mood,
    required List<ClothingItem> items,
  }) async {
    final saved = await _repo.save(
      Outfit(name: name, mood: mood, items: items, createdAt: DateTime.now()),
    );
    await load();
    return saved;
  }

  /// Removes the look from memory first so swipe-to-dismiss never sees a
  /// stale tile, then deletes it from the database.
  Future<void> delete(Outfit outfit) async {
    if (outfit.id == null) return;
    _outfits = _outfits.where((o) => o.id != outfit.id).toList();
    notifyListeners();
    await _repo.delete(outfit.id!);
    await load();
  }

  /// Puts a just-deleted look back (used by the undo snackbar).
  Future<void> restore(Outfit outfit) async {
    await _repo.save(outfit);
    await load();
  }

  Future<void> toggleFavorite(Outfit outfit) async {
    if (outfit.id == null) return;
    await _repo.setFavorite(outfit.id!, !outfit.isFavorite);
    await load();
  }

  Future<void> rename(Outfit outfit, String name) async {
    if (outfit.id == null) return;
    await _repo.rename(outfit.id!, name);
    await load();
  }
}
