/// Turn segmentation and per-turn metrics.
///
/// Pipeline:
/// - Correct angle jumps (>10°) for both sensors
/// - Average yaw between sensors; unwrap and smooth
/// - Detect alternating max/min yaw peaks (turn points) via hysteresis
/// - Build segments between consecutive peaks
/// - Compute metrics: max edge angle, parallelness (avg + thirds), smoothness SD (thirds)
library;
import '../models/imu_sample.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

class TurnSegment {
  final DateTime startTime;
  final DateTime endTime;
  final int startIndexLeft;
  final int startIndexRight;
  final int endIndexLeft;
  final int endIndexRight;
  final int direction; // -1 left, +1 right
  final double maxEdgeAngle; // maximum absolute pitch during turn (from either sensor)
  final double avgParallelness; // average ski parallelness (degrees difference, calibrated)
  final double beginningParallelness; // average parallelness in first third
  final double middleParallelness; // average parallelness in middle third
  final double endParallelness; // average parallelness in final third
  final double beginningSmoothnessSD; // standard deviation of angular velocity in first third
  final double middleSmoothnessSD; // standard deviation of angular velocity in middle third
  final double endSmoothnessSD; // standard deviation of angular velocity in final third
  final double avgSmoothnessSD; // average of the three smoothness SDs
  double get durationSeconds => endTime.difference(startTime).inMilliseconds / 1000.0;

  TurnSegment({
    required this.startTime,
    required this.endTime,
    required this.startIndexLeft,
    required this.startIndexRight,
    required this.endIndexLeft,
    required this.endIndexRight,
    required this.direction,
    required this.maxEdgeAngle,
    required this.avgParallelness,
    required this.beginningParallelness,
    required this.middleParallelness,
    required this.endParallelness,
    required this.beginningSmoothnessSD,
    required this.middleSmoothnessSD,
    required this.endSmoothnessSD,
    required this.avgSmoothnessSD,
  });
}

class SegmentationParams {
  final double minPeakChangeDeg; // minimum yaw change from valley to peak to count as a turn
  final int smoothingWindow; // number of samples for moving average smoothing

  const SegmentationParams({
    this.minPeakChangeDeg = 10.0, // hysteresis threshold (deg) for switching
    this.smoothingWindow = 5,
  });
}

