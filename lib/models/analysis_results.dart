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
  final List<double> smoothBeginning;
  final List<double> smoothMiddle;
  final List<double> smoothEnd;
  final List<double> smoothAvg;
  final List<double> turnScores; // Per-turn score (avg of 4 categories)

  // Aggregates
  final double? turnSymmetryRatio;
  final double? turnSymmetryScore;
  final double? overallScore;

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
    required this.smoothBeginning,
    required this.smoothMiddle,
    required this.smoothEnd,
    required this.smoothAvg,
    required this.turnScores,
    required this.turnSymmetryRatio,
    required this.turnSymmetryScore,
    required this.overallScore,
  });
}
