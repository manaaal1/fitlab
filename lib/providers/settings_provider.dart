import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app preferences: theme mode and first-launch onboarding.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs)
    : _themeMode = _parseMode(_prefs.getString(_themeKey)),
      _seenOnboarding = _prefs.getBool(_onboardingKey) ?? false;

  static const _themeKey = 'theme_mode';
  static const _onboardingKey = 'seen_onboarding';

  final SharedPreferences _prefs;

  ThemeMode _themeMode;
  bool _seenOnboarding;

  ThemeMode get themeMode => _themeMode;
  bool get seenOnboarding => _seenOnboarding;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_themeKey, mode.name);
  }

  Future<void> completeOnboarding() async {
    _seenOnboarding = true;
    notifyListeners();
    await _prefs.setBool(_onboardingKey, true);
  }

  Future<void> resetOnboarding() async {
    _seenOnboarding = false;
    notifyListeners();
    await _prefs.setBool(_onboardingKey, false);
  }

  static ThemeMode _parseMode(String? value) => ThemeMode.values.firstWhere(
    (m) => m.name == value,
    orElse: () => ThemeMode.system,
  );
}
