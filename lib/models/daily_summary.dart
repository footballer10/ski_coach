/// Model for tracking daily run statistics
library;

class DailyRunSummary {
  final DateTime timestamp;
  final int turnCount;
  final double overallScore;
  final double durationScore;
  final double edgeAngleScore;
  final double parallelnessScore;
  final double turnShapeScore;
  final double symmetryScore;

  DailyRunSummary({
    required this.timestamp,
    required this.turnCount,
    required this.overallScore,
    required this.durationScore,
    required this.edgeAngleScore,
    required this.parallelnessScore,
    required this.turnShapeScore,
    required this.symmetryScore,
  });
}

class DailySummaryData {
  final DateTime date;
  final List<DailyRunSummary> runs;

  DailySummaryData({
    required this.date,
    required this.runs,
  });

  // Calculate statistics
  double get averageScore =>
      runs.isEmpty ? 0 : runs.map((r) => r.overallScore).reduce((a, b) => a + b) / runs.length;

  double get bestScore =>
      runs.isEmpty ? 0 : runs.map((r) => r.overallScore).reduce((a, b) => a > b ? a : b);

  int get totalTurns =>
      runs.fold(0, (sum, r) => sum + r.turnCount);

  double averageCategoryScore(String category) {
    if (runs.isEmpty) return 0;
    final scores = runs.map((r) {
      switch (category) {
        case 'Duration':
          return r.durationScore;
        case 'Edge Angle':
          return r.edgeAngleScore;
        case 'Parallelness':
          return r.parallelnessScore;
        case 'Turn Shape':
          return r.turnShapeScore;
        case 'Symmetry':
          return r.symmetryScore;
        default:
          return 0.0;
      }
    });
    return scores.reduce((a, b) => a + b) / runs.length;
  }

  Map<String, double> get categoryAverages => {
    'Duration': averageCategoryScore('Duration'),
    'Edge Angle': averageCategoryScore('Edge Angle'),
    'Parallelness': averageCategoryScore('Parallelness'),
    'Turn Shape': averageCategoryScore('Turn Shape'),
    'Symmetry': averageCategoryScore('Symmetry'),
  };
}
