/// Calculate turn duration metrics.
library;

import 'package:flutter/foundation.dart';

class DurationCalculator {
  /// Calculate turn duration in seconds
  static double calculate({
    required DateTime startTime,
    required DateTime endTime,
    required int turnNumber,
  }) {
    final duration = endTime.difference(startTime).inMilliseconds / 1000.0;

    if (kDebugMode) {
      debugPrint('');
      debugPrint(
        '⏱️  ════════════════════════════════════════════════════════════════════════',
      );
      debugPrint('⏱️  METRIC: TURN DURATION');
      debugPrint(
        '⏱️  ════════════════════════════════════════════════════════════════════════',
      );
      debugPrint('⏱️  Turn #$turnNumber');
      debugPrint('⏱️  Start: $startTime');
      debugPrint('⏱️  End: $endTime');
      debugPrint(
        '⏱️  Duration: ${duration.toStringAsFixed(3)}s (${endTime.difference(startTime).inMilliseconds}ms)',
      );
    }

    return duration;
  }
}
