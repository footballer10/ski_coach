class AnalysisResults {
  final int leftSampleCount;
  final int rightSampleCount;
  final List<List<int>> leftSegments;
  final List<List<int>> rightSegments;
  final int runDurationSeconds;
  final DateTime? runStartTime;

  // Per-turn arrays
  final int turnCount;
  final List<double> turnDurationsSeconds;
  final List<double> edgeAngles;
  final List<int> turnDirections; // 1 right, -1 left
  final List<double> parallelBeginning;
  final List<double> parallelMiddle;
  final List<double> parallelEnd;
  final List<double> parallelAvg;
  final List<double> turnShapeBeginning;
  final List<double> turnShapeMiddle;
  final List<double> turnShapeEnd;
  final List<double> turnShapeAvg;
  final List<double> turnScores; // Per-turn score (avg of 4 categories)

  // Aggregates
  final double? turnSymmetryRatio;
  final double? turnSymmetryScore;
  final double? overallScore;
  
  // Processed sensor data and segments for graphs
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
