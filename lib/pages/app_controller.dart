import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'connection_page.dart';
import 'run_page.dart';
import '../models.dart';
import '../services/segmentation.dart';

/// Main controller that manages all run pages and handles connection state.
class AppController extends StatefulWidget {
  const AppController({super.key});

  @override
  State<AppController> createState() => _AppControllerState();
}

class _AppControllerState extends State<AppController> {
  final PageController _pageController = PageController();
  final List<Widget> _runPages = [];
  final List<GlobalKey<RunPageState>> _runPageKeys = [];
  final List<GlobalKey<RunPageState>> _tempErrorPageKeys = [];

  dynamic _bleMgr;
  String? _leftId;
  String? _rightId;
  bool _showConnectionOverlay = !kIsWeb;
  bool _showArrows = false;
  int _currentPage = 0;

  // Track AI processing state globally
  bool _isAnyAiProcessing = false;

  double _estimateSamplingRateHz(List<ImuSample> samples) {
    if (samples.length <= 1) return 100.0;
    final duration = samples.last.timestamp.difference(samples.first.timestamp);
    if (duration.inMilliseconds <= 0) return 100.0;
    return (samples.length - 1) * 1000.0 / duration.inMilliseconds;
  }

  List<TurnSegment> _matchSegmentsToDurations({
    required List<TurnSegment> computed,
    required List<double> expectedDurationsSeconds,
  }) {
    if (expectedDurationsSeconds.isEmpty) return computed;
    final desired = expectedDurationsSeconds.length;
    if (computed.length <= desired) return computed;
    if (computed.length == desired) return computed;

    double bestCost = double.infinity;
    int bestStart = 0;

    for (int start = 0; start <= computed.length - desired; start++) {
      double cost = 0.0;
      for (int i = 0; i < desired; i++) {
        cost +=
            (computed[start + i].durationSeconds - expectedDurationsSeconds[i])
                .abs();
      }
      if (cost < bestCost) {
        bestCost = cost;
        bestStart = start;
      }
    }

    return computed.sublist(bestStart, bestStart + desired);
  }

