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
    
    // Average pitch from both sensors at aligned timestamps
    final avgPitch = _averagePitchSignals(left, right);
    
    if (kDebugMode) {
      debugPrint('🎿 Segmentation: Created ${avgPitch.length} averaged pitch points');
    }
    
    // Detect crossings on the averaged pitch signal
    final crossings = _detectCrossings(avgPitch, params);

    if (kDebugMode) {
      debugPrint('🎿 Segmentation: Detected ${crossings.length} zero crossings');
    }

    // Build segments from consecutive crossings.
    // Start from first crossing, end at last crossing.
    final segments = <TurnSegment>[];
    for (int k = 0; k + 1 < crossings.length; k++) {
      final a = crossings[k];
      final b = crossings[k + 1];

      final seg = TurnSegment(
        startTime: a.time,
        endTime: b.time,
        startIndexLeft: _nearestIndex(left, a.time),
        startIndexRight: _nearestIndex(right, a.time),
        endIndexLeft: _nearestIndex(left, b.time),
        endIndexRight: _nearestIndex(right, b.time),
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

  static List<_AnglePoint> _averagePitchSignals(List<ImuSample> left, List<ImuSample> right) {
    // Merge and average pitch from both sensors at all timestamps
    final Map<int, List<double>> pitchByTime = {};
    
    // Collect all pitch values by timestamp (milliseconds since epoch)
    for (final s in left) {
      final key = s.timestamp.millisecondsSinceEpoch;
      pitchByTime.putIfAbsent(key, () => []).add(s.pitch);
    }
    for (final s in right) {
      final key = s.timestamp.millisecondsSinceEpoch;
      pitchByTime.putIfAbsent(key, () => []).add(s.pitch);
    }
    
    // Average pitch values at each timestamp and create AnglePoints
    final result = <_AnglePoint>[];
    final sortedKeys = pitchByTime.keys.toList()..sort();
    for (final ms in sortedKeys) {
      final values = pitchByTime[ms]!;
      final avg = values.reduce((a, b) => a + b) / values.length;
      result.add(_AnglePoint(DateTime.fromMillisecondsSinceEpoch(ms), avg));
    }
    
    return result;
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
