/// Calculate ski parallelness (yaw difference) for turn segments.
library;

import '../../models.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

class ParallelnessResult {
  final double average;
  final double beginning;
  final double middle;
  final double end;

  ParallelnessResult({
    required this.average,
    required this.beginning,
    required this.middle,
    required this.end,
  });
}

class ParallelnessCalculator {
  /// Calculate parallelness metrics for a turn segment
  static ParallelnessResult calculate({
    required List<ImuSample> leftSamples,
    required List<ImuSample> rightSamples,
    required int startIdxLeft,
    required int endIdxLeft,
    required int startIdxRight,
    required int endIdxRight,
    required DateTime startTime,
    required DateTime endTime,
    required int turnNumber,
  }) {
    if (kDebugMode) {
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 METRIC 2: PARALLELNESS (Yaw Difference) - ALL SAMPLES');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Turn #$turnNumber');
      debugPrint('📊 NOTE: Calibration offset already applied to right sensor in STEP 1');
    }

    // Calculate turn thirds
    final duration = endTime.difference(startTime);
    final thirdDuration = Duration(milliseconds: duration.inMilliseconds ~/ 3);
    final middleStart = startTime.add(thirdDuration);
    final endStart = startTime.add(thirdDuration * 2);

    if (kDebugMode) {
      debugPrint('📊 Turn thirds: 1st=${thirdDuration.inMilliseconds}ms, Mid=${thirdDuration.inMilliseconds}ms, End=${thirdDuration.inMilliseconds}ms');
    }

    double sumTotal = 0.0;
    int countTotal = 0;
    double sumBeginning = 0.0;
    int countBeginning = 0;
    double sumMiddle = 0.0;
    int countMiddle = 0;
    double sumEnd = 0.0;
    int countEnd = 0;

    for (int i = 0; i < math.min(leftSamples.length, rightSamples.length); i++) {
      if (i >= startIdxLeft && i <= endIdxLeft && i >= startIdxRight && i <= endIdxRight) {
        final leftSample = leftSamples[i];
        final rightSample = rightSamples[i];

        // Use stored parallelness if available, otherwise compute it
        double parallelness;
        if (leftSample.parallelness != null) {
          parallelness = leftSample.parallelness!;
        } else if (rightSample.parallelness != null) {
          parallelness = rightSample.parallelness!;
        } else {
          // Compute from corrected yaw values (calibration already applied in STEP 1)
          final actualDiff = rightSample.yaw - leftSample.yaw;
          parallelness = actualDiff.abs();
        }

        sumTotal += parallelness;
        countTotal++;

        // Determine which third this sample belongs to
        final sampleTime = leftSample.timestamp;
        String third = '';
        if (sampleTime.isBefore(middleStart)) {
          sumBeginning += parallelness;
          countBeginning++;
          third = '1st';
        } else if (sampleTime.isBefore(endStart)) {
          sumMiddle += parallelness;
          countMiddle++;
          third = 'mid';
        } else {
          sumEnd += parallelness;
          countEnd++;
          third = 'end';
        }

        if (kDebugMode) {
          debugPrint('   [$i] ($third) L_yaw=${leftSample.yaw.toStringAsFixed(2)}°, R_yaw=${rightSample.yaw.toStringAsFixed(2)}°, |diff|=${parallelness.toStringAsFixed(2)}°');
        }
      }
    }

    final avgTotal = countTotal > 0 ? sumTotal / countTotal : 0.0;
    final avgBeginning = countBeginning > 0 ? sumBeginning / countBeginning : 0.0;
    final avgMiddle = countMiddle > 0 ? sumMiddle / countMiddle : 0.0;
    final avgEnd = countEnd > 0 ? sumEnd / countEnd : 0.0;

    if (kDebugMode) {
      debugPrint('📊 FINAL PARALLELNESS TOTALS:');
      debugPrint('   - ALL samples: count=$countTotal, sum=${sumTotal.toStringAsFixed(2)}°, avg=${avgTotal.toStringAsFixed(2)}°');
      debugPrint('   - 1st third: count=$countBeginning, sum=${sumBeginning.toStringAsFixed(2)}°, avg=${avgBeginning.toStringAsFixed(2)}°');
      debugPrint('   - Mid third: count=$countMiddle, sum=${sumMiddle.toStringAsFixed(2)}°, avg=${avgMiddle.toStringAsFixed(2)}°');
      debugPrint('   - End third: count=$countEnd, sum=${sumEnd.toStringAsFixed(2)}°, avg=${avgEnd.toStringAsFixed(2)}°');
    }

    return ParallelnessResult(
      average: avgTotal,
      beginning: avgBeginning,
      middle: avgMiddle,
      end: avgEnd,
    );
  }
}
