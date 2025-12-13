/// AI Coach service for on-device LLM inference
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

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
  Llama? _llama; // LLM instance

  // Customizable prompts
  String?
  _systemPrompt; // Set once - contains instructions/personality for the LLM
  String? _userPrompt; // Set per run - the actual query with ski run data

  // Session history tracking
  final List<String> _categoriesCoached = [];
  final List<String> _drillsCoached = [];

  /// Get the list of categories coached in this session
  List<String> getCategoriesCoached() => List.unmodifiable(_categoriesCoached);

  /// Get the list of drills coached in this session
  List<String> getDrillsCoached() => List.unmodifiable(_drillsCoached);

  /// Clear session history
  void clearSessionHistory() {
    _categoriesCoached.clear();
    _drillsCoached.clear();
    debugPrint('🤖 Session history cleared');
  }

  /// Initialize AI Coach:
  /// 1. Copies 4.9GB model from assets to app documents (first run only)
  /// 2. Loads model into memory immediately
  /// 3. Gets ready to receive system and user prompts
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🤖 Initializing AI Coach with on-device LLM...');

      // Copy model from assets to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/llama-model.gguf';
      final modelFile = File(modelPath);

      if (!await modelFile.exists()) {
        debugPrint(
          '🤖 Copying model from assets to app storage (this may take a moment)...',
        );
        final byteData = await rootBundle.load(
          'assets/models/llama-3.1-8b-instruct-q4_k_m.gguf',
        );
        await modelFile.writeAsBytes(byteData.buffer.asUint8List());
        final sizeGB = byteData.lengthInBytes / 1024 / 1024 / 1024;
        debugPrint('🤖 ✅ Model copied: ${sizeGB.toStringAsFixed(2)} GB');
      } else {
        debugPrint('🤖 Model already exists in app storage');
      }

      _modelPath = modelPath;

      // Load model into memory immediately
      debugPrint('🤖 Loading model into memory (this will take a moment)...');
      final modelParams = ModelParams();
      final contextParams = ContextParams()
        ..nCtx =
          12500 // Context window: 12,500 tokens
        ..nPredict = 2500; // Max response: 2,500 tokens
      final samplerParams = SamplerParams()
        ..temp = 0.0; // Temperature: 0 for deterministic output

      _llama = Llama(
        _modelPath!,
        modelParams,
        contextParams,
        samplerParams,
        false, // verbose
      );
      debugPrint('🤖 ✅ Model loaded into memory and ready');

      _isInitialized = true;
      debugPrint('🤖 ✅ AI Coach fully initialized');
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
    debugPrint(
      '🤖 First 100 chars: ${prompt.substring(0, prompt.length > 100 ? 100 : prompt.length)}',
    );
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
        'System prompt = LLM instructions/personality',
      );
    }

    if (_userPrompt == null) {
      throw Exception(
        '❌ User prompt not set!\n'
        'Call: getAICoach().setUserPrompt(yourPromptHere) before generating advice\n'
        'User prompt = the actual ski run query with data',
      );
    }

    return _sendPromptsToLLM(_systemPrompt!, _userPrompt!);
  }

  /// Parse AI response and extract category, drill, and feedback
  /// Expected format: "...//category//drill//feedback"
  /// Returns the feedback paragraph to display
  String parseAndStoreResponse(String aiResponse) {
    try {
      // Find all occurrences of //
      final separators = <int>[];
      int index = aiResponse.indexOf('//');
      while (index != -1) {
        separators.add(index);
        index = aiResponse.indexOf('//', index + 2);
      }

      // Need at least 3 separators (3rd to last, 2nd to last, last)
      if (separators.length < 3) {
        debugPrint(
          '🤖 ⚠️ AI response does not have enough // separators (found ${separators.length}, need 3)',
        );
        debugPrint('🤖 Raw response: $aiResponse');
        return aiResponse; // Return raw response if format is incorrect
      }

      // Get positions of 3rd to last, 2nd to last, and last separators
      final thirdToLastPos = separators[separators.length - 3];
      final secondToLastPos = separators[separators.length - 2];
      final lastPos = separators[separators.length - 1];

      // Extract category (between 3rd to last and 2nd to last)
      final category = aiResponse
          .substring(thirdToLastPos + 2, secondToLastPos)
          .trim();

      // Extract drill (between 2nd to last and last)
      final drill = aiResponse.substring(secondToLastPos + 2, lastPos).trim();

      // Extract feedback (after last separator)
      final feedback = aiResponse.substring(lastPos + 2).trim();

      // Store in session history
      if (category.isNotEmpty) {
        _categoriesCoached.add(category);
        debugPrint('🤖 ✅ Category coached: $category');
      }
      if (drill.isNotEmpty) {
        _drillsCoached.add(drill);
        debugPrint('🤖 ✅ Drill coached: $drill');
      }

      debugPrint('🤖 ✅ Parsed AI response successfully');
      debugPrint('🤖    Category: $category');
      debugPrint('🤖    Drill: $drill');
      debugPrint('🤖    Feedback length: ${feedback.length} chars');

      return feedback;
    } catch (e) {
      debugPrint('🤖 ❌ Error parsing AI response: $e');
      debugPrint('🤖 Raw response: $aiResponse');
      return aiResponse; // Return raw response on error
    }
  }

  /// Send both prompts to the on-device LLM and get response.
  ///
  /// SYSTEM PROMPT: Sent ONCE - instructs the LLM on how to behave
  /// USER PROMPT: Sent EACH RUN - the specific question/data for this run
  ///
  /// The LLM runs entirely on-device (no internet, no API calls).
  /// If this fails, the exception will bubble up - no fallback methods.
  Future<String> _sendPromptsToLLM(
    String systemPrompt,
    String userPrompt,
  ) async {
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
      debugPrint('🤖 Sending to on-device Llama 3.1 8B model...');

      if (_llama == null) {
        throw Exception('Model not loaded - call initialize() first');
      }

      // Clear previous context and set new prompt
      _llama!.clear();
      _llama!.setPrompt(combinedPrompt);

      // Generate response
      debugPrint('🤖 Generating response...');
      final responseBuffer = StringBuffer();
      await for (final token in _llama!.generateText()) {
        responseBuffer.write(token);
      }

      final response = responseBuffer.toString();
      debugPrint('🤖 ========== AI RESPONSE ==========');
      debugPrint('🤖 Full response (${response.length} chars):');
      debugPrint(response);
      debugPrint('🤖 ===================================');

      return response;
    } catch (e) {
      debugPrint('🤖 ❌ Error: $e');
      rethrow; // No fallback - user wants to see errors
    }
  }
}
