import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class MLCAICoach {
  static const MethodChannel _channel = MethodChannel('ski_coach/mlc');
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (!Platform.isIOS) {
      throw UnsupportedError('MLC LLM is only supported on iOS');
    }
    _isInitialized = true;
    debugPrint('🍎 MLC AI Coach initialized for iOS');
  }

  Future<void> loadModelIntoMemory() async {
    if (!_isInitialized) {
      throw Exception('MLC not initialized. Call initialize() first.');
    }

    try {
      debugPrint('🍎 Loading MLC model into memory...');
      final stopwatch = Stopwatch()..start();
      
      await _channel.invokeMethod('loadModel');
      
      stopwatch.stop();
      debugPrint('🍎 ✓ MLC model loaded in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('🍎 ❌ Failed to load MLC model: $e');
      rethrow;
    }
  }

  Future<void> unloadModelFromMemory() async {
    try {
      debugPrint('🍎 Unloading MLC model from memory...');
      await _channel.invokeMethod('unloadModel');
      debugPrint('🍎 ✓ MLC model unloaded');
    } catch (e) {
      debugPrint('🍎 ⚠️ Error unloading MLC model: $e');
    }
  }

  Future<String> generateCoachingAdvice({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required int maxTokens,
  }) async {
    if (!_isInitialized) {
      throw Exception('MLC not initialized');
    }

    try {
      debugPrint('🍎 Starting MLC generation...');
      debugPrint('🍎 System prompt length: ${systemPrompt.length}');
      debugPrint('🍎 User prompt length: ${userPrompt.length}');
      debugPrint('🍎 Max tokens: $maxTokens, Temperature: $temperature');
      
      final stopwatch = Stopwatch()..start();

      final result = await _channel.invokeMethod<String>('generate', {
        'systemPrompt': systemPrompt,
        'userPrompt': userPrompt,
        'temperature': temperature,
        'maxTokens': maxTokens,
      });

      stopwatch.stop();
      final tokensPerSecond = (result?.length ?? 0) / (stopwatch.elapsedMilliseconds / 1000);
      
      debugPrint('🍎 ✓ MLC generation complete');
      debugPrint('🍎   Time: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('🍎   Output length: ${result?.length ?? 0} chars');
      debugPrint('🍎   Speed: ${tokensPerSecond.toStringAsFixed(1)} chars/sec');

      return result ?? '';
    } catch (e) {
      debugPrint('🍎 ❌ MLC generation failed: $e');
      rethrow;
    }
  }

  Future<bool> isModelLoaded() async {
    try {
      final result = await _channel.invokeMethod<bool>('isModelLoaded');
      return result ?? false;
    } catch (e) {
      debugPrint('🍎 ⚠️ Error checking MLC model status: $e');
      return false;
    }
  }
}
