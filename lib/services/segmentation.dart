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
  int get durationSeconds => endTime.difference(startTime).inSeconds;

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
  final double zeroBandDeg; // hysteresis band around 0
  final Duration minGapBetweenCrossings; // debounce crossings
  final Duration maxPairDelta; // max delta to pair L/R crossings
  final Duration minTurnDuration;
  final Duration maxTurnDuration;

  const SegmentationParams({
    this.zeroBandDeg = 3.0,
    this.minGapBetweenCrossings = const Duration(milliseconds: 700),
    this.maxPairDelta = const Duration(milliseconds: 300),
    this.minTurnDuration = const Duration(milliseconds: 800),
    this.maxTurnDuration = const Duration(seconds: 4),
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

    // Pair crossings; never miss a turn if apart: use earliest as boundary and nearest on other side if within window; else still create turn with single-sensor crossing
    final paired = <_Boundary>[];
    int i = 0, j = 0;
    while (i < leftCross.length || j < rightCross.length) {
      final lc = i < leftCross.length ? leftCross[i] : null;
      final rc = j < rightCross.length ? rightCross[j] : null;

      if (lc == null && rc == null) break;
      if (lc != null && rc == null) {
        paired.add(_Boundary(lc.time, lc.dir, lc.index, null, null, null));
        i++;
        continue;
      }
      if (rc != null && lc == null) {
        paired.add(_Boundary(rc.time, rc.dir, null, rc.index, null, null));
        j++;
        continue;
      }

      // both available
      final delta = (lc!.time.difference(rc!.time)).abs();
      if (delta <= params.maxPairDelta) {
        // pair
        final t = lc.time.isBefore(rc.time) ? lc.time : rc.time;
        paired.add(_Boundary(t, lc.dir, lc.index, rc.index, null, null));
        i++; j++;
      } else {
        // Not within window: still create boundary from earlier and leave other for next
        if (lc.time.isBefore(rc.time)) {
          paired.add(_Boundary(lc.time, lc.dir, lc.index, null, null, null));
          i++;
        } else {
          paired.add(_Boundary(rc.time, rc.dir, null, rc.index, null, null));
          j++;
        }
      }
    }

    // Build segments from consecutive boundaries enforcing min/max duration and alternating direction
    final segments = <TurnSegment>[];
    for (int k = 0; k + 1 < paired.length; k++) {
      final a = paired[k];
      final b = paired[k + 1];
      final dur = b.time.difference(a.time);
      if (dur < params.minTurnDuration || dur > params.maxTurnDuration) continue;
      // ensure alternation
      if (a.dir == b.dir) continue;

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
    final out = <_Crossing>[];
    DateTime lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    int lastSign = 0; // -1, 0, +1
    bool inBand = true;
    for (int i = 0; i < pts.length; i++) {
      final v = pts[i].angle;
      final t = pts[i].time;
      final sign = v > p.zeroBandDeg ? 1 : (v < -p.zeroBandDeg ? -1 : 0);

      // hysteresis: only consider leaving band when beyond thresholds
      if (sign == 0) {
        inBand = true;
        continue;
      }
      if (inBand) {
        // first sample leaving band defines the sign state
        inBand = false;
        lastSign = sign;
        continue;
      }
      // detect sign change when previously opposite and we're beyond band
      if (lastSign != 0 && sign != lastSign) {
        // debounce on time
        if (t.difference(lastEmit) >= p.minGapBetweenCrossings) {
          out.add(_Crossing(time: t, dir: sign, index: i));
          lastEmit = t;
          lastSign = sign;
        } else {
          // too soon, ignore bounce
          lastSign = sign; // update state but don't emit
        }
      } else {
        lastSign = sign;
      }
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
