/// Data models for ski run analysis
library;

import 'dart:convert';

/// IMU sensor sample with accelerometer, gyroscope, and orientation data
class ImuSample {
  final DateTime timestamp;
  final double ax, ay, az;
  final double gx, gy, gz;
  final double roll, pitch, yaw;
  final double? parallelness;

  ImuSample({
    required this.timestamp,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.roll,
    required this.pitch,
    required this.yaw,
    this.parallelness,
  });

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.millisecondsSinceEpoch,
    'ax': ax,
    'ay': ay,
    'az': az,
    'gx': gx,
    'gy': gy,
    'gz': gz,
    'roll': roll,
    'pitch': pitch,
    'yaw': yaw,
    if (parallelness != null) 'parallelness': parallelness,
  };

  factory ImuSample.fromMap(Map<String, dynamic> map) => ImuSample(
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    ax: (map['ax'] as num).toDouble(),
    ay: (map['ay'] as num).toDouble(),
    az: (map['az'] as num).toDouble(),
    gx: (map['gx'] as num).toDouble(),
    gy: (map['gy'] as num).toDouble(),
    gz: (map['gz'] as num).toDouble(),
    roll: (map['roll'] as num).toDouble(),
    pitch: (map['pitch'] as num).toDouble(),
    yaw: (map['yaw'] as num).toDouble(),
    parallelness: map['parallelness'] != null
        ? (map['parallelness'] as num).toDouble()
        : null,
  );

  Map<String, dynamic> toJson() => toMap();
  factory ImuSample.fromJson(Map<String, dynamic> json) =>
      ImuSample.fromMap(json);
}

/// Complete analysis results for a ski run
class AnalysisResults {
  final int leftSampleCount;
  final int rightSampleCount;
  final List<List<int>> leftSegments;
  final List<List<int>> rightSegments;
  final int runDurationSeconds;
  final DateTime? runStartTime;

  final int turnCount;
  final List<double> turnDurationsSeconds;
  final List<double> edgeAngles;
  final List<int> turnDirections;
  final List<double> parallelBeginning;
  final List<double> parallelMiddle;
  final List<double> parallelEnd;
  final List<double> parallelAvg;
  final List<double> turnShapeBeginning;
  final List<double> turnShapeMiddle;
  final List<double> turnShapeEnd;
  final List<double> turnShapeAvg;
  final List<double> turnScores;

  final double? turnSymmetryRatio;
  final String? turnSymmetryBiggerSide; // 'L' or 'R'
  final double? turnSymmetryScore;
  final double? overallScore;

  final List? processedLeftSamples;
  final List? processedRightSamples;
  final List? segments;

  const AnalysisResults({
    required this.leftSampleCount,
    required this.rightSampleCount,
    required this.leftSegments,
    required this.rightSegments,
    required this.runDurationSeconds,
    required this.runStartTime,
    required this.turnCount,
    required this.turnDurationsSeconds,
    required this.edgeAngles,
    required this.turnDirections,
    required this.parallelBeginning,
    required this.parallelMiddle,
    required this.parallelEnd,
    required this.parallelAvg,
    required this.turnShapeBeginning,
    required this.turnShapeMiddle,
    required this.turnShapeEnd,
    required this.turnShapeAvg,
    required this.turnScores,
    required this.turnSymmetryRatio,
    required this.turnSymmetryBiggerSide,
    required this.turnSymmetryScore,
    required this.overallScore,
    this.processedLeftSamples,
    this.processedRightSamples,
    this.segments,
  });

