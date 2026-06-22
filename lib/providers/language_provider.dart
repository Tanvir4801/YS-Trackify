import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, hindi, gujarati }

class LanguageProvider extends ChangeNotifier {
  static const String _prefKey = 'app_language';

  AppLanguage _language = AppLanguage.english;
  bool _initialized = false;

  AppLanguage get language => _language;
  bool get initialized => _initialized;

  Locale get locale {
    switch (_language) {
      case AppLanguage.hindi:
        return const Locale('hi');
      case AppLanguage.gujarati:
        return const Locale('gu');
      case AppLanguage.english:
        return const Locale('en');
    }
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefKey) ?? 'en';
    _language = _fromCode(value);
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) {
      return;
    }

    _language = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _codeFromLanguage(language));
  }

  AppLanguage _fromCode(String code) {
    switch (code) {
      case 'hi':
        return AppLanguage.hindi;
      case 'gu':
        return AppLanguage.gujarati;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }

  String _codeFromLanguage(AppLanguage language) {
    switch (language) {
      case AppLanguage.hindi:
        return 'hi';
      case AppLanguage.gujarati:
        return 'gu';
      case AppLanguage.english:
        return 'en';
    }
  }
}
