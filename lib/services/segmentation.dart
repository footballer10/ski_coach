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
  final Duration minGapBetweenPeaks; // debounce rapid oscillations
  final double minTurnAmplitudeDeg; // yaw swing required across a full turn segment
  final double minEdgeAngleDeg; // optional guard using max pitch during the segment
  final Duration minSegmentDuration; // ensure turns last long enough to be real
  final int smoothingWindow; // number of samples for moving average smoothing

  const SegmentationParams({
    this.minPeakChangeDeg = 22.0, // require ~22° swing between valley & peak to count
    this.minGapBetweenPeaks = const Duration(milliseconds: 325), // slightly longer debounce
    this.minTurnAmplitudeDeg = 35.0,
    this.minEdgeAngleDeg = 0.0,
    this.minSegmentDuration = const Duration(milliseconds: 850),
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
    final smoothedYaw = _smoothYaw(avgYaw, params.smoothingWindow);
    final unwrappedYaw = _unwrapYaw(smoothedYaw);
    
    if (kDebugMode) {
      debugPrint('🎿 Segmentation: Created ${avgYaw.length} averaged yaw points');
    }
    
    // Detect yaw peaks (local maxima/minima = turn points)
    final peaks = _detectYawPeaks(smoothedYaw, params);

    if (kDebugMode) {
      debugPrint('🎿 Segmentation: Detected ${peaks.length} yaw peaks (turn points)');
    }

    // Build segments from consecutive peaks
    final segments = <TurnSegment>[];
    for (int k = 0; k + 1 < peaks.length; k++) {
      final a = peaks[k];
      final b = peaks[k + 1];

      final startIdxLeft = _nearestIndex(left, a.time);
      final startIdxRight = _nearestIndex(right, a.time);
      final endIdxLeft = _nearestIndex(left, b.time);
      final endIdxRight = _nearestIndex(right, b.time);
      final startYawIdx = _indexForTime(smoothedYaw, a.time);
      final endYawIdx = _indexForTime(smoothedYaw, b.time);

      if (startYawIdx == null || endYawIdx == null) {
        continue;
      }

      if (startYawIdx >= endYawIdx) {
        continue;
      }

      if (b.time.difference(a.time) < params.minSegmentDuration) {
        continue;
      }

      // Find maximum absolute pitch during this turn segment
      double maxEdgeAngle = 0.0;
      for (int i = startIdxLeft; i <= endIdxLeft && i < left.length; i++) {
        maxEdgeAngle = math.max(maxEdgeAngle, left[i].pitch.abs());
      }
      for (int i = startIdxRight; i <= endIdxRight && i < right.length; i++) {
        maxEdgeAngle = math.max(maxEdgeAngle, right[i].pitch.abs());
      }

      if (params.minEdgeAngleDeg > 0 && maxEdgeAngle < params.minEdgeAngleDeg) {
        continue;
      }

      final yawSwing = _yawSwing(unwrappedYaw, startYawIdx, endYawIdx);
      if (yawSwing < params.minTurnAmplitudeDeg) {
        continue;
      }

      final isRightTurn = b.isPeak;
      if (!_isMonotonicTurn(unwrappedYaw, startYawIdx, endYawIdx, expectIncreasing: isRightTurn)) {
        continue;
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
    
    if (kDebugMode) {
      debugPrint('🎿 Segmentation: Created ${segments.length} turn segments');
      for (int i = 0; i < segments.length; i++) {
        debugPrint('   Turn ${i + 1}: ${segments[i].durationSeconds}s, edge=${segments[i].maxEdgeAngle.toStringAsFixed(1)}° (dir=${segments[i].direction})');
      }
    }
    
    return segments;
  }

  static List<_AnglePoint> _averageYawSignals(List<ImuSample> left, List<ImuSample> right) {
    // Merge and average yaw from both sensors at all timestamps
    // Handle yaw wraparound: -180° to +180°
    final Map<int, List<double>> yawByTime = {};
    
    // Collect all yaw values by timestamp (milliseconds since epoch)
    for (final s in left) {
      final key = s.timestamp.millisecondsSinceEpoch;
      yawByTime.putIfAbsent(key, () => []).add(s.yaw);
    }
    for (final s in right) {
      final key = s.timestamp.millisecondsSinceEpoch;
      yawByTime.putIfAbsent(key, () => []).add(s.yaw);
    }
    
    // Average yaw values at each timestamp, handling wraparound
    final result = <_AnglePoint>[];
    final sortedKeys = yawByTime.keys.toList()..sort();
    for (final ms in sortedKeys) {
      final values = yawByTime[ms]!;
      final avg = _averageAngles(values);
      result.add(_AnglePoint(DateTime.fromMillisecondsSinceEpoch(ms), avg));
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

  static List<_Peak> _detectYawPeaks(List<_AnglePoint> pts, SegmentationParams p) {
    // Detect local maxima and minima in yaw signal
    // A peak is a local maximum (right turn), valley is local minimum (left turn)
    if (pts.length < 3) return [];
    
    final peaks = <_Peak>[];
    DateTime? lastPeakTime;
    
    const prominenceWindow = 20; // samples to inspect on each side for prominence
    for (int i = 1; i < pts.length - 1; i++) {
      final prev = pts[i - 1].angle;
      final curr = pts[i].angle;
      final next = pts[i + 1].angle;
      final t = pts[i].time;
      
      // Handle wraparound when comparing angles
      final diffPrev = _angleDiff(curr, prev);
      final diffNext = _angleDiff(next, curr);
      
      bool isLocalMax = diffPrev > 0 && diffNext < 0;
      bool isLocalMin = diffPrev < 0 && diffNext > 0;
      
      if (isLocalMax || isLocalMin) {
        final leftSwing = _swingMagnitude(pts, i, prominenceWindow, toLeft: true);
        final rightSwing = _swingMagnitude(pts, i, prominenceWindow, toLeft: false);
        final prominence = (leftSwing == 0 || rightSwing == 0)
            ? math.max(leftSwing, rightSwing)
            : math.min(leftSwing, rightSwing);

        if (prominence < p.minPeakChangeDeg) {
          continue; // not enough yaw change on both sides, treat as noise
        }
        
        // Debounce
        if (lastPeakTime != null && t.difference(lastPeakTime) < p.minGapBetweenPeaks) {
          continue;
        }
        
        peaks.add(_Peak(time: t, yaw: curr, isPeak: isLocalMax, index: i));
        lastPeakTime = t;
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

  static double _swingMagnitude(
    List<_AnglePoint> pts,
    int center,
    int window, {
    required bool toLeft,
  }) {
    if (pts.isEmpty) return 0;
    final base = pts[center].angle;
    double swing = 0.0;
    int steps = 0;
    int j = toLeft ? center - 1 : center + 1;
    while (j >= 0 && j < pts.length && steps < window) {
      swing = math.max(swing, _angleDiff(base, pts[j].angle).abs());
      steps++;
      j += toLeft ? -1 : 1;
    }
    return swing;
  }

  static List<_AnglePoint> _smoothYaw(List<_AnglePoint> pts, int window) {
    if (window <= 1 || pts.length < 3) {
      return pts;
    }
    final half = window ~/ 2;
    final smoothed = <_AnglePoint>[];
    for (int i = 0; i < pts.length; i++) {
      final start = math.max(0, i - half);
      final end = math.min(pts.length - 1, i + half);
      final angles = <double>[];
      for (int j = start; j <= end; j++) {
        angles.add(pts[j].angle);
      }
      final avg = _averageAngles(angles);
      smoothed.add(_AnglePoint(pts[i].time, avg));
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

  static bool _isMonotonicTurn(
    List<double> unwrappedYaw,
    int startIdx,
    int endIdx, {
    required bool expectIncreasing,
    double maxBacktrackDeg = 6.0,
    double maxViolationRatio = 0.25,
  }) {
    if (unwrappedYaw.isEmpty || startIdx >= endIdx) {
      return false;
    }
    double prev = unwrappedYaw[startIdx];
    int violations = 0;
    int total = 0;
    for (int i = startIdx + 1; i <= endIdx; i++) {
      final delta = unwrappedYaw[i] - prev;
      prev = unwrappedYaw[i];
      if (delta.abs() < 0.5) {
        continue; // ignore tiny jitter
      }
      total++;
      if (expectIncreasing) {
        if (delta < -maxBacktrackDeg) {
          violations++;
        }
      } else {
        if (delta > maxBacktrackDeg) {
          violations++;
        }
      }
      if (violations > total * maxViolationRatio) {
        return false;
      }
    }
    return total > 0;
  }

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
