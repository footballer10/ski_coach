/// Turn segmentation - peak/valley detection for turn boundaries.
library;

import '../models.dart';
import 'imu_preprocessor.dart';
import 'metrics/edge_angle_calculator.dart';
import 'metrics/parallelness_calculator.dart';
import 'metrics/turn_shape_calculator.dart';
import 'metrics/duration_calculator.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

/// Turn segment with boundaries and calculated metrics
class TurnSegment {
  final DateTime startTime;
  final DateTime endTime;
  final int startIndexLeft;
  final int startIndexRight;
  final int endIndexLeft;
  final int endIndexRight;
  final int direction; // -1 left, +1 right
  final double maxEdgeAngle;
  final double avgParallelness;
  final double beginningParallelness;
  final double middleParallelness;
  final double endParallelness;
  final double beginningTurnShapeSD;
  final double middleTurnShapeSD;
  final double endTurnShapeSD;
  final double avgTurnShapeSD;
  final double durationSeconds;

  TurnSegment({
    required this.startTime,
    required this.endTime,
    required this.startIndexLeft,
    required this.startIndexRight,
    required this.endIndexLeft,
    required this.endIndexRight,
    required this.direction,
    required this.maxEdgeAngle,
    required this.avgParallelness,
    required this.beginningParallelness,
    required this.middleParallelness,
    required this.endParallelness,
    required this.beginningTurnShapeSD,
    required this.middleTurnShapeSD,
    required this.endTurnShapeSD,
    required this.avgTurnShapeSD,
    required this.durationSeconds,
  });
}

/// Segmentation parameters
class SegmentationParams {
  final double minPeakChangeDeg;

  SegmentationParams({
    this.minPeakChangeDeg = 15.0,
  });
}

/// Peak or valley in yaw signal
class _Peak {
  final DateTime time;
  final double yaw;
  final bool isPeak;
  final int index;

  _Peak({
    required this.time,
    required this.yaw,
    required this.isPeak,
    required this.index,
  });
}

