library;

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';

AICoach? _aiCoachInstance;

AICoach getAICoach() {
  _aiCoachInstance ??= AICoach();
  return _aiCoachInstance!;
}

const String _apiModel = 'gpt-6-luna';
const int _apiMaxResponseTokens = 10000;

class AICoach {
  static final AICoach _instance = AICoach._();
  factory AICoach() => _instance;
  AICoach._();

  String? _systemPrompt;
  String? _userPrompt;

  void setSystemPrompt(String prompt) {
    _systemPrompt = prompt;
  }

  void setUserPrompt(String prompt) {
    _userPrompt = prompt;
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
    if (_userPrompt == null) {
      throw Exception('User prompt not set');
    }
    if (_systemPrompt == null) {
      throw Exception('System prompt not set');
    }
    return _sendPromptsToAPI(_systemPrompt!, _userPrompt!);
  }

  /// Extracts the user-visible coaching feedback from the model output.
  ///
  /// New contract: the model may include reasoning, and the user-facing text is
  /// everything after the LAST occurrence of `//`.
  ///
  /// If no delimiter exists, returns the entire response.
  String extractFeedback(String aiResponse) {
    final last = aiResponse.lastIndexOf('//');
    if (last == -1) return aiResponse.trim();
    return aiResponse.substring(last + 2).trim();
  }

  Future<String> _sendPromptsToAPI(
    String systemPrompt,
    String userPrompt,
  ) async {
    final apiKey = AIPreferences.apiKey;
    if (apiKey.isEmpty) {
      throw Exception('No OpenAI API key. Tap the refresh button to add one.');
    }

    // Create a new client for each request to avoid connection reuse issues
    final client = http.Client();

    try {
      // gpt-6-luna does not accept `temperature`, so it is not sent.
      final response = await client
          .post(
            Uri.parse('https://api.openai.com/v1/responses'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(<String, dynamic>{
              'model': _apiModel,
              'input': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
              'max_output_tokens': _apiMaxResponseTokens,
            }),
          )
          .timeout(const Duration(seconds: 300)); // Long step-by-step prompts can take minutes

      if (response.statusCode != 200) {
        throw Exception(
          'API request failed: ${response.statusCode} - ${response.body}',
        );
      }

      debugPrint('🤖 API Response Status: ${response.statusCode}');
      debugPrint('🤖 API Response Body: ${response.body}');

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      if (jsonResponse['status'] == 'incomplete') {
        throw Exception(
          'AI response was cut off: ${jsonResponse['incomplete_details']}',
        );
      }

      // The output list can start with a reasoning item, so look for the
      // message item and join its text parts.
      final buffer = StringBuffer();
      final output = jsonResponse['output'];
      if (output is List) {
        for (final item in output) {
          if (item is Map<String, dynamic> && item['type'] == 'message') {
            final content = item['content'];
            if (content is List) {
              for (final part in content) {
                if (part is Map<String, dynamic> && part['text'] is String) {
                  buffer.write(part['text'] as String);
                }
              }
            }
          }
        }
      }

      if (buffer.isEmpty) {
        debugPrint(
          '🤖 ❌ Failed to parse response. JSON structure: ${jsonResponse.keys}',
        );
        throw Exception('API response parsing failed');
      }

      final aiResponse = buffer.toString();
      debugPrint(
        '🤖 ✓ Successfully parsed AI response (${aiResponse.length} characters)',
      );
      debugPrint(
        '🤖 Response preview: ${aiResponse.substring(0, aiResponse.length > 200 ? 200 : aiResponse.length)}...',
      );

      return aiResponse;
    } finally {
      // Always close the client to prevent connection reuse issues
      client.close();
    }
  }
}
