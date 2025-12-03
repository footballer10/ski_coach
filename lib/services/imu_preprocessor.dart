/// IMU data preprocessing: calibration offsets, jump correction, unwrapping, averaging, smoothing.
library;

import '../../models/imu_sample.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

/// Internal class for angle data with timestamp
class AnglePoint {
  final DateTime time;
  final double angle;

  AnglePoint(this.time, this.angle);
}

/// Preprocesses IMU data through the full pipeline
class ImuPreprocessor {
  /// Apply calibration offset to right sensor yaw
  static List<ImuSample> applyYawOffset(
    List<ImuSample> samples,
    double offset, [
    String label = '',
  ]) {
    if (kDebugMode) {
      debugPrint('');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 STEP 1: APPLY YAW OFFSET ($label)');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 Offset: ${offset.toStringAsFixed(2)}° (subtracting from right sensor)');
      debugPrint('🔧 Processing ${samples.length} samples...');
    }

    final corrected = <ImuSample>[];
    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      final newYaw = s.yaw - offset;
      corrected.add(ImuSample(
        timestamp: s.timestamp,
        ax: s.ax,
        ay: s.ay,
        az: s.az,
        gx: s.gx,
        gy: s.gy,
        gz: s.gz,
        yaw: newYaw,
        pitch: s.pitch,
        roll: s.roll,
        parallelness: s.parallelness,
      ));

