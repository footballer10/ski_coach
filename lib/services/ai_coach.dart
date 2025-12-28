library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';

AICoach? _aiCoachInstance;

AICoach getAICoach() {
  _aiCoachInstance ??= AICoach();
  return _aiCoachInstance!;
}

const int _localContextTokens = 15000;
const int _localMaxResponseTokens = 5000;
const int _apiMaxResponseTokens = 5000;

class AICoach {
  static final AICoach _instance = AICoach._();
  factory AICoach() => _instance;
  AICoach._();

  bool _isInitialized = false;
  String? _modelPath;
  Llama? _llama;

  String? _systemPromptLocal;
  String? _systemPromptAPI;
  String? _userPrompt;

  final List<String> _categoriesCoached = [];
  final List<String> _drillsCoached = [];

  List<String> getCategoriesCoached() => List.unmodifiable(_categoriesCoached);
  List<String> getDrillsCoached() => List.unmodifiable(_drillsCoached);

  void clearSessionHistory() {
    _categoriesCoached.clear();
    _drillsCoached.clear();
  }

  Future<void> initialize({bool forceLoad = false}) async {
    if (_isInitialized && !forceLoad) return;

    if (forceLoad || AIPreferences.currentMode == AIMode.local) {
      await _loadLocalModel();
    }

    _isInitialized = true;
  }

  Future<void> _loadLocalModel() async {
    if (_llama != null) return;

    final docDir = await getApplicationDocumentsDirectory();
    _modelPath = '${docDir.path}/llama-3.1-8b-instruct-q4_k_m.gguf';

    final file = File(_modelPath!);
    if (!file.existsSync()) {
      final data = await rootBundle.load(
        'assets/models/llama-3.1-8b-instruct-q4_k_m.gguf',
      );
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }

    try {
      final modelParams = ModelParams();
      final contextParams = ContextParams()
        ..nCtx = _localContextTokens
        ..nPredict = _localMaxResponseTokens;
      final samplerParams = SamplerParams()..temp = 0.0;
      _llama = Llama(
        _modelPath!,
        modelParams,
        contextParams,
        samplerParams,
        false,
      );
    } catch (e) {
      try {
        final modelParams = ModelParams();
        final contextParams = ContextParams()
          ..nCtx = 12500
          ..nPredict = 2500;
        final samplerParams = SamplerParams()..temp = 0.0;
        _llama = Llama(
          _modelPath!,
          modelParams,
          contextParams,
          samplerParams,
          false,
        );
      } catch (e) {
        rethrow;
      }
    }
  }

  void setSystemPromptLocal(String prompt) {
    _systemPromptLocal = prompt;
  }

  void setSystemPromptAPI(String prompt) {
    _systemPromptAPI = prompt;
  }

  void setUserPrompt(String prompt) {
    _userPrompt = prompt;
  }

  String? getSystemPromptLocal() => _systemPromptLocal;
  String? getSystemPromptAPI() => _systemPromptAPI;
  String? getUserPrompt() => _userPrompt;

  Future<String> generateCoachingAdvice({
    required double edgeAngleScore,
    required double parallelScore,
    required double turnShapeScore,
    required double durationScore,
    required double runScore,
    required Map<String, double> categoryScores,
  }) async {
    if (_userPrompt == null) {
      throw Exception('User prompt not set');
    }

    if (AIPreferences.currentMode == AIMode.local) {
      if (_systemPromptLocal == null) {
        throw Exception('Local system prompt not set');
      }
      if (_llama == null) {
        await _loadLocalModel();
      }
      return _sendPromptsToLocalLLM(_systemPromptLocal!, _userPrompt!);
    } else {
      if (_systemPromptAPI == null) {
        throw Exception('API system prompt not set');
      }
      return _sendPromptsToAPI(_systemPromptAPI!, _userPrompt!);
    }
  }

