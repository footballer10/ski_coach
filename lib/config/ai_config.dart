import '../services/ai_coach.dart';

enum AIMode { local, api }

class AIPreferences {
  static AIMode _currentMode = AIMode.api;
  static const String _apiKey =
      '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';

  static AIMode get currentMode => _currentMode;
  static String get apiKey => _apiKey;

  static Future<void> setMode(AIMode mode) async {
    if (_currentMode == mode) return;

    final aiCoach = getAICoach();

    // When switching TO Local mode, load model into memory
    if (mode == AIMode.local) {
      await aiCoach.loadModelIntoMemory();
    }

    // When switching FROM Local mode TO API mode, unload model
    if (_currentMode == AIMode.local && mode == AIMode.api) {
      aiCoach.unloadModelFromMemory();
    }

    _currentMode = mode;
  }
}
