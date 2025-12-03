/// Calculate turn smoothness via standard deviation of angular velocity.
library;

import '../imu_preprocessor.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

class SmoothnessResult {
  final double average;
  final double beginning;
  final double middle;
  final double end;

  SmoothnessResult({
    required this.average,
    required this.beginning,
    required this.middle,
    required this.end,
  });
}

class SmoothnessCalculator {
  /// Calculate smoothness metrics for a turn segment
  static SmoothnessResult calculate({
    required List<AnglePoint> smoothedYaw,
    required List<double> unwrappedSmoothedYaw,
    required DateTime startTime,
    required DateTime endTime,
    required double samplingRate,
    required int turnNumber,
  }) {
    if (kDebugMode) {
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 METRIC 3: SMOOTHNESS (Angular Velocity Standard Deviation) - ALL SAMPLES');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Turn #$turnNumber');
      debugPrint('📊 Angular velocity = Δyaw × sampling_rate (${samplingRate}Hz)');
    }

    // Calculate turn thirds
    final duration = endTime.difference(startTime);
    final thirdDuration = Duration(milliseconds: duration.inMilliseconds ~/ 3);
    final middleStart = startTime.add(thirdDuration);
    final endStart = startTime.add(thirdDuration * 2);

    // Find indices in smoothed yaw
    final startYawIdx = ImuPreprocessor.indexForTime(smoothedYaw, startTime) ?? 0;
    final endYawIdx = ImuPreprocessor.indexForTime(smoothedYaw, endTime) ?? smoothedYaw.length - 1;

    final velocitiesBeginning = <double>[];
    final velocitiesMiddle = <double>[];
    final velocitiesEnd = <double>[];

    for (int i = startYawIdx; i < endYawIdx; i++) {
      final yawChange = unwrappedSmoothedYaw[i + 1] - unwrappedSmoothedYaw[i];
      final angularVelocity = yawChange * samplingRate;
      final sampleTime = smoothedYaw[i].time;

      String third = '';
      if (sampleTime.isBefore(middleStart)) {
        velocitiesBeginning.add(angularVelocity);
        third = '1st';
      } else if (sampleTime.isBefore(endStart)) {
        velocitiesMiddle.add(angularVelocity);
        third = 'mid';
      } else {
        velocitiesEnd.add(angularVelocity);
        third = 'end';
      }

      if (kDebugMode) {
        debugPrint('   [$i] ($third) unwrappedYaw[i]=${unwrappedSmoothedYaw[i].toStringAsFixed(2)}°, unwrappedYaw[i+1]=${unwrappedSmoothedYaw[i + 1].toStringAsFixed(2)}°, Δyaw=${yawChange.toStringAsFixed(4)}°, angVel=${angularVelocity.toStringAsFixed(2)}°/s');
      }
    }

    final sdBeginning = _standardDeviation(velocitiesBeginning);
    final sdMiddle = _standardDeviation(velocitiesMiddle);
    final sdEnd = _standardDeviation(velocitiesEnd);
    final sdAverage = (sdBeginning + sdMiddle + sdEnd) / 3.0;

    if (kDebugMode) {
      debugPrint('📊 FINAL SMOOTHNESS TOTALS:');
      debugPrint('   - 1st third: ${velocitiesBeginning.length} velocities, SD=${sdBeginning.toStringAsFixed(2)}°/s');
      debugPrint('   - Mid third: ${velocitiesMiddle.length} velocities, SD=${sdMiddle.toStringAsFixed(2)}°/s');
      debugPrint('   - End third: ${velocitiesEnd.length} velocities, SD=${sdEnd.toStringAsFixed(2)}°/s');
      debugPrint('   - AVG of 3 SDs: ${sdAverage.toStringAsFixed(2)}°/s');
    }

    return SmoothnessResult(
      average: sdAverage,
      beginning: sdBeginning,
      middle: sdMiddle,
      end: sdEnd,
    );
  }

  /// Calculate standard deviation of a list of values
  static double _standardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance);
  }
}
