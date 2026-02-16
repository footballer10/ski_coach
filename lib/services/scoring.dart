import 'dart:math' as math;

/// Scoring utilities for ski metrics
class Scoring {
  /// Turn Duration: 100x if x < 1, 100 if x = 1, 100/x if x > 1
  static double duration(double seconds) {
    if (seconds <= 0) return 0.0;
    if (seconds < 1.0) {
      return (100.0 * seconds).clamp(0.0, 100.0);
    } else {
      return (100.0 / seconds).clamp(0.0, 100.0);
    }
  }

  /// Edge Angle: 100 - 100·e^(-0.00005·x^2.96)
  static double edgeAngle(double degrees) {
    final x = degrees.isFinite ? math.max(0.0, degrees) : 0.0;
    final v = 100.0 - 100.0 * math.exp(-0.00005 * math.pow(x, 2.96));
    return v.isFinite ? v.toDouble().clamp(0.0, 100.0) : 0.0;
  }

  /// Parallelness: 100·e^(-((x/30)^2))
  static double parallel(double value) {
    final v = 100.0 * math.exp(-math.pow(value / 30.0, 2));
    return v.isFinite ? v.toDouble().clamp(0.0, 100.0) : 0.0;
  }

  /// Turn Shape SD: 100·e^(-((x/46.2)^2))
  static double turnShape(double sd) {
    final v = 100.0 * math.exp(-math.pow(sd / 46.2, 2));
    return v.isFinite ? v.toDouble().clamp(0.0, 100.0) : 0.0;
  }

  /// Turn Symmetry: 100/x^2
  static double symmetry(double ratio) {
    if (ratio <= 0) return 0.0;
    final v = 100.0 / math.pow(ratio, 2);
    return v.isFinite ? v.toDouble().clamp(0.0, 100.0) : 0.0;
  }
}