  Map<String, dynamic> toJson() => {
    'runStartTime': runStartTime?.toIso8601String(),
    'runDurationSeconds': runDurationSeconds,
    'turnCount': turnCount,
    'turnDirections': turnDirections,
    'overallScore': overallScore,
    'turnSymmetryScore': turnSymmetryScore,
    'turnSymmetryRatio': turnSymmetryRatio,
    'turnSymmetryBiggerSide': turnSymmetryBiggerSide,
    'turnDurationsSeconds': turnDurationsSeconds,
    'edgeAngles': edgeAngles,
    'parallelAvg': parallelAvg,
    'parallelBeginning': parallelBeginning,
    'parallelMiddle': parallelMiddle,
    'parallelEnd': parallelEnd,
    'turnShapeAvg': turnShapeAvg,
    'turnShapeBeginning': turnShapeBeginning,
    'turnShapeMiddle': turnShapeMiddle,
    'turnShapeEnd': turnShapeEnd,
    'turnScores': turnScores,
    'processedLeftSamples': processedLeftSamples
        ?.map((s) => s is ImuSample ? s.toJson() : s)
        .toList(),
    'processedRightSamples': processedRightSamples
        ?.map((s) => s is ImuSample ? s.toJson() : s)
        .toList(),
    'segments': segments
        ?.map((s) {
          if (s == null) return null;
          // If segments are already serialized (e.g., from an imported run),
          // preserve them so exports keep the data needed to rebuild graphs.
          if (s is Map) {
            try {
              return Map<String, dynamic>.from(s);
            } catch (_) {
              return null;
            }
          }
          try {
            return (s as dynamic).toJson();
          } catch (e) {
            return null;
          }
        })
        .where((s) => s != null)
        .toList(),
  };

  factory AnalysisResults.fromJson(Map<String, dynamic> json) =>
      AnalysisResults(
        leftSampleCount: 0,
        rightSampleCount: 0,
        leftSegments: [],
        rightSegments: [],
        runDurationSeconds: json['runDurationSeconds'] as int,
        runStartTime: json['runStartTime'] != null
            ? DateTime.parse(json['runStartTime'] as String)
            : null,
        turnCount: json['turnCount'] as int,
        turnDurationsSeconds: (json['turnDurationsSeconds'] as List)
            .cast<double>(),
        edgeAngles: (json['edgeAngles'] as List).cast<double>(),
        turnDirections: (json['turnDirections'] as List).cast<int>(),
        parallelBeginning: (json['parallelBeginning'] as List).cast<double>(),
        parallelMiddle: (json['parallelMiddle'] as List).cast<double>(),
        parallelEnd: (json['parallelEnd'] as List).cast<double>(),
        parallelAvg: (json['parallelAvg'] as List).cast<double>(),
        turnShapeBeginning: (json['turnShapeBeginning'] as List).cast<double>(),
        turnShapeMiddle: (json['turnShapeMiddle'] as List).cast<double>(),
        turnShapeEnd: (json['turnShapeEnd'] as List).cast<double>(),
        turnShapeAvg: (json['turnShapeAvg'] as List).cast<double>(),
        turnScores: (json['turnScores'] as List).cast<double>(),
        turnSymmetryRatio: json['turnSymmetryRatio'] as double?,
        turnSymmetryBiggerSide: json['turnSymmetryBiggerSide'] as String?,
        turnSymmetryScore: json['turnSymmetryScore'] as double?,
        overallScore: json['overallScore'] as double?,
        processedLeftSamples: json['processedLeftSamples'] != null
            ? (json['processedLeftSamples'] as List)
                  .map((s) => ImuSample.fromJson(s))
                  .toList()
            : null,
        processedRightSamples: json['processedRightSamples'] != null
            ? (json['processedRightSamples'] as List)
                  .map((s) => ImuSample.fromJson(s))
                  .toList()
            : null,
        segments: json['segments'] as List?,
      );

