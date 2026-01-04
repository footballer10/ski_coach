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

  /// Edge Angle: 100·cos(π/90·(x-45))^5
  static double edgeAngle(double degrees) {
    final v = 100.0 * math.pow(math.cos((math.pi / 90.0) * (degrees - 45.0)), 5);
    return v.isFinite ? v.toDouble().clamp(0.0, 100.0) : 0.0;
  }

  /// Parallelness: 100·e^(-((x/37.3)^1.47))
  static double parallel(double value) {
    final v = 100.0 * math.exp(-math.pow(value / 37.3, 1.47));
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
