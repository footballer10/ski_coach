/// AI Coach service for LLM inference
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// Global singleton instance
AICoach? _aiCoachInstance;

// Get global AICoach instance
AICoach getAICoach() {
  return _aiCoachInstance ?? AICoach._();
}

class AICoach {
  static final AICoach _instance = AICoach._();
  
  factory AICoach() {
    return _instance;
  }
  
  AICoach._();
  
  bool _isInitialized = false;
  String? _modelPath;
  final List<String> _lastThreeDrills = [];
  
  // Customizable prompts - set these before generating advice
  String? _systemPrompt;
  String? _userPrompt;
  
  static const String _handbookContext = '''
FIS Drills and Exercises Handbook Knowledge:

LEVEL 1 - BEGINNER:
- Basic Balance: Stand on one ski, glide straight, switch feet
- Wedge Turns: Make small turns using a wedge position
- Straight Running: Glide down gentle slopes in a straight line
- Side Slipping: Slide sideways on both skis
- J-Turns: Make wide J-shaped turns

LEVEL 2 - INTERMEDIATE:
- Parallel Turns: Link parallel turns on moderate slopes
- Dynamic Balance: Hop on one ski while moving
- Pole Touch: Touch pole to snow during turn initiation
- Carved Turns: Engage edges and carve on harder snow
- Rhythm Turns: Make quick, linked turns with consistent timing

LEVEL 3 - ADVANCED:
- High-Speed Carving: Carve at higher speeds with strong edge angles
- Mogul Skiing: Navigate bumps with absorption technique
- Short Radius Turns: Quick, tight turns on steep terrain
- One-Ski Carving: Carve turns on one ski at a time
- Jump Turns: Use unweighting to pivot skis

LEVEL 4 - EXPERT:
- Racing Lines: Optimize turn shape for speed
- Extreme Carving: Maximum edge angles on steep slopes
- Switch Skiing: Ski backwards with control
- Off-Piste Techniques: Handle variable snow conditions
- Competition Drills: Race-specific training exercises

Metric to Drill Mapping:
- Edge Angle: Carving drills, wedge turns, side slipping
- Parallel: Parallel turns, rhythm turns, pole touch
- Turn Shape: Carved turns, rhythm turns, racing lines
- Duration: Quick turns, rhythm exercises, short radius
''';

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🤖 Initializing AI Coach with llama.cpp...');
      
      // Copy model from assets to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/llama-model.gguf';
      final modelFile = File(modelPath);
      
      if (!await modelFile.exists()) {
        debugPrint('🤖 Copying model from assets...');
        final byteData = await rootBundle.load('assets/models/llama-3.2-3b-instruct-q4_k_m.gguf');
        await modelFile.writeAsBytes(byteData.buffer.asUint8List());
        debugPrint('🤖 Model copied to $modelPath (${(byteData.lengthInBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB)');
      }
      
