/// IMU data preprocessing: unwrapping, calibration, jump correction, averaging.
library;

import '../models/imu_sample.dart';
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
  /// STEP 1: Unwrap angles to remove ±180° discontinuities
  static List<ImuSample> unwrapAngles(
    List<ImuSample> samples, [
    String label = '',
  ]) {
    if (samples.isEmpty) return samples;

    if (kDebugMode) {
      debugPrint('');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 STEP 1: UNWRAP ANGLES ($label)');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 Purpose: Remove ±180° wraparound discontinuities');
      debugPrint('🔧 Input: ${samples.length} samples');
    }

    final unwrapped = <ImuSample>[];
    double yawOffset = 0.0;
    double pitchOffset = 0.0;
    double rollOffset = 0.0;

    unwrapped.add(samples[0]);

    for (int i = 1; i < samples.length; i++) {
      final prev = samples[i - 1];
      final curr = samples[i];

      // Check yaw
      final yawDiff = curr.yaw - prev.yaw;
      if (yawDiff > 180) {
        yawOffset -= 360;
      } else if (yawDiff < -180) {
        yawOffset += 360;
      }

      // Check pitch
      final pitchDiff = curr.pitch - prev.pitch;
      if (pitchDiff > 180) {
        pitchOffset -= 360;
      } else if (pitchDiff < -180) {
        pitchOffset += 360;
      }

      // Check roll
      final rollDiff = curr.roll - prev.roll;
      if (rollDiff > 180) {
        rollOffset -= 360;
      } else if (rollDiff < -180) {
        rollOffset += 360;
      }

      unwrapped.add(ImuSample(
        timestamp: curr.timestamp,
        ax: curr.ax,
        ay: curr.ay,
        az: curr.az,
        gx: curr.gx,
        gy: curr.gy,
        gz: curr.gz,
        yaw: curr.yaw + yawOffset,
        pitch: curr.pitch + pitchOffset,
        roll: curr.roll + rollOffset,
        parallelness: curr.parallelness,
      ));
    }

    if (kDebugMode) {
      debugPrint('🔧 SIDE-BY-SIDE COMPARISON:');
      debugPrint('   Idx | Wrapped Roll | Unwrapped Roll | Wrapped Pitch | Unwrapped Pitch | Wrapped Yaw   | Unwrapped Yaw');
      debugPrint('   ────|──────────────|────────────────|───────────────|─────────────────|───────────────|───────────────');
      for (int i = 0; i < samples.length; i++) {
        final orig = samples[i];
        final unwr = unwrapped[i];
        debugPrint('   ${i.toString().padLeft(3)} | ${orig.roll.toStringAsFixed(2).padLeft(12)} | ${unwr.roll.toStringAsFixed(2).padLeft(14)} | ${orig.pitch.toStringAsFixed(2).padLeft(13)} | ${unwr.pitch.toStringAsFixed(2).padLeft(15)} | ${orig.yaw.toStringAsFixed(2).padLeft(13)} | ${unwr.yaw.toStringAsFixed(2).padLeft(13)}');
      }
      debugPrint('🔧 Unwrapping complete.');
    }

    return unwrapped;
  }

  /// STEP 2: Apply calibration offset to RIGHT sensor yaw
  static List<ImuSample> applyYawOffset(
    List<ImuSample> samples,
    double offset, [
    String label = '',
  ]) {
    if (kDebugMode) {
      debugPrint('');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 STEP 3: APPLY YAW OFFSET ($label)');
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
    }

    if (kDebugMode) {
      debugPrint('🔧 SIDE-BY-SIDE COMPARISON:');
      debugPrint('   Idx | Before Yaw   | After Yaw');
      debugPrint('   ────|──────────────|────────────');
      for (int i = 0; i < samples.length; i++) {
        debugPrint('   ${i.toString().padLeft(3)} | ${samples[i].yaw.toStringAsFixed(2).padLeft(12)} | ${corrected[i].yaw.toStringAsFixed(2).padLeft(10)}');
      }
      debugPrint('🔧 Offset applied to all samples.');
    }

    return corrected;
  }

  /// STEP 3: Correct angle jumps with accumulating offset
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
    }

    final corrected = <ImuSample>[];
    corrected.add(samples[0]);

    double yawAccumOffset = 0.0;
    double pitchAccumOffset = 0.0;
    double rollAccumOffset = 0.0;

    for (int i = 1; i < samples.length; i++) {
      final prev = corrected[i - 1];
      final curr = samples[i];

      // Detect yaw jump
      final yawDiff = (curr.yaw - prev.yaw).abs();
      if (yawDiff > threshold && yawDiff < 180) { // Not a wraparound
        yawAccumOffset += (prev.yaw - curr.yaw);
      }

      // Detect pitch jump
      final pitchDiff = (curr.pitch - prev.pitch).abs();
      if (pitchDiff > threshold && pitchDiff < 180) {
        pitchAccumOffset += (prev.pitch - curr.pitch);
      }

      // Detect roll jump
      final rollDiff = (curr.roll - prev.roll).abs();
      if (rollDiff > threshold && rollDiff < 180) {
        rollAccumOffset += (prev.roll - curr.roll);
      }

      corrected.add(ImuSample(
        timestamp: curr.timestamp,
        ax: curr.ax,
        ay: curr.ay,
        az: curr.az,
        gx: curr.gx,
        gy: curr.gy,
        gz: curr.gz,
        yaw: curr.yaw + yawAccumOffset,
        pitch: curr.pitch + pitchAccumOffset,
        roll: curr.roll + rollAccumOffset,
        parallelness: curr.parallelness,
      ));
    }

    if (kDebugMode) {
      debugPrint('🔧 SIDE-BY-SIDE COMPARISON:');
      debugPrint('   Idx | Before Roll  | After Roll   | Before Pitch | After Pitch  | Before Yaw   | After Yaw');
      debugPrint('   ────|──────────────|──────────────|──────────────|──────────────|──────────────|───────────');
      for (int i = 0; i < samples.length; i++) {
        final orig = samples[i];
        final corr = corrected[i];
        debugPrint('   ${i.toString().padLeft(3)} | ${orig.roll.toStringAsFixed(2).padLeft(12)} | ${corr.roll.toStringAsFixed(2).padLeft(12)} | ${orig.pitch.toStringAsFixed(2).padLeft(12)} | ${corr.pitch.toStringAsFixed(2).padLeft(12)} | ${orig.yaw.toStringAsFixed(2).padLeft(12)} | ${corr.yaw.toStringAsFixed(2).padLeft(9)}');
      }
      debugPrint('🔧 Jump correction complete.');
    }

    return corrected;
  }

  /// STEP 4: Average yaw signals from both sensors (preserves originals)
  static List<AnglePoint> averageYawSignals(
    List<ImuSample> left,
    List<ImuSample> right,
  ) {
    if (kDebugMode) {
      debugPrint('');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 STEP 4: AVERAGE YAW SIGNALS');
      debugPrint('🔧 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🔧 Left samples: ${left.length}, Right samples: ${right.length}');
      debugPrint('🔧 NOTE: Original sensor yaws preserved for parallelness calculation');
    }

    final result = <AnglePoint>[];
    final minLength = math.min(left.length, right.length);

    for (int i = 0; i < minLength; i++) {
      final avgYaw = (left[i].yaw + right[i].yaw) / 2.0;
      result.add(AnglePoint(left[i].timestamp, avgYaw));
    }

    if (kDebugMode) {
      debugPrint('🔧 SIDE-BY-SIDE COMPARISON:');
      debugPrint('   Idx | Left Yaw     | Right Yaw    | Avg Yaw');
      debugPrint('   ────|──────────────|──────────────|────────────');
      for (int i = 0; i < result.length; i++) {
        debugPrint('   ${i.toString().padLeft(3)} | ${left[i].yaw.toStringAsFixed(2).padLeft(12)} | ${right[i].yaw.toStringAsFixed(2).padLeft(12)} | ${result[i].angle.toStringAsFixed(2).padLeft(10)}');
      }
      debugPrint('🔧 Averaging complete. Created ${result.length} averaged points.');
    }

    return result;
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
