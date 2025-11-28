import 'package:flutter/material.dart';
import 'connection_page.dart';
import 'run_page.dart';

/// Main controller that manages all run pages and handles connection state.
class AppController extends StatefulWidget {
  const AppController({super.key});

  @override
  State<AppController> createState() => _AppControllerState();
}

class _AppControllerState extends State<AppController> {
  final PageController _pageController = PageController();
  List<Widget> _runPages = [];
  final List<GlobalKey<RunPageState>> _runPageKeys = [];
  
  dynamic _bleMgr;
  String? _leftId;
  String? _rightId;
  bool _showConnectionOverlay = true;
  bool _showArrows = false;
  int _currentPage = 0;

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
        autoStart: false,
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

  bool _reconnectOpen = false;

  void _onSensorsDisconnected() {
    debugPrint('🎿 AppController: _onSensorsDisconnected called');
    if (!mounted) {
      debugPrint('🎿 AppController: Not mounted, skipping navigation');
      return;
    }
    if (_reconnectOpen) {
      debugPrint('🎿 AppController: Reconnect modal already open, skipping push');
      return;
    }
    _reconnectOpen = true;
    debugPrint('🎿 AppController: Pushing ConnectionPage with showCloseButton=true');
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
            // - If current page is pre-recording/recording, replace with error page offering 'Start Another Run'
            // - Summary pages: do not inject error
            final currentKey = (_currentPage >= 0 && _currentPage < _runPageKeys.length) ? _runPageKeys[_currentPage] : null;
            final currentState = currentKey?.currentState;
            if (currentState != null && currentState.mounted) {
              // If it is not already in results due to a recording disconnect, show post-reconnect error
              currentState.showPostReconnectErrorStartNewRun();
            }
            // Notify pages to resubscribe/reset guards
            _notifyRunPagesReconnected();
          },
        ),
      ),
    )
        .then((_) {
      // Modal closed (via X or after successful reconnect)
      _reconnectOpen = false;
      // If closed via X and sensors are not connected, show error with ONLY reconnect button
      try {
        final bothConnected = _bleMgr != null &&
            _leftId != null && _rightId != null &&
            _bleMgr.isConnected(_leftId) && _bleMgr.isConnected(_rightId);
        if (!bothConnected) {
          final currentKey = (_currentPage >= 0 && _currentPage < _runPageKeys.length) ? _runPageKeys[_currentPage] : null;
          final currentState = currentKey?.currentState;
          if (currentState != null && currentState.mounted) {
            currentState.showDisconnectErrorOnlyReconnect('Sensors disconnected. Please reconnect to continue.');
          }
        }
      } catch (_) {
        // If BLE manager does not expose isConnected yet, skip
      }
    });
  }

  void _notifyRunPagesReconnected() {
    for (final key in _runPageKeys) {
      key.currentState?.onSensorsReconnected();
    }
  }

  bool _anyRecordingDisconnectError() {
    for (final key in _runPageKeys) {
      final state = key.currentState;
      if (state != null && state.mounted && state.hasRecordingDisconnectError) {
        return true;
      }
    }
    return false;
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
      autoStart: true,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Run pages in PageView
          if (_runPages.isNotEmpty)
            PageView(
              controller: _pageController,
              children: _runPages,
            )
          else
            const SizedBox(),
          
          // Connection overlay (shown on startup and when disconnected)
          if (_showConnectionOverlay)
            Container(
              color: Colors.white,
              child: ConnectionPage(
                onConnected: _onSensorsConnected,
              ),
            ),
          
          // Navigation arrows (only when multiple runs exist and not on connection screen)
          if (_showArrows && _runPages.length > 1 && !_showConnectionOverlay && _currentPage > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 32, color: Colors.white),
                    onPressed: () {
                      final currentPage = _pageController.page?.round() ?? 0;
                      if (currentPage > 0) {
                        _pageController.animateToPage(
                          currentPage - 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          if (_showArrows && _runPages.length > 1 && !_showConnectionOverlay && _currentPage < _runPages.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 32, color: Colors.white),
                    onPressed: () {
                      final currentPage = _pageController.page?.round() ?? 0;
                      if (currentPage < _runPages.length - 1) {
                        _pageController.animateToPage(
                          currentPage + 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ),
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
