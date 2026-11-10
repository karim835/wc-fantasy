import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends ChangeNotifier {
  static const _key = 'locale';
  Locale _locale = const Locale('fr');

  Locale get locale => _locale;
  bool get isFrench => _locale.languageCode == 'fr';

  LocaleNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved != 'fr') {
      _locale = Locale(saved);
      notifyListeners();
    }
  }

  Future<void> setLocale(String langCode) async {
    if (_locale.languageCode == langCode) return;
    _locale = Locale(langCode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, langCode);
  }
}

final localeNotifier = LocaleNotifier();
