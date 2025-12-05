import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:ski_coach/services/scoring.dart';
import 'package:ski_coach/models/analysis_results.dart';
import 'package:ski_coach/widgets/time_series_graph.dart';
import 'package:ski_coach/models/imu_sample.dart';
import 'package:ski_coach/services/segmentation.dart';

/// Dot plot scaler for creating histogram columns
class DotPlotScaler {
  final double b;           // Starting value
  final double d;           // Step size
  final int optimalColumn;  // Which column index has the optimal line
  final List<double> columns; // Trimmed columns containing data
  final int startColumn;    // First column index in full range
  final int endColumn;      // Last column index in full range
  
  DotPlotScaler({
    required double minValue,
    required double maxValue,
    required double optimalValue,
  }) : 
    d = _calculateD(minValue, maxValue, optimalValue),
    b = _calculateB(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue)),
    startColumn = _calculateStartColumn(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue), _calculateB(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue))),
    endColumn = _calculateEndColumn(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue), _calculateB(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue))),
    columns = _calculateTrimmedColumns(_calculateB(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue)), _calculateD(minValue, maxValue, optimalValue), _calculateStartColumn(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue), _calculateB(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue))), _calculateEndColumn(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue), _calculateB(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue)))),
    optimalColumn = _findOptimalColumn(_calculateTrimmedColumns(_calculateB(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue)), _calculateD(minValue, maxValue, optimalValue), _calculateStartColumn(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue), _calculateB(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue))), _calculateEndColumn(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue), _calculateB(minValue, maxValue, optimalValue, _calculateD(minValue, maxValue, optimalValue)))), optimalValue);
  
  static double _calculateD(double minValue, double maxValue, double optimalValue) {
    final greatest = math.max(math.max(minValue, maxValue), optimalValue);
    final least = math.min(math.min(minValue, maxValue), optimalValue);
    final range = greatest - least;
    final rawD = range / 10.0;
    return _roundUpTo1SF(rawD);
  }
  
  static double _calculateB(double minValue, double maxValue, double optimalValue, double d) {
    final least = math.min(math.min(minValue, maxValue), optimalValue);
    final greatest = math.max(math.max(minValue, maxValue), optimalValue);
    
    // Start by rounding down the least value
    double b = _roundToMultipleOf(least, d);
    
    // Ensure the greatest value fits within 11 columns (b + 10*d must be >= greatest)
    while (b + 10 * d < greatest) {
      b -= d;
    }
    
    // Also ensure the least value fits (b should be <= least)
    while (b > least) {
      b -= d;
    }
    
    return b;
  }
  
  static int _calculateStartColumn(double minValue, double maxValue, double optimalValue, double d, double b) {
    final least = math.min(math.min(minValue, maxValue), optimalValue);
    
    // Find which column the least value falls into
    int startCol = ((least - b) / d).floor();
    return math.max(0, startCol);
  }
  
  static int _calculateEndColumn(double minValue, double maxValue, double optimalValue, double d, double b) {
    final greatest = math.max(math.max(minValue, maxValue), optimalValue);
    
    // Find which column the greatest value falls into
    int endCol = ((greatest - b) / d).ceil();
    return math.min(10, endCol);
  }
  
  static List<double> _calculateTrimmedColumns(double b, double d, int startCol, int endCol) {
    final numCols = endCol - startCol + 1;
    return List.generate(numCols, (i) => b + (startCol + i) * d);
  }
  
  static int _findOptimalColumn(List<double> columns, double optimalValue) {
    int closestIndex = 0;
    double closestDistance = (columns[0] - optimalValue).abs();
    for (int i = 1; i < columns.length; i++) {
      final distance = (columns[i] - optimalValue).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = i;
      }
    }
    return closestIndex;
  }
  
  static double _roundUpTo1SF(double value) {
    if (value <= 0) return 0.1;
    final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    return (value / magnitude).ceil() * magnitude;
  }
  
  static double _roundToMultipleOf(double value, double multiple) {
    if (multiple <= 0) return value;
    return (value / multiple).floor() * multiple;
  }
  
  int findColumnIndex(double value) {
    int closestIndex = 0;
    double closestDistance = (columns[0] - value).abs();
    for (int i = 1; i < columns.length; i++) {
      final distance = (columns[i] - value).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = i;
      }
    }
    return closestIndex;
  }
}

/// Dot plot widget showing distribution of values across turns
class DotPlot extends StatelessWidget {
  final List<double> values;
  final int? highlightIndex;
  final double optimalValue;
  final String units;
  final double height;
  