class TurnSegmentation {
  static List<TurnSegment> segment({
    required List<ImuSample> left,
    required List<ImuSample> right,
    SegmentationParams params = const SegmentationParams(),
    double? yawOffset, // Calibrated offset (right - left) from connection
    double samplingRate = 100.0, // Sampling rate in Hz (default 100Hz)
  }) {
    if (kDebugMode) {
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 ═══════════════════ SEGMENTATION START ══════════════════════');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Input: ${left.length}L/${right.length}R samples');
      debugPrint('📊 Calibrated yaw offset (right - left): ${yawOffset?.toStringAsFixed(2) ?? "null"}°');
      debugPrint('📊 Sampling rate: ${samplingRate}Hz');
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 STEP 1: RAW DATA (First 10 samples from each sensor)');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 LEFT SENSOR:');
      for (int i = 0; i < math.min(10, left.length); i++) {
        debugPrint('   [$i] yaw=${left[i].yaw.toStringAsFixed(2)}°, pitch=${left[i].pitch.toStringAsFixed(2)}°, roll=${left[i].roll.toStringAsFixed(2)}°');
      }
      debugPrint('📊 RIGHT SENSOR:');
      for (int i = 0; i < math.min(10, right.length); i++) {
        debugPrint('   [$i] yaw=${right[i].yaw.toStringAsFixed(2)}°, pitch=${right[i].pitch.toStringAsFixed(2)}°, roll=${right[i].roll.toStringAsFixed(2)}°');
      }
      if (yawOffset != null) {
        debugPrint('');
        debugPrint('📊 Initial yaw difference (right - left) at connection: ${yawOffset.toStringAsFixed(2)}°');
        debugPrint('📊 This offset will be applied to RIGHT sensor yaw values BEFORE any other processing');
      }
    }
    
    // STEP 1: Apply calibration offset to RIGHT sensor's yaw (correct for initial difference)
    final calibratedLeft = left;
    final calibratedRight = yawOffset != null ? _applyYawOffset(right, -yawOffset, 'RIGHT') : right;
    
    // STEP 2: Correct sudden angle jumps (>10°) in all angles for both sensors
    final correctedLeft = _correctAngleJumps(calibratedLeft, 'LEFT');
    final correctedRight = _correctAngleJumps(calibratedRight, 'RIGHT');
    
    // STEP 3: Unwrap individual sensor yaws (handle wraparound before averaging)
    final unwrappedLeft = _unwrapSensorYaw(correctedLeft, 'LEFT');
    final unwrappedRight = _unwrapSensorYaw(correctedRight, 'RIGHT');
    
    // STEP 4: Average unwrapped yaw from both sensors
    final avgYaw = _averageUnwrappedYawSignals(correctedLeft, correctedRight, unwrappedLeft, unwrappedRight);
    
    // STEP 5: Smooth the averaged yaw
    final smoothedYaw = _smoothYaw(avgYaw, params.smoothingWindow);
    
    // STEP 6: Unwrap smoothed yaw for peak detection
    final unwrappedSmoothedYaw = _unwrapYaw(smoothedYaw, 'SMOOTHED');
    
    // STEP 7: Detect yaw peaks (local maxima/minima = turn points)
    final peaks = _detectYawPeaks(smoothedYaw, unwrappedSmoothedYaw, params);

    if (kDebugMode) {
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 STEP 7: TURN SEGMENTATION (Peak Detection)');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Detected ${peaks.length} peaks/valleys (turn boundaries)');
      debugPrint('📊 Hysteresis threshold: ${params.minPeakChangeDeg}°');
      for (int i = 0; i < peaks.length; i++) {
        final p = peaks[i];
        final marker = p.isPeak ? '📈 MAX (Right turn end)' : '📉 MIN (Left turn end)';
        debugPrint('   $marker #${i+1}: idx=${p.index}, yaw=${p.yaw.toStringAsFixed(2)}°, unwrapped=${unwrappedSmoothedYaw[p.index].toStringAsFixed(2)}°');
      }
      debugPrint('📊 Total segments (turns) to create: ${peaks.length - 1}');
    }

    // Build segments from consecutive peaks (alternation is inherent to detector)
    final segments = <TurnSegment>[];
    
    for (int k = 0; k + 1 < peaks.length; k++) {
      final a = peaks[k];
      final b = peaks[k + 1];

      // No explicit alternation check; detector already alternates max/min

      final startIdxLeft = _nearestIndex(correctedLeft, a.time);
      final startIdxRight = _nearestIndex(correctedRight, a.time);
      final endIdxLeft = _nearestIndex(correctedLeft, b.time);
      final endIdxRight = _nearestIndex(correctedRight, b.time);
      final startYawIdx = _indexForTime(smoothedYaw, a.time);
      final endYawIdx = _indexForTime(smoothedYaw, b.time);

      if (startYawIdx == null || endYawIdx == null || startYawIdx >= endYawIdx) {
        if (kDebugMode) {
          debugPrint('   ❌ Turn ${k + 1}: rejected (invalid yaw indices)');
        }
        continue;
      }
      
      if (kDebugMode) {
        debugPrint('');
        debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
        debugPrint('📊 TURN ${k + 1} DETAILED ANALYSIS');
        debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
        debugPrint('📊 Time range: ${a.time.millisecondsSinceEpoch} to ${b.time.millisecondsSinceEpoch}');
        debugPrint('📊 Duration: ${b.time.difference(a.time).inMilliseconds / 1000.0}s');
        debugPrint('📊 Indices: L[$startIdxLeft:$endIdxLeft] R[$startIdxRight:$endIdxRight] Yaw[$startYawIdx:$endYawIdx]');
        debugPrint('📊 Direction: ${b.isPeak ? "RIGHT (1)" : "LEFT (-1)"}');
        debugPrint('📊 Yaw range: ${smoothedYaw[startYawIdx].angle.toStringAsFixed(2)}° → ${smoothedYaw[endYawIdx].angle.toStringAsFixed(2)}°');
        debugPrint('📊 Unwrapped yaw range: ${unwrappedSmoothedYaw[startYawIdx].toStringAsFixed(2)}° → ${unwrappedSmoothedYaw[endYawIdx].toStringAsFixed(2)}°');
      }

      // No approach-time requirement; we simply pair consecutive peaks

      // Find maximum absolute pitch during this turn segment
      double maxEdgeAngle = 0.0;
      int maxEdgeIdx = -1;
      String maxEdgeSensor = '';
      
      if (kDebugMode) {
        debugPrint('');
        debugPrint('📊 ────────────────────────────────────────────────────────────────────────');
        debugPrint('📊 METRIC 1: MAX EDGE ANGLE (Absolute Pitch)');
        debugPrint('📊 ────────────────────────────────────────────────────────────────────────');
      }
      
      for (int i = startIdxLeft; i <= endIdxLeft && i < correctedLeft.length; i++) {
        final pitch = correctedLeft[i].pitch.abs();
        if (kDebugMode && i - startIdxLeft < 3) {
          debugPrint('   L[$i] pitch=${correctedLeft[i].pitch.toStringAsFixed(2)}°, |pitch|=${pitch.toStringAsFixed(2)}°');
        }
        if (pitch > maxEdgeAngle) {
          maxEdgeAngle = pitch;
          maxEdgeIdx = i;
          maxEdgeSensor = 'LEFT';
        }
      }
      for (int i = startIdxRight; i <= endIdxRight && i < correctedRight.length; i++) {
        final pitch = correctedRight[i].pitch.abs();
        if (kDebugMode && i - startIdxRight < 3) {
          debugPrint('   R[$i] pitch=${correctedRight[i].pitch.toStringAsFixed(2)}°, |pitch|=${pitch.toStringAsFixed(2)}°');
        }
        if (pitch > maxEdgeAngle) {
          maxEdgeAngle = pitch;
          maxEdgeIdx = i;
          maxEdgeSensor = 'RIGHT';
        }
      }
      
      if (kDebugMode) {
        debugPrint('   ... (${(endIdxLeft - startIdxLeft + 1) + (endIdxRight - startIdxRight + 1)} total samples checked)');
        debugPrint('   🎯 MAX EDGE ANGLE: ${maxEdgeAngle.toStringAsFixed(2)}° at index [$maxEdgeIdx] ($maxEdgeSensor sensor)');
      }
      
      // Compute ski parallelness: difference in yaw angles (calibration already applied)
      double sumParallelness = 0.0;
      int parallelnessCount = 0;
      
      // Also track parallelness for turn thirds
      double sumBeginning = 0.0, sumMiddle = 0.0, sumEnd = 0.0;
      int countBeginning = 0, countMiddle = 0, countEnd = 0;
      
      final turnDuration = b.time.difference(a.time);
      final thirdDuration = turnDuration ~/ 3;
      final middleStart = a.time.add(thirdDuration);
      final endStart = a.time.add(thirdDuration * 2);
      
      if (kDebugMode) {
        debugPrint('');
        debugPrint('📊 ────────────────────────────────────────────────────────────────────────');
        debugPrint('📊 METRIC 2: PARALLELNESS (Yaw Difference)');
        debugPrint('📊 ────────────────────────────────────────────────────────────────────────');
        debugPrint('📊 Turn thirds: 1st=${thirdDuration.inMilliseconds}ms, Mid=${thirdDuration.inMilliseconds}ms, End=${thirdDuration.inMilliseconds}ms');
        debugPrint('📊 NOTE: Calibration offset already applied to right sensor in STEP 1');
      }
      
      for (int i = 0; i < math.min(correctedLeft.length, correctedRight.length); i++) {
        if (i >= startIdxLeft && i <= endIdxLeft && i >= startIdxRight && i <= endIdxRight) {
          final leftSample = correctedLeft[i];
          final rightSample = correctedRight[i];
          
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
          
          sumParallelness += parallelness;
          parallelnessCount++;
          
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
          
          if (kDebugMode && parallelnessCount <= 5) {
            debugPrint('   [$i] ($third) L_yaw=${leftSample.yaw.toStringAsFixed(2)}°, R_yaw=${rightSample.yaw.toStringAsFixed(2)}°, |diff|=${parallelness.toStringAsFixed(2)}°');
          }
        }
      }
      
      final avgParallelness = parallelnessCount > 0 ? sumParallelness / parallelnessCount : 0.0;
      final beginningParallelness = countBeginning > 0 ? sumBeginning / countBeginning : 0.0;
      final middleParallelness = countMiddle > 0 ? sumMiddle / countMiddle : 0.0;
      final endParallelness = countEnd > 0 ? sumEnd / countEnd : 0.0;
      
      if (kDebugMode) {
        debugPrint('   ... ($parallelnessCount total samples)');
        debugPrint('   📊 WHOLE TURN AVG: ${avgParallelness.toStringAsFixed(2)}°');
        debugPrint('   📊 1st Third (${countBeginning} samples): ${beginningParallelness.toStringAsFixed(2)}°');
        debugPrint('   📊 Mid Third (${countMiddle} samples): ${middleParallelness.toStringAsFixed(2)}°');
        debugPrint('   📊 End Third (${countEnd} samples): ${endParallelness.toStringAsFixed(2)}°');
      }
      
      // Compute smoothness: standard deviation of angular velocity for each third
      // Angular velocity = change in yaw * sampling rate
      final angularVelocitiesBeginning = <double>[];
      final angularVelocitiesMiddle = <double>[];
      final angularVelocitiesEnd = <double>[];
      
      if (kDebugMode) {
        debugPrint('');
        debugPrint('📊 ────────────────────────────────────────────────────────────────────────');
        debugPrint('📊 METRIC 3: SMOOTHNESS (Angular Velocity Standard Deviation)');
        debugPrint('📊 ────────────────────────────────────────────────────────────────────────');
        debugPrint('📊 Angular velocity = Δyaw × sampling_rate (${samplingRate}Hz)');
      }
      
      for (int i = startYawIdx; i < endYawIdx; i++) {
        final yawChange = unwrappedSmoothedYaw[i + 1] - unwrappedSmoothedYaw[i];
        final angularVelocity = yawChange * samplingRate;
        final sampleTime = smoothedYaw[i].time;
        
        String third = '';
        if (sampleTime.isBefore(middleStart)) {
          angularVelocitiesBeginning.add(angularVelocity);
          third = '1st';
        } else if (sampleTime.isBefore(endStart)) {
          angularVelocitiesMiddle.add(angularVelocity);
          third = 'mid';
        } else {
          angularVelocitiesEnd.add(angularVelocity);
          third = 'end';
        }
        
        if (kDebugMode && i - startYawIdx < 5) {
          debugPrint('   [$i] ($third) yawChange=${yawChange.toStringAsFixed(4)}°, angVel=${angularVelocity.toStringAsFixed(2)}°/s');
        }
      }
      
      final beginningSmoothnessSD = _standardDeviation(angularVelocitiesBeginning);
      final middleSmoothnessSD = _standardDeviation(angularVelocitiesMiddle);
      final endSmoothnessSD = _standardDeviation(angularVelocitiesEnd);
      final avgSmoothnessSD = (beginningSmoothnessSD + middleSmoothnessSD + endSmoothnessSD) / 3.0;
      
      if (kDebugMode) {
        debugPrint('   ... (${angularVelocitiesBeginning.length + angularVelocitiesMiddle.length + angularVelocitiesEnd.length} total velocity samples)');
        debugPrint('   📊 WHOLE TURN AVG SD: ${avgSmoothnessSD.toStringAsFixed(2)}°/s');
        debugPrint('   📊 1st Third SD (${angularVelocitiesBeginning.length} samples): ${beginningSmoothnessSD.toStringAsFixed(2)}°/s');
        debugPrint('   📊 Mid Third SD (${angularVelocitiesMiddle.length} samples): ${middleSmoothnessSD.toStringAsFixed(2)}°/s');
        debugPrint('   📊 End Third SD (${angularVelocitiesEnd.length} samples): ${endSmoothnessSD.toStringAsFixed(2)}°/s');
      }

      final seg = TurnSegment(
        startTime: a.time,
        endTime: b.time,
        startIndexLeft: startIdxLeft,
        startIndexRight: startIdxRight,
        endIndexLeft: endIdxLeft,
        endIndexRight: endIdxRight,
        direction: b.isPeak ? 1 : -1, // peak = right turn, valley = left turn
        maxEdgeAngle: maxEdgeAngle,
        avgParallelness: avgParallelness,
        beginningParallelness: beginningParallelness,
        middleParallelness: middleParallelness,
        endParallelness: endParallelness,
        beginningSmoothnessSD: beginningSmoothnessSD,
        middleSmoothnessSD: middleSmoothnessSD,
        endSmoothnessSD: endSmoothnessSD,
        avgSmoothnessSD: avgSmoothnessSD,
      );
      segments.add(seg);
      
      if (kDebugMode) {
        debugPrint('');
        debugPrint('   ✅ TURN ${k + 1} COMPLETE:');
        debugPrint('      Duration: ${seg.durationSeconds.toStringAsFixed(3)}s');
        debugPrint('      Direction: ${seg.direction == 1 ? "RIGHT" : "LEFT"}');
        debugPrint('      Max Edge: ${seg.maxEdgeAngle.toStringAsFixed(2)}°');
        debugPrint('      Parallel: ${seg.avgParallelness.toStringAsFixed(2)}°');
        debugPrint('      Smooth: ${seg.avgSmoothnessSD.toStringAsFixed(2)}°/s');
      }
    }
    
    if (kDebugMode) {
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 ═══════════════════ SEGMENTATION COMPLETE ══════════════════════');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Total turns created: ${segments.length}');
      debugPrint('');
      for (int i = 0; i < segments.length; i++) {
        final s = segments[i];
        debugPrint('   Turn ${i+1}: ${s.durationSeconds.toStringAsFixed(3)}s, ${s.direction == 1 ? "RIGHT" : "LEFT"}, edge=${s.maxEdgeAngle.toStringAsFixed(1)}°, parallel=${s.avgParallelness.toStringAsFixed(1)}°, smooth=${s.avgSmoothnessSD.toStringAsFixed(1)}°/s');
      }
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
    }
    
    return segments;
  }

  /// Unwrap yaw angles from a list of IMU samples
  static List<double> _unwrapSensorYaw(List<ImuSample> samples, [String label = '']) {
    if (samples.isEmpty) return const [];
    
    if (kDebugMode && label.isNotEmpty) {
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 STEP 3: YAW UNWRAPPING ($label sensor)');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Removing wraparound discontinuities (±180° jumps) BEFORE averaging');
      debugPrint('📊 Wrapped yaw (first 10):');
      for (int i = 0; i < math.min(10, samples.length); i++) {
        debugPrint('   [$i] wrapped=${samples[i].yaw.toStringAsFixed(2)}°');
      }
    }
    
    final unwrapped = List<double>.filled(samples.length, 0.0);
    unwrapped[0] = samples[0].yaw;
    for (int i = 1; i < samples.length; i++) {
      final diff = _angleDiff(samples[i].yaw, samples[i - 1].yaw);
      unwrapped[i] = unwrapped[i - 1] + diff;
    }
    
    if (kDebugMode && label.isNotEmpty) {
      debugPrint('📊 Unwrapped yaw (first 10):');
      for (int i = 0; i < math.min(10, unwrapped.length); i++) {
        debugPrint('   [$i] unwrapped=${unwrapped[i].toStringAsFixed(2)}°');
      }
      debugPrint('   ... (${unwrapped.length} total unwrapped samples)');
    }
    
    return unwrapped;
  }

  /// Average unwrapped yaw signals from left and right sensors
  static List<_AnglePoint> _averageUnwrappedYawSignals(
    List<ImuSample> left,
    List<ImuSample> right,
    List<double> unwrappedLeft,
    List<double> unwrappedRight,
  ) {
    final result = <_AnglePoint>[];
    if (left.isEmpty || right.isEmpty) {
      return result;
    }

    final pairCount = math.min(left.length, right.length);
    final droppedLeft = left.length - pairCount;
    final droppedRight = right.length - pairCount;

    for (int k = 0; k < pairCount; k++) {
      final l = left[k];
      final r = right[k];
      // Average the unwrapped values, then wrap back to [-180, 180]
      final avgUnwrapped = (unwrappedLeft[k] + unwrappedRight[k]) / 2.0;
      final wrappedAvg = _wrapAngle(avgUnwrapped);
      final meanMs = ((l.timestamp.millisecondsSinceEpoch + r.timestamp.millisecondsSinceEpoch) / 2).round();
      final isUtc = l.timestamp.isUtc || r.timestamp.isUtc;
      result.add(_AnglePoint(DateTime.fromMillisecondsSinceEpoch(meanMs, isUtc: isUtc), wrappedAvg));
    }

    if (kDebugMode) {
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 STEP 4: YAW AVERAGING (From unwrapped values)');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Paired $pairCount samples (dropped: ${droppedLeft}L/${droppedRight}R)');
      debugPrint('📊 Averaging unwrapped yaw values, then wrapping back to [-180, 180]');
      debugPrint('📊 NOTE: Original individual sensor yaws PRESERVED for parallelness calculation');
      debugPrint('📊 Averaged yaw (first 10):');
      for (int i = 0; i < math.min(10, result.length); i++) {
        if (i < unwrappedLeft.length && i < unwrappedRight.length) {
          debugPrint('   [$i] L_unwrapped=${unwrappedLeft[i].toStringAsFixed(2)}°, R_unwrapped=${unwrappedRight[i].toStringAsFixed(2)}°, Avg=${result[i].angle.toStringAsFixed(2)}°');
        }
      }
    }

    return result;
  }

  static List<_AnglePoint> _averageYawSignals(List<ImuSample> left, List<ImuSample> right) {
    // Pair left/right samples by index order; discard extras when lists differ in length
    final result = <_AnglePoint>[];
    if (left.isEmpty || right.isEmpty) {
      return result;
    }

    final pairCount = math.min(left.length, right.length);
    final droppedLeft = left.length - pairCount;
    final droppedRight = right.length - pairCount;

    for (int k = 0; k < pairCount; k++) {
      final l = left[k];
      final r = right[k];
      final avgYaw = _averageAngles([l.yaw, r.yaw]);
      final meanMs = ((l.timestamp.millisecondsSinceEpoch + r.timestamp.millisecondsSinceEpoch) / 2).round();
      final isUtc = l.timestamp.isUtc || r.timestamp.isUtc;
      result.add(_AnglePoint(DateTime.fromMillisecondsSinceEpoch(meanMs, isUtc: isUtc), avgYaw));
    }

    if (kDebugMode) {
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 STEP 3: YAW AVERAGING (After calibration & jump correction)');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Paired $pairCount samples (dropped: ${droppedLeft}L/${droppedRight}R)');
      debugPrint('📊 Using circular averaging to handle wraparound');
      debugPrint('📊 Averaged yaw (first 10):');
      for (int i = 0; i < math.min(10, result.length); i++) {
        if (i < left.length && i < right.length) {
          debugPrint('   [$i] L=${left[i].yaw.toStringAsFixed(2)}°, R=${right[i].yaw.toStringAsFixed(2)}°, Avg=${result[i].angle.toStringAsFixed(2)}°');
        }
      }
    }

    return result;
  }

  /// Average angles handling wraparound at ±180°
  static double _averageAngles(List<double> angles) {
    if (angles.isEmpty) return 0.0;
    if (angles.length == 1) return angles[0];
    
    // Convert to unit vectors, average, then back to angle
    double sumX = 0.0, sumY = 0.0;
    for (final a in angles) {
      final rad = a * 3.14159265359 / 180.0;
      sumX += math.cos(rad);
      sumY += math.sin(rad);
    }
    final avgRad = math.atan2(sumY / angles.length, sumX / angles.length);
    return avgRad * 180.0 / 3.14159265359;
  }

  static int _nearestIndex(List<ImuSample> xs, DateTime t) {
    int best = 0;
    int lo = 0, hi = xs.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final cmp = xs[mid].timestamp.compareTo(t);
      if (cmp == 0) return mid;
      if (cmp < 0) { lo = mid + 1; best = mid; } else { hi = mid - 1; }
    }
    // refine
    final candidates = [best, (best + 1).clamp(0, xs.length - 1)];
    candidates.sort((a,b) => xs[a].timestamp.difference(t).abs().compareTo(xs[b].timestamp.difference(t).abs()));
    return candidates.first;
  }

  static List<_Peak> _detectYawPeaks(
    List<_AnglePoint> pts,
    List<double> unwrapped,
    SegmentationParams p,
  ) {
    if (pts.length < 2 || pts.length != unwrapped.length) {
      return [];
    }

    final peaks = <_Peak>[];
    final hysteresis = math.max(p.minPeakChangeDeg, 10.0);

    // Decide whether we start by looking for a max or a min based on the first noticeable slope
    bool seekingMax = true;
    for (int i = 1; i < unwrapped.length; i++) {
      final delta = unwrapped[i] - unwrapped[i - 1];
      if (delta.abs() > 0.05) {
        seekingMax = delta > 0;
        break;
      }
    }

    double currentExtreme = unwrapped[0];
    int extremeIdx = 0;

    if (kDebugMode) {
      // Peak detector: hysteresis=${hysteresis.toStringAsFixed(1)}° starting=${seekingMax ? 'MAX' : 'MIN'}
    }

    for (int i = 1; i < unwrapped.length; i++) {
      final value = unwrapped[i];

      if (seekingMax) {
        if (value > currentExtreme) {
          currentExtreme = value;
          extremeIdx = i;
        } else if (currentExtreme - value >= hysteresis) {
          peaks.add(_Peak(
            time: pts[extremeIdx].time,
            yaw: pts[extremeIdx].angle,
            isPeak: true,
            index: extremeIdx,
          ));
          if (kDebugMode) {
            // Commit MAX peak
          }
          seekingMax = false;
          currentExtreme = value;
          extremeIdx = i;
        }
      } else {
        if (value < currentExtreme) {
          currentExtreme = value;
          extremeIdx = i;
        } else if (value - currentExtreme >= hysteresis) {
          peaks.add(_Peak(
            time: pts[extremeIdx].time,
            yaw: pts[extremeIdx].angle,
            isPeak: false,
            index: extremeIdx,
          ));
          if (kDebugMode) {
            // Commit MIN peak
          }
          seekingMax = true;
          currentExtreme = value;
          extremeIdx = i;
        }
      }
    }

    return peaks;
  }

  /// Calculate angular difference handling wraparound: result in range [-180, 180]
  static double _angleDiff(double a, double b) {
    double diff = a - b;
    while (diff > 180) {
      diff -= 360;
    }
    while (diff < -180) {
      diff += 360;
    }
    return diff;
  }

  static double _wrapAngle(double angle) {
    double wrapped = angle;
    while (wrapped > 180) {
      wrapped -= 360;
    }
    while (wrapped <= -180) {
      wrapped += 360;
    }
    return wrapped;
  }

  static List<_AnglePoint> _smoothYaw(
    List<_AnglePoint> pts,
    int window,
  ) {
    if (window <= 1 || pts.length < 3) {
      return pts;
    }
    
    if (kDebugMode) {
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 STEP 5: SMOOTHING (Moving Average)');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Window size: $window samples');
      debugPrint('📊 Unwrapping, smoothing, then wrapping back to [-180, 180]');
    }
    
    // First unwrap the yaw values
    final unwrapped = List<double>.filled(pts.length, 0.0);
    unwrapped[0] = pts[0].angle;
    for (int i = 1; i < pts.length; i++) {
      final diff = _angleDiff(pts[i].angle, pts[i - 1].angle);
      unwrapped[i] = unwrapped[i - 1] + diff;
    }
    
    // Then smooth the unwrapped values
    final half = window ~/ 2;
    final smoothed = <_AnglePoint>[];
    for (int i = 0; i < pts.length; i++) {
      final start = math.max(0, i - half);
      final end = math.min(pts.length - 1, i + half);
      double sum = 0.0;
      int count = 0;
      for (int j = start; j <= end; j++) {
        sum += unwrapped[j];
        count++;
      }
      final avg = count == 0 ? unwrapped[i] : sum / count;
      smoothed.add(_AnglePoint(pts[i].time, _wrapAngle(avg)));
      
      if (kDebugMode && i < 10) {
        debugPrint('   [$i] raw=${pts[i].angle.toStringAsFixed(2)}°, smoothed=${_wrapAngle(avg).toStringAsFixed(2)}°');
      }
    }
    
    if (kDebugMode) {
      debugPrint('   ... (${smoothed.length} total smoothed samples)');
    }
    
    return smoothed;
  }

  static List<double> _unwrapYaw(List<_AnglePoint> pts, [String label = '']) {
    if (pts.isEmpty) {
      return const [];
    }
    
    if (kDebugMode && label.isNotEmpty) {
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 STEP 6: YAW UNWRAPPING ($label)');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Removing wraparound discontinuities (±180° jumps) for peak detection');
      debugPrint('📊 Wrapped yaw (first 10):');
      for (int i = 0; i < math.min(10, pts.length); i++) {
        debugPrint('   [$i] wrapped=${pts[i].angle.toStringAsFixed(2)}°');
      }
    }
    
    final unwrapped = List<double>.filled(pts.length, 0.0);
    unwrapped[0] = pts[0].angle;
    for (int i = 1; i < pts.length; i++) {
      final diff = _angleDiff(pts[i].angle, pts[i - 1].angle);
      unwrapped[i] = unwrapped[i - 1] + diff;
    }
    
    if (kDebugMode && label.isNotEmpty) {
      debugPrint('📊 Unwrapped yaw (first 10):');
      for (int i = 0; i < math.min(10, unwrapped.length); i++) {
        debugPrint('   [$i] unwrapped=${unwrapped[i].toStringAsFixed(2)}°');
      }
      debugPrint('   ... (${unwrapped.length} total unwrapped samples)');
    }
    
    return unwrapped;
  }

  // Approach-time logic removed per simplified design

  static int? _indexForTime(List<_AnglePoint> pts, DateTime time) {
    int lo = 0;
    int hi = pts.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final cmp = pts[mid].time.compareTo(time);
      if (cmp == 0) {
        return mid;
      }
      if (cmp < 0) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    final candidates = <int>[];
    if (lo < pts.length) {
      candidates.add(lo);
    }
    if (hi >= 0) {
      candidates.add(hi);
    }
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) => pts[a].time.difference(time).abs().compareTo(pts[b].time.difference(time).abs()));
    return candidates.first;
  }

  /// Correct sudden angle jumps (>10°) in yaw, pitch, and roll for a sensor
  static List<ImuSample> _correctAngleJumps(List<ImuSample> samples, [String label = '']) {
    if (samples.isEmpty) return samples;
    
    if (kDebugMode && label.isNotEmpty) {
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 STEP 2: ANGLE JUMP CORRECTION ($label)');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Detecting and correcting jumps >10° in yaw, pitch, and roll');
      debugPrint('📊 Input angles (first 10):');
      for (int i = 0; i < math.min(10, samples.length); i++) {
        debugPrint('   [$i] yaw=${samples[i].yaw.toStringAsFixed(2)}°, pitch=${samples[i].pitch.toStringAsFixed(2)}°, roll=${samples[i].roll.toStringAsFixed(2)}°');
      }
    }
    
    final corrected = <ImuSample>[];
    corrected.add(samples[0]);
    
    double yawOffset = 0.0;
    double pitchOffset = 0.0;
    double rollOffset = 0.0;
    
    for (int i = 1; i < samples.length; i++) {
      final prev = samples[i - 1];
      final curr = samples[i];
      
      // Check for jumps in each angle
      final yawDiff = _angleDiff(curr.yaw, prev.yaw);
      final pitchDiff = curr.pitch - prev.pitch;
      final rollDiff = curr.roll - prev.roll;
      
      // If jump > 10°, accumulate offset to undo it
      if (yawDiff.abs() > 10.0) {
        yawOffset += yawDiff;
        if (kDebugMode && label.isNotEmpty) {
          debugPrint('   ⚠️ YAW jump detected at [$i]: ${yawDiff.toStringAsFixed(2)}° (offset now: ${yawOffset.toStringAsFixed(2)}°)');
        }
      }
      if (pitchDiff.abs() > 10.0) {
        pitchOffset += pitchDiff;
        if (kDebugMode && label.isNotEmpty) {
          debugPrint('   ⚠️ PITCH jump detected at [$i]: ${pitchDiff.toStringAsFixed(2)}° (offset now: ${pitchOffset.toStringAsFixed(2)}°)');
        }
      }
      if (rollDiff.abs() > 10.0) {
        rollOffset += rollDiff;
        if (kDebugMode && label.isNotEmpty) {
          debugPrint('   ⚠️ ROLL jump detected at [$i]: ${rollDiff.toStringAsFixed(2)}° (offset now: ${rollOffset.toStringAsFixed(2)}°)');
        }
      }
      
      // Apply accumulated offsets
      corrected.add(ImuSample(
        timestamp: curr.timestamp,
        ax: curr.ax,
        ay: curr.ay,
        az: curr.az,
        gx: curr.gx,
        gy: curr.gy,
        gz: curr.gz,
        yaw: _wrapAngle(curr.yaw - yawOffset),
        pitch: curr.pitch - pitchOffset,
        roll: curr.roll - rollOffset,
      ));
    }
    
    if (kDebugMode && label.isNotEmpty) {
      debugPrint('📊 Total accumulated offsets: yaw=${yawOffset.toStringAsFixed(2)}°, pitch=${pitchOffset.toStringAsFixed(2)}°, roll=${rollOffset.toStringAsFixed(2)}°');
      debugPrint('📊 Corrected angles (first 10):');
      for (int i = 0; i < math.min(10, corrected.length); i++) {
        debugPrint('   [$i] yaw=${corrected[i].yaw.toStringAsFixed(2)}°, pitch=${corrected[i].pitch.toStringAsFixed(2)}°, roll=${corrected[i].roll.toStringAsFixed(2)}°');
      }
      debugPrint('   ... (${corrected.length} total corrected samples)');
    }
    
    return corrected;
  }
  
  /// Apply calibration offset to yaw values
  static List<ImuSample> _applyYawOffset(List<ImuSample> samples, double offset, [String label = '']) {
    if (samples.isEmpty) return samples;
    
    if (kDebugMode && label.isNotEmpty) {
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 STEP 1B: APPLY CALIBRATION OFFSET ($label)');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Applying offset: ${offset.toStringAsFixed(2)}° to yaw values');
      debugPrint('📊 This corrects for initial difference detected at connection');
      debugPrint('📊 Before/After (first 10):');
      for (int i = 0; i < math.min(10, samples.length); i++) {
        final newYaw = _wrapAngle(samples[i].yaw + offset);
        debugPrint('   [$i] before=${samples[i].yaw.toStringAsFixed(2)}°, after=${newYaw.toStringAsFixed(2)}°');
      }
    }
    
    return samples.map((s) => ImuSample(
      timestamp: s.timestamp,
      ax: s.ax, ay: s.ay, az: s.az,
      gx: s.gx, gy: s.gy, gz: s.gz,
      yaw: _wrapAngle(s.yaw + offset),
      pitch: s.pitch,
      roll: s.roll,
      parallelness: s.parallelness,
    )).toList();
  }
  
  /// Calculate standard deviation of a list of values
  static double _standardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    if (values.length == 1) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => math.pow(v - mean, 2)).toList();
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance);
  }
}

// _ApproachCheck removed per simplified design

class _AnglePoint {
  final DateTime time;
  final double angle;
  _AnglePoint(this.time, this.angle);
}

class _Peak {
  final DateTime time;
  final double yaw;
  final bool isPeak; // true = local max (right turn), false = local min (left turn)
  final int index;
  _Peak({required this.time, required this.yaw, required this.isPeak, required this.index});
}
