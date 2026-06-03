import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  zhHans('zh_Hans', Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')),
  en('en', Locale('en'));

  final String key;
  final Locale locale;

  const AppLanguage(this.key, this.locale);

  static AppLanguage fromKey(String? key) {
    return AppLanguage.values.firstWhere(
      (language) => language.key == key,
      orElse: () => AppLanguage.zhHans,
    );
  }

  static AppLanguage fromLocale(Locale locale) {
    if (locale.languageCode.toLowerCase() == 'en') return AppLanguage.en;
    return AppLanguage.zhHans;
  }
}

class LocaleStore extends ChangeNotifier {
  static const _prefKey = 'app_language';

  AppLanguage _language = AppLanguage.zhHans;

  LocaleStore() {
    _loadSaved();
  }

  AppLanguage get language => _language;

  Locale get locale => _language.locale;

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    final next = AppLanguage.fromKey(saved);
    if (next == _language) return;
    _language = next;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, language.key);
  }
}
