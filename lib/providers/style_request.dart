import 'package:flutter/foundation.dart';

import '../core/constants/moods.dart';
import '../data/models/clothing_item.dart';

/// "Build a look around this piece": raised from a piece's detail screen,
/// consumed by the generator tab.
class StyleRequest {
  const StyleRequest({required this.piece, required this.mood});

  final ClothingItem piece;
  final Mood mood;
}

/// Carries a [StyleRequest] across screens. The shell switches to the
/// generator when one is pending; the generator takes it and acts on it.
class StyleRequestController extends ChangeNotifier {
  StyleRequest? _pending;

  StyleRequest? get pending => _pending;

  void request(StyleRequest request) {
    _pending = request;
    notifyListeners();
  }

  /// Returns and clears the pending request.
  StyleRequest? take() {
    final request = _pending;
    _pending = null;
    return request;
  }
}
