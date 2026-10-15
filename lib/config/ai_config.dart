import '../services/ai_coach.dart';
import 'secrets.dart';

enum AIMode { local, api }

class AIPreferences {
  static AIMode _currentMode = AIMode.api;
  static const String _apiKey = openAiApiKey;

  static AIMode get currentMode => _currentMode;
  static String get apiKey => _apiKey;

  static Future<void> setMode(AIMode mode) async {
    if (_currentMode == mode) return;

    final aiCoach = getAICoach();

    try {
      // When switching TO Local mode, load model into memory
      if (mode == AIMode.local) {
        await aiCoach.loadModelIntoMemory();
      }

      // When switching FROM Local mode TO API mode, unload model
      if (_currentMode == AIMode.local && mode == AIMode.api) {
        await aiCoach.unloadModelFromMemory();
      }

      _currentMode = mode;
    } catch (e) {
      // If loading fails, keep current mode
      throw Exception('Failed to switch AI mode: $e');
    }
  }
}