  const DotPlot({
    super.key,
    required this.values,
    this.highlightIndex,
    required this.optimalValue,
    required this.units,
    this.height = 100,
  });
  
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(height: height, child: const Center(child: Text('No data')));
    }
    
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    
    final scaler = DotPlotScaler(
      minValue: minValue,
      maxValue: maxValue,
      optimalValue: optimalValue,
    );
    
    final numColumns = scaler.columns.length;
    
    // Group values into columns
    final columnCounts = List.generate(numColumns, (_) => <int>[]);
    for (int i = 0; i < values.length; i++) {
      final columnIndex = scaler.findColumnIndex(values[i]);
      columnCounts[columnIndex].add(i);
    }
    
    // Trim empty columns from start and end, but keep optimal column
    int firstNonEmpty = scaler.optimalColumn;  // Start with optimal
    int lastNonEmpty = scaler.optimalColumn;   // Start with optimal
    
    // Expand to include all data points
    for (int i = 0; i < numColumns; i++) {
      if (columnCounts[i].isNotEmpty) {
        firstNonEmpty = math.min(firstNonEmpty, i);
        lastNonEmpty = math.max(lastNonEmpty, i);
      }
    }
    
    // Ensure we have at least 6 columns and at most 11
    final minColumns = 6;
    final maxColumns = 11;
    int trimmedNumColumns = lastNonEmpty - firstNonEmpty + 1;
    
    // Expand to minimum columns if needed
    if (trimmedNumColumns < minColumns) {
      final expansion = minColumns - trimmedNumColumns;
      final leftExpansion = expansion ~/ 2;
      final rightExpansion = expansion - leftExpansion;
      firstNonEmpty = math.max(0, firstNonEmpty - leftExpansion);
      lastNonEmpty = math.min(numColumns - 1, lastNonEmpty + rightExpansion);
      trimmedNumColumns = lastNonEmpty - firstNonEmpty + 1;
    }
    
    // Contract to maximum columns if needed
    if (trimmedNumColumns > maxColumns) {
      final contraction = trimmedNumColumns - maxColumns;
      final leftContraction = contraction ~/ 2;
      final rightContraction = contraction - leftContraction;
      firstNonEmpty = firstNonEmpty + leftContraction;
      lastNonEmpty = lastNonEmpty - rightContraction;
      trimmedNumColumns = lastNonEmpty - firstNonEmpty + 1;
    }
    
    // Create trimmed columns and data
    final trimmedColumns = scaler.columns.sublist(firstNonEmpty, lastNonEmpty + 1);
    final trimmedColumnCounts = columnCounts.sublist(firstNonEmpty, lastNonEmpty + 1);
    final adjustedOptimalColumn = scaler.optimalColumn - firstNonEmpty;
    
    // Calculate required height based on max dots in any column
    final maxDotsInColumn = trimmedColumnCounts.map((col) => col.length).reduce(math.max);
    final dotSize = 6.0;
    final dotSpacing = 2.0; // vertical margin is 1px on each side
    final minPlotHeight = 60.0;
    final labelHeight = 30.0;
    final calculatedPlotHeight = math.max(minPlotHeight, maxDotsInColumn * (dotSize + dotSpacing) + 10);
    final totalHeight = calculatedPlotHeight + labelHeight;
    
    return SizedBox(
      height: totalHeight,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columnWidth = (constraints.maxWidth - 20) / trimmedNumColumns;
                return Stack(
                  children: [
                    // Optimal line (only show if in visible range)
                    if (adjustedOptimalColumn >= 0 && adjustedOptimalColumn < trimmedNumColumns)
                      Positioned(
                        left: 10 + adjustedOptimalColumn * columnWidth + columnWidth / 2,
                        top: 0,
                        bottom: 30,
                        child: CustomPaint(
                          painter: DottedLinePainter(color: Colors.red),
                          size: Size(1, calculatedPlotHeight),
                        ),
                      ),
                    // Dots
                    ...List.generate(trimmedNumColumns, (colIndex) {
                      final dotsInColumn = trimmedColumnCounts[colIndex];
                      return Positioned(
                        left: 10 + colIndex * columnWidth,
                        bottom: 30,
                        top: 0,
                        width: columnWidth,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ClipRect(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: dotsInColumn.reversed.map((turnIndex) {
                                final isHighlighted = highlightIndex != null && turnIndex == highlightIndex;
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 1),
                                  width: dotSize,
                                  height: dotSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isHighlighted ? Colors.blue : Colors.grey,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    }),
                    // Column labels
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 30,
                      child: Row(
                        children: List.generate(trimmedNumColumns, (i) {
                          return Expanded(
                            child: Center(
                              child: Text(
                                trimmedColumns[i].toStringAsFixed(2),
                                style: const TextStyle(fontSize: 9),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  final Color color;
  
  const DottedLinePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double startY = 0;
    
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Displays run analysis results with navigation through categories and turns
class ResultsView extends StatefulWidget {
  final AnalysisResults? results; // null if showing error
  final String? errorMessage;
  final VoidCallback onNewRun;
  final VoidCallback? onReconnect;
  final VoidCallback? onCalibrateAcceleration;
  final bool showReconnectButton;
  final bool showTryAgainButton;

  const ResultsView({
    super.key,
    this.results,
    this.errorMessage,
    required this.onNewRun,
    this.onReconnect,
    this.onCalibrateAcceleration,
    this.showReconnectButton = true,
    this.showTryAgainButton = true,
  });

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

enum ViewMode { overview, categoryAll, turnAll, categoryTurn }

class _ResultsViewState extends State<ResultsView> {
  String _selectedCategory = 'All Categories';
  String _selectedTurn = 'All Turns';
  String _categoryPageThird = 'Whole Turn'; // For Parallel/Turn Shape category page
  // Phase selections per current turn
  String _parallelPhase = 'Whole Turn';
  String _turnShapePhase = 'Whole Turn';
  
  // Navigation history stack
  final List<Map<String, String>> _navigationHistory = [];
  
  final List<String> _categories = const [
    'All Categories',
    'Turn Duration',
    'Edge Angle',
    'Parallel',
    'Turn Shape',
  ];

  List<String> get _turns {
    final count = (widget.results?.turnCount ?? 0) > 0 ? (widget.results?.turnCount ?? 0) : 5;
    return [
      'All Turns',
      ...List.generate(count, (i) {
        final dirs = widget.results?.turnDirections ?? const [];
        final direction = i < dirs.length 
            ? (dirs[i] == 1 ? '(R)' : '(L)')
            : '';
        return 'Turn ${i + 1} $direction'.trim();
      })
    ];
  }

  ViewMode get _viewMode {
    final allCat = _selectedCategory == 'All Categories';
    final allTurn = _selectedTurn == 'All Turns';
    
    if (allCat && allTurn) return ViewMode.overview;
    if (!allCat && allTurn) return ViewMode.categoryAll;
    if (allCat && !allTurn) return ViewMode.turnAll;
    return ViewMode.categoryTurn;
  }

  double _scoreForDuration(double x) {
    return Scoring.duration(x);
  }

  double _scoreForEdgeAngle(double x) {
    return Scoring.edgeAngle(x);
  }

  double _scoreForParallelness(double x) {
    return Scoring.parallel(x);
  }
  
  double _scoreForTurnShapeSD(double x) {
    return Scoring.turnShape(x);
  }

  void _navigateBack() {
    if (_navigationHistory.isEmpty) return;
    final prev = _navigationHistory.removeLast();
    setState(() {
      _selectedCategory = prev['category']!;
      _selectedTurn = prev['turn']!;
      _categoryPageThird = prev['categoryPageThird']!;
      _parallelPhase = prev['parallelPhase']!;
      _turnShapePhase = prev['turnShapePhase']!;
    });
  }

  void _pushNavigation() {
    _navigationHistory.add({
      'category': _selectedCategory,
      'turn': _selectedTurn,
      'categoryPageThird': _categoryPageThird,
      'parallelPhase': _parallelPhase,
      'turnShapePhase': _turnShapePhase,
    });
  }

  void _selectCategory(String category) {
    _pushNavigation();
    setState(() => _selectedCategory = category);
  }

  void _selectTurn(String turn) {
    _pushNavigation();
    setState(() {
      _selectedTurn = turn;
      _parallelPhase = 'Whole Turn';
      _turnShapePhase = 'Whole Turn';
    });
  }
  
  void _selectCategoryAndTurn(String category, String turn) {
    _pushNavigation();
    setState(() {
      _selectedCategory = category;
      _selectedTurn = turn;
      _parallelPhase = 'Whole Turn';
      _turnShapePhase = 'Whole Turn';
    });
  }

  // Helper methods for dot plots
  double _getOptimalForCategory(String category) {
    switch (category) {
      case 'Turn Duration':
        return 2.0;
      case 'Edge Angle':
        return 45.0;
      case 'Parallel':
        return 0.0;
      case 'Turn Shape':
        return 0.0;
      default:
        return 0.0;
    }
  }

  String _getUnitsForCategory(String category) {
    switch (category) {
      case 'Turn Duration':
        return 's';
      case 'Edge Angle':
        return '°';
      case 'Parallel':
        return '°';
      case 'Turn Shape':
        return '°/s';
      default:
        return '';
    }
  }

  List<double> _getValuesForCategory(String category, String phase) {
    switch (category) {
      case 'Turn Duration':
        return widget.results?.turnDurationsSeconds ?? [];
      case 'Edge Angle':
        return widget.results?.edgeAngles ?? [];
      case 'Parallel':
        if (phase == 'Initiation') return widget.results?.parallelBeginning ?? [];
        if (phase == 'Control') return widget.results?.parallelMiddle ?? [];
        if (phase == 'Completion') return widget.results?.parallelEnd ?? [];
        return widget.results?.parallelAvg ?? [];
      case 'Turn Shape':
        if (phase == 'Initiation') return widget.results?.turnShapeBeginning ?? [];
        if (phase == 'Control') return widget.results?.turnShapeMiddle ?? [];
        if (phase == 'Completion') return widget.results?.turnShapeEnd ?? [];
        return widget.results?.turnShapeAvg ?? [];
      default:
        return [];
    }
  }

  List<double> _getValuesForMetric(String metric, String phase) {
    switch (metric) {
      case 'Turn Duration':
        return widget.results?.turnDurationsSeconds ?? [];
      case 'Edge Angle':
        return widget.results?.edgeAngles ?? [];
      case 'Parallel':
        if (phase == 'Initiation') return widget.results?.parallelBeginning ?? [];
        if (phase == 'Control') return widget.results?.parallelMiddle ?? [];
        if (phase == 'Completion') return widget.results?.parallelEnd ?? [];
        // Default: average of the three phases
        final beginning = widget.results?.parallelBeginning ?? [];
        final middle = widget.results?.parallelMiddle ?? [];
        final end = widget.results?.parallelEnd ?? [];
        if (beginning.isEmpty || middle.isEmpty || end.isEmpty) return widget.results?.parallelAvg ?? [];
        return List.generate(
          beginning.length,
          (i) => (beginning[i] + middle[i] + end[i]) / 3.0,
        );
      case 'Turn Shape':
        if (phase == 'Initiation') return widget.results?.turnShapeBeginning ?? [];
        if (phase == 'Control') return widget.results?.turnShapeMiddle ?? [];
        if (phase == 'Completion') return widget.results?.turnShapeEnd ?? [];
        // Default: average of the three phases
        final beginning = widget.results?.turnShapeBeginning ?? [];
        final middle = widget.results?.turnShapeMiddle ?? [];
        final end = widget.results?.turnShapeEnd ?? [];
        if (beginning.isEmpty || middle.isEmpty || end.isEmpty) return widget.results?.turnShapeAvg ?? [];
        return List.generate(
          beginning.length,
          (i) => (beginning[i] + middle[i] + end[i]) / 3.0,
        );
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error state if present
    if (widget.errorMessage != null) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 80, color: Colors.red),
                    const SizedBox(height: 24),
                    const Text(
                      'ERROR',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.errorMessage!,
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                if (widget.onReconnect != null && widget.showReconnectButton)
                  ElevatedButton.icon(
                    onPressed: widget.onReconnect,
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('Reconnect Sensors'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (widget.onReconnect != null && widget.showReconnectButton) const SizedBox(height: 8),
                if (widget.showTryAgainButton)
                  ElevatedButton.icon(
                    onPressed: widget.onNewRun,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Start Another Run'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    
    return Column(
      children: [
        _buildNavigationBar(),
        Expanded(child: _buildContent()),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: widget.onNewRun,
                  icon: const Icon(Icons.add, size: 24),
                  label: const Text('Start New Run'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (widget.onCalibrateAcceleration != null) const SizedBox(width: 8),
              if (widget.onCalibrateAcceleration != null)
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: widget.onCalibrateAcceleration,
                    icon: const Icon(Icons.settings_input_component, size: 20),
                    label: const Text('Accel Cal'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationBar() {
    final showThirdDropdown = (_selectedCategory == 'Parallel' || _selectedCategory == 'Turn Shape') && _selectedTurn == 'All Turns';
    final showThirdDropdownCategoryTurn = (_selectedCategory == 'Parallel' || _selectedCategory == 'Turn Shape') && _selectedTurn != 'All Turns';
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _navigationHistory.isNotEmpty ? _navigateBack : null,
              tooltip: 'Back',
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              ),
              style: const TextStyle(fontSize: 12, color: Colors.black),
              dropdownColor: Colors.white,
              isExpanded: true,
              items: _categories
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat, style: const TextStyle(fontSize: 12, color: Colors.black)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) _selectCategory(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedTurn,
              decoration: const InputDecoration(
                labelText: 'Turn',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              ),
              style: const TextStyle(fontSize: 12, color: Colors.black),
              dropdownColor: Colors.white,
              isExpanded: true,
              items: _turns
                  .map((turn) => DropdownMenuItem(
                        value: turn,
                        child: Text(turn, style: const TextStyle(fontSize: 12, color: Colors.black)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) _selectTurn(value);
              },
            ),
          ),
          if (showThirdDropdownCategoryTurn)
            const SizedBox(width: 8),
          if (showThirdDropdownCategoryTurn)
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCategory == 'Parallel' ? _parallelPhase : _turnShapePhase,
                decoration: const InputDecoration(
                  labelText: 'Third',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
                style: const TextStyle(fontSize: 12, color: Colors.black),
                dropdownColor: Colors.white,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Whole Turn', child: Text('Whole Turn', style: TextStyle(fontSize: 12, color: Colors.black))),
                  DropdownMenuItem(value: 'Initiation', child: Text('Initiation', style: TextStyle(fontSize: 12, color: Colors.black))),
                  DropdownMenuItem(value: 'Control', child: Text('Control', style: TextStyle(fontSize: 12, color: Colors.black))),
                  DropdownMenuItem(value: 'Completion', child: Text('Completion', style: TextStyle(fontSize: 12, color: Colors.black))),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _pushNavigation();
                    setState(() {
                      if (_selectedCategory == 'Parallel') {
                        _parallelPhase = value;
                      } else {
                        _turnShapePhase = value;
                      }
                    });
                  }
                },
              ),
            ),
          if (showThirdDropdown)
            const SizedBox(width: 8),
          if (showThirdDropdown)
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _categoryPageThird,
                decoration: const InputDecoration(
                  labelText: 'Third',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
                style: const TextStyle(fontSize: 12, color: Colors.black),
                dropdownColor: Colors.white,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Whole Turn', child: Text('Whole Turn', style: TextStyle(fontSize: 12, color: Colors.black))),
                  DropdownMenuItem(value: 'Initiation', child: Text('Initiation', style: TextStyle(fontSize: 12, color: Colors.black))),
                  DropdownMenuItem(value: 'Control', child: Text('Control', style: TextStyle(fontSize: 12, color: Colors.black))),
                  DropdownMenuItem(value: 'Completion', child: Text('Completion', style: TextStyle(fontSize: 12, color: Colors.black))),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _categoryPageThird = value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSummary({bool includeSimilarity = false}) {
        final duration = widget.results?.runDurationSeconds ?? 0;
        final durationStr = duration > 0 
          ? '${duration}s'
          : '—';
        final startTimeStr = widget.results?.runStartTime != null
          ? '${widget.results!.runStartTime!.hour.toString().padLeft(2, '0')}:${widget.results!.runStartTime!.minute.toString().padLeft(2, '0')}'
          : '—';
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem('Turns', '${(widget.results?.turnCount ?? 0) > 0 ? (widget.results?.turnCount ?? 0) : (_turns.length - 1)}'),
                _summaryItem('Duration', durationStr),
                _summaryItem('Start', startTimeStr),
              _summaryItem('Score', widget.results?.overallScore != null ? widget.results!.overallScore!.toStringAsFixed(1) : '—', prominent: true),
              if (includeSimilarity)
                _summaryItem(
                  'Symmetry',
                  widget.results?.turnSymmetryRatio != null ? widget.results!.turnSymmetryRatio!.toStringAsFixed(3) : '—',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, {bool prominent = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: prominent ? Colors.blue : Colors.grey, fontWeight: prominent ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: prominent ? 18 : 14, fontWeight: FontWeight.bold, color: prominent ? Colors.blue : Colors.black)),
      ],
    );
  }

  Widget _buildLeftPane({bool includeSimilarity = false}) {
    final items = _categories.skip(1).toList();
    if (includeSimilarity) items.add('Turn Symmetry');
    
    // Precompute Turn Duration average value and score
    String turnDurationVal = '—';
    String turnDurationScore = '—';
      final durations = widget.results?.turnDurationsSeconds ?? const [];
      if (durations.isNotEmpty) {
      final avg = durations.reduce((a,b) => a + b) / durations.length;
      turnDurationVal = '${avg.toStringAsFixed(3)}s';
      double scoreSum = 0.0;
      for (final x in durations) {
        scoreSum += _scoreForDuration(x);
      }
      final avgScore = scoreSum / durations.length;
      turnDurationScore = avgScore.isFinite ? avgScore.toStringAsFixed(1) : '—';
    }
    
    // Precompute Edge Angle average value and score
    String edgeAngleVal = '—';
    String edgeAngleScore = '—';
      final angles = widget.results?.edgeAngles ?? const [];
      if (angles.isNotEmpty) {
      final avg = angles.reduce((a,b) => a + b) / angles.length;
      edgeAngleVal = '${avg.toStringAsFixed(1)}°';
      double scoreSum = 0.0;
      for (final x in angles) {
        scoreSum += _scoreForEdgeAngle(x);
      }
      final avgScore = scoreSum / angles.length;
      edgeAngleScore = avgScore.isFinite ? avgScore.toStringAsFixed(1) : '—';
    }
    
    // Precompute Parallelness average value and score
    String parallelVal = '—';
    String parallelScore = '—';
      final parallels = widget.results?.parallelAvg ?? const [];
      if (parallels.isNotEmpty) {
      final avg = parallels.reduce((a,b) => a + b) / parallels.length;
      parallelVal = '${avg.toStringAsFixed(1)}°';
      double scoreSum = 0.0;
      for (final x in parallels) {
        scoreSum += _scoreForParallelness(x);
      }
      final avgScore = scoreSum / parallels.length;
      parallelScore = avgScore.isFinite ? avgScore.toStringAsFixed(1) : '—';
    }
    
    // Precompute Turn Shape average value and score
    String smoothVal = '—';
    String smoothScore = '—';
      final smooths = widget.results?.turnShapeAvg ?? const [];
      if (smooths.isNotEmpty) {
      final avg = smooths.reduce((a,b) => a + b) / smooths.length;
      smoothVal = '${avg.toStringAsFixed(1)}°/s';
      double scoreSum = 0.0;
      for (final x in smooths) {
        scoreSum += _scoreForTurnShapeSD(x);
      }
      final avgScore = scoreSum / smooths.length;
      smoothScore = avgScore.isFinite ? avgScore.toStringAsFixed(1) : '—';
    }
    
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      children: [
        ...items.map((cat) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(cat, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                cat == 'Turn Duration'
                    ? 'Val: $turnDurationVal | Score: $turnDurationScore'
                    : cat == 'Edge Angle'
                        ? 'Val: $edgeAngleVal | Score: $edgeAngleScore'
                        : cat == 'Parallel'
                            ? 'Val: $parallelVal | Score: $parallelScore'
                            : cat == 'Turn Shape'
                                ? 'Val: $smoothVal | Score: $smoothScore'
                                : cat == 'Turn Symmetry'
                                    ? 'Val: ${widget.results?.turnSymmetryRatio != null ? widget.results!.turnSymmetryRatio!.toStringAsFixed(3) : '—'} | Score: ${widget.results?.turnSymmetryScore != null ? widget.results!.turnSymmetryScore!.toStringAsFixed(1) : '—'}'
                                    : 'Val: — | Score: —',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: cat == 'Turn Symmetry' ? null : () => _selectCategory(cat),
            )),
      ],
    );
  }

  Widget _buildRightPaneVisualization() {
    final turnCount = (widget.results?.turnCount ?? 0) > 0 ? (widget.results?.turnCount ?? 0) : 5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView.builder(
            itemCount: turnCount,
            itemBuilder: (context, i) {
              final dirs = widget.results?.turnDirections ?? const [];
              final direction = i < dirs.length 
                  ? (dirs[i] == 1 ? '(R)' : '(L)')
                  : '';
              final turnLabel = 'Turn ${i + 1} $direction'.trim();
              final isSelected = _selectedTurn == turnLabel;
              return GestureDetector(
                onTap: () => _selectTurn(turnLabel),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey[400],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (i < (widget.results?.turnScores.length ?? 0))
                            ? widget.results!.turnScores[i].toStringAsFixed(1)
                            : '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_viewMode) {
      case ViewMode.overview:
        return _buildOverview();
      case ViewMode.categoryAll:
        return _buildCategoryAllTurns();
      case ViewMode.turnAll:
        return _buildTurnAllCategories();
      case ViewMode.categoryTurn:
        return _buildCategoryTurn();
    }
  }

  Widget _buildOverview() {
    return Column(
      children: [
        _buildCompactSummary(includeSimilarity: false),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildLeftPane(includeSimilarity: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildRightPaneVisualization()),
            ],
          ),
        ),
        // Footer reserved for future insights cards
      ],
    );
  }

  // Compact layout based on summary + panes

  Widget _buildCategoryAllTurns() {
    final actualTurnCount = (widget.results?.turnCount ?? 0) > 0 ? (widget.results?.turnCount ?? 0) : 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: _buildCategorySummary(),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: actualTurnCount,
            itemBuilder: (context, i) {
                  // Create turn label with direction to match _turns list
                  final dirs = widget.results?.turnDirections ?? const [];
                  final direction = i < dirs.length 
                      ? (dirs[i] == 1 ? '(R)' : '(L)')
                      : '';
                  final turnLabel = 'Turn ${i + 1} $direction'.trim();
                    final turnDuration = (i < (widget.results?.turnDurationsSeconds.length ?? 0))
                      ? '${widget.results!.turnDurationsSeconds[i].toStringAsFixed(3)}s'
                      : '—';
                    final turnDurationScore = (i < (widget.results?.turnDurationsSeconds.length ?? 0))
                      ? _scoreForDuration(widget.results!.turnDurationsSeconds[i]).toStringAsFixed(1)
                      : '—';
                    final edgeAngle = (i < (widget.results?.edgeAngles.length ?? 0))
                      ? '${widget.results!.edgeAngles[i].toStringAsFixed(1)}°'
                      : '—';
                    final edgeAngleScore = (i < (widget.results?.edgeAngles.length ?? 0))
                      ? _scoreForEdgeAngle(widget.results!.edgeAngles[i]).toStringAsFixed(1)
                      : '—';
                    
                    // Parallelness (based on selected phase)
                    String parallelText = '—';
                    String parallelScoreText = '—';
                    if (_selectedCategory == 'Parallel') {
                      double? val;
                      if (_categoryPageThird == 'Whole Turn' && i < (widget.results?.parallelAvg.length ?? 0)) {
                        val = widget.results!.parallelAvg[i];
                      } else if (_categoryPageThird == 'Initiation' && i < (widget.results?.parallelBeginning.length ?? 0)) {
                        val = widget.results!.parallelBeginning[i];
                      } else if (_categoryPageThird == 'Control' && i < (widget.results?.parallelMiddle.length ?? 0)) {
                        val = widget.results!.parallelMiddle[i];
                      } else if (_categoryPageThird == 'Completion' && i < (widget.results?.parallelEnd.length ?? 0)) {
                        val = widget.results!.parallelEnd[i];
                      }
                      if (val != null) {
                        parallelText = '${val.toStringAsFixed(1)}°';
                        parallelScoreText = _scoreForParallelness(val).toStringAsFixed(1);
                      }
                    }
                    
                    // Turn Shape (based on selected phase)
                    String smoothText = '—';
                    String smoothScoreText = '—';
                    if (_selectedCategory == 'Turn Shape') {
                      double? val;
                      if (_categoryPageThird == 'Whole Turn' && i < (widget.results?.turnShapeAvg.length ?? 0)) {
                        val = widget.results!.turnShapeAvg[i];
                      } else if (_categoryPageThird == 'Initiation' && i < (widget.results?.turnShapeBeginning.length ?? 0)) {
                        val = widget.results!.turnShapeBeginning[i];
                      } else if (_categoryPageThird == 'Control' && i < (widget.results?.turnShapeMiddle.length ?? 0)) {
                        val = widget.results!.turnShapeMiddle[i];
                      } else if (_categoryPageThird == 'Completion' && i < (widget.results?.turnShapeEnd.length ?? 0)) {
                        val = widget.results!.turnShapeEnd[i];
                      }
                      if (val != null) {
                        smoothText = '${val.toStringAsFixed(1)}°/s';
                        smoothScoreText = _scoreForTurnShapeSD(val).toStringAsFixed(1);
                      }
                    }
                  return GestureDetector(
                    onTap: () => _selectCategoryAndTurn(_selectedCategory, turnLabel),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Turn ${i + 1}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              if (_selectedCategory == 'Turn Duration') ...[
                                const SizedBox(width: 8),
                                Text(
                                  '$turnDuration | Score: $turnDurationScore',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                              if (_selectedCategory == 'Edge Angle') ...[
                                const SizedBox(width: 8),
                                Text(
                                  '$edgeAngle | Score: $edgeAngleScore',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                              if (_selectedCategory == 'Parallel') ...[
                                const SizedBox(width: 8),
                                Text(
                                  '$parallelText | Score: $parallelScoreText',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                              if (_selectedCategory == 'Turn Shape') ...[
                                const SizedBox(width: 8),
                                Text(
                                  '$smoothText | Score: $smoothScoreText',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: _buildCategoryDotPlot(),
        ),
      ],
    );
  }

  Widget _buildCategorySummary() {
    String valueText = '—';
    String optimalText = '—';
    String scoreText = '—';

    if (_selectedCategory == 'Turn Duration') {
      optimalText = '2.000s';
      final durations = widget.results?.turnDurationsSeconds ?? const [];
      if (_selectedTurn == 'All Turns') {
        if (durations.isNotEmpty) {
          final avg = durations.reduce((a,b) => a + b) / durations.length;
          valueText = '${avg.toStringAsFixed(3)}s';
          // score: average of per-turn scores
          double scoreSum = 0.0;
          for (final x in durations) {
            final s = 100.0 * (math.pow(0.1205, math.pow(math.log(x / 2.0), 2)) as double);
            scoreSum += s;
          }
          final avgScore = scoreSum / durations.length;
          scoreText = avgScore.isFinite ? avgScore.toStringAsFixed(1) : '—';
        }
      } else {
        // specific turn
        final match = RegExp(r'Turn (\d+)').firstMatch(_selectedTurn);
        if (match != null) {
          final idx = int.parse(match.group(1)!) - 1;
          if (idx >= 0 && idx < durations.length) {
            final x = durations[idx];
            valueText = '${x.toStringAsFixed(3)}s';
            final score = 100.0 * (math.pow(0.1205, math.pow(math.log(x / 2.0), 2)) as double);
            scoreText = score.isFinite ? score.toStringAsFixed(1) : '—';
          }
        }
      }
    } else if (_selectedCategory == 'Parallel') {
      optimalText = '0.0°';
      final phase = _categoryPageThird;
      List<double> vals = const [];
      if (_selectedTurn == 'All Turns') {
        if (phase == 'Whole Turn') {
          vals = widget.results?.parallelAvg ?? const [];
        } else if (phase == 'Initiation') vals = widget.results?.parallelBeginning ?? const [];
        else if (phase == 'Control') vals = widget.results?.parallelMiddle ?? const [];
        else if (phase == 'Completion') vals = widget.results?.parallelEnd ?? const [];
        if (vals.isNotEmpty) {
          final avg = vals.reduce((a,b) => a + b) / vals.length;
          valueText = '${avg.toStringAsFixed(1)}°';
          double scoreSum = 0.0;
          for (final x in vals) {
            scoreSum += _scoreForParallelness(x);
          }
          final avgScore = scoreSum / vals.length;
          scoreText = avgScore.isFinite ? avgScore.toStringAsFixed(1) : '—';
        }
      } else {
        final match = RegExp(r'Turn (\d+)').firstMatch(_selectedTurn);
        if (match != null) {
          final idx = int.parse(match.group(1)!) - 1;
          double? val;
          if (phase == 'Whole Turn' && idx < (widget.results?.parallelAvg.length ?? 0)) {
            val = widget.results!.parallelAvg[idx];
          } else if (phase == 'Initiation' && idx < (widget.results?.parallelBeginning.length ?? 0)) {
            val = widget.results!.parallelBeginning[idx];
          } else if (phase == 'Control' && idx < (widget.results?.parallelMiddle.length ?? 0)) {
            val = widget.results!.parallelMiddle[idx];
          } else if (phase == 'Completion' && idx < (widget.results?.parallelEnd.length ?? 0)) {
            val = widget.results!.parallelEnd[idx];
          }
          if (val != null) {
            valueText = '${val.toStringAsFixed(1)}°';
            scoreText = _scoreForParallelness(val).toStringAsFixed(1);
          }
        }
      }
    } else if (_selectedCategory == 'Turn Shape') {
      optimalText = '0.0°/s';
      final phase = _categoryPageThird;
      List<double> vals = const [];
      if (_selectedTurn == 'All Turns') {
        if (phase == 'Whole Turn') {
          vals = widget.results?.turnShapeAvg ?? const [];
        } else if (phase == 'Initiation') vals = widget.results?.turnShapeBeginning ?? const [];
        else if (phase == 'Control') vals = widget.results?.turnShapeMiddle ?? const [];
        else if (phase == 'Completion') vals = widget.results?.turnShapeEnd ?? const [];
        if (vals.isNotEmpty) {
          final avg = vals.reduce((a,b) => a + b) / vals.length;
          valueText = '${avg.toStringAsFixed(1)}°/s';
          double scoreSum = 0.0;
          for (final x in vals) {
            scoreSum += _scoreForTurnShapeSD(x);
          }
          final avgScore = scoreSum / vals.length;
          scoreText = avgScore.isFinite ? avgScore.toStringAsFixed(1) : '—';
        }
      } else {
        final match = RegExp(r'Turn (\d+)').firstMatch(_selectedTurn);
        if (match != null) {
          final idx = int.parse(match.group(1)!) - 1;
          double? val;
          if (phase == 'Whole Turn' && idx < (widget.results?.turnShapeAvg.length ?? 0)) {
            val = widget.results!.turnShapeAvg[idx];
          } else if (phase == 'Initiation' && idx < (widget.results?.turnShapeBeginning.length ?? 0)) {
            val = widget.results!.turnShapeBeginning[idx];
          } else if (phase == 'Control' && idx < (widget.results?.turnShapeMiddle.length ?? 0)) {
            val = widget.results!.turnShapeMiddle[idx];
          } else if (phase == 'Completion' && idx < (widget.results?.turnShapeEnd.length ?? 0)) {
            val = widget.results!.turnShapeEnd[idx];
          }
          if (val != null) {
            valueText = '${val.toStringAsFixed(1)}°/s';
            scoreText = _scoreForTurnShapeSD(val).toStringAsFixed(1);
          }
        }
      }
    } else if (_selectedCategory == 'Edge Angle') {
      optimalText = '45.0°';
      final angles = widget.results?.edgeAngles ?? const [];
      if (_selectedTurn == 'All Turns') {
        if (angles.isNotEmpty) {
          final avg = angles.reduce((a,b) => a + b) / angles.length;
          valueText = '${avg.toStringAsFixed(1)}°';
          // score: average of per-turn scores
          double scoreSum = 0.0;
          for (final x in angles) {
            scoreSum += _scoreForEdgeAngle(x);
          }
          final avgScore = scoreSum / angles.length;
          scoreText = avgScore.isFinite ? avgScore.toStringAsFixed(1) : '—';
        }
      } else {
        // specific turn
        final match = RegExp(r'Turn (\d+)').firstMatch(_selectedTurn);
        if (match != null) {
          final idx = int.parse(match.group(1)!) - 1;
          if (idx >= 0 && idx < angles.length) {
            final x = angles[idx];
            valueText = '${x.toStringAsFixed(1)}°';
            scoreText = _scoreForEdgeAngle(x).toStringAsFixed(1);
          }
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem('Value', valueText),
            _summaryItem('Optimal', optimalText),
            _summaryItem('Score', scoreText, prominent: true),
          ],
        ),
      ),
    );
  }

  // Removed old color-coded visualization in favor of compact GPS card

  Widget _buildCategoryDotPlot() {
    final values = _getValuesForCategory(_selectedCategory, _categoryPageThird);
    if (values.isEmpty) return const SizedBox();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Values Across Turns',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DotPlot(
              values: values,
              highlightIndex: null,
              optimalValue: _getOptimalForCategory(_selectedCategory),
              units: _getUnitsForCategory(_selectedCategory),
              height: 120,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnAllCategories() {
    // Get current turn index
    int? selectedTurnIndex;
    if (_selectedTurn != 'All Turns') {
      final match = RegExp(r'Turn (\d+)').firstMatch(_selectedTurn);
      if (match != null) {
        selectedTurnIndex = int.parse(match.group(1)!) - 1;
      }
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selectedTurnIndex != null && selectedTurnIndex < (widget.results?.turnScores.length ?? 0)) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Turn Score: ',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.results!.turnScores[selectedTurnIndex].toStringAsFixed(1),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _buildMetricModule('Turn Duration', 0),
          const SizedBox(height: 8),
          _buildMetricModule('Edge Angle', 0),
          const SizedBox(height: 8),
          _buildMetricModule('Parallel', 0),
          const SizedBox(height: 8),
          _buildMetricModule('Turn Shape', 0),
        ],
      ),
    );
  }

  Widget _buildMetricModule(String metric, int turnIndex) {
    final showDropdown = (metric == 'Parallel' || metric == 'Turn Shape');
    
    // Extract turn index from _selectedTurn (e.g., "Turn 3" -> 2)
    int? selectedTurnIndex;
    if (_selectedTurn != 'All Turns') {
      final match = RegExp(r'Turn (\d+)').firstMatch(_selectedTurn);
      if (match != null) {
        selectedTurnIndex = int.parse(match.group(1)!) - 1;
      }
    }
    
    String valueText = '—';
    String scoreText = '—';
    if (metric == 'Turn Duration' && selectedTurnIndex != null && selectedTurnIndex < (widget.results?.turnDurationsSeconds.length ?? 0)) {
      final x = widget.results!.turnDurationsSeconds[selectedTurnIndex];
      valueText = '${x.toStringAsFixed(3)}s';
      scoreText = _scoreForDuration(x).toStringAsFixed(1);
    } else if (metric == 'Edge Angle' && selectedTurnIndex != null && selectedTurnIndex < (widget.results?.edgeAngles.length ?? 0)) {
      final x = widget.results!.edgeAngles[selectedTurnIndex];
      valueText = '${x.toStringAsFixed(1)}°';
      scoreText = _scoreForEdgeAngle(x).toStringAsFixed(1);
    } else if (metric == 'Parallel' && selectedTurnIndex != null) {
      final phase = _parallelPhase;
      double? parallelVal;
      if (phase == 'Whole Turn' && selectedTurnIndex < (widget.results?.parallelAvg.length ?? 0)) {
        parallelVal = widget.results!.parallelAvg[selectedTurnIndex];
      } else if (phase == 'Initiation' && selectedTurnIndex < (widget.results?.parallelBeginning.length ?? 0)) {
        parallelVal = widget.results!.parallelBeginning[selectedTurnIndex];
      } else if (phase == 'Control' && selectedTurnIndex < (widget.results?.parallelMiddle.length ?? 0)) {
        parallelVal = widget.results!.parallelMiddle[selectedTurnIndex];
      } else if (phase == 'Completion' && selectedTurnIndex < (widget.results?.parallelEnd.length ?? 0)) {
        parallelVal = widget.results!.parallelEnd[selectedTurnIndex];
      }
      if (parallelVal != null) {
        valueText = '${parallelVal.toStringAsFixed(1)}°';
        scoreText = _scoreForParallelness(parallelVal).toStringAsFixed(1);
      }
    } else if (metric == 'Turn Shape' && selectedTurnIndex != null) {
      final phase = _turnShapePhase;
      double? smoothVal;
      if (phase == 'Whole Turn' && selectedTurnIndex < (widget.results?.turnShapeAvg.length ?? 0)) {
        smoothVal = widget.results!.turnShapeAvg[selectedTurnIndex];
      } else if (phase == 'Initiation' && selectedTurnIndex < (widget.results?.turnShapeBeginning.length ?? 0)) {
        smoothVal = widget.results!.turnShapeBeginning[selectedTurnIndex];
      } else if (phase == 'Control' && selectedTurnIndex < (widget.results?.turnShapeMiddle.length ?? 0)) {
        smoothVal = widget.results!.turnShapeMiddle[selectedTurnIndex];
      } else if (phase == 'Completion' && selectedTurnIndex < (widget.results?.turnShapeEnd.length ?? 0)) {
        smoothVal = widget.results!.turnShapeEnd[selectedTurnIndex];
      }
      if (smoothVal != null) {
        valueText = '${smoothVal.toStringAsFixed(1)}°/s SD';
        scoreText = _scoreForTurnShapeSD(smoothVal).toStringAsFixed(1);
      }
    }
    
    return GestureDetector(
      onTap: () => _selectCategoryAndTurn(metric, _selectedTurn),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  metric,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text('Val: $valueText', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text('Score: $scoreText', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
              if (showDropdown) ...[
                const SizedBox(height: 2),
                SizedBox(
                  height: 28,
                  child: DropdownButtonFormField<String>(
                    initialValue: metric == 'Parallel' ? _parallelPhase : _turnShapePhase,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 9, color: Colors.black),
                    dropdownColor: Colors.white,
                    menuMaxHeight: 200,
                    items: const [
                      DropdownMenuItem(value: 'Whole Turn', child: Text('Whole', style: TextStyle(fontSize: 9, color: Colors.black))),
                      DropdownMenuItem(value: 'Initiation', child: Text('Init', style: TextStyle(fontSize: 9, color: Colors.black))),
                      DropdownMenuItem(value: 'Control', child: Text('Ctrl', style: TextStyle(fontSize: 9, color: Colors.black))),
                      DropdownMenuItem(value: 'Completion', child: Text('Comp', style: TextStyle(fontSize: 9, color: Colors.black))),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _pushNavigation();
                        setState(() {
                          if (metric == 'Parallel') {
                            _parallelPhase = value;
                          } else {
                            _turnShapePhase = value;
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Add time series graph for Edge Angle or Parallel in metric modules
              if (selectedTurnIndex != null && (metric == 'Edge Angle' || metric == 'Parallel')) ...[
                SizedBox(
                  height: 120,
                  child: _buildTimeSeriesGraphForMetric(metric, selectedTurnIndex),
                ),
                const SizedBox(height: 8),
              ],
              if (selectedTurnIndex != null) ...[
                SizedBox(
                  height: 80,
                  child: DotPlot(
                    values: _getValuesForMetric(
                      metric,
                      metric == 'Parallel' ? _parallelPhase : (metric == 'Turn Shape' ? _turnShapePhase : 'Whole Turn'),
                    ),
                    highlightIndex: selectedTurnIndex,
                    optimalValue: _getOptimalForCategory(metric),
                    units: _getUnitsForCategory(metric),
                    height: 80,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTurn() {
    // Extract turn index from _selectedTurn (e.g., "Turn 3" -> 2)
    int? selectedTurnIndex;
    if (_selectedTurn != 'All Turns') {
      final match = RegExp(r'Turn (\d+)').firstMatch(_selectedTurn);
      if (match != null) {
        selectedTurnIndex = int.parse(match.group(1)!) - 1;
      }
    }
    
    String valueText = '—';
    String scoreText = '—';
    if (_selectedCategory == 'Turn Duration' && selectedTurnIndex != null && selectedTurnIndex < (widget.results?.turnDurationsSeconds.length ?? 0)) {
      final x = widget.results!.turnDurationsSeconds[selectedTurnIndex];
      valueText = '${x.toStringAsFixed(3)}s';
      scoreText = _scoreForDuration(x).toStringAsFixed(1);
    } else if (_selectedCategory == 'Edge Angle' && selectedTurnIndex != null && selectedTurnIndex < (widget.results?.edgeAngles.length ?? 0)) {
      final x = widget.results!.edgeAngles[selectedTurnIndex];
      valueText = '${x.toStringAsFixed(1)}°';
      scoreText = _scoreForEdgeAngle(x).toStringAsFixed(1);
    } else if (_selectedCategory == 'Parallel' && selectedTurnIndex != null) {
      final phase = _parallelPhase;
      double? val;
      if (phase == 'Whole Turn' && selectedTurnIndex < (widget.results?.parallelAvg.length ?? 0)) {
        val = widget.results!.parallelAvg[selectedTurnIndex];
      } else if (phase == 'Initiation' && selectedTurnIndex < (widget.results?.parallelBeginning.length ?? 0)) {
        val = widget.results!.parallelBeginning[selectedTurnIndex];
      } else if (phase == 'Control' && selectedTurnIndex < (widget.results?.parallelMiddle.length ?? 0)) {
        val = widget.results!.parallelMiddle[selectedTurnIndex];
      } else if (phase == 'Completion' && selectedTurnIndex < (widget.results?.parallelEnd.length ?? 0)) {
        val = widget.results!.parallelEnd[selectedTurnIndex];
      }
      if (val != null) {
        valueText = '${val.toStringAsFixed(1)}°';
        scoreText = _scoreForParallelness(val).toStringAsFixed(1);
      }
    } else if (_selectedCategory == 'Turn Shape' && selectedTurnIndex != null) {
      final phase = _turnShapePhase;
      double? val;
      if (phase == 'Whole Turn' && selectedTurnIndex < (widget.results?.turnShapeAvg.length ?? 0)) {
        val = widget.results!.turnShapeAvg[selectedTurnIndex];
      } else if (phase == 'Initiation' && selectedTurnIndex < (widget.results?.turnShapeBeginning.length ?? 0)) {
        val = widget.results!.turnShapeBeginning[selectedTurnIndex];
      } else if (phase == 'Control' && selectedTurnIndex < (widget.results?.turnShapeMiddle.length ?? 0)) {
        val = widget.results!.turnShapeMiddle[selectedTurnIndex];
      } else if (phase == 'Completion' && selectedTurnIndex < (widget.results?.turnShapeEnd.length ?? 0)) {
        val = widget.results!.turnShapeEnd[selectedTurnIndex];
      }
      if (val != null) {
        valueText = '${val.toStringAsFixed(1)}°/s';
        scoreText = _scoreForTurnShapeSD(val).toStringAsFixed(1);
      }
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category, Value, and Score all in one line with same prominent text size
                  Row(
                    children: [
                      Text(
                        '$_selectedCategory: ',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        valueText,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      const Text(
                        ' | Score: ',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        scoreText,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Add time series graph for Edge Angle, Parallel, or Turn Shape
                  if (selectedTurnIndex != null && (_selectedCategory == 'Edge Angle' || _selectedCategory == 'Parallel' || _selectedCategory == 'Turn Shape')) ...[
                    SizedBox(
                      height: 180,
                      child: _buildTimeSeriesGraph(selectedTurnIndex),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (selectedTurnIndex != null) ...[
                    DotPlot(
                      values: _getValuesForCategory(
                        _selectedCategory,
                        _selectedCategory == 'Parallel' ? _parallelPhase : (_selectedCategory == 'Turn Shape' ? _turnShapePhase : 'Whole Turn'),
                      ),
                      highlightIndex: selectedTurnIndex,
                      optimalValue: _getOptimalForCategory(_selectedCategory),
                      units: _getUnitsForCategory(_selectedCategory),
                      height: 180,  // This is now a minimum, DotPlot will calculate actual height
                    ),
                  ] else ...[
                    const Text('[No turn selected]', style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSeriesGraph(int turnIndex) {
    if (_selectedCategory == 'Edge Angle') {
      return _buildEdgeAngleGraph(turnIndex);
    } else if (_selectedCategory == 'Parallel') {
      return _buildParallelnessGraph(turnIndex);
    } else if (_selectedCategory == 'Turn Shape') {
      return _buildTurnShapeGraph(turnIndex);
    }
    return const SizedBox();
  }

  Widget _buildTimeSeriesGraphForMetric(String metric, int turnIndex) {
    if (metric == 'Edge Angle') {
      return _buildEdgeAngleGraph(turnIndex);
    } else if (metric == 'Parallel') {
      return _buildParallelnessGraph(turnIndex);
    } else if (metric == 'Turn Shape') {
      return _buildTurnShapeGraph(turnIndex);
    }
    return const SizedBox();
  }

  Widget _buildEdgeAngleGraph(int turnIndex) {
    final processedLeft = widget.results?.processedLeftSamples as List<ImuSample>?;
    final processedRight = widget.results?.processedRightSamples as List<ImuSample>?;
    final segments = widget.results?.segments as List<TurnSegment>?;

    if (processedLeft == null || processedRight == null || segments == null || turnIndex >= segments.length) {
      return const SizedBox();
    }

    final segment = segments[turnIndex];
    final dataPoints = <GraphPoint>[];

    // Get samples for this turn and plot max(left.pitch, right.pitch) over time
    for (int i = segment.startIndexLeft; i <= segment.endIndexLeft && i < processedLeft.length; i++) {
      final rightIndex = segment.startIndexRight + (i - segment.startIndexLeft);
      
      if (rightIndex >= segment.startIndexRight && rightIndex <= segment.endIndexRight && rightIndex < processedRight.length) {
        final leftSample = processedLeft[i];
        final rightSample = processedRight[rightIndex];
        final timeSec = leftSample.timestamp.difference(segment.startTime).inMicroseconds / 1000000.0;
        final maxPitch = math.max(leftSample.pitch.abs(), rightSample.pitch.abs());
        dataPoints.add(GraphPoint(timeSec, maxPitch));
      }
    }

    return TimeSeriesGraph(
      dataPoints: dataPoints,
      optimalValue: 45.0,
      yAxisLabel: 'Edge Angle (°)',
      durationSeconds: segment.durationSeconds,
      height: 120,
    );
  }

  Widget _buildTurnShapeGraph(int turnIndex) {
    final processedLeft = widget.results?.processedLeftSamples as List<ImuSample>?;
    final processedRight = widget.results?.processedRightSamples as List<ImuSample>?;
    final segments = widget.results?.segments as List<TurnSegment>?;

    if (processedLeft == null || processedRight == null || segments == null || turnIndex >= segments.length) {
      return const SizedBox();
    }

    final segment = segments[turnIndex];
    final phase = _turnShapePhase;
    
    // Determine time range based on selected phase
    int startIdx, endIdx;
    double sectionDuration;
    double optimalLineValue;

    final totalSamples = segment.endIndexLeft - segment.startIndexLeft + 1;
    final samplesPerThird = (totalSamples / 3.0).round();

    if (phase == 'Whole Turn') {
      startIdx = segment.startIndexLeft;
      endIdx = segment.endIndexLeft;
      sectionDuration = segment.durationSeconds;
      optimalLineValue = segment.avgTurnShapeSD;
    } else {
      double thirdDuration = segment.durationSeconds / 3.0;
      
      if (phase == 'Initiation') {
        startIdx = segment.startIndexLeft;
        endIdx = segment.startIndexLeft + samplesPerThird - 1;
        sectionDuration = thirdDuration;
        optimalLineValue = segment.beginningTurnShapeSD;
      } else if (phase == 'Control') {
        startIdx = segment.startIndexLeft + samplesPerThird;
        endIdx = segment.startIndexLeft + 2 * samplesPerThird - 1;
        sectionDuration = thirdDuration;
        optimalLineValue = segment.middleTurnShapeSD;
      } else { // Completion
        startIdx = segment.startIndexLeft + 2 * samplesPerThird;
        endIdx = segment.endIndexLeft;
        sectionDuration = thirdDuration;
        optimalLineValue = segment.endTurnShapeSD;
      }
    }

    final dataPoints = <GraphPoint>[];
    final sectionStartTime = processedLeft[startIdx].timestamp;

    // Calculate angular velocity for this section
    for (int i = startIdx; i <= endIdx && i < processedLeft.length; i++) {
      final rightIndex = segment.startIndexRight + (i - segment.startIndexLeft);
      
      if (rightIndex >= segment.startIndexRight && rightIndex <= segment.endIndexRight && rightIndex < processedRight.length) {
        // Calculate average angular velocity magnitude at this point
        final leftSample = processedLeft[i];
        final rightSample = processedRight[rightIndex];
        final timeSec = leftSample.timestamp.difference(sectionStartTime).inMicroseconds / 1000000.0;
        
        // Average of left and right angular velocity magnitudes
        final leftAngVel = math.sqrt(leftSample.gx * leftSample.gx + leftSample.gy * leftSample.gy + leftSample.gz * leftSample.gz);
        final rightAngVel = math.sqrt(rightSample.gx * rightSample.gx + rightSample.gy * rightSample.gy + rightSample.gz * rightSample.gz);
        final avgAngVel = (leftAngVel + rightAngVel) / 2.0;
        
        dataPoints.add(GraphPoint(timeSec, avgAngVel));
      }
    }

    return TimeSeriesGraph(
      dataPoints: dataPoints,
      optimalValue: optimalLineValue,
      yAxisLabel: 'Angular Velocity (°/s)',
      durationSeconds: sectionDuration,
      height: 120,
    );
  }

  Widget _buildParallelnessGraph(int turnIndex) {
    final processedLeft = widget.results?.processedLeftSamples as List<ImuSample>?;
    final processedRight = widget.results?.processedRightSamples as List<ImuSample>?;
    final segments = widget.results?.segments as List<TurnSegment>?;

    if (processedLeft == null || processedRight == null || segments == null || turnIndex >= segments.length) {
      return const SizedBox();
    }

    final segment = segments[turnIndex];
    final phase = _parallelPhase;
    
    // Determine time range based on selected phase
    int startIdx, endIdx;
    double sectionDuration;
    double optimalLineValue;

    final totalSamples = segment.endIndexLeft - segment.startIndexLeft + 1;
    final samplesPerThird = (totalSamples / 3.0).round();

    if (phase == 'Whole Turn') {
      startIdx = segment.startIndexLeft;
      endIdx = segment.endIndexLeft;
      sectionDuration = segment.durationSeconds;
      optimalLineValue = segment.avgParallelness;
    } else {
      double thirdDuration = segment.durationSeconds / 3.0;
      
      if (phase == 'Initiation') {
        startIdx = segment.startIndexLeft;
        endIdx = segment.startIndexLeft + samplesPerThird - 1;
        sectionDuration = thirdDuration;
        optimalLineValue = segment.beginningParallelness;
      } else if (phase == 'Control') {
        startIdx = segment.startIndexLeft + samplesPerThird;
        endIdx = segment.startIndexLeft + 2 * samplesPerThird - 1;
        sectionDuration = thirdDuration;
        optimalLineValue = segment.middleParallelness;
      } else { // Completion
        startIdx = segment.startIndexLeft + 2 * samplesPerThird;
        endIdx = segment.endIndexLeft;
        sectionDuration = thirdDuration;
        optimalLineValue = segment.endParallelness;
      }
    }

    final dataPoints = <GraphPoint>[];
    final sectionStartTime = processedLeft[startIdx].timestamp;

    // Get samples for this section and plot |left.yaw - right.yaw|
    for (int i = startIdx; i <= endIdx && i < processedLeft.length; i++) {
      final rightIndex = segment.startIndexRight + (i - segment.startIndexLeft);
      
      if (rightIndex >= segment.startIndexRight && rightIndex <= segment.endIndexRight && rightIndex < processedRight.length) {
        final leftSample = processedLeft[i];
        final rightSample = processedRight[rightIndex];
        final timeSec = leftSample.timestamp.difference(sectionStartTime).inMicroseconds / 1000000.0;
        final parallelness = (leftSample.yaw - rightSample.yaw).abs();
        dataPoints.add(GraphPoint(timeSec, parallelness));
      }
    }

    return TimeSeriesGraph(
      dataPoints: dataPoints,
      optimalValue: optimalLineValue,
      yAxisLabel: 'Parallelness (°)',
      durationSeconds: sectionDuration,
      height: 120,
    );
  }
}
