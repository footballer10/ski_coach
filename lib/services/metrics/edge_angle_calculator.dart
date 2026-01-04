/// Calculate maximum edge angle (pitch) from both sensors during a turn.
library;

import '../../models.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

class EdgeAngleCalculator {
  /// Calculate maximum averaged edge angle from both sensors
  /// Averages each left/right pair, then finds the max of those averages
  static double calculateMaxEdgeAngle({
    required List<ImuSample> leftSamples,
    required List<ImuSample> rightSamples,
    required int startIdxLeft,
    required int endIdxLeft,
    required int startIdxRight,
    required int endIdxRight,
    required int turnNumber,
  }) {
    if (kDebugMode) {
      debugPrint('');
      debugPrint(
        '📊 ════════════════════════════════════════════════════════════════════════',
      );
      debugPrint('📊 METRIC 1: MAX EDGE ANGLE (Averaged Pitch)');
      debugPrint(
        '📊 ════════════════════════════════════════════════════════════════════════',
      );
      debugPrint('📊 Turn #$turnNumber');
      debugPrint('📊 Left indices: $startIdxLeft → $endIdxLeft');
      debugPrint('📊 Right indices: $startIdxRight → $endIdxRight');
    }

    double maxAvgEdgeAngle = 0.0;

    // Iterate through overlapping indices and average each pair
    final minLength = math.min(leftSamples.length, rightSamples.length);
    final startIdx = math.max(startIdxLeft, startIdxRight);
    final endIdx = math.min(
      math.min(endIdxLeft, endIdxRight),
      minLength - 1,
    );

    for (int i = startIdx; i <= endIdx; i++) {
      final leftPitch = leftSamples[i].pitch.abs();
      final rightPitch = rightSamples[i].pitch.abs();
      
      // Only consider pitch values that are reasonable for skiing (0-90 degrees)
      if (leftPitch <= 90.0 && rightPitch <= 90.0) {
        final avgPitch = (leftPitch + rightPitch) / 2.0;
        
        if (avgPitch > maxAvgEdgeAngle) {
          maxAvgEdgeAngle = avgPitch;
          if (kDebugMode) {
            debugPrint(
              '   [$i] L=${leftPitch.toStringAsFixed(2)}° R=${rightPitch.toStringAsFixed(2)}° AVG=${avgPitch.toStringAsFixed(2)}° ← NEW MAX',
            );
          }
        } else if (kDebugMode) {
          debugPrint(
            '   [$i] L=${leftPitch.toStringAsFixed(2)}° R=${rightPitch.toStringAsFixed(2)}° AVG=${avgPitch.toStringAsFixed(2)}°',
          );
        }
      } else if (kDebugMode) {
        debugPrint(
          '   [$i] L=${leftPitch.toStringAsFixed(2)}° R=${rightPitch.toStringAsFixed(2)}° ✗ (out of range)',
        );
      }
    }

    if (kDebugMode) {
      debugPrint(
        '📊 FINAL MAX AVERAGED EDGE ANGLE: ${maxAvgEdgeAngle.toStringAsFixed(2)}°',
      );
    }

    return maxAvgEdgeAngle;
  }
}
