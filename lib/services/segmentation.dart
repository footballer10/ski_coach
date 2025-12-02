/// Turn segmentation and per-turn metrics.
///
/// Pipeline:
/// - Correct angle jumps (>10°) for both sensors
/// - Average yaw between sensors; unwrap and smooth
/// - Detect alternating max/min yaw peaks (turn points) via hysteresis
/// - Build segments between consecutive peaks
/// - Compute metrics: max edge angle, parallelness (avg + thirds), smoothness SD (thirds)
library segmentation;
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
      debugPrint('🎿 Segmentation: Processing ${left.length} left samples, ${right.length} right samples');
    }
    
    // Correct sudden angle jumps (>10°) in all angles for both sensors
    final correctedLeft = _correctAngleJumps(left);
    final correctedRight = _correctAngleJumps(right);
    
    // Average yaw from both sensors at aligned timestamps
    final avgYaw = _averageYawSignals(correctedLeft, correctedRight);
    final unwrappedAvgYaw = _unwrapYaw(avgYaw);
    final smoothedYaw = _smoothYaw(avgYaw, unwrappedAvgYaw, params.smoothingWindow);
    final unwrappedYaw = _unwrapYaw(smoothedYaw);
    
    if (kDebugMode) {
      debugPrint('🎿 Segmentation: Created ${avgYaw.length} averaged yaw points');
      for (int i = 0; i < avgYaw.length; i++) {
        final pt = avgYaw[i];
        debugPrint('      avgYaw[$i] @ ${pt.time.toIso8601String()} = ${pt.angle.toStringAsFixed(2)}°');
      }
      for (int i = 0; i < smoothedYaw.length; i++) {
        final pt = smoothedYaw[i];
        debugPrint('      smoothYaw[$i] @ ${pt.time.toIso8601String()} = ${pt.angle.toStringAsFixed(2)}°');
      }
    }
    
    // Detect yaw peaks (local maxima/minima = turn points)
    final peaks = _detectYawPeaks(smoothedYaw, unwrappedYaw, params);

    if (kDebugMode) {
      debugPrint('🎿 Segmentation: Detected ${peaks.length} yaw peaks (turn points)');
      for (int i = 0; i < peaks.length; i++) {
        final p = peaks[i];
        debugPrint('      peak[$i] -> time=${p.time.toIso8601String()}, yaw=${p.yaw.toStringAsFixed(2)}°, type=${p.isPeak ? 'MAX' : 'MIN'}');
      }
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
          debugPrint('   ❌ Segment ${k + 1}: rejected (invalid yaw indices)');
        }
        continue;
      }

      // No approach-time requirement; we simply pair consecutive peaks

      // Find maximum absolute pitch during this turn segment
      double maxEdgeAngle = 0.0;
      for (int i = startIdxLeft; i <= endIdxLeft && i < correctedLeft.length; i++) {
        maxEdgeAngle = math.max(maxEdgeAngle, correctedLeft[i].pitch.abs());
      }
      for (int i = startIdxRight; i <= endIdxRight && i < correctedRight.length; i++) {
        maxEdgeAngle = math.max(maxEdgeAngle, correctedRight[i].pitch.abs());
      }
      
      // Compute ski parallelness: difference in yaw angles accounting for calibration
      double sumParallelness = 0.0;
      int parallelnessCount = 0;
      final calibratedOffset = yawOffset ?? 0.0;
      
      // Also track parallelness for turn thirds
      double sumBeginning = 0.0, sumMiddle = 0.0, sumEnd = 0.0;
      int countBeginning = 0, countMiddle = 0, countEnd = 0;
      
      final turnDuration = b.time.difference(a.time);
      final thirdDuration = turnDuration ~/ 3;
      final middleStart = a.time.add(thirdDuration);
      final endStart = a.time.add(thirdDuration * 2);
      
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
            // Fallback: compute from yaw values
            final actualDiff = rightSample.yaw - leftSample.yaw;
            parallelness = (actualDiff - calibratedOffset).abs();
          }
          
          sumParallelness += parallelness;
          parallelnessCount++;
          
          // Determine which third this sample belongs to
          final sampleTime = leftSample.timestamp;
          if (sampleTime.isBefore(middleStart)) {
            sumBeginning += parallelness;
            countBeginning++;
          } else if (sampleTime.isBefore(endStart)) {
            sumMiddle += parallelness;
            countMiddle++;
          } else {
            sumEnd += parallelness;
            countEnd++;
          }
        }
      }
      
      final avgParallelness = parallelnessCount > 0 ? sumParallelness / parallelnessCount : 0.0;
      final beginningParallelness = countBeginning > 0 ? sumBeginning / countBeginning : 0.0;
      final middleParallelness = countMiddle > 0 ? sumMiddle / countMiddle : 0.0;
      final endParallelness = countEnd > 0 ? sumEnd / countEnd : 0.0;
      
      // Compute smoothness: standard deviation of angular velocity for each third
      // Angular velocity = change in yaw * sampling rate
      final angularVelocitiesBeginning = <double>[];
      final angularVelocitiesMiddle = <double>[];
      final angularVelocitiesEnd = <double>[];
      
      for (int i = startYawIdx; i < endYawIdx; i++) {
        final yawChange = unwrappedYaw[i + 1] - unwrappedYaw[i];
        final angularVelocity = yawChange * samplingRate;
        final sampleTime = smoothedYaw[i].time;
        
        if (sampleTime.isBefore(middleStart)) {
          angularVelocitiesBeginning.add(angularVelocity);
        } else if (sampleTime.isBefore(endStart)) {
          angularVelocitiesMiddle.add(angularVelocity);
        } else {
          angularVelocitiesEnd.add(angularVelocity);
        }
      }
      
      final beginningSmoothnessSD = _standardDeviation(angularVelocitiesBeginning);
      final middleSmoothnessSD = _standardDeviation(angularVelocitiesMiddle);
      final endSmoothnessSD = _standardDeviation(angularVelocitiesEnd);
      final avgSmoothnessSD = (beginningSmoothnessSD + middleSmoothnessSD + endSmoothnessSD) / 3.0;

      final duration = b.time.difference(a.time);
      final yawSwing = _yawSwing(unwrappedYaw, startYawIdx, endYawIdx);
      if (kDebugMode) {
        debugPrint('      ↳ raw yaw between indices [$startYawIdx, $endYawIdx]:');
        for (int idx = startYawIdx; idx <= endYawIdx; idx++) {
          debugPrint('         yaw[$idx] = ${unwrappedYaw[idx].toStringAsFixed(2)} (smoothed=${smoothedYaw[idx].angle.toStringAsFixed(2)}° @ ${smoothedYaw[idx].time.toIso8601String()})');
        }
      }
      
      if (kDebugMode) {
        debugPrint('   ✅ Segment ${k + 1}: accepted (duration=${duration.inMilliseconds}ms, swing=${yawSwing.toStringAsFixed(1)}°, edge=${maxEdgeAngle.toStringAsFixed(1)}°, parallel=[beg:${beginningParallelness.toStringAsFixed(1)}° mid:${middleParallelness.toStringAsFixed(1)}° end:${endParallelness.toStringAsFixed(1)}°])');
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
    }
    
      // No rejection summary needed; simple consecutive pairing in use
    
    if (kDebugMode) {
      debugPrint('🎿 Segmentation: Created ${segments.length} turn segments');
      for (int i = 0; i < segments.length; i++) {
        debugPrint('   Turn ${i + 1}: ${segments[i].durationSeconds}s, edge=${segments[i].maxEdgeAngle.toStringAsFixed(1)}°, parallel=[avg:${segments[i].avgParallelness.toStringAsFixed(1)}° beg:${segments[i].beginningParallelness.toStringAsFixed(1)}° mid:${segments[i].middleParallelness.toStringAsFixed(1)}° end:${segments[i].endParallelness.toStringAsFixed(1)}°] (dir=${segments[i].direction})');
      }
    }
    
    return segments;
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

    if (kDebugMode && (droppedLeft > 0 || droppedRight > 0)) {
      debugPrint('🎯 Segmentation: index pairing dropped extras left=$droppedLeft right=$droppedRight');
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
      debugPrint('      peak-detector: hysteresis=${hysteresis.toStringAsFixed(1)}° starting=${seekingMax ? 'MAX' : 'MIN'}');
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
            debugPrint('         ↳ commit MAX idx=$extremeIdx yaw=${pts[extremeIdx].angle.toStringAsFixed(2)}°');
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
            debugPrint('         ↳ commit MIN idx=$extremeIdx yaw=${pts[extremeIdx].angle.toStringAsFixed(2)}°');
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
    List<double> unwrapped,
    int window,
  ) {
    if (window <= 1 || pts.length < 3 || pts.length != unwrapped.length) {
      return pts;
    }
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
    }
    return smoothed;
  }

  static List<double> _unwrapYaw(List<_AnglePoint> pts) {
    if (pts.isEmpty) {
      return const [];
    }
    final unwrapped = List<double>.filled(pts.length, 0.0);
    unwrapped[0] = pts[0].angle;
    for (int i = 1; i < pts.length; i++) {
      final diff = _angleDiff(pts[i].angle, pts[i - 1].angle);
      unwrapped[i] = unwrapped[i - 1] + diff;
    }
    return unwrapped;
  }

  static double _yawSwing(List<double> unwrappedYaw, int startIdx, int endIdx) {
    if (unwrappedYaw.isEmpty || startIdx >= endIdx) {
      return 0.0;
    }
    final slice = unwrappedYaw.sublist(startIdx, endIdx + 1);
    double minVal = slice.first;
    double maxVal = slice.first;
    for (final val in slice) {
      if (val < minVal) {
        minVal = val;
      }
      if (val > maxVal) {
        maxVal = val;
      }
    }
    return maxVal - minVal;
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
  static List<ImuSample> _correctAngleJumps(List<ImuSample> samples) {
    if (samples.isEmpty) return samples;
    
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
      }
      if (pitchDiff.abs() > 10.0) {
        pitchOffset += pitchDiff;
      }
      if (rollDiff.abs() > 10.0) {
        rollOffset += rollDiff;
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
    
    if (kDebugMode) {
      if (yawOffset.abs() > 0.1 || pitchOffset.abs() > 0.1 || rollOffset.abs() > 0.1) {
        debugPrint('      angle-jump correction: yaw offset=${yawOffset.toStringAsFixed(2)}°, pitch offset=${pitchOffset.toStringAsFixed(2)}°, roll offset=${rollOffset.toStringAsFixed(2)}°');
      }
    }
    
    return corrected;
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
