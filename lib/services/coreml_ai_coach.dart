import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// CoreML AI Coach - iOS-specific implementation using Apple's CoreML
/// This provides the same interface as the llama_cpp_dart version but uses
/// Apple's optimized Neural Engine for much faster inference on iOS devices.
class CoreMLAICoach {
  static const _channel = MethodChannel('ski_coach/coreml');
  
  bool _isInitialized = false;
  bool _isModelLoaded = false;

  /// Check if CoreML is available (iOS only)
  static bool get isAvailable => Platform.isIOS;

  /// Initialize the CoreML coach (no-op, actual loading happens on demand)
  Future<void> initialize() async {
    if (!isAvailable) {
      throw UnsupportedError('CoreML is only available on iOS');
    }
    _isInitialized = true;
    debugPrint('🍎 CoreML AI Coach initialized');
  }

  /// Load the model into memory
  Future<void> loadModelIntoMemory() async {
    if (_isModelLoaded) {
      debugPrint('🍎 CoreML model already loaded');
      return;
    }

    debugPrint('🍎 Loading CoreML model into memory...');
    try {
      final result = await _channel.invokeMethod<bool>('loadModel');
      if (result == true) {
        _isModelLoaded = true;
        debugPrint('🍎 CoreML model loaded and ready!');
      } else {
        throw Exception('Model loading returned false');
      }
    } catch (e) {
      debugPrint('🍎 CoreML model load failed: $e');
      rethrow;
    }
  }

  /// Unload the model from memory
  Future<void> unloadModelFromMemory() async {
    if (!_isModelLoaded) {
      debugPrint('🍎 CoreML model not loaded, nothing to unload');
      return;
    }

    debugPrint('🍎 Unloading CoreML model from memory...');
    try {
      await _channel.invokeMethod('unloadModel');
      _isModelLoaded = false;
      debugPrint('🍎 CoreML model unloaded, memory freed');
    } catch (e) {
      debugPrint('🍎 CoreML model unload failed: $e');
    }
  }

  /// Generate coaching advice using CoreML
  Future<String> generateCoachingAdvice({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required int maxTokens,
  }) async {
    if (!_isModelLoaded) {
      throw Exception(
        'CoreML model not loaded. Please toggle to Local mode first to load the model.',
      );
    }

    debugPrint('🍎 Generating response with CoreML...');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _channel.invokeMethod<String>(
        'generate',
        {
          'systemPrompt': systemPrompt,
          'userPrompt': userPrompt,
          'temperature': temperature,
          'maxTokens': maxTokens,
        },
      );

      stopwatch.stop();
      debugPrint(
        '🍎 CoreML generation completed in ${stopwatch.elapsedMilliseconds}ms',
      );

      if (response == null || response.isEmpty) {
        throw Exception('CoreML returned empty response');
      }

      return response;
    } catch (e) {
      stopwatch.stop();
      debugPrint('🍎 CoreML generation failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  /// Check if model is currently loaded
  Future<bool> isModelLoaded() async {
    try {
      final result = await _channel.invokeMethod<bool>('isModelLoaded');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    if (_isModelLoaded) {
      unloadModelFromMemory();
    }
  }
}
