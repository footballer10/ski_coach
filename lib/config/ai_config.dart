import 'package:shared_preferences/shared_preferences.dart';

/// Holds the OpenAI API key. In this version the key is entered in the app
/// (key icon on the start screen, or the refresh button on a run's coaching
/// card) and saved only on this device.
class AIPreferences {
  static const String _prefsKey = 'openai_api_key';
  static String _apiKey = '';

  static String get apiKey => _apiKey;
  static bool get hasApiKey => _apiKey.isNotEmpty;

  /// Loads a previously saved key. Call once at startup.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_prefsKey) ?? '';
  }

  /// Saves [key] on this device. An empty key removes it.
  static Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_apiKey.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, _apiKey);
    }
  }
}
