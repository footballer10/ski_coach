import 'package:flutter/material.dart';
import 'connection_page.dart';
import 'run_page.dart';
import 'daily_summary_page.dart';
import '../models.dart';
import '../models/daily_summary.dart';

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
  bool _showConnectionOverlay = true;
  bool _showArrows = false;
  int _currentPage = 0;

  // Track runs for daily summary
  final List<DailyRunSummary> _todaysRuns = [];
  final DateTime _sessionStartDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
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
        onRunCompleted: _recordRun,
        onFinishDay: _showDailySummary,
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

  void _recordRun(Map<String, dynamic> analysisResults) {
    // Extract scores from analysis results
    final turnCount = (analysisResults['turnCount'] as int?) ?? 0;
    final scores = analysisResults['scores'] as Map<String, dynamic>?;
    
    if (scores != null && turnCount > 0) {
      final run = DailyRunSummary(
        timestamp: DateTime.now(),
        turnCount: turnCount,
        overallScore: (scores['overall'] as num?)?.toDouble() ?? 0.0,
        durationScore: (scores['duration'] as num?)?.toDouble() ?? 0.0,
        edgeAngleScore: (scores['edgeAngle'] as num?)?.toDouble() ?? 0.0,
        parallelnessScore: (scores['parallelness'] as num?)?.toDouble() ?? 0.0,
        turnShapeScore: (scores['turnShape'] as num?)?.toDouble() ?? 0.0,
        symmetryScore: (scores['symmetry'] as num?)?.toDouble() ?? 0.0,
      );
      
      setState(() {
        _todaysRuns.add(run);
      });
    }
  }

  void _showDailySummary() {
    if (_todaysRuns.isEmpty) {
      // Show message if no runs recorded
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No runs recorded today'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 10, left: 10, right: 10),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
      return;
    }

    final summaryData = DailySummaryData(
      date: _sessionStartDate,
      runs: List.from(_todaysRuns),
    );

    final summaryPage = DailySummaryPage(
      summaryData: summaryData,
      onDisconnect: _onSensorsDisconnected,
    );

    final targetPage = _runPages.length;

    setState(() {
      _runPages.add(summaryPage);
    });

    // Navigate to summary page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && mounted) {
        _pageController.jumpToPage(targetPage);
        setState(() {
          _currentPage = targetPage;
        });
      }
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
      onRunCompleted: _recordRun,
      onFinishDay: _showDailySummary,
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
      onRunCompleted: _recordRun,
      onFinishDay: _showDailySummary,
      onImportedRun: _addImportedRunPage,
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
    final exportedRun = importedRun as ExportedRun;
    final results = exportedRun.analysisResults;
    
    // Convert to analysis results format
    final analysisResults = {
      'leftSampleCount': results.leftSampleCount,
      'rightSampleCount': results.rightSampleCount,
      'leftSegments': results.leftSegments,
      'rightSegments': results.rightSegments,
      'duration': results.runDurationSeconds,
      'startTime': results.runStartTime,
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
      'turnSymmetryScore': results.turnSymmetryScore,
      'processedLeftSamples': results.processedLeftSamples,
      'processedRightSamples': results.processedRightSamples,
      'segments': results.segments,
    };
    
    final pageKey = GlobalKey<RunPageState>();
    final newPage = RunPage(
      key: pageKey,
      bleMgr: _bleMgr,
      leftId: _leftId!,
      rightId: _rightId!,
      onRecordAgain: _addNewRunPage,
      onDisconnect: _onSensorsDisconnected,
      onManualReconnect: _onManualReconnectPressed,
      autoStart: false,
      // No onImportedRun callback - imported results pages replace locally
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
              child: ConnectionPage(onConnected: _onSensorsConnected),
            ),

          // Navigation arrows removed per user request

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