/// Main turn segmentation class
class TurnSegmentation {
  /// Segment ski run into individual turns with metrics
  static List<TurnSegment> segment({
    required List<ImuSample> leftSamples,
    required List<ImuSample> rightSamples,
    required double yawOffset,
    required double samplingRate,
    SegmentationParams? params,
  }) {
    params ??= SegmentationParams();

    if (kDebugMode) {
      debugPrint('');
      debugPrint('🎿 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🎿 ═══════════════ TURN SEGMENTATION PIPELINE START ════════════════');
      debugPrint('🎿 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🎿 Left samples: ${leftSamples.length}, Right samples: ${rightSamples.length}');
      debugPrint('🎿 Yaw offset: ${yawOffset.toStringAsFixed(2)}°, Sampling rate: ${samplingRate}Hz');
      debugPrint('🎿 Min peak change: ${params.minPeakChangeDeg}°');
    }

    // STEP 1: Unwrap angles (removes ±180° wraparound)
    final unwrappedLeft = ImuPreprocessor.unwrapAngles(leftSamples, 'LEFT');
    final unwrappedRight = ImuPreprocessor.unwrapAngles(rightSamples, 'RIGHT');

    // STEP 2: Correct angle jumps for both sensors
    final correctedLeft = ImuPreprocessor.correctAngleJumps(unwrappedLeft, 'LEFT');
    final correctedRight = ImuPreprocessor.correctAngleJumps(unwrappedRight, 'RIGHT');

    // STEP 3: Apply calibration offset to RIGHT sensor yaw only
    final correctedRightYaw = ImuPreprocessor.applyYawOffset(
      correctedRight,
      yawOffset,
      'RIGHT',
    );

    // STEP 4: Average yaw signals
    final avgYaw = ImuPreprocessor.averageYawSignals(
      correctedLeft,
      correctedRightYaw,
    );

    // STEP 5: Detect peaks and valleys (turn boundaries)
    final peaks = _detectYawPeaks(avgYaw, params);

    if (kDebugMode) {
      debugPrint('');
      debugPrint('🎯 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🎯 STEP 5: PEAK DETECTION RESULTS');
      debugPrint('🎯 ════════════════════════════════════════════════════════════════════════');
      debugPrint('🎯 Found ${peaks.length} peaks/valleys');
      for (int i = 0; i < peaks.length; i++) {
        final p = peaks[i];
        debugPrint('   [${i + 1}] ${p.isPeak ? "PEAK (right)" : "VALLEY (left)"} at ${p.time}, yaw=${p.yaw.toStringAsFixed(2)}°, idx=${p.index}');
      }
    }

    // STEP 6: Build turn segments between consecutive peaks
    final segments = <TurnSegment>[];

    for (int k = 0; k < peaks.length - 1; k++) {
      final a = peaks[k];
      final b = peaks[k + 1];

      if (kDebugMode) {
        debugPrint('');
        debugPrint('🔄 ════════════════════════════════════════════════════════════════════════');
        debugPrint('🔄 PROCESSING TURN ${k + 1} (between peaks ${k + 1} and ${k + 2})');
        debugPrint('🔄 ════════════════════════════════════════════════════════════════════════');
        debugPrint('🔄 Start: ${a.time} (${a.isPeak ? "peak" : "valley"})');
        debugPrint('🔄 End: ${b.time} (${b.isPeak ? "peak" : "valley"})');
      }

      // Find nearest sample indices for this turn
      final startIdxLeft = ImuPreprocessor.nearestIndex(correctedLeft, a.time);
      final endIdxLeft = ImuPreprocessor.nearestIndex(correctedLeft, b.time);
      final startIdxRight = ImuPreprocessor.nearestIndex(correctedRightYaw, a.time);
      final endIdxRight = ImuPreprocessor.nearestIndex(correctedRightYaw, b.time);

      // METRIC 1: Calculate max edge angle
      final maxEdgeAngle = EdgeAngleCalculator.calculateMaxEdgeAngle(
        leftSamples: correctedLeft,
        rightSamples: correctedRightYaw,
        startIdxLeft: startIdxLeft,
        endIdxLeft: endIdxLeft,
        startIdxRight: startIdxRight,
        endIdxRight: endIdxRight,
        turnNumber: k + 1,
      );

      // METRIC 2: Calculate parallelness
      final parallelnessResult = ParallelnessCalculator.calculate(
        leftSamples: correctedLeft,
        rightSamples: correctedRightYaw,
        startIdxLeft: startIdxLeft,
        endIdxLeft: endIdxLeft,
        startIdxRight: startIdxRight,
        endIdxRight: endIdxRight,
        startTime: a.time,
        endTime: b.time,
        turnNumber: k + 1,
      );

      // METRIC 3: Calculate turn shape
      final turnShapeResult = TurnShapeCalculator.calculate(
        avgYaw: avgYaw,
        startTime: a.time,
        endTime: b.time,
        samplingRate: samplingRate,
        turnNumber: k + 1,
      );

      // METRIC 4: Calculate duration
      final duration = DurationCalculator.calculate(
        startTime: a.time,
        endTime: b.time,
        turnNumber: k + 1,
      );

      // Create turn segment
      final seg = TurnSegment(
        startTime: a.time,
        endTime: b.time,
        startIndexLeft: startIdxLeft,
        startIndexRight: startIdxRight,
        endIndexLeft: endIdxLeft,
        endIndexRight: endIdxRight,
        direction: b.isPeak ? 1 : -1,
        maxEdgeAngle: maxEdgeAngle,
        avgParallelness: parallelnessResult.average,
        beginningParallelness: parallelnessResult.beginning,
        middleParallelness: parallelnessResult.middle,
        endParallelness: parallelnessResult.end,
        beginningTurnShapeSD: turnShapeResult.beginning,
        middleTurnShapeSD: turnShapeResult.middle,
        endTurnShapeSD: turnShapeResult.end,
        avgTurnShapeSD: turnShapeResult.average,
        durationSeconds: duration,
      );

      segments.add(seg);

      if (kDebugMode) {
        debugPrint('');
        debugPrint('✅ ════════════════════════════════════════════════════════════════════════');
        debugPrint('✅ TURN ${k + 1} SEGMENT CREATED');
        debugPrint('✅ ════════════════════════════════════════════════════════════════════════');
        debugPrint('   Duration: ${seg.durationSeconds.toStringAsFixed(3)}s (${seg.startTime} → ${seg.endTime})');
        debugPrint('   Direction: ${seg.direction == 1 ? "RIGHT (peak)" : "LEFT (valley)"}');
        debugPrint('   Sample indices (L): $startIdxLeft → $endIdxLeft');
        debugPrint('   Sample indices (R): $startIdxRight → $endIdxRight');
        debugPrint('   METRICS:');
        debugPrint('      • Max Edge Angle: ${seg.maxEdgeAngle.toStringAsFixed(2)}°');
        debugPrint('      • Avg Parallelness: ${seg.avgParallelness.toStringAsFixed(2)}° (1st=${seg.beginningParallelness.toStringAsFixed(2)}°, mid=${seg.middleParallelness.toStringAsFixed(2)}°, end=${seg.endParallelness.toStringAsFixed(2)}°)');
        debugPrint('      • Avg Turn Shape SD: ${seg.avgTurnShapeSD.toStringAsFixed(2)}°/s (1st=${seg.beginningTurnShapeSD.toStringAsFixed(2)}°/s, mid=${seg.middleTurnShapeSD.toStringAsFixed(2)}°/s, end=${seg.endTurnShapeSD.toStringAsFixed(2)}°/s)');
      }
    }

    if (kDebugMode) {
      debugPrint('');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 ═══════════════════ SEGMENTATION COMPLETE ══════════════════════');
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
      debugPrint('📊 Total turns created: ${segments.length}');
      debugPrint('');
      for (int i = 0; i < segments.length; i++) {
        final s = segments[i];
        debugPrint('   Turn ${i + 1}: ${s.durationSeconds.toStringAsFixed(3)}s, ${s.direction == 1 ? "RIGHT" : "LEFT"}, edge=${s.maxEdgeAngle.toStringAsFixed(1)}°, parallel=${s.avgParallelness.toStringAsFixed(1)}°');
      }
      debugPrint('📊 ════════════════════════════════════════════════════════════════════════');
    }

    return segments;
  }

