import '../models/imu_sample.dart';
import 'package:flutter/foundation.dart';

class TurnSegment {
  final DateTime startTime;
  final DateTime endTime;
  final int startIndexLeft;
  final int startIndexRight;
  final int endIndexLeft;
  final int endIndexRight;
  final int direction; // -1 left, +1 right
  double get durationSeconds => endTime.difference(startTime).inMilliseconds / 1000.0;

  TurnSegment({
    required this.startTime,
    required this.endTime,
    required this.startIndexLeft,
    required this.startIndexRight,
    required this.endIndexLeft,
    required this.endIndexRight,
    required this.direction,
  });
}

class SegmentationParams {
  final double zeroBandDeg; // hysteresis band around 0 to avoid noise
  final Duration minGapBetweenCrossings; // debounce rapid oscillations during transitions
  final Duration maxPairDelta; // max delta to pair L/R crossings

  const SegmentationParams({
    this.zeroBandDeg = 0.5, // tighter band; every real zero crossing counts
    this.minGapBetweenCrossings = const Duration(milliseconds: 150), // debounce only jitter
    this.maxPairDelta = const Duration(milliseconds: 500),
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
    
    // Use pitch (lean left/right) for turn detection due to sensor orientation
    final leftCross = _detectCrossings(left.map((s) => _AnglePoint(s.timestamp, s.pitch)).toList(), params);
    final rightCross = _detectCrossings(right.map((s) => _AnglePoint(s.timestamp, s.pitch)).toList(), params);

    if (kDebugMode) {
      debugPrint('🎿 Segmentation: Detected ${leftCross.length} left crossings, ${rightCross.length} right crossings');
    }

    // Pair crossings: always match left and right, use average timestamp
    // This prevents thinking there are two separate crossings when timing differs
    final paired = <_Boundary>[];
    final maxCount = leftCross.length > rightCross.length ? leftCross.length : rightCross.length;
    
    for (int i = 0; i < maxCount; i++) {
      final lc = i < leftCross.length ? leftCross[i] : null;
      final rc = i < rightCross.length ? rightCross[i] : null;

      if (lc != null && rc != null) {
        // Both sensors have crossing: average their timestamps
        final avgMillis = (lc.time.millisecondsSinceEpoch + rc.time.millisecondsSinceEpoch) ~/ 2;
        final avgTime = DateTime.fromMillisecondsSinceEpoch(avgMillis);
        paired.add(_Boundary(avgTime, lc.dir, lc.index, rc.index, null, null));
      } else if (lc != null) {
        // Only left sensor
        paired.add(_Boundary(lc.time, lc.dir, lc.index, null, null, null));
      } else if (rc != null) {
        // Only right sensor
        paired.add(_Boundary(rc.time, rc.dir, null, rc.index, null, null));
      }
    }

    // Build segments from consecutive boundaries.
    // Start from first crossing, end at last crossing.
    final segments = <TurnSegment>[];
    for (int k = 0; k + 1 < paired.length; k++) {
      final a = paired[k];
      final b = paired[k + 1];

      final seg = TurnSegment(
        startTime: a.time,
        endTime: b.time,
        startIndexLeft: a.leftIndex ?? _nearestIndex(left, a.time),
        startIndexRight: a.rightIndex ?? _nearestIndex(right, a.time),
        endIndexLeft: b.leftIndex ?? _nearestIndex(left, b.time),
        endIndexRight: b.rightIndex ?? _nearestIndex(right, b.time),
        direction: b.dir, // direction of entering next turn
      );
      segments.add(seg);
    }
    
    if (kDebugMode) {
      debugPrint('🎿 Segmentation: Created ${segments.length} turn segments');
      for (int i = 0; i < segments.length; i++) {
        debugPrint('   Turn ${i + 1}: ${segments[i].durationSeconds}s (dir=${segments[i].direction})');
      }
    }
    
    return segments;
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

  static List<_Crossing> _detectCrossings(List<_AnglePoint> pts, SegmentationParams p) {
    // Simple zero-crossing detector: emit crossing whenever pitch crosses through zero
    // with hysteresis to avoid noise, debounced to filter rapid oscillations.
    final out = <_Crossing>[];
    DateTime lastBoundaryTime = DateTime.fromMillisecondsSinceEpoch(0);
    int prevSign = 0; // -1, 0, +1
    
    for (int i = 0; i < pts.length; i++) {
      final v = pts[i].angle;
      final t = pts[i].time;
      // Determine current sign with hysteresis band
      int currentSign;
      if (v > p.zeroBandDeg) {
        currentSign = 1;
      } else if (v < -p.zeroBandDeg) {
        currentSign = -1;
      } else {
        // In dead band; keep previous sign
        currentSign = prevSign;
      }

      // Detect sign flip (crossing zero)
      if (prevSign != 0 && currentSign != 0 && currentSign != prevSign) {
        // Zero crossing detected; debounce
        if (t.difference(lastBoundaryTime) >= p.minGapBetweenCrossings) {
          out.add(_Crossing(time: t, dir: currentSign, index: i));
          lastBoundaryTime = t;
        }
      }

      prevSign = currentSign;
    }
    return out;
  }
}

class _AnglePoint {
  final DateTime time;
  final double angle;
  _AnglePoint(this.time, this.angle);
}

class _Crossing {
  final DateTime time;
  final int dir; // -1 left, +1 right
  final int index;
  _Crossing({required this.time, required this.dir, required this.index});
}

class _Boundary {
  final DateTime time;
  final int dir;
  final int? leftIndex;
  final int? rightIndex;
  final int? leftEnd;
  final int? rightEnd;
  _Boundary(this.time, this.dir, this.leftIndex, this.rightIndex, this.leftEnd, this.rightEnd);
}
