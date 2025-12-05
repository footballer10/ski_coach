import 'dart:math' as math;

/// Scoring utilities for ski metrics
class Scoring {
  /// Turn Duration: 100 · 0.1205^((ln(x / 2))^2)
  static double duration(double seconds) {
    if (seconds <= 0) return 0.0;
    final v = 100.0 * (math.pow(0.1205, math.pow(math.log(seconds / 2.0), 2)) as double);
    return v.isFinite ? v.toDouble() : 0.0;
  }

  /// Edge Angle: 102.552 · (0.99818^((x - 45)^2)) - 2.552
  static double edgeAngle(double degrees) {
    final v = 102.552 * math.pow(0.99818, math.pow(degrees - 45.0, 2)) - 2.552;
    return v.isFinite ? v.toDouble().clamp(0.0, 100.0) : 0.0;
  }

  /// Parallelness: 100 · 0.9923^(x^1.623)
  static double parallel(double value) {
    final v = 100.0 * math.pow(0.9923, math.pow(value, 1.623));
    return v.isFinite ? v.toDouble().clamp(0.0, 100.0) : 0.0;
  }

  /// Turn Shape SD: 100 · 0.998946^(x^2)
  static double turnShape(double sd) {
    final v = 100.0 * math.pow(0.998946, math.pow(sd, 2));
    return v.isFinite ? v.toDouble().clamp(0.0, 100.0) : 0.0;
  }

  /// Turn Symmetry: 100 · 0.028^(ln(ratio))
  static double symmetry(double ratio) {
    if (ratio <= 0) return 0.0;
    final v = 100.0 * math.pow(0.028, math.log(ratio));
    return v.isFinite ? v.toDouble().clamp(0.0, 100.0) : 0.0;
  }
}