      _modelPath = modelPath;
      _isInitialized = true;
      debugPrint('🤖 AI Coach initialized successfully');
      debugPrint('🤖 Ready to send/receive prompts to LLM at: $modelPath');
    } catch (e) {
      debugPrint('🤖 ❌ AI Coach initialization failed: $e');
      _isInitialized = false;
    }
  }

  void setSystemPrompt(String prompt) {
    _systemPrompt = prompt;
    debugPrint('🤖 System prompt set (${prompt.length} characters)');
  }

  void setUserPrompt(String prompt) {
    _userPrompt = prompt;
    debugPrint('🤖 User prompt set (${prompt.length} characters)');
  }

  String? getSystemPrompt() => _systemPrompt;
  String? getUserPrompt() => _userPrompt;

  Future<String> generateCoachingAdvice({
    required double edgeAngleScore,
    required double parallelScore,
    required double turnShapeScore,
    required double durationScore,
    required double runScore,
    required Map<String, double> categoryScores,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // If custom prompts are set, use them (ready for llama.cpp integration)
    if (_systemPrompt != null && _userPrompt != null) {
      debugPrint('🤖 Using custom system and user prompts');
      return _sendPromptsToAI(_systemPrompt!, _userPrompt!);
    }
    
    // Otherwise use rule-based fallback
    return _generateFallbackAdvice(categoryScores, runScore);
  }

  Future<String> _sendPromptsToAI(String systemPrompt, String userPrompt) async {
    if (_modelPath == null) {
      debugPrint('🤖 ❌ Model path not set');
      return _generateFallbackAdvice({}, 0.0);
    }
    
    try {
      debugPrint('🤖 Sending prompts to LLM...');
      
      // Construct the full prompt
      final fullPrompt = '''$systemPrompt

$userPrompt''';
      
      debugPrint('🤖 System prompt: ${systemPrompt.length} chars');
      debugPrint('🤖 User prompt: ${userPrompt.length} chars');
      debugPrint('🤖 Model path: $_modelPath');
      
      // TODO: Integrate with actual llama.cpp native code
      // For now, log that we're ready to send
      debugPrint('🤖 ✅ Ready to send prompt to LLM');
      debugPrint('🤖 Full prompt preview (first 200 chars): ${fullPrompt.substring(0, fullPrompt.length > 200 ? 200 : fullPrompt.length)}...');
      
      // Placeholder until llama_cpp_dart is properly integrated
      return 'Awaiting llama.cpp response...';
    } catch (e) {
      debugPrint('🤖 ❌ Error sending prompts to AI: $e');
      return _generateFallbackAdvice({}, 0.0);
    }
  }

  String _generateFallbackAdvice(Map<String, double> scores, double runScore) {
    // Simple rule-based fallback if AI fails
    // Find the lowest scoring category
    final lowestEntry = scores.entries.reduce((a, b) => a.value < b.value ? a : b);
    final lowestCategory = lowestEntry.key;
    final score = scores[lowestCategory] ?? 0.0;
    
    switch (lowestCategory) {
      case 'Edge Angle':
        return '''**Category to work on:** Edge Angle
**What you're doing wrong:** Your edge angles are too shallow (score: ${score.toStringAsFixed(2)}), limiting your grip on the snow.
**Tip:** Focus on angulating your body - flex your ankles and knees while keeping your upper body upright.
**Drill:** Side Slipping - Start on a gentle slope, stand perpendicular to the fall line, and practice releasing your edges to slide sideways. Gradually increase edge angle to control your speed.''';
      
      case 'Parallel':
        return '''**Category to work on:** Parallel
**What you're doing wrong:** Your skis aren't staying parallel (score: ${score.toStringAsFixed(2)}), creating a wedge that slows you down.
**Tip:** Focus on keeping equal weight on both skis and rotate both legs together as one unit.
**Drill:** Railroad Tracks - Make turns while imagining your skis are on parallel train tracks. Focus on matching the angle and direction of both skis throughout the turn.''';
      
      case 'Turn Shape':
        return '''**Category to work on:** Turn Shape
**What you're doing wrong:** Your turns are inconsistent (score: ${score.toStringAsFixed(2)}), with varying shapes and speeds.
**Tip:** Focus on smooth, progressive edge engagement rather than quick pivoting movements.
**Drill:** Rhythm Turns - Link 10 turns in a row with consistent timing. Count "1-2-3-turn, 1-2-3-turn" to develop a steady rhythm.''';
      
      case 'Duration':
        return '''**Category to work on:** Duration
**What you're doing wrong:** Your turn timing is off (score: ${score.toStringAsFixed(2)}), either too rushed or too slow.
**Tip:** Aim for 2-second turns - complete and controlled from initiation to completion.
**Drill:** Metronome Turns - Use a mental count or actual metronome app to time your turns. Start each turn every 2 seconds, maintaining consistent speed.''';
      
      default:
        return '''**Overall Performance:** Score ${runScore.toStringAsFixed(2)}
**Tip:** Focus on fundamental skills: balance, edge control, and rhythm.
**Drill:** Basic Parallel Turns - Make medium-radius turns on a groomed slope, focusing on smooth weight transfer and parallel ski alignment.''';
    }
  }

  void resetSession() {
    _lastThreeDrills.clear();
    debugPrint('🤖 Session memory reset');
  }
}