  List<TurnSegment>? _rebuildSegmentsForImportIfMissing(AnalysisResults results) {
    final existing = results.segments;
    final hasExisting = existing is List && existing.isNotEmpty;
    if (hasExisting) return null;

    final leftRaw = results.processedLeftSamples;
    final rightRaw = results.processedRightSamples;
    if (leftRaw is! List || rightRaw is! List) return null;

    final left = leftRaw.whereType<ImuSample>().toList();
    final right = rightRaw.whereType<ImuSample>().toList();
    if (left.isEmpty || right.isEmpty) return null;

    final samplingRate = _estimateSamplingRateHz(left);

    // processedRightSamples already have yaw offset applied during original
    // analysis, so use yawOffset=0 to avoid double-applying.
    final computed = TurnSegmentation.segment(
      leftSamples: left,
      rightSamples: right,
      yawOffset: 0.0,
      samplingRate: samplingRate,
    );
    if (computed.isEmpty) return null;

    return _matchSegmentsToDurations(
      computed: computed,
      expectedDurationsSeconds: results.turnDurationsSeconds,
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageChanged);
    // The web demo has no Bluetooth, so it skips the sensor screen and
    // opens straight to the sample runs.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSampleRuns());
    }
  }

  void _openSampleRuns() {
    _closeConnectionOverlay();
    _showSamplePickerWhenReady();
  }

  /// Opens the sample picker as soon as the run page has been built.
  void _showSamplePickerWhenReady([int attempt = 0]) {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final page = _runPageKeys
          .map((key) => key.currentState)
          .whereType<RunPageState>()
          .firstOrNull;
      if (page != null && page.mounted) {
        page.trySampleRun();
      } else if (attempt < 20) {
        _showSamplePickerWhenReady(attempt + 1);
      }
    });
  }


  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onSensorsConnected(dynamic bleMgr, String leftId, String rightId) {
    _bleMgr = bleMgr;
    _leftId = leftId;
    _rightId = rightId;

    // If this is the first connection, add the first run page (don't auto-start)
    if (_runPages.isEmpty) {
      final pageKey = GlobalKey<RunPageState>();
      final newPage = RunPage(
        key: pageKey,
        bleMgr: bleMgr,
        leftId: leftId,
        rightId: rightId,
        onRecordAgain: _addNewRunPage,
        onDisconnect: _onSensorsDisconnected,
        onManualReconnect: _onManualReconnectPressed,
        autoStart: false,
        onImportedRun: _addImportedRunPage, // Allow import to create new page
        isAnyAiProcessing: () => _isAnyAiProcessing,
        onAiProcessingChanged: _onAiProcessingChanged,
        onResultsShown: () {
          // Enable arrows after first results shown
          if (!_showArrows) {
            setState(() => _showArrows = true);
          }
        },
      );

      setState(() {
        _runPages.add(newPage);
        _runPageKeys.add(pageKey);
      });
    }

    // Hide connection overlay
    setState(() {
      _showConnectionOverlay = false;
    });
  }

  void _onAiProcessingChanged(bool isProcessing) {
    if (_isAnyAiProcessing == isProcessing) return; // No change
    
    setState(() {
      _isAnyAiProcessing = isProcessing;
    });
  }

  bool _reconnectOpen = false;

  void _onSensorsDisconnected() {
    if (!mounted) {
      return;
    }
    debugPrint('⚠️ Sensors disconnected');

    // Determine current page state
    final currentKey = (_currentPage >= 0 && _currentPage < _runPageKeys.length)
        ? _runPageKeys[_currentPage]
        : null;
    final currentState = currentKey?.currentState;

    if (currentState != null && currentState.mounted) {
      if (currentState.isSummaryWithValidResults) {
        // On results screen: add temporary error page to the right
        _addTemporaryDisconnectErrorPage();
      } else {
        // On recording or pre-recording: replace with error page
        currentState.showDisconnectErrorWithReconnectButton();
      }
    }
  }

  void _onManualReconnectPressed() {
    if (_reconnectOpen) {
      return;
    }
    _reconnectOpen = true;
    debugPrint('📊 Manual reconnect initiated');
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ConnectionPage(
              showCloseButton: true,
              onConnected: (bleMgr, leftId, rightId) {
                _bleMgr = bleMgr;
                _leftId = leftId;
                _rightId = rightId;
                Navigator.of(context).pop();
                // Enable arrows if not already enabled
                if (!_showArrows && _runPages.isNotEmpty) {
                  setState(() => _showArrows = true);
                }
                // After reconnect:
                // - If temporary error page(s) exist (from results), remove them
                // - If current page shows disconnect error, replace with 'Start Another Run' error
                final currentKey =
                    (_currentPage >= 0 && _currentPage < _runPageKeys.length)
                    ? _runPageKeys[_currentPage]
                    : null;
                final currentState = currentKey?.currentState;
                if (currentState != null && currentState.mounted) {
                  if (_tempErrorPageKeys.isNotEmpty) {
                    // Remove temporary error page(s) and restore results
                    _removeTemporaryErrorPages();
                  } else if (currentState.hasDisconnectError) {
                    // Replace disconnect error with 'Start Another Run' option
                    currentState.showPostReconnectErrorStartNewRun();
                  }
                }
              },
            ),
          ),
        )
        .then((_) {
          // Modal closed (either via X button or after successful reconnect)
          _reconnectOpen = false;
          // If closed via X, the error page remains unchanged (user stays on same error page)
        });
  }

  void _addTemporaryDisconnectErrorPage() {
    final pageKey = GlobalKey<RunPageState>();
    final newPage = RunPage(
      key: pageKey,
      bleMgr: _bleMgr,
      leftId: _leftId ?? '',
      rightId: _rightId ?? '',
      onRecordAgain: _addNewRunPage,
      onDisconnect: _onSensorsDisconnected,
      onManualReconnect: _onManualReconnectPressed,
      autoStart: false,
      isAnyAiProcessing: () => _isAnyAiProcessing,
      onAiProcessingChanged: _onAiProcessingChanged,
      onResultsShown: null,
    );
    int targetIndex = 0;
    setState(() {
      _runPages.add(newPage);
      _runPageKeys.add(pageKey);
      _tempErrorPageKeys.add(pageKey);
      targetIndex = _runPages.length - 1;
      _currentPage = targetIndex;
    });
    // Show disconnect error with reconnect button
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureDisconnectErrorInitialized(pageKey);
      _forceNavigateToPage(targetIndex);
    });
  }

  void _ensureDisconnectErrorInitialized(
    GlobalKey<RunPageState> key, {
    int attempt = 0,
  }) {
    if (!mounted) return;
    const maxAttempts = 12;
    final state = key.currentState;
    if (state != null && state.mounted) {
      state.showDisconnectErrorWithReconnectButton();
      return;
    }
    if (attempt >= maxAttempts) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureDisconnectErrorInitialized(key, attempt: attempt + 1);
    });
  }

  void _removeTemporaryErrorPages() {
    if (_tempErrorPageKeys.isEmpty) return;
    int targetPage = 0;
    setState(() {
      for (final key in _tempErrorPageKeys) {
        final idx = _runPageKeys.indexOf(key);
        if (idx >= 0) {
          _runPageKeys.removeAt(idx);
          _runPages.removeAt(idx);
        }
      }
      _tempErrorPageKeys.clear();
      if (_runPages.isEmpty) {
        _currentPage = 0;
      } else {
        _currentPage = _currentPage.clamp(0, _runPages.length - 1);
      }
      targetPage = _currentPage;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _forceNavigateToPage(targetPage);
    });
  }

  void _forceNavigateToPage(int pageIndex, {int attempt = 0}) {
    if (!mounted) return;
    if (_runPages.isEmpty) return;
    const maxAttempts = 12;
    final clampedIndex = pageIndex.clamp(0, _runPages.length - 1);
    if (!_pageController.hasClients) {
      if (attempt >= maxAttempts) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _forceNavigateToPage(clampedIndex, attempt: attempt + 1);
      });
      return;
    }

    final current = _pageController.page?.round();
    if (current == clampedIndex) {
      return;
    }

    try {
      _pageController.jumpToPage(clampedIndex);
    } catch (err) {
      debugPrint('⚠️ jumpToPage error: $err');
    }

    if (attempt >= maxAttempts) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceNavigateToPage(clampedIndex, attempt: attempt + 1);
    });
  }

  void _addNewRunPage() {
    final pageKey = GlobalKey<RunPageState>();
    final newPage = RunPage(
      key: pageKey,
      bleMgr: _bleMgr,
      leftId: _leftId!,
      rightId: _rightId!,
      onRecordAgain: _addNewRunPage,
      onDisconnect: _onSensorsDisconnected,
      onManualReconnect: _onManualReconnectPressed,
      autoStart: true,
      onImportedRun: _addImportedRunPage,
      isAnyAiProcessing: () => _isAnyAiProcessing,
      onAiProcessingChanged: _onAiProcessingChanged,
      onResultsShown: () {
        // Enable arrows after first results shown
        if (!_showArrows) {
          setState(() => _showArrows = true);
        }
      },
    );

    final targetPage = _runPages.length;

    setState(() {
      _runPages.add(newPage);
      _runPageKeys.add(pageKey);
    });

    // Jump to the new page and update current page tracker immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && mounted) {
        _pageController.jumpToPage(targetPage);
        // Ensure page indicator updates immediately
        setState(() {
          _currentPage = targetPage;
        });
      }
    });
  }

  void _addImportedRunPage(dynamic importedRun) {
    // importedRun is an ExportedRun object
    final exportedRun = (importedRun as ExportedRun).applyTurnRangeIfPresent();
    final results = exportedRun.analysisResults;

    final rebuiltSegments = _rebuildSegmentsForImportIfMissing(results);
    final segmentsForGraphs = (results.segments is List &&
            (results.segments as List).isNotEmpty)
        ? results.segments
        : rebuiltSegments;
    
    // Convert to analysis results format
    final analysisResults = {
      'leftSampleCount': results.leftSampleCount,
      'rightSampleCount': results.rightSampleCount,
      'leftSegments': results.leftSegments,
      'rightSegments': results.rightSegments,
      'duration': results.runDurationSeconds,
        'startTime': (segmentsForGraphs is List<TurnSegment> &&
            segmentsForGraphs.isNotEmpty)
          ? segmentsForGraphs.first.startTime
          : results.runStartTime,
      'turnCount': results.turnCount,
      'turnDurations': results.turnDurationsSeconds,
      'edgeAngles': results.edgeAngles,
      'turnDirections': results.turnDirections,
      'parallelBeginning': results.parallelBeginning,
      'parallelMiddle': results.parallelMiddle,
      'parallelEnd': results.parallelEnd,
      'parallelAvg': results.parallelAvg,
      'turnShapeBeginning': results.turnShapeBeginning,
      'turnShapeMiddle': results.turnShapeMiddle,
      'turnShapeEnd': results.turnShapeEnd,
      'turnShapeAvg': results.turnShapeAvg,
      'turnSymmetryRatio': results.turnSymmetryRatio,
      'turnSymmetryBiggerSide': results.turnSymmetryBiggerSide,
      'turnSymmetryScore': results.turnSymmetryScore,
      'processedLeftSamples': results.processedLeftSamples,
      'processedRightSamples': results.processedRightSamples,
      'segments': segmentsForGraphs,
    };
    
    final pageKey = GlobalKey<RunPageState>();
    final newPage = RunPage(
      key: pageKey,
      bleMgr: _bleMgr,
      leftId: _leftId ?? '',
      rightId: _rightId ?? '',
      onRecordAgain: _addNewRunPage,
      onDisconnect: _onSensorsDisconnected,
      onManualReconnect: _onManualReconnectPressed,
      autoStart: false,
      onImportedRun: _addImportedRunPage, // All results pages create new page on import
      isAnyAiProcessing: () => _isAnyAiProcessing,
      onAiProcessingChanged: _onAiProcessingChanged,
      initialState: RunState.results, // Start directly in results state
      initialResults: analysisResults,
      initialImportedName: exportedRun.runName,
      initialAiFeedback: exportedRun.aiFeedback,
      onResultsShown: () {
        if (!_showArrows) {
          setState(() => _showArrows = true);
        }
      },
    );

    final targetPage = _runPages.length;

    setState(() {
      _runPages.add(newPage);
      _runPageKeys.add(pageKey);
    });

    // Jump to the new page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && mounted) {
        _pageController.jumpToPage(targetPage);
        setState(() {
          _currentPage = targetPage;
        });
      }
    });
  }

  /// Hides the startup connection screen, creating a sensorless run page
  /// if none exists yet.
  void _closeConnectionOverlay() {
    setState(() {
      _showConnectionOverlay = false;
      // If no run pages exist yet, create the first one without sensors
      if (_runPages.isEmpty) {
        final pageKey = GlobalKey<RunPageState>();
        final newPage = RunPage(
          key: pageKey,
          bleMgr: null,
          leftId: '',
          rightId: '',
          onRecordAgain: _addNewRunPage,
          onDisconnect: _onSensorsDisconnected,
          onManualReconnect: _onManualReconnectPressed,
          autoStart: false,
          onAiProcessingChanged: _onAiProcessingChanged,
          onImportedRun: _addImportedRunPage,
          isAnyAiProcessing: () => _isAnyAiProcessing,
        );
        _runPages.add(newPage);
        _runPageKeys.add(pageKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Run pages in PageView
          if (_runPages.isNotEmpty)
            PageView(controller: _pageController, children: _runPages)
          else
            const SizedBox(),

          // Connection overlay (shown on startup and when disconnected)
          if (_showConnectionOverlay)
            Container(
              color: Colors.white,
              child: ConnectionPage(
                onConnected: _onSensorsConnected,
                onClose: _closeConnectionOverlay,
                onTrySample: _openSampleRuns,
              ),
            ),

          // Page indicator dots (only when runs exist and not on connection screen)
          if (_runPages.isNotEmpty && !_showConnectionOverlay)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_runPages.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.blue
                              : Colors.grey.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
