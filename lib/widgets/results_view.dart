import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:ski_coach/services/scoring.dart';
import 'package:ski_coach/models/analysis_results.dart';

/// Displays run analysis results with navigation through categories and turns
class ResultsView extends StatefulWidget {
  final AnalysisResults? results; // null if showing error
  final String? errorMessage;
  final VoidCallback onNewRun;
  final VoidCallback? onReconnect;
  final bool showReconnectButton;
  final bool showTryAgainButton;

  const ResultsView({
    super.key,
    this.results,
    this.errorMessage,
    required this.onNewRun,
    this.onReconnect,
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
  String _categoryPageThird = 'Whole Turn'; // For Parallel/Smoothness category page
  // Phase selections per current turn
  String _parallelPhase = 'Whole Turn';
  String _smoothnessPhase = 'Whole Turn';
  
  // Navigation history stack
  final List<Map<String, String>> _navigationHistory = [];
  
  final List<String> _categories = const [
    'All Categories',
    'Turn Duration',
    'Edge Angle',
    'Parallel Ski Control',
    'Smoothness',
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
  
  double _scoreForSmoothnessSD(double x) {
    return Scoring.smoothness(x);
  }

  void _pushNavigation() {
    _navigationHistory.add({
      'category': _selectedCategory,
      'turn': _selectedTurn,
      'categoryPageThird': _categoryPageThird,
      'parallelPhase': _parallelPhase,
      'smoothnessPhase': _smoothnessPhase,
    });
  }

  void _navigateBack() {
    if (_navigationHistory.isEmpty) return;
    final prev = _navigationHistory.removeLast();
    setState(() {
      _selectedCategory = prev['category']!;
      _selectedTurn = prev['turn']!;
      _categoryPageThird = prev['categoryPageThird']!;
      _parallelPhase = prev['parallelPhase']!;
      _smoothnessPhase = prev['smoothnessPhase']!;
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
      _smoothnessPhase = 'Whole Turn';
    });
  }
  
  void _selectCategoryAndTurn(String category, String turn) {
    _pushNavigation();
    setState(() {
      _selectedCategory = category;
      _selectedTurn = turn;
      _parallelPhase = 'Whole Turn';
      _smoothnessPhase = 'Whole Turn';
    });
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
      ],
    );
  }

  Widget _buildNavigationBar() {
    final showThirdDropdown = (_selectedCategory == 'Parallel Ski Control' || _selectedCategory == 'Smoothness') && _selectedTurn == 'All Turns';
    final showThirdDropdownCategoryTurn = (_selectedCategory == 'Parallel Ski Control' || _selectedCategory == 'Smoothness') && _selectedTurn != 'All Turns';
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          children: [
          if (_navigationHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _navigateBack,
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
                initialValue: _selectedCategory == 'Parallel Ski Control' ? _parallelPhase : _smoothnessPhase,
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
                  DropdownMenuItem(value: 'First Third', child: Text('First Third', style: TextStyle(fontSize: 12, color: Colors.black))),
                  DropdownMenuItem(value: 'Middle Third', child: Text('Middle Third', style: TextStyle(fontSize: 12, color: Colors.black))),
                  DropdownMenuItem(value: 'Final Third', child: Text('Final Third', style: TextStyle(fontSize: 12, color: Colors.black))),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _pushNavigation();
                    setState(() {
                      if (_selectedCategory == 'Parallel Ski Control') {
                        _parallelPhase = value;
                      } else {
                        _smoothnessPhase = value;
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
                  DropdownMenuItem(value: 'First Third', child: Text('First Third', style: TextStyle(fontSize: 12, color: Colors.black))),
                  DropdownMenuItem(value: 'Middle Third', child: Text('Middle Third', style: TextStyle(fontSize: 12, color: Colors.black))),
                  DropdownMenuItem(value: 'Final Third', child: Text('Final Third', style: TextStyle(fontSize: 12, color: Colors.black))),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: List.generate((widget.results?.turnCount ?? 0) > 0 ? (widget.results?.turnCount ?? 0) : 5, (i) {
              final turnLabel = 'Turn ${i + 1}';
              final isSelected = _selectedTurn == turnLabel;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _selectTurn(turnLabel),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
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
                            (i < (widget.results?.turnDurationsSeconds.length ?? 0))
                              ? '${widget.results!.turnDurationsSeconds[i].toStringAsFixed(3)}s'
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
                ),
              );
            }),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCategorySummary(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: List.generate(actualTurnCount, (i) {
                  final turnLabel = 'Turn ${i + 1}';
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
                  return GestureDetector(
                    onTap: () => _selectCategoryAndTurn(_selectedCategory, turnLabel),
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Turn ${i + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            if (_selectedCategory == 'Turn Duration') ...[
                              const SizedBox(width: 8),
                              Text(
                                '$turnDuration | Score: $turnDurationScore',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                            if (_selectedCategory == 'Edge Angle') ...[
                              const SizedBox(width: 8),
                              Text(
                                '$edgeAngle | Score: $edgeAngleScore',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildDotPlot(),
        ],
      ),
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

  Widget _buildDotPlot() {
    final turnCount = widget.results?.leftSegments.length ?? 0;
    
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
            SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  '[Dot plot: $turnCount turns]',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnAllCategories() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.6,
        children: [
          _buildMetricModule('Turn Duration', 0),
          _buildMetricModule('Edge Angle', 0),
          _buildMetricModule('Parallel Ski Control', 0),
          _buildMetricModule('Smoothness', 0),
        ],
      ),
    );
  }

  Widget _buildMetricModule(String metric, int turnIndex) {
    final showDropdown = (metric == 'Parallel Ski Control' || metric == 'Smoothness');
    
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
    } else if (metric == 'Parallel Ski Control' && selectedTurnIndex != null) {
      final phase = _parallelPhase;
      double? parallelVal;
      if (phase == 'Whole Turn' && selectedTurnIndex < (widget.results?.parallelAvg.length ?? 0)) {
        parallelVal = widget.results!.parallelAvg[selectedTurnIndex];
      } else if (phase == 'First Third' && selectedTurnIndex < (widget.results?.parallelBeginning.length ?? 0)) {
        parallelVal = widget.results!.parallelBeginning[selectedTurnIndex];
      } else if (phase == 'Middle Third' && selectedTurnIndex < (widget.results?.parallelMiddle.length ?? 0)) {
        parallelVal = widget.results!.parallelMiddle[selectedTurnIndex];
      } else if (phase == 'Final Third' && selectedTurnIndex < (widget.results?.parallelEnd.length ?? 0)) {
        parallelVal = widget.results!.parallelEnd[selectedTurnIndex];
      }
      if (parallelVal != null) {
        valueText = '${parallelVal.toStringAsFixed(1)}°';
        scoreText = _scoreForParallelness(parallelVal).toStringAsFixed(1);
      }
    } else if (metric == 'Smoothness' && selectedTurnIndex != null) {
      final phase = _smoothnessPhase;
      double? smoothVal;
      if (phase == 'Whole Turn' && selectedTurnIndex < (widget.results?.smoothAvg.length ?? 0)) {
        smoothVal = widget.results!.smoothAvg[selectedTurnIndex];
      } else if (phase == 'First Third' && selectedTurnIndex < (widget.results?.smoothBeginning.length ?? 0)) {
        smoothVal = widget.results!.smoothBeginning[selectedTurnIndex];
      } else if (phase == 'Middle Third' && selectedTurnIndex < (widget.results?.smoothMiddle.length ?? 0)) {
        smoothVal = widget.results!.smoothMiddle[selectedTurnIndex];
      } else if (phase == 'Final Third' && selectedTurnIndex < (widget.results?.smoothEnd.length ?? 0)) {
        smoothVal = widget.results!.smoothEnd[selectedTurnIndex];
      }
      if (smoothVal != null) {
        valueText = '${smoothVal.toStringAsFixed(1)}°/s SD';
        scoreText = _scoreForSmoothnessSD(smoothVal).toStringAsFixed(1);
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
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Text('Val: $valueText', style: const TextStyle(fontSize: 9)),
              Text('Score: $scoreText', style: const TextStyle(fontSize: 9)),
              if (showDropdown) ...[
                const SizedBox(height: 2),
                SizedBox(
                  height: 28,
                  child: DropdownButtonFormField<String>(
                    initialValue: metric == 'Parallel Ski Control' ? _parallelPhase : _smoothnessPhase,
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
                      DropdownMenuItem(value: 'First Third', child: Text('1st', style: TextStyle(fontSize: 9, color: Colors.black))),
                      DropdownMenuItem(value: 'Middle Third', child: Text('Mid', style: TextStyle(fontSize: 9, color: Colors.black))),
                      DropdownMenuItem(value: 'Final Third', child: Text('Final', style: TextStyle(fontSize: 9, color: Colors.black))),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _pushNavigation();
                        setState(() {
                          if (metric == 'Parallel Ski Control') {
                            _parallelPhase = value;
                          } else {
                            _smoothnessPhase = value;
                          }
                        });
                      }
                    },
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
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Value: $valueText', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Score: $scoreText', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  const Text('[Dot plot]', style: TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
