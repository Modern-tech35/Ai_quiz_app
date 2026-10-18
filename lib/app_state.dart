import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';

/// Holds app-wide UI state (language + theme) and persists it locally.
class AppState extends ChangeNotifier {
  AppState() {
    _load();
  }

  static const _localeKey = 'app_locale';
  static const _themeKey = 'app_theme_mode';

  Locale _locale = const Locale('en');
  ThemeMode _themeMode = ThemeMode.system;
  bool _loaded = false;

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get loaded => _loaded;

  String get languageCode => _locale.languageCode;

  /// Translate a key in the current language (falls back to English).
  String t(String key) {
    final lang = appTranslations[languageCode] ?? appTranslations['en']!;
    return lang[key] ?? appTranslations['en']![key] ?? key;
  }

  AppLanguage get currentLanguage => supportedLanguages.firstWhere(
        (l) => l.code == languageCode,
        orElse: () => supportedLanguages.first,
      );

  Future<void> setLocale(String code) async {
    if (!appTranslations.containsKey(code)) return;
    _locale = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, code);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);
    if (savedLocale != null && appTranslations.containsKey(savedLocale)) {
      _locale = Locale(savedLocale);
    }
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme != null) {
      _themeMode = ThemeMode.values
          .firstWhere((m) => m.name == savedTheme, orElse: () => ThemeMode.system);
    }
    _loaded = true;
    notifyListeners();
  }
}
