// lib/lang.dart
class AppLang {
  static Map<String, Map<String, String>> translations = {
    'en': {
      'settingsTitle': 'Settings',
      'language': 'Language',
      'darkMode': 'Dark Mode',
    },
    'tr': {
      'settingsTitle': 'Ayarlar',
      'language': 'Dil',
      'darkMode': 'Karanlık Mod',
    },
  };

  static String getText(String langCode, String key) {
    return translations[langCode]?[key] ?? key;
  }
}
