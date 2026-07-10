import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService {
  static const String _languageKey = 'language_code';
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('ar'));

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString(_languageKey);
    print(
      '🌍 LocalizationService: Loaded language code from prefs: $languageCode',
    );
    if (languageCode != null) {
      locale.value = Locale(languageCode);
      print('🌍 LocalizationService: Set locale to ${locale.value}');
    } else {
      print(
        '🌍 LocalizationService: No saved language, defaulting to ${locale.value}',
      );
    }
  }

  static Future<void> setLocale(Locale newLocale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, newLocale.languageCode);
    locale.value = newLocale;
  }

  static bool isArabic() {
    return locale.value.languageCode == 'ar';
  }
}
