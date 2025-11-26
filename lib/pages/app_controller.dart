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
  final List<Widget> _runPages = [];
  
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
      final pageKey = UniqueKey();
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
      });
    }
    
    // Hide connection overlay
    setState(() {
      _showConnectionOverlay = false;
    });
  }

  void _onSensorsDisconnected() {
    // Show connection overlay (preserve all run pages)
    setState(() {
      _showConnectionOverlay = true;
      _showArrows = false;
    });
  }

  void _addNewRunPage() {
    final pageKey = UniqueKey();
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
