import 'dart:math' as math;

/// Utilities to segment a recorded IMU run into turns and compute metrics.
///
/// Expects samples to be `List<Map<String,double>>` where each sample contains
/// keys: `ax, ay, az, gx, gy, gz, roll, pitch, yaw` and a timestamp key `t`
/// representing milliseconds since epoch as a double.

class TurnSummary {
  final int startIndex;
  final int endIndex;
  final double startTimeMs;
  final double endTimeMs;
  final double durationSec;
  final int sampleCount;
  final Map<String, double> metrics;

  TurnSummary({
    required this.startIndex,
    required this.endIndex,
    required this.startTimeMs,
    required this.endTimeMs,
    required this.durationSec,
    required this.sampleCount,
    required this.metrics,
  });

  Map<String, dynamic> toJson() => {
        'startIndex': startIndex,
        'endIndex': endIndex,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
        'durationSec': durationSec,
        'sampleCount': sampleCount,
        'metrics': metrics,
      };
}

/// Segment a recording into turns using yaw change rate.
///
/// Simple model: compute yaw derivative (deg/s) and mark samples where
/// abs(yawRate) >= `yawRateThreshold` as in-turn. Contiguous regions are
/// merged; short regions below `minDurationSec` or smaller than
/// `minSamples` are discarded.
List<TurnSummary> segmentTurns(
  List<Map<String, double>> samples, {
  double yawRateThreshold = 20.0, // deg/s
  double minDurationSec = 0.15,
  int minSamples = 5,
}) {
  final n = samples.length;
  if (n < 2) return [];

  // compute yaw rate per interval (ms -> s)
  final yawRates = List<double>.filled(n, 0.0);
  for (var i = 1; i < n; i++) {
    final prev = samples[i - 1];
    final cur = samples[i];
    final t0 = (prev['t'] ?? 0.0);
    final t1 = (cur['t'] ?? 0.0);
    final dt = (t1 - t0) / 1000.0; // s
    if (dt <= 0) {
      yawRates[i] = 0.0;
      continue;
    }
    final y0 = (prev['yaw'] ?? 0.0);
    final y1 = (cur['yaw'] ?? 0.0);
    // handle wrap-around at +-180 degrees
    var dy = y1 - y0;
    if (dy > 180) dy -= 360;
    if (dy < -180) dy += 360;
    yawRates[i] = dy / dt; // deg/s
  }

  // mark in-turn samples
  final inTurn = List<bool>.filled(n, false);
  for (var i = 0; i < n; i++) {
    if (yawRates[i].abs() >= yawRateThreshold) inTurn[i] = true;
  }

  // collect contiguous regions
  final List<TurnSummary> turns = [];
  int? regionStart;
  for (var i = 0; i < n; i++) {
    if (inTurn[i]) {
      regionStart ??= i;
    } else {
      if (regionStart != null) {
        final start = regionStart;
        final end = i - 1;
        final startT = samples[start]['t'] ?? 0.0;
        final endT = samples[end]['t'] ?? 0.0;
        final dur = (endT - startT) / 1000.0;
        final count = end - start + 1;
        if (dur >= minDurationSec && count >= minSamples) {
          final metrics = _computeTurnMetrics(samples, start, end, yawRates);
          turns.add(TurnSummary(
            startIndex: start,
            endIndex: end,
            startTimeMs: startT,
            endTimeMs: endT,
            durationSec: dur,
            sampleCount: count,
            metrics: metrics,
          ));
        }
        regionStart = null;
      }
    }
  }
  // tail region
  if (regionStart != null) {
    final start = regionStart;
    final end = n - 1;
    final startT = samples[start]['t'] ?? 0.0;
    final endT = samples[end]['t'] ?? 0.0;
    final dur = (endT - startT) / 1000.0;
    final count = end - start + 1;
    if (dur >= minDurationSec && count >= minSamples) {
      final metrics = _computeTurnMetrics(samples, start, end, yawRates);
      turns.add(TurnSummary(
        startIndex: start,
        endIndex: end,
        startTimeMs: startT,
        endTimeMs: endT,
        durationSec: dur,
        sampleCount: count,
        metrics: metrics,
      ));
    }
  }

  return turns;
}

Map<String, double> _computeTurnMetrics(List<Map<String, double>> samples, int start, int end, List<double> yawRates) {
  double peakYawRate = 0.0;
  double sumYawRate = 0.0;
  int count = 0;
  double peakLatAccel = 0.0;
  double sumLatAccel = 0.0;

  for (var i = start; i <= end; i++) {
    final yr = yawRates[i].abs();
    peakYawRate = yr > peakYawRate ? yr : peakYawRate;
    sumYawRate += yr;
    final ax = samples[i]['ax'] ?? 0.0;
    final ay = samples[i]['ay'] ?? 0.0;
    final lat = math.sqrt(ax * ax + ay * ay);
    peakLatAccel = lat > peakLatAccel ? lat : peakLatAccel;
    sumLatAccel += lat;
    count++;
  }

  final meanYawRate = count > 0 ? sumYawRate / count : 0.0;
  final meanLatAccel = count > 0 ? sumLatAccel / count : 0.0;

  final startYaw = samples[start]['yaw'] ?? 0.0;
  final endYaw = samples[end]['yaw'] ?? 0.0;
  // compute delta yaw with wrap handling
  var dYaw = endYaw - startYaw;
  if (dYaw > 180) dYaw -= 360;
  if (dYaw < -180) dYaw += 360;

  return {
    'peakYawRate': peakYawRate,
    'meanYawRate': meanYawRate,
    'peakLateralAccel': peakLatAccel,
    'meanLateralAccel': meanLatAccel,
    'deltaYaw': dYaw,
  };
}

/// Compute simple run-level metrics: duration and sampling rate.
Map<String, double> computeRunMetrics(List<Map<String, double>> samples) {
  if (samples.isEmpty) return {'durationSec': 0.0, 'sampleRateHz': 0.0, 'sampleCount': 0.0};
  final start = samples.first['t'] ?? 0.0;
  final end = samples.last['t'] ?? 0.0;
  final dur = (end - start) / 1000.0;
  final count = samples.length;
  final rate = dur > 0 ? count / dur : 0.0;
  return {'durationSec': dur, 'sampleRateHz': rate, 'sampleCount': count.toDouble()};
}
