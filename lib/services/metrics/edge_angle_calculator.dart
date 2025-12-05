/// Calculate maximum edge angle (pitch) from both sensors during a turn.
library;

import '../../models/imu_sample.dart';
import 'package:flutter/foundation.dart';

class EdgeAngleCalculator {
  /// Calculate maximum absolute pitch during turn segment
  /// Requires at least 5 samples within 10 degrees to filter out random jumps
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
      debugPrint('📊 METRIC 1: MAX EDGE ANGLE (Pitch) - FILTERED SAMPLES');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Turn #$turnNumber');
      debugPrint('📊 Left indices: $startIdxLeft → $endIdxLeft');
      debugPrint('📊 Right indices: $startIdxRight → $endIdxRight');
    }

    // Collect all valid pitch values (absolute, within reasonable range)
    final List<double> validPitches = [];

    // Check left sensor - filter out unrealistic values
    for (int i = startIdxLeft; i <= endIdxLeft; i++) {
      final pitch = leftSamples[i].pitch.abs();
      // Only consider pitch values that are reasonable for skiing (0-90 degrees)
      if (pitch <= 90.0) {
        validPitches.add(pitch);
        if (kDebugMode) {
          debugPrint('   L[$i] pitch=${pitch.toStringAsFixed(2)}° ✓');
        }
      } else if (kDebugMode) {
        debugPrint('   L[$i] pitch=${pitch.toStringAsFixed(2)}° ✗ (out of range)');
      }
    }

    // Check right sensor - filter out unrealistic values
    for (int i = startIdxRight; i <= endIdxRight; i++) {
      final pitch = rightSamples[i].pitch.abs();
      // Only consider pitch values that are reasonable for skiing (0-90 degrees)
      if (pitch <= 90.0) {
        validPitches.add(pitch);
        if (kDebugMode) {
          debugPrint('   R[$i] pitch=${pitch.toStringAsFixed(2)}° ✓');
        }
      } else if (kDebugMode) {
        debugPrint('   R[$i] pitch=${pitch.toStringAsFixed(2)}° ✗ (out of range)');
      }
    }

    if (validPitches.isEmpty) {
      if (kDebugMode) {
        debugPrint('📊 ⚠️ No valid pitch values found, returning 0.0°');
      }
      return 0.0;
    }

    // Sort to find clusters
    validPitches.sort();

    // Find the maximum pitch value that has at least 5 samples within 10 degrees
    double maxEdgeAngle = 0.0;
    
    for (int i = 0; i < validPitches.length; i++) {
      final candidate = validPitches[i];
      
      // Count how many samples are within 10 degrees of this candidate
      int nearbyCount = 0;
      for (final pitch in validPitches) {
        if ((pitch - candidate).abs() <= 10.0) {
          nearbyCount++;
        }
      }
      
      // If this candidate has at least 5 nearby samples and is higher than current max
      if (nearbyCount >= 5 && candidate > maxEdgeAngle) {
        maxEdgeAngle = candidate;
        if (kDebugMode) {
          debugPrint('   Candidate ${candidate.toStringAsFixed(2)}° has $nearbyCount nearby samples ← NEW MAX');
        }
      }
    }

    if (kDebugMode) {
      debugPrint('📊 FINAL MAX EDGE ANGLE: ${maxEdgeAngle.toStringAsFixed(2)}° (from ${validPitches.length} valid samples)');
    }

    return maxEdgeAngle;
  }
}
