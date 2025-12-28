/// Calculate maximum edge angle (pitch) from both sensors during a turn.
library;

import '../../models.dart';
import 'package:flutter/foundation.dart';

class EdgeAngleCalculator {
  /// Calculate maximum absolute pitch during turn segment
  /// Filters out unrealistic values (>90 degrees) and returns the maximum
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
      debugPrint('📊 METRIC 1: MAX EDGE ANGLE (Pitch)');
      debugPrint(
        '📊 ════════════════════════════════════════════════════════════════════════',
      );
      debugPrint('📊 Turn #$turnNumber');
      debugPrint('📊 Left indices: $startIdxLeft → $endIdxLeft');
      debugPrint('📊 Right indices: $startIdxRight → $endIdxRight');
    }

    double maxEdgeAngle = 0.0;

    // Check left sensor - filter out unrealistic values
    for (int i = startIdxLeft; i <= endIdxLeft && i < leftSamples.length; i++) {
      final pitch = leftSamples[i].pitch.abs();
      // Only consider pitch values that are reasonable for skiing (0-90 degrees)
      if (pitch <= 90.0 && pitch > maxEdgeAngle) {
        maxEdgeAngle = pitch;
        if (kDebugMode) {
          debugPrint('   L[$i] pitch=${pitch.toStringAsFixed(2)}° ← NEW MAX');
        }
      } else if (kDebugMode) {
        if (pitch > 90.0) {
          debugPrint(
            '   L[$i] pitch=${pitch.toStringAsFixed(2)}° ✗ (out of range)',
          );
        } else {
          debugPrint('   L[$i] pitch=${pitch.toStringAsFixed(2)}°');
        }
      }
    }

    // Check right sensor - filter out unrealistic values
    for (
      int i = startIdxRight;
      i <= endIdxRight && i < rightSamples.length;
      i++
    ) {
      final pitch = rightSamples[i].pitch.abs();
      // Only consider pitch values that are reasonable for skiing (0-90 degrees)
      if (pitch <= 90.0 && pitch > maxEdgeAngle) {
        maxEdgeAngle = pitch;
        if (kDebugMode) {
          debugPrint('   R[$i] pitch=${pitch.toStringAsFixed(2)}° ← NEW MAX');
        }
      } else if (kDebugMode) {
        if (pitch > 90.0) {
          debugPrint(
            '   R[$i] pitch=${pitch.toStringAsFixed(2)}° ✗ (out of range)',
          );
        } else {
          debugPrint('   R[$i] pitch=${pitch.toStringAsFixed(2)}°');
        }
      }
    }

    if (kDebugMode) {
      debugPrint(
        '📊 FINAL MAX EDGE ANGLE: ${maxEdgeAngle.toStringAsFixed(2)}°',
      );
    }

    return maxEdgeAngle;
  }
}
