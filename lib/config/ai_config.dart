import 'secrets.dart';

class AIPreferences {
  static const String _apiKey = openAiApiKey;

  static String get apiKey => _apiKey;
}
