/// AI Coach service for on-device LLM inference
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
  
  // Customizable prompts
  String? _systemPrompt; // Set once - contains instructions/personality for the LLM
  String? _userPrompt;   // Set per run - the actual query with ski run data
  
  /// Initialize AI Coach:
  /// 1. Copies 2.3GB model from assets to app documents (first run only)
  /// 2. Gets ready to receive system and user prompts
  /// 3. Will load model into memory when first prompt is sent
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🤖 Initializing AI Coach with on-device LLM...');
      
      // Copy model from assets to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/llama-model.gguf';
      final modelFile = File(modelPath);
      
      if (!await modelFile.exists()) {
        debugPrint('🤖 Copying model from assets to app storage (this may take a moment)...');
        final byteData = await rootBundle.load('assets/models/llama-3.2-3b-instruct-q4_k_m.gguf');
        await modelFile.writeAsBytes(byteData.buffer.asUint8List());
        final sizeGB = byteData.lengthInBytes / 1024 / 1024 / 1024;
        debugPrint('🤖 ✅ Model copied: ${sizeGB.toStringAsFixed(2)} GB');
      } else {
        debugPrint('🤖 Model already exists in app storage');
      }
      
      _modelPath = modelPath;
      _isInitialized = true;
      debugPrint('🤖 AI Coach initialized - ready to send prompts to LLM at: $_modelPath');
    } catch (e) {
      debugPrint('🤖 ❌ Initialization error: $e');
      rethrow;
    }
  }

  /// Set the system prompt - this defines the LLM behavior, instructions, and personality.
  /// Called once at app startup or when you want to change the AI behavior.
  /// 
  /// Example: "You are an expert ski coach. Provide brief, actionable advice..."
  void setSystemPrompt(String prompt) {
    _systemPrompt = prompt;
    debugPrint('🤖 System prompt set (${prompt.length} chars)');
    debugPrint('🤖 First 100 chars: ${prompt.substring(0, prompt.length > 100 ? 100 : prompt.length)}');
  }

  /// Set the user prompt - this is the actual query/data sent with each ski run result.
  /// Called before generateCoachingAdvice with the specific run data.
  /// 
  /// Example: "My run had: Edge Angle 65 degrees, Parallel 82%, Turn Shape 78%, Duration 2.1s..."
  void setUserPrompt(String prompt) {
    _userPrompt = prompt;
    debugPrint('🤖 User prompt set (${prompt.length} chars)');
  }

  String? getSystemPrompt() => _systemPrompt;
  String? getUserPrompt() => _userPrompt;

  /// Generate coaching advice by sending prompts to the on-device LLM.
  /// 
  /// PROMPT FLOW:
  /// 1. System prompt (instruction) = sent ONCE, defines AI behavior
  /// 2. User prompt (query with run data) = sent each run, gets advice for this specific run
  /// 3. LLM responds with tailored coaching advice
  /// 
  /// This is called automatically after each run to generate coaching advice.
  /// If system or user prompt is not set, throws an exception so you know to set them first.
  Future<String> generateCoachingAdvice({
    required double edgeAngleScore,
    required double parallelScore,
    required double turnShapeScore,
    required double durationScore,
    required double runScore,
    required Map<String, double> categoryScores,
  }) async {
    if (!_isInitialized) {
      debugPrint('🤖 Not initialized, initializing now...');
      await initialize();
    }
    
    if (_systemPrompt == null) {
      throw Exception(
        '❌ System prompt not set!\n'
        'Call: getAICoach().setSystemPrompt(yourPromptHere) first\n'
        'System prompt = LLM instructions/personality'
      );
    }
    
    if (_userPrompt == null) {
      throw Exception(
        '❌ User prompt not set!\n'
        'Call: getAICoach().setUserPrompt(yourPromptHere) before generating advice\n'
        'User prompt = the actual ski run query with data'
      );
    }
    
    return _sendPromptsToLLM(_systemPrompt!, _userPrompt!);
  }
  
  /// Send both prompts to the on-device LLM and get response.
  /// 
  /// SYSTEM PROMPT: Sent ONCE - instructs the LLM on how to behave
  /// USER PROMPT: Sent EACH RUN - the specific question/data for this run
  /// 
  /// The LLM runs entirely on-device (no internet, no API calls).
  /// If this fails, the exception will bubble up - no fallback methods.
  Future<String> _sendPromptsToLLM(String systemPrompt, String userPrompt) async {
    if (_modelPath == null) {
      throw Exception('Model path not set - initialization may have failed');
    }
    
    try {
      debugPrint('🤖 ========== SENDING TO LLM ==========');
      debugPrint('🤖 Model: $_modelPath');
      debugPrint('🤖 System prompt: ${systemPrompt.length} chars');
      debugPrint('🤖 User prompt: ${userPrompt.length} chars');
      
      // Combine prompts for sending to LLM
      // System prompt sets context, user prompt is the specific query
      final combinedPrompt = '$systemPrompt\n\n$userPrompt';
      
      debugPrint('🤖 Combined prompt: ${combinedPrompt.length} chars');
      debugPrint('🤖 Sending to on-device Llama 3.2-3B model...');
      
      // ⚠️ TODO: Wire up actual llama_cpp_dart inference
      // The llama_cpp_dart package needs to be properly integrated here.
      // Expected API (once available):
      //   - Load context: final llama = await LLamaContext.load(modelPath: _modelPath);
      //   - Run inference: final response = await llama.prompt(combinedPrompt);
      //   - Return response string
      
      // For now, throwing error so you see it needs implementation
      throw UnimplementedError(
        'LLM inference not yet wired - ready to send:\n\n'
        'SYSTEM PROMPT ($systemPrompt.length chars):\n${systemPrompt.substring(0, systemPrompt.length > 200 ? 200 : systemPrompt.length)}...\n\n'
        'USER PROMPT (${userPrompt.length} chars):\n${userPrompt.substring(0, userPrompt.length > 200 ? 200 : userPrompt.length)}...'
      );
      
    } catch (e) {
      debugPrint('🤖 ❌ Error: $e');
      rethrow; // No fallback - user wants to see errors
    }
  }
}