  AnalysisResults sliceTurns({
    required int startTurn1Based,
    required int endTurn1Based,
  }) {
    if (turnCount <= 0) return this;

    final start = startTurn1Based.clamp(1, turnCount);
    final end = endTurn1Based.clamp(start, turnCount);

    final startIndex = start - 1;
    final endExclusive = end;

    List<T> sliceList<T>(List<T> list) {
      if (startIndex >= list.length) return <T>[];
      final effectiveEnd = endExclusive.clamp(0, list.length);
      if (effectiveEnd <= startIndex) return <T>[];
      return list.sublist(startIndex, effectiveEnd);
    }

    final slicedDurations = sliceList<double>(turnDurationsSeconds);
    final slicedDurationSeconds = slicedDurations.isNotEmpty
        ? slicedDurations.reduce((a, b) => a + b).round()
        : 0;

    DateTime? slicedStartTime = runStartTime;
    if (segments is List && (segments as List).isNotEmpty) {
      final segs = segments as List;
      if (startIndex >= 0 && startIndex < segs.length) {
        final firstSeg = segs[startIndex];
        if (firstSeg is Map) {
          final raw = firstSeg['startTime'] ??
              firstSeg['start_time'] ??
              firstSeg['timestamp'] ??
              firstSeg['startTimestamp'] ??
              firstSeg['start_timestamp'];
          if (raw is String) {
            try {
              slicedStartTime = DateTime.parse(raw);
            } catch (_) {
              // Ignore parse errors; keep existing runStartTime
            }
          } else if (raw is int) {
            try {
              slicedStartTime = DateTime.fromMillisecondsSinceEpoch(raw);
            } catch (_) {
              // Ignore invalid epoch; keep existing runStartTime
            }
          }
        }
      }
    }

    return AnalysisResults(
      leftSampleCount: leftSampleCount,
      rightSampleCount: rightSampleCount,
      leftSegments: leftSegments,
      rightSegments: rightSegments,
      runDurationSeconds: slicedDurationSeconds,
      runStartTime: slicedStartTime,
      turnCount: (end - start + 1),
      turnDurationsSeconds: slicedDurations,
      edgeAngles: sliceList<double>(edgeAngles),
      turnDirections: sliceList<int>(turnDirections),
      parallelBeginning: sliceList<double>(parallelBeginning),
      parallelMiddle: sliceList<double>(parallelMiddle),
      parallelEnd: sliceList<double>(parallelEnd),
      parallelAvg: sliceList<double>(parallelAvg),
      turnShapeBeginning: sliceList<double>(turnShapeBeginning),
      turnShapeMiddle: sliceList<double>(turnShapeMiddle),
      turnShapeEnd: sliceList<double>(turnShapeEnd),
      turnShapeAvg: sliceList<double>(turnShapeAvg),
      turnScores: sliceList<double>(turnScores),
      // Recompute symmetry/overall on display/import; clear stored values.
      turnSymmetryRatio: null,
      turnSymmetryBiggerSide: null,
      turnSymmetryScore: null,
      overallScore: null,
      processedLeftSamples: processedLeftSamples,
      processedRightSamples: processedRightSamples,
      segments: segments is List ? sliceList(segments as List) : segments,
    );
  }
}

/// Exported run data for sharing/importing
class ExportedRun {
  final int schemaVersion;
  final String turnRange;
  final String runName;
  final AnalysisResults analysisResults;
  final String? aiFeedback;

  const ExportedRun({
    required this.schemaVersion,
    this.turnRange = '',
    required this.runName,
    required this.analysisResults,
    this.aiFeedback,
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'turnRange': turnRange,
    'runName': runName,
    'analysisResults': analysisResults.toJson(),
    if (aiFeedback != null) 'aiFeedback': aiFeedback,
  };

  factory ExportedRun.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw FormatException(
        'Unsupported schema version: ${json['schemaVersion']}',
      );
    }

    final rawTurnRange = json['turnRange'];
    final parsedTurnRange = rawTurnRange is String ? rawTurnRange : '';

    return ExportedRun(
      schemaVersion: json['schemaVersion'] as int,
      turnRange: parsedTurnRange,
      runName: json['runName'] as String,
      analysisResults: AnalysisResults.fromJson(json['analysisResults']),
      aiFeedback: json['aiFeedback'] as String?,
    );
  }

  /// If [turnRange] is filled (e.g. "5-17"), returns a new [ExportedRun]
  /// whose [analysisResults] include only that turn subset.
  ///
  /// Invalid/blank ranges are ignored.
  ExportedRun applyTurnRangeIfPresent() {
    final range = _tryParseTurnRange(turnRange);
    if (range == null) return this;

    final start = range[0];
    final end = range[1];
    final sliced = analysisResults.sliceTurns(
      startTurn1Based: start,
      endTurn1Based: end,
    );

    return ExportedRun(
      schemaVersion: schemaVersion,
      turnRange: turnRange,
      runName: runName,
      analysisResults: sliced,
      aiFeedback: aiFeedback,
    );
  }

  static List<int>? _tryParseTurnRange(String? value) {
    if (value == null) return null;
    final v = value.trim();
    if (v.isEmpty) return null;

    final match = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(v);
    if (match == null) return null;

    final start = int.tryParse(match.group(1)!);
    final end = int.tryParse(match.group(2)!);
    if (start == null || end == null) return null;
    if (start <= 0 || end <= 0) return null;

    return start <= end ? <int>[start, end] : <int>[end, start];
  }

  String toJsonString() => jsonEncode(toJson());

  static ExportedRun fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return ExportedRun.fromJson(json);
  }
}