  /// Detect peaks and valleys in yaw signal using hysteresis
  static List<_Peak> _detectYawPeaks(
    List<AnglePoint> pts,
    SegmentationParams params,
  ) {
    if (pts.length < 2) {
      return [];
    }

    final peaks = <_Peak>[];
    final hysteresis = math.max(params.minPeakChangeDeg, 10.0);

    // Decide whether we start by looking for a max or a min
    bool seekingMax = true;
    for (int i = 1; i < pts.length; i++) {
      final delta = pts[i].angle - pts[i - 1].angle;
      if (delta.abs() > 0.05) {
        seekingMax = delta > 0;
        break;
      }
    }

    double currentExtreme = pts[0].angle;
    int extremeIdx = 0;

    if (kDebugMode) {
      debugPrint('🎯 Hysteresis: ${hysteresis.toStringAsFixed(1)}°, Starting mode: ${seekingMax ? "seeking MAX" : "seeking MIN"}');
    }

    for (int i = 1; i < pts.length; i++) {
      final value = pts[i].angle;

      if (seekingMax) {
        if (value > currentExtreme) {
          currentExtreme = value;
          extremeIdx = i;
        } else if (currentExtreme - value >= hysteresis) {
          peaks.add(_Peak(
            time: pts[extremeIdx].time,
            yaw: pts[extremeIdx].angle,
            isPeak: true,
            index: extremeIdx,
          ));
          seekingMax = false;
          currentExtreme = value;
          extremeIdx = i;
        }
      } else {
        if (value < currentExtreme) {
          currentExtreme = value;
          extremeIdx = i;
        } else if (value - currentExtreme >= hysteresis) {
          peaks.add(_Peak(
            time: pts[extremeIdx].time,
            yaw: pts[extremeIdx].angle,
            isPeak: false,
            index: extremeIdx,
          ));
          seekingMax = true;
          currentExtreme = value;
          extremeIdx = i;
        }
      }
    }

    return peaks;
  }
}
