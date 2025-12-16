/// Data models for ski run analysis
library;

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
    required this.turnSymmetryScore,
    required this.overallScore,
    this.processedLeftSamples,
    this.processedRightSamples,
    this.segments,
  });
}
