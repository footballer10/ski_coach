/// Calculate turn symmetry metrics from turn durations.
library;

import 'package:flutter/foundation.dart';

class SymmetryResult {
  final double?
  ratio; // bigger / smaller average duration (or null if can't calculate)
  final int leftCount;
  final int rightCount;
  final double? leftAverage;
  final double? rightAverage;

  SymmetryResult({
    required this.ratio,
    required this.leftCount,
    required this.rightCount,
    required this.leftAverage,
    required this.rightAverage,
  });
}

class SymmetryCalculator {
  /// Calculate turn symmetry ratio from turn durations
  ///
  /// Returns the ratio of (longer average) / (shorter average) for left vs right turns.
  /// A ratio of 1.0 = perfect symmetry, higher values = more asymmetric.
  static SymmetryResult calculate({
    required List<double> turnDurations,
    required List<int> turnDirections,
  }) {
    if (kDebugMode) {
      debugPrint('');
      debugPrint(
        '⚖️  ════════════════════════════════════════════════════════════════════════',
      );
      debugPrint('⚖️  METRIC: TURN SYMMETRY');
      debugPrint(
        '⚖️  ════════════════════════════════════════════════════════════════════════',
      );
      debugPrint('⚖️  Total turns: ${turnDurations.length}');
    }

    final leftDurations = <double>[];
    final rightDurations = <double>[];

    for (
      int i = 0;
      i < turnDirections.length && i < turnDurations.length;
      i++
    ) {
      if (turnDirections[i] == -1) {
        leftDurations.add(turnDurations[i]);
      } else if (turnDirections[i] == 1) {
        rightDurations.add(turnDurations[i]);
      }
    }

    if (kDebugMode) {
      debugPrint('⚖️  Left turns: ${leftDurations.length}');
      for (int i = 0; i < leftDurations.length; i++) {
        debugPrint('     L[${i + 1}]: ${leftDurations[i].toStringAsFixed(3)}s');
      }
      debugPrint('⚖️  Right turns: ${rightDurations.length}');
      for (int i = 0; i < rightDurations.length; i++) {
        debugPrint(
          '     R[${i + 1}]: ${rightDurations[i].toStringAsFixed(3)}s',
        );
      }
    }

    double? leftAvg;
    double? rightAvg;
    double? ratio;

    if (leftDurations.isNotEmpty && rightDurations.isNotEmpty) {
      leftAvg = leftDurations.reduce((a, b) => a + b) / leftDurations.length;
      rightAvg = rightDurations.reduce((a, b) => a + b) / rightDurations.length;

      final bigger = leftAvg > rightAvg ? leftAvg : rightAvg;
      final smaller = leftAvg > rightAvg ? rightAvg : leftAvg;
      ratio = bigger / smaller;

      if (!ratio.isFinite || ratio <= 0) {
        ratio = null;
      }

      if (kDebugMode) {
        debugPrint('⚖️  RESULTS:');
        debugPrint('     Left average: ${leftAvg.toStringAsFixed(3)}s');
        debugPrint('     Right average: ${rightAvg.toStringAsFixed(3)}s');
        debugPrint(
          '     Symmetry ratio: ${ratio?.toStringAsFixed(3) ?? "N/A"}',
        );
        debugPrint('     (1.0 = perfect, higher = more asymmetric)');
      }
    } else {
      if (kDebugMode) {
        debugPrint(
          '⚖️  Cannot calculate symmetry: need both left and right turns',
        );
      }
    }

    return SymmetryResult(
      ratio: ratio,
      leftCount: leftDurations.length,
      rightCount: rightDurations.length,
      leftAverage: leftAvg,
      rightAverage: rightAvg,
    );
  }
}
