/// AI Coach service using llama.cpp for local inference
library;

import 'package:llama_cpp_dart/llama_cpp_dart.dart';
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
  
  LlamaProcessor? _processor;
  bool _isInitialized = false;
  final List<String> _lastThreeDrills = [];
  String _systemPrompt = ''; // Can be set via setSystemPrompt()
  
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
      debugPrint('🤖 Initializing AI Coach...');
      
      // Copy model from assets to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/llama-model.gguf';
      final modelFile = File(modelPath);
      
      if (!await modelFile.exists()) {
        debugPrint('🤖 Copying model from assets...');
        final byteData = await rootBundle.load('assets/models/Llama-3.2-3B-Instruct-Q4_K_M.gguf');
        await modelFile.writeAsBytes(byteData.buffer.asUint8List());
        debugPrint('🤖 Model copied to $modelPath');
      }
      
      // Initialize llama.cpp processor
      _processor = LlamaProcessor(
        modelPath: modelPath,
        contextSize: 2048,
        batchSize: 512,
        temperature: 0.7,
        topK: 40,
        topP: 0.9,
      );
      
      await _processor!.initialize();
      _isInitialized = true;
      debugPrint('🤖 AI Coach initialized successfully');
    } catch (e) {
      debugPrint('🤖 ❌ AI Coach initialization failed: $e');
      _isInitialized = false;
    }
  }

  void setSystemPrompt(String prompt) {
    _systemPrompt = prompt;
    debugPrint('🤖 System prompt set (${prompt.length} characters)');
  }

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
    
    if (_processor == null) {
      return _generateFallbackAdvice(categoryScores, runScore);
    }
    
    try {
      // Calculate level
      final avgCategoryScore = (edgeAngleScore + parallelScore + turnShapeScore + durationScore) / 4;
      final levelScore = (avgCategoryScore + runScore) / 2;
      final skillLevel = _getSkillLevel(levelScore);
      
      // Find lowest scoring category (but with some randomness to avoid repetition)
      final lowestCategory = _selectCategoryToWorkOn(categoryScores);
      
      // Build prompt
      final prompt = _buildPrompt(
        lowestCategory: lowestCategory,
        levelScore: levelScore,
        skillLevel: skillLevel,
        scores: categoryScores,
        runScore: runScore,
      );
      
      debugPrint('🤖 Generating advice for $lowestCategory (level: $skillLevel)');
      
      // Generate response
      final response = await _processor!.prompt(prompt);
      
      // Update memory
      _updateDrillMemory(response);
      
      return response;
    } catch (e) {
      debugPrint('🤖 ❌ AI generation failed: $e');
      return _generateFallbackAdvice(categoryScores, runScore);
    }
  }

  String _buildPrompt({
    required String lowestCategory,
    required double levelScore,
    required String skillLevel,
    required Map<String, double> scores,
    required double runScore,
  }) {
    final lastDrillsList = _lastThreeDrills.isEmpty 
        ? 'None' 
        : _lastThreeDrills.join(', ');
    
    return '''<|system|>
You are an expert ski coach AI. You analyze ski performance data and provide personalized coaching advice.

$_handbookContext

Your task:
1. Identify what the skier is doing wrong in the category: $lowestCategory
2. Provide a specific tip to improve
3. Select an appropriate drill from the handbook for their skill level: $skillLevel
4. Do NOT use these recent drills: $lastDrillsList
5. Add natural variations to keep it interesting

Output format (be concise, 3-4 sentences max):
**Category to work on:** [category name]
**What you're doing wrong:** [brief explanation]
**Tip:** [specific actionable tip]
**Drill:** [drill name] - [full instructions with variation]
<|end|>
<|user|>
Skier Performance:
- Edge Angle Score: ${scores['Edge Angle']?.toStringAsFixed(2) ?? '0'}
- Parallel Score: ${scores['Parallel']?.toStringAsFixed(2) ?? '0'}
- Turn Shape Score: ${scores['Turn Shape']?.toStringAsFixed(2) ?? '0'}
- Duration Score: ${scores['Duration']?.toStringAsFixed(2) ?? '0'}
- Overall Run Score: ${runScore.toStringAsFixed(2)}
- Skill Level: $skillLevel (Level Score: ${levelScore.toStringAsFixed(2)})
- Category to focus on: $lowestCategory
<|end|>
<|assistant|>''';
  }

  String _getSkillLevel(double levelScore) {
    if (levelScore < 0.5) return 'Beginner (Level 1)';
    if (levelScore < 0.8) return 'Intermediate (Level 2)';
    if (levelScore < 0.9) return 'Advanced (Level 3)';
    return 'Expert (Level 4)';
  }

  String _selectCategoryToWorkOn(Map<String, double> scores) {
    // Find the two lowest scoring categories
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    // 70% chance to pick the lowest, 30% chance to pick second lowest
    // This adds variety while still prioritizing weak areas
    if (sortedEntries.length >= 2 && DateTime.now().millisecondsSinceEpoch % 10 < 3) {
      return sortedEntries[1].key;
    }
    return sortedEntries.first.key;
  }

  void _updateDrillMemory(String response) {
    // Extract drill name from response (look for "**Drill:**" section)
    final drillMatch = RegExp(r'\*\*Drill:\*\*\s*([^-]+)').firstMatch(response);
    if (drillMatch != null) {
      final drillName = drillMatch.group(1)?.trim() ?? '';
      if (drillName.isNotEmpty) {
        _lastThreeDrills.add(drillName);
        if (_lastThreeDrills.length > 3) {
          _lastThreeDrills.removeAt(0);
        }
        debugPrint('🤖 Updated drill memory: $_lastThreeDrills');
      }
    }
  }

  String _generateFallbackAdvice(Map<String, double> scores, double runScore) {
    // Simple rule-based fallback if AI fails
    final lowestCategory = _selectCategoryToWorkOn(scores);
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
        return '''**Category to work on:** Turn Duration
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

  Future<void> dispose() async {
    await _processor?.dispose();
    _processor = null;
    _isInitialized = false;
  }
}
