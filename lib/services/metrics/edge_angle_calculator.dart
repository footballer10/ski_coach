/// Calculate maximum edge angle (pitch) from both sensors during a turn.
library;

import '../../models/imu_sample.dart';
import 'package:flutter/foundation.dart';

class EdgeAngleCalculator {
  /// Calculate maximum absolute pitch during turn segment
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
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 METRIC 1: MAX EDGE ANGLE (Pitch) - ALL SAMPLES');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Turn #$turnNumber');
      debugPrint('📊 Left indices: $startIdxLeft → $endIdxLeft');
      debugPrint('📊 Right indices: $startIdxRight → $endIdxRight');
    }

    double maxEdgeAngle = 0.0;

    // Check left sensor
    for (int i = startIdxLeft; i <= endIdxLeft; i++) {
      final pitch = leftSamples[i].pitch;
      final absPitch = pitch.abs();
      
      if (absPitch > maxEdgeAngle) {
        maxEdgeAngle = absPitch;
        if (kDebugMode) {
          debugPrint('   L[$i] pitch=${pitch.toStringAsFixed(2)}°, |pitch|=${absPitch.toStringAsFixed(2)}° ← NEW MAX');
        }
      } else if (kDebugMode) {
        debugPrint('   L[$i] pitch=${pitch.toStringAsFixed(2)}°, |pitch|=${absPitch.toStringAsFixed(2)}°');
      }
    }

    // Check right sensor
    for (int i = startIdxRight; i <= endIdxRight; i++) {
      final pitch = rightSamples[i].pitch;
      final absPitch = pitch.abs();
      
      if (absPitch > maxEdgeAngle) {
        maxEdgeAngle = absPitch;
        if (kDebugMode) {
          debugPrint('   R[$i] pitch=${pitch.toStringAsFixed(2)}°, |pitch|=${absPitch.toStringAsFixed(2)}° ← NEW MAX');
        }
      } else if (kDebugMode) {
        debugPrint('   R[$i] pitch=${pitch.toStringAsFixed(2)}°, |pitch|=${absPitch.toStringAsFixed(2)}°');
      }
    }

    if (kDebugMode) {
      debugPrint('📊 FINAL MAX EDGE ANGLE: ${maxEdgeAngle.toStringAsFixed(2)}°');
    }

    return maxEdgeAngle;
  }
}