      if (kDebugMode) {
        debugPrint('   [$i] Before: ${s.yaw.toStringAsFixed(2)}°, After: ${newYaw.toStringAsFixed(2)}°');
      }
    }

    if (kDebugMode) {
      debugPrint('🔧 Offset applied to all samples.');
    }

    return corrected;
  }

  /// Correct angle jumps larger than threshold (default 10°)
  static List<ImuSample> correctAngleJumps(
    List<ImuSample> samples, [
    String label = '',
    double threshold = 10.0,
  ]) {
    if (samples.isEmpty) return samples;

    if (kDebugMode) {
      debugPrint('');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 STEP 2: CORRECT ANGLE JUMPS ($label)');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 Threshold: ${threshold.toStringAsFixed(2)}°');
      debugPrint('🔧 Input: ${samples.length} samples');
      debugPrint('🔧 INPUT SAMPLES (ALL):');
    }

    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      if (kDebugMode) {
        debugPrint('   [$i] yaw=${s.yaw.toStringAsFixed(2)}°, pitch=${s.pitch.toStringAsFixed(2)}°, roll=${s.roll.toStringAsFixed(2)}°');
      }
    }

    final corrected = <ImuSample>[];
    corrected.add(samples[0]);

    for (int i = 1; i < samples.length; i++) {
      final prev = corrected[i - 1];
      final curr = samples[i];

      double correctedYaw = curr.yaw;
      double correctedPitch = curr.pitch;
      double correctedRoll = curr.roll;

      // Detect and correct yaw jumps
      final yawDiff = (curr.yaw - prev.yaw).abs();
      if (yawDiff > threshold) {
        correctedYaw = prev.yaw;
      }

      // Detect and correct pitch jumps
      final pitchDiff = (curr.pitch - prev.pitch).abs();
      if (pitchDiff > threshold) {
        correctedPitch = prev.pitch;
      }

      // Detect and correct roll jumps
      final rollDiff = (curr.roll - prev.roll).abs();
      if (rollDiff > threshold) {
        correctedRoll = prev.roll;
      }

      corrected.add(ImuSample(
        timestamp: curr.timestamp,
        ax: curr.ax,
        ay: curr.ay,
        az: curr.az,
        gx: curr.gx,
        gy: curr.gy,
        gz: curr.gz,
        yaw: correctedYaw,
        pitch: correctedPitch,
        roll: correctedRoll,
        parallelness: curr.parallelness,
      ));
    }

    if (kDebugMode) {
      debugPrint('🔧 OUTPUT SAMPLES (ALL):');
      for (int i = 0; i < corrected.length; i++) {
        final s = corrected[i];
        debugPrint('   [$i] yaw=${s.yaw.toStringAsFixed(2)}°, pitch=${s.pitch.toStringAsFixed(2)}°, roll=${s.roll.toStringAsFixed(2)}°');
      }
      debugPrint('🔧 Jump correction complete.');
    }

    return corrected;
  }

  /// Unwrap individual sensor yaw angles (before averaging)
  static List<double> unwrapSensorYaw(
    List<ImuSample> samples, [
    String label = '',
  ]) {
    if (samples.isEmpty) return [];

    if (kDebugMode) {
      debugPrint('');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 STEP 3: UNWRAP SENSOR YAW ($label)');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 Purpose: Remove ±180° wraparound discontinuities BEFORE averaging');
      debugPrint('🔧 Input: ${samples.length} samples');
      debugPrint('🔧 INPUT SAMPLES (ALL):');
    }

    for (int i = 0; i < samples.length; i++) {
      if (kDebugMode) {
        debugPrint('   [$i] wrapped_yaw=${samples[i].yaw.toStringAsFixed(2)}°');
      }
    }

    final unwrapped = <double>[];
    unwrapped.add(samples[0].yaw);
    double offset = 0.0;

    for (int i = 1; i < samples.length; i++) {
      final diff = samples[i].yaw - samples[i - 1].yaw;
      if (diff > 180) {
        offset -= 360;
      } else if (diff < -180) {
        offset += 360;
      }
      unwrapped.add(samples[i].yaw + offset);
    }

    if (kDebugMode) {
      debugPrint('🔧 OUTPUT UNWRAPPED YAW (ALL):');
      for (int i = 0; i < unwrapped.length; i++) {
        debugPrint('   [$i] unwrapped_yaw=${unwrapped[i].toStringAsFixed(2)}°');
      }
      debugPrint('🔧 Unwrapping complete.');
    }

    return unwrapped;
  }

  /// Average unwrapped yaw signals from both sensors (preserves originals)
  static List<AnglePoint> averageUnwrappedYawSignals(
    List<ImuSample> left,
    List<ImuSample> right,
    List<double> unwrappedLeft,
    List<double> unwrappedRight,
  ) {
    if (kDebugMode) {
      debugPrint('');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 STEP 4: AVERAGE UNWRAPPED YAW SIGNALS');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 Left samples: ${left.length}, Right samples: ${right.length}');
      debugPrint('🔧 NOTE: Original sensor yaws preserved for parallelness calculation');
    }

    final result = <AnglePoint>[];
    final minLength = math.min(left.length, right.length);

    for (int i = 0; i < minLength; i++) {
      final avgYaw = (unwrappedLeft[i] + unwrappedRight[i]) / 2.0;
      result.add(AnglePoint(left[i].timestamp, avgYaw));
    }

    if (kDebugMode) {
      debugPrint('🔧 OUTPUT AVERAGED YAW (ALL):');
      for (int i = 0; i < result.length; i++) {
        debugPrint('   [$i] L_unwrapped=${unwrappedLeft[i].toStringAsFixed(2)}°, R_unwrapped=${unwrappedRight[i].toStringAsFixed(2)}°, avg=${result[i].angle.toStringAsFixed(2)}°');
      }
      debugPrint('🔧 Averaging complete. Created ${result.length} averaged points.');
    }

    return result;
  }

  /// Smooth yaw signal with moving average
  static List<AnglePoint> smoothYaw(
    List<AnglePoint> avgYaw, {
    int windowSize = 5,
  }) {
    if (avgYaw.length < windowSize) return avgYaw;

    if (kDebugMode) {
      debugPrint('');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 STEP 5: SMOOTH AVERAGED YAW');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 Window size: $windowSize samples');
      debugPrint('🔧 Input: ${avgYaw.length} points');
    }

    final smoothed = <AnglePoint>[];
    for (int i = 0; i < avgYaw.length; i++) {
      final start = math.max(0, i - windowSize ~/ 2);
      final end = math.min(avgYaw.length, i + windowSize ~/ 2 + 1);
      final window = avgYaw.sublist(start, end);

      double sum = 0;
      for (final pt in window) {
        sum += pt.angle;
      }
      final avg = sum / window.length;
      smoothed.add(AnglePoint(avgYaw[i].time, avg));
    }

    if (kDebugMode) {
      debugPrint('🔧 OUTPUT SMOOTHED YAW (ALL):');
      for (int i = 0; i < smoothed.length; i++) {
        debugPrint('   [$i] before=${avgYaw[i].angle.toStringAsFixed(2)}°, after=${smoothed[i].angle.toStringAsFixed(2)}°');
      }
      debugPrint('🔧 Smoothing complete.');
    }

    return smoothed;
  }

  /// Unwrap smoothed yaw for peak detection
  static List<double> unwrapSmoothedYaw(
    List<AnglePoint> pts, [
    String label = '',
  ]) {
    if (pts.isEmpty) return [];

    if (kDebugMode) {
      debugPrint('');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 STEP 6: UNWRAP SMOOTHED YAW');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 Purpose: Remove ±180° wraparound for peak detection');
      debugPrint('🔧 Input: ${pts.length} smoothed points');
      debugPrint('🔧 INPUT SMOOTHED YAW (ALL):');
    }

    for (int i = 0; i < pts.length; i++) {
      if (kDebugMode) {
        debugPrint('   [$i] wrapped_yaw=${pts[i].angle.toStringAsFixed(2)}°');
      }
    }

    final unwrapped = <double>[];
    unwrapped.add(pts[0].angle);
    double offset = 0.0;

    for (int i = 1; i < pts.length; i++) {
      final diff = pts[i].angle - pts[i - 1].angle;
      if (diff > 180) {
        offset -= 360;
      } else if (diff < -180) {
        offset += 360;
      }
      unwrapped.add(pts[i].angle + offset);
    }

    if (kDebugMode) {
      debugPrint('🔧 OUTPUT UNWRAPPED SMOOTHED YAW (ALL):');
      for (int i = 0; i < unwrapped.length; i++) {
        debugPrint('   [$i] unwrapped_yaw=${unwrapped[i].toStringAsFixed(2)}°');
      }
      debugPrint('🔧 Unwrapping complete.');
    }

    return unwrapped;
  }

  /// Wrap angle to ±180° range
  static double wrapAngle(double angle) {
    double wrapped = angle % 360;
    if (wrapped > 180) {
      wrapped -= 360;
    } else if (wrapped < -180) {
      wrapped += 360;
    }
    return wrapped;
  }

  /// Calculate angle difference accounting for wraparound
  static double angleDiff(double a, double b) {
    double diff = (a - b) % 360;
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }
    return diff;
  }

  /// Find nearest sample index for a given timestamp
  static int nearestIndex(List<ImuSample> samples, DateTime time) {
    if (samples.isEmpty) return -1;
    int bestIdx = 0;
    Duration bestDiff = (samples[0].timestamp.difference(time)).abs();
    for (int i = 1; i < samples.length; i++) {
      final diff = (samples[i].timestamp.difference(time)).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Find index in angle points for a given timestamp
  static int? indexForTime(List<AnglePoint> pts, DateTime time) {
    for (int i = 0; i < pts.length; i++) {
      if (pts[i].time == time) return i;
    }
    return null;
  }
}
