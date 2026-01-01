library;

import 'package:flutter/foundation.dart';
import 'dart:async';
// import 'dart:io';  // Unused when local AI is disabled
import 'dart:convert';
// import 'package:path_provider/path_provider.dart';  // Unused when local AI is disabled
// import 'package:llama_cpp_dart/llama_cpp_dart.dart';  // Unused when local AI is disabled
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';

AICoach? _aiCoachInstance;

AICoach getAICoach() {
  _aiCoachInstance ??= AICoach();
  return _aiCoachInstance!;
}

// LOCAL AI TEMPORARILY DISABLED
// const int _localContextTokens = 8000;
// const int _localMaxResponseTokens = 3000;
const int _apiMaxResponseTokens = 8000;

class AICoach {
  static final AICoach _instance = AICoach._();
  factory AICoach() => _instance;
  AICoach._();

  bool _isInitialized = false;
  // String? _modelPath;  // LOCAL AI DISABLED
  // Llama? _llama;  // LOCAL AI DISABLED

  String? _systemPromptLocal;
  String? _systemPromptAPI;
  String? _userPrompt;

  final List<String> _categoriesCoached = [];
  final List<String> _drillsCoached = [];
  
  // LOCAL AI TEMPORARILY DISABLED
  // bool _isDownloading = false;
  // double _downloadProgress = 0.0;
  // bool _isLoading = false;

  List<String> getCategoriesCoached() => List.unmodifiable(_categoriesCoached);
  List<String> getDrillsCoached() => List.unmodifiable(_drillsCoached);

  void clearSessionHistory() {
    _categoriesCoached.clear();
    _drillsCoached.clear();
  }

  Future<void> initialize({bool forceLoad = false}) async {
    if (_isInitialized && !forceLoad) return;
    _isInitialized = true;
  }
  
  /// Download model in background if not present
  Future<void> ensureModelDownloaded() async {
    // LOCAL AI TEMPORARILY DISABLED
    debugPrint('🤖 Local AI disabled - use API mode');
    return;
    
    // final docDir = await getApplicationDocumentsDirectory();
    // final modelPath = '${docDir.path}/model.gguf';
    // final file = File(modelPath);
    // 
    // if (file.existsSync()) {
    //   debugPrint('🤖 Model already downloaded');
    //   return;
    // }
    // 
    // _downloadModelInBackground();
  }
  
  // ignore: unused_element
  Future<void> _downloadModelInBackground() async {
    // LOCAL AI TEMPORARILY DISABLED
    debugPrint('🤖 Model download disabled');
    return;
    
    // if (_isDownloading) return;
    // 
    // _isDownloading = true;
    // debugPrint('🤖 Starting model download...');
    // 
    // // Qwen 2.5 7B Instruct Q4_K_M from HuggingFace
    // const modelUrl = 'https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf';
    // 
    // try {
    //   final docDir = await getApplicationDocumentsDirectory();
    //   final modelPath = '${docDir.path}/model.gguf';
    //   final file = File(modelPath);
    //   
    //   debugPrint('🤖 Downloading from: $modelUrl');
    //   debugPrint('🤖 Saving to: $modelPath');
    //   
    //   final client = http.Client();
    //   final request = http.Request('GET', Uri.parse(modelUrl));
    //   request.followRedirects = true;
    //   request.maxRedirects = 5;
    //   
    //   final response = await client.send(request);
    //   
    //   debugPrint('🤖 Response status: ${response.statusCode}');
    //   
    //   if (response.statusCode == 200) {
    //     final contentLength = response.contentLength ?? 0;
    //     debugPrint('🤖 File size: ${(contentLength / 1024 / 1024).toStringAsFixed(2)} MB');
    //     
    //     var downloaded = 0;
    //     final bytes = <int>[];
    //     
    //     await for (final chunk in response.stream) {
    //       bytes.addAll(chunk);
    //       downloaded += chunk.length;
    //       
    //       if (contentLength > 0) {
    //         _downloadProgress = downloaded / contentLength;
    //         if (downloaded % (10 * 1024 * 1024) == 0 || downloaded == contentLength) {
    //           debugPrint('🤖 Downloaded: ${(downloaded / 1024 / 1024).toStringAsFixed(2)} MB (${(_downloadProgress * 100).toStringAsFixed(1)}%)');
    //         }
    //       }
    //     }
    //     
    //     debugPrint('🤖 Writing file to disk...');
    //     await file.writeAsBytes(bytes);
    //     debugPrint('🤖 Model downloaded successfully to: $modelPath');
    //   } else {
    //     debugPrint('🤖 Download failed with status: ${response.statusCode}');
    //     debugPrint('🤖 Response headers: ${response.headers}');
    //     throw Exception('Download failed: HTTP ${response.statusCode}');
    //   }
    //   
    //   client.close();
    // } catch (e, stackTrace) {
    //   debugPrint('🤖 Download error: $e');
    //   debugPrint('🤖 Stack trace: $stackTrace');
    // } finally {
    //   _isDownloading = false;
    //   _downloadProgress = 0.0;
    // }
  }

