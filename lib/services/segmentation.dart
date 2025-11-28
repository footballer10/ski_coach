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
  }) {
    if (kDebugMode) {
      debugPrint('🎿 Segmentation: Processing ${left.length} left samples, ${right.length} right samples');
    }
    
    // Average yaw from both sensors at aligned timestamps
    final avgYaw = _averageYawSignals(left, right);
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

      final startIdxLeft = _nearestIndex(left, a.time);
      final startIdxRight = _nearestIndex(right, a.time);
      final endIdxLeft = _nearestIndex(left, b.time);
      final endIdxRight = _nearestIndex(right, b.time);
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
      for (int i = startIdxLeft; i <= endIdxLeft && i < left.length; i++) {
        maxEdgeAngle = math.max(maxEdgeAngle, left[i].pitch.abs());
      }
      for (int i = startIdxRight; i <= endIdxRight && i < right.length; i++) {
        maxEdgeAngle = math.max(maxEdgeAngle, right[i].pitch.abs());
      }

      final duration = b.time.difference(a.time);
      final yawSwing = _yawSwing(unwrappedYaw, startYawIdx, endYawIdx);
      if (kDebugMode) {
        debugPrint('      ↳ raw yaw between indices [$startYawIdx, $endYawIdx]:');
        for (int idx = startYawIdx; idx <= endYawIdx; idx++) {
          debugPrint('         yaw[$idx] = ${unwrappedYaw[idx].toStringAsFixed(2)} (smoothed=${smoothedYaw[idx].angle.toStringAsFixed(2)}° @ ${smoothedYaw[idx].time.toIso8601String()})');
        }
      }
      
      if (kDebugMode) {
        debugPrint('   ✅ Segment ${k + 1}: accepted (duration=${duration.inMilliseconds}ms, swing=${yawSwing.toStringAsFixed(1)}°, edge=${maxEdgeAngle.toStringAsFixed(1)}°)');
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
      );
      segments.add(seg);
    }
    
      // No rejection summary needed; simple consecutive pairing in use
    
    if (kDebugMode) {
      debugPrint('🎿 Segmentation: Created ${segments.length} turn segments');
      for (int i = 0; i < segments.length; i++) {
        debugPrint('   Turn ${i + 1}: ${segments[i].durationSeconds}s, edge=${segments[i].maxEdgeAngle.toStringAsFixed(1)}° (dir=${segments[i].direction})');
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