  String parseAndStoreResponse(String aiResponse) {
    try {
      final separators = <int>[];
      int index = aiResponse.indexOf('//');
      while (index != -1) {
        separators.add(index);
        index = aiResponse.indexOf('//', index + 2);
      }

      if (separators.length < 3) {
        return aiResponse;
      }

      final thirdToLastPos = separators[separators.length - 3];
      final secondToLastPos = separators[separators.length - 2];
      final lastPos = separators[separators.length - 1];

      final category = aiResponse
          .substring(thirdToLastPos + 2, secondToLastPos)
          .trim();
      final drill = aiResponse.substring(secondToLastPos + 2, lastPos).trim();
      final feedback = aiResponse.substring(lastPos + 2).trim();

      if (category.isNotEmpty) _categoriesCoached.add(category);
      if (drill.isNotEmpty) _drillsCoached.add(drill);

      return feedback;
    } catch (e) {
      return aiResponse;
    }
  }

  Future<String> _sendPromptsToLocalLLM(
    String systemPrompt,
    String userPrompt,
  ) async {
    if (_modelPath == null) {
      throw Exception('Model path not set');
    }

    if (_llama == null) {
      throw Exception('Model not loaded');
    }

    final combinedPrompt = '$systemPrompt\n\n$userPrompt';

    _llama!.clear();
    _llama!.setPrompt(combinedPrompt);

    final responseBuffer = StringBuffer();
    await for (final token in _llama!.generateText()) {
      responseBuffer.write(token);
    }

    return responseBuffer.toString();
  }

  Future<String> _sendPromptsToAPI(
    String systemPrompt,
    String userPrompt,
  ) async {
    final apiKey = AIPreferences.apiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
      throw Exception('OpenAI API key not set in lib/config/ai_config.dart');
    }

    final responsesUrl = Uri.parse('https://api.openai.com/v1/responses');
    final chatCompletionsUrl = Uri.parse(
      'https://api.openai.com/v1/chat/completions',
    );
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    Future<http.Response> postJson(Uri url, Map<String, dynamic> body) {
      return http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));
    }

    // Preferred: Responses API (matches OpenAI Playground "Responses" behavior).
    http.Response response = await postJson(responsesUrl, <String, dynamic>{
      'model': 'gpt-5.2',
      'input': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.0,
      'max_output_tokens': _apiMaxResponseTokens,
    });

    // Fallback: Chat Completions API (older schema).
    if (response.statusCode != 200) {
      response = await postJson(chatCompletionsUrl, <String, dynamic>{
        'model': 'gpt-5.2',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.0,
        'max_tokens': _apiMaxResponseTokens,
      });
    }

    if (response.statusCode != 200) {
      throw Exception(
        'API request failed: ${response.statusCode} - ${response.body}',
      );
    }

    debugPrint('🤖 API Response Status: ${response.statusCode}');
    debugPrint('🤖 API Response Body: ${response.body}');

    final jsonResponse = jsonDecode(response.body);

    String? aiResponse;
    if (jsonResponse is Map<String, dynamic>) {
      final choices = jsonResponse['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final msg = first['message'];
          if (msg is Map<String, dynamic> && msg['content'] is String) {
            aiResponse = msg['content'] as String;
          } else if (first['text'] is String) {
            aiResponse = first['text'] as String;
          }
        }
      }

      if (aiResponse == null && jsonResponse['output_text'] is String) {
        aiResponse = jsonResponse['output_text'] as String;
      }
    }

    if (aiResponse == null) {
      debugPrint(
        '🤖 ❌ Failed to parse response. JSON structure: ${jsonResponse.keys}',
      );
      throw Exception('API response parsing failed');
    }

    debugPrint(
      '🤖 ✓ Successfully parsed AI response (${aiResponse.length} characters)',
    );
    debugPrint(
      '🤖 Response preview: ${aiResponse.substring(0, aiResponse.length > 200 ? 200 : aiResponse.length)}...',
    );

    return aiResponse;
  }
}