  /// Load model into memory when switching to Local mode
  Future<void> loadModelIntoMemory() async {
    // LOCAL AI TEMPORARILY DISABLED
    debugPrint('⚠️ Local AI is disabled. Please use API mode.');
    throw Exception('Local AI is temporarily disabled. Please use API mode in settings.');
    
    // if (_isLoading) {
    //   debugPrint('⚠️ Model load/unload already in progress, ignoring request');
    //   return;
    // }
    // 
    // _isLoading = true;
    // try {
    //   if (_llama != null) {
    //     debugPrint('🤖 Model already loaded in memory');
    //     return;
    //   }
    //   debugPrint('🤖 Loading model into memory...');
    //   await _loadLocalModel();
    //   debugPrint('🤖 Model loaded and ready!');
    // } catch (e) {
    //   debugPrint('❌ Model load failed: $e');
    //   rethrow;
    // } finally {
    //   _isLoading = false;
    // }
  }

  /// Unload model from memory when switching to API mode
  Future<void> unloadModelFromMemory() async {
    // LOCAL AI TEMPORARILY DISABLED
    debugPrint('⚠️ Local AI is disabled');
    return;
    
    // if (_isLoading) {
    //   debugPrint('⚠️ Model load/unload already in progress, ignoring request');
    //   return;
    // }
    // 
    // _isLoading = true;
    // try {
    //   if (_llama == null) {
    //     debugPrint('🤖 Model not loaded, nothing to unload');
    //     return;
    //   }
    //   debugPrint('🤖 Unloading model from memory...');
    //   _llama = null;
    //   debugPrint('🤖 Model unloaded, memory freed');
    // } finally {
    //   _isLoading = false;
    // }
  }

  // ignore: unused_element
  Future<void> _loadLocalModel() async {
    // LOCAL AI TEMPORARILY DISABLED
    throw Exception('Local AI is disabled');
    
    // if (_llama != null) return;
    //
    // final docDir = await getApplicationDocumentsDirectory();
    // _modelPath = '${docDir.path}/model.gguf';
    // final file = File(_modelPath!);
    //
    // // If model doesn't exist, trigger download
    // if (!file.existsSync()) {
    //   debugPrint('🤖 Model not found. Downloading...');
    //   await _downloadModelInBackground();
    //   
    //   // Check again after download
    //   if (!file.existsSync()) {
    //     throw Exception(
    //       'Model download failed. Please check internet connection or use API mode.',
    //     );
    //   }
    // }
    //
    // debugPrint('🤖 Model found at: $_modelPath');
    //
    // try {
    //   final modelParams = ModelParams();
    //   final contextParams = ContextParams()
    //     ..nCtx = _localContextTokens
    //     ..nPredict = _localMaxResponseTokens;
    //   final samplerParams = SamplerParams()..temp = 0.0;
    //   _llama = Llama(
    //     _modelPath!,
    //     modelParams,
    //     contextParams,
    //     samplerParams,
    //     false,
    //   );
    // } catch (e) {
    //   debugPrint('⚠️ Failed with full context, trying reduced settings...');
    //   try {
    //     final modelParams = ModelParams();
    //     final contextParams = ContextParams()
    //       ..nCtx = 4000
    //       ..nPredict = 1500;
    //     final samplerParams = SamplerParams()..temp = 0.0;
    //     _llama = Llama(
    //       _modelPath!,
    //       modelParams,
    //       contextParams,
    //       samplerParams,
    //       false,
    //     );
    //     debugPrint('🤖 Model loaded with reduced context (4000 tokens)');
    //   } catch (e) {
    //     debugPrint('❌ Failed even with reduced settings: $e');
    //     rethrow;
    //   }
    // }
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
      // LOCAL AI TEMPORARILY DISABLED
      throw Exception(
        'Local AI is temporarily disabled. Please use API mode in settings.',
      );
      
      // if (_systemPromptLocal == null) {
      //   throw Exception('Local system prompt not set');
      // }
      // 
      // if (_llama == null) {
      //   throw Exception(
      //     'Local model not loaded. Please toggle to Local mode first to load the model into memory.',
      //   );
      // }
      // return _sendPromptsToLocalLLM(_systemPromptLocal!, _userPrompt!);
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

  // ignore: unused_element
  Future<String> _sendPromptsToLocalLLM(
    String systemPrompt,
    String userPrompt,
  ) async {
    // LOCAL AI TEMPORARILY DISABLED
    throw Exception('Local AI is disabled');
    
    // if (_modelPath == null) {
    //   throw Exception('Model path not set');
    // }
    //
    // if (_llama == null) {
    //   throw Exception('Model not loaded');
    // }
    //
    // final combinedPrompt = '$systemPrompt\n\n$userPrompt';
    //
    // _llama!.clear();
    // _llama!.setPrompt(combinedPrompt);
    //
    // final responseBuffer = StringBuffer();
    // await for (final token in _llama!.generateText()) {
    //   responseBuffer.write(token);
    // }
    //
    // return responseBuffer.toString();
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
      // Try new Responses API format (output array)
      final output = jsonResponse['output'];
      if (output is List && output.isNotEmpty) {
        final firstOutput = output.first;
        if (firstOutput is Map<String, dynamic>) {
          final content = firstOutput['content'];
          if (content is List && content.isNotEmpty) {
            final firstContent = content.first;
            if (firstContent is Map<String, dynamic> &&
                firstContent['text'] is String) {
              aiResponse = firstContent['text'] as String;
            }
          }
        }
      }

      // Try Chat Completions API format (choices array)
      if (aiResponse == null) {
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
      }

      // Try legacy format
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
