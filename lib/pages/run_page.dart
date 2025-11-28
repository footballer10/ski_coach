import 'dart:async';
import 'package:flutter/material.dart';
import '../models/imu_sample.dart';
import '../services/segmentation.dart';
import '../widgets/results_view.dart';

/// Single page that handles the full run lifecycle:
/// recording → processing → results
class RunPage extends StatefulWidget {
  final dynamic bleMgr;
  final String leftId;
  final String rightId;
  final VoidCallback onRecordAgain;
  final VoidCallback onDisconnect;
  final VoidCallback? onResultsShown;
  final VoidCallback? onReconnected;
  final bool autoStart;

  const RunPage({
    super.key,
    required this.bleMgr,
    required this.leftId,
    required this.rightId,
    required this.onRecordAgain,
    required this.onDisconnect,
    this.onResultsShown,
    this.onReconnected,
    this.autoStart = false,
  });

  @override
  State<RunPage> createState() => _RunPageState();
}

enum RunState { recording, processing, results }

class _RunPageState extends State<RunPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  RunState _state = RunState.recording;
  StreamSubscription<Map<String, double>>? _leftSub;
  StreamSubscription<Map<String, double>>? _rightSub;
  Map<String, double>? _leftLatest;
  Map<String, double>? _rightLatest;
  bool _recording = false;
  Map<String, dynamic>? _analysisResults;
  
  // Watchdog timers to detect sensor disconnection
  Timer? _leftWatchdog;
  Timer? _rightWatchdog;
  DateTime? _lastLeftData;
  DateTime? _lastRightData;
  bool _disconnectHandled = false; // Prevent multiple disconnect triggers
  bool _disconnectedWhileRecording = false; // Track if disconnect happened during recording
  static const _dataTimeout = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _subscribeToSamples();
    _startWatchdogs();
    
    // Auto-start recording if requested
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startRecording();
        }
      });
    }
    
    // Register reconnect callback
    widget.onReconnected?.call();
  }

  @override
  void didUpdateWidget(RunPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if we just reconnected (new bleMgr/IDs while disconnect flag is set)
    if (_disconnectedWhileRecording && 
        (widget.bleMgr != oldWidget.bleMgr || 
         widget.leftId != oldWidget.leftId || 
         widget.rightId != oldWidget.rightId)) {
      debugPrint('🎿 RunPage: Detected reconnect after recording disconnect, resetting to fresh recording state');
      _resetToRecording();
    }
  }

  @override
  void dispose() {
    _leftSub?.cancel();
    _rightSub?.cancel();
    _leftWatchdog?.cancel();
    _rightWatchdog?.cancel();
    super.dispose();
  }
  
  void _startWatchdogs() {
    _leftWatchdog?.cancel();
    _rightWatchdog?.cancel();
    
    // Check for left sensor data timeout every second
    _leftWatchdog = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _disconnectHandled) {
        timer.cancel();
        return;
      }
      if (_lastLeftData != null) {
        final timeSinceData = DateTime.now().difference(_lastLeftData!);
        if (timeSinceData > _dataTimeout && !_disconnectHandled) {
          _disconnectHandled = true; // Set flag immediately, atomically
          debugPrint('🎿 RunPage: Watchdog set _disconnectHandled = true');
          debugPrint('🎿 RunPage: Watchdog about to call _handleSensorDisconnect (mounted=$mounted, _disconnectHandled=$_disconnectHandled)');
          timer.cancel();
          debugPrint('🎿 RunPage: Left sensor timeout - no data for ${timeSinceData.inSeconds}s');
          _handleSensorDisconnect('Left sensor disconnected (no data)');
        }
      }
    });
    
    // Check for right sensor data timeout every second
    _rightWatchdog = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _disconnectHandled) {
        timer.cancel();
        return;
      }
      if (_lastRightData != null) {
        final timeSinceData = DateTime.now().difference(_lastRightData!);
        if (timeSinceData > _dataTimeout && !_disconnectHandled) {
          _disconnectHandled = true; // Set flag immediately, atomically
          debugPrint('🎿 RunPage: Watchdog set _disconnectHandled = true');
          debugPrint('🎿 RunPage: Watchdog about to call _handleSensorDisconnect (mounted=$mounted, _disconnectHandled=$_disconnectHandled)');
          timer.cancel();
          debugPrint('🎿 RunPage: Right sensor timeout - no data for ${timeSinceData.inSeconds}s');
          _handleSensorDisconnect('Right sensor disconnected (no data)');
        }
      }
    });
  }

  void _subscribeToSamples() {
    final leftStream = widget.bleMgr.sampleStream(widget.leftId);
    final rightStream = widget.bleMgr.sampleStream(widget.rightId);

    if (leftStream != null) {
      _leftSub = leftStream.listen(
        (s) {
          if (mounted) {
            setState(() => _leftLatest = s);
            _lastLeftData = DateTime.now();
          }
        },
        onDone: () {
          if (mounted) {
            if (!_disconnectHandled) {
              _disconnectHandled = true;
              debugPrint('🎿 RunPage: Left stream onDone set _disconnectHandled = true');
            }
            debugPrint('🎿 RunPage: Left sensor disconnected');
            _handleSensorDisconnect('Left sensor disconnected');
          }
        },
        onError: (error) {
          if (mounted) {
            if (!_disconnectHandled) {
              _disconnectHandled = true;
              debugPrint('🎿 RunPage: Left stream onError set _disconnectHandled = true');
            }
            debugPrint('🎿 RunPage: Left sensor error: $error');
            _handleSensorDisconnect('Left sensor connection error');
          }
        },
      );
    }

    if (rightStream != null) {
      _rightSub = rightStream.listen(
        (s) {
          if (mounted) {
            setState(() => _rightLatest = s);
            _lastRightData = DateTime.now();
          }
        },
        onDone: () {
          if (mounted) {
            if (!_disconnectHandled) {
              _disconnectHandled = true;
              debugPrint('🎿 RunPage: Right stream onDone set _disconnectHandled = true');
            }
            debugPrint('🎿 RunPage: Right sensor disconnected');
            _handleSensorDisconnect('Right sensor disconnected');
          }
        },
        onError: (error) {
          if (mounted) {
            if (!_disconnectHandled) {
              _disconnectHandled = true;
              debugPrint('🎿 RunPage: Right stream onError set _disconnectHandled = true');
            }
            debugPrint('🎿 RunPage: Right sensor error: $error');
            _handleSensorDisconnect('Right sensor connection error');
          }
        },
      );
    }
  }

  void _handleSensorDisconnect(String message) {
    debugPrint('🎿 RunPage: _handleSensorDisconnect entered with message: $message');
    
    // Stop watchdogs
    _leftWatchdog?.cancel();
    _rightWatchdog?.cancel();
    
    // Stop recording if active
    if (_recording) {
      debugPrint('🎿 RunPage: Stopping recording due to disconnect');
      widget.bleMgr.stopRecording();
      _disconnectedWhileRecording = true;
    }
    
    // Cancel subscriptions
    _leftSub?.cancel();
    _rightSub?.cancel();
    _leftSub = null;
    _rightSub = null;
    
    // Do not overwrite current results view; just stop recording and show reconnect
    debugPrint('🎿 RunPage: Preparing reconnect overlay (preserving current page)');
    setState(() {
      _recording = false;
    });
    // Bring up reconnect modal immediately (idempotent via AppController)
    debugPrint('🎿 RunPage: About to call widget.onDisconnect()');
    widget.onDisconnect();
    debugPrint('🎿 RunPage: widget.onDisconnect() called successfully');
  }

  void _resetToRecording() {
    // Reset disconnect flags
    _disconnectHandled = false;
    _disconnectedWhileRecording = false;
    
    // Resubscribe to samples when resetting
    _subscribeToSamples();
    _startWatchdogs();
    
    setState(() {
      _state = RunState.recording;
      _recording = false;
      _analysisResults = null;
      _leftLatest = null;
      _rightLatest = null;
      _lastLeftData = null;
      _lastRightData = null;
    });
  }

  Future<void> _startRecording() async {
    // Use BleManager's built-in recording
    widget.bleMgr.startRecording();
    setState(() => _recording = true);
  }

  Future<void> _stopRecording() async {
    setState(() {
      _recording = false;
      _state = RunState.processing;
    });

    // Abort analysis if disconnect was handled or state is not recording
    if (_disconnectHandled || _state != RunState.processing) {
      debugPrint('🎿 RunPage: Analysis aborted due to disconnect or state change.');
      return;
    }

    // Get recorded data from BleManager
    final recordedData = widget.bleMgr.stopRecording();
    
    // Extract samples for each sensor
    final leftSamples = recordedData[widget.leftId] ?? [];
    final rightSamples = recordedData[widget.rightId] ?? [];

    debugPrint('🎿 RunPage: Recorded ${leftSamples.length} left, ${rightSamples.length} right samples');

    // Check for empty data
    if (leftSamples.isEmpty || rightSamples.isEmpty) {
      setState(() {
        _analysisResults = {
          'error': leftSamples.isEmpty && rightSamples.isEmpty
              ? 'No data recorded from either sensor'
              : leftSamples.isEmpty
                  ? 'No data recorded from left sensor'
                  : 'No data recorded from right sensor',
        };
        _state = RunState.results;
      });
      return;
    }

    // Segment turns using roll zero-crossings on both sensors
    List<ImuSample> leftImu = leftSamples.cast<ImuSample>();
    List<ImuSample> rightImu = rightSamples.cast<ImuSample>();
    final segments = TurnSegmentation.segment(left: leftImu, right: rightImu);
    final turnDurations = segments.map((s) => s.durationSeconds).toList();
    final edgeAngles = segments.map((s) => s.maxEdgeAngle).toList();

    debugPrint('🎿 RunPage: Segmentation complete - ${segments.length} turns, durations: $turnDurations, edges: $edgeAngles');

    // Check if no turns detected
    if (segments.isEmpty) {
      setState(() {
        _analysisResults = {
          'error': 'No turns detected. Try recording a longer run with clear turns.',
        };
        _state = RunState.results;
      });
      return;
    }

    // Simulate analysis delay
    await Future.delayed(const Duration(milliseconds: 300));

    final results = {
      'leftSampleCount': leftSamples.length,
      'rightSampleCount': rightSamples.length,
      'leftSamples': leftSamples,
      'rightSamples': rightSamples,
        'duration': leftSamples.isNotEmpty && leftSamples.length > 1
          ? leftSamples.last.timestamp.difference(leftSamples.first.timestamp).inSeconds
          : 0,
        'startTime': leftSamples.isNotEmpty ? leftSamples.first.timestamp : null,
        'turnCount': segments.length,
        'turnDurations': turnDurations,
        'edgeAngles': edgeAngles,
    };

    debugPrint('🎿 RunPage: Results prepared - turnCount=${results['turnCount']}, turnDurations=${results['turnDurations']}');

    if (!mounted) return;

    setState(() {
      _analysisResults = results;
      _state = RunState.results;
    });
    
    // Notify parent that results are shown
    widget.onResultsShown?.call();
  }

  Widget _buildRecordingView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recording Session',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSampleCard('LEFT Sensor', _leftLatest, Colors.green),
                  const SizedBox(height: 12),
                  _buildSampleCard('RIGHT Sensor', _rightLatest, Colors.blue),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_recording)
            ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.fiber_manual_record, size: 28),
              label: const Text('Start Recording', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop, size: 28),
              label: const Text('Stop Recording', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProcessingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Analyzing run data...', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    if (_analysisResults == null) return const SizedBox();

    // Check for error
    final error = _analysisResults!['error'] as String?;
    if (error != null) {
      final isSensorDisconnect = _analysisResults!['isSensorDisconnect'] == true;
      // Only show reconnect button if both sensors are NOT currently connected
      final bothConnected = widget.bleMgr.isConnected(widget.leftId) && widget.bleMgr.isConnected(widget.rightId);
      return ResultsView(
        leftSampleCount: 0,
        rightSampleCount: 0,
        leftSegments: const [],
        rightSegments: const [],
        runDurationSeconds: 0,
        runStartTime: null,
        turnCount: 0,
        turnDurationsSeconds: const [],
        errorMessage: error,
        onNewRun: _resetToRecording,
        onReconnect: isSensorDisconnect ? widget.onDisconnect : null,
        showReconnectButton: isSensorDisconnect && !bothConnected,
      );
    }

    final leftCount = _analysisResults!['leftSampleCount'] ?? 0;
    final rightCount = _analysisResults!['rightSampleCount'] ?? 0;
    final leftSegments = (_analysisResults!['leftSegments'] as List?)?.cast<List<int>>() ?? [];
    final rightSegments = (_analysisResults!['rightSegments'] as List?)?.cast<List<int>>() ?? [];
      final duration = _analysisResults!['duration'] ?? 0;
      final startTime = _analysisResults!['startTime'] as DateTime?;
    final turnCount = _analysisResults!['turnCount'] ?? 0;
    final turnDurations = (_analysisResults!['turnDurations'] as List?)?.cast<double>() ?? [];
    final edgeAngles = (_analysisResults!['edgeAngles'] as List?)?.cast<double>() ?? [];

    return ResultsView(
      leftSampleCount: leftCount,
      rightSampleCount: rightCount,
      leftSegments: leftSegments,
      rightSegments: rightSegments,
        runDurationSeconds: duration,
        runStartTime: startTime,
      turnCount: turnCount,
      turnDurationsSeconds: turnDurations,
      edgeAngles: edgeAngles,
      onNewRun: widget.onRecordAgain,
      showReconnectButton: false,
    );
  }

  Widget _buildSampleCard(String label, Map<String, double>? sample, Color color) {
    if (sample == null) {
      return Card(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Waiting for data...'),
            ],
          ),
        ),
      );
    }

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip('ax', sample['ax']),
                _chip('ay', sample['ay']),
                _chip('az', sample['az']),
                _chip('gx', sample['gx']),
                _chip('gy', sample['gy']),
                _chip('gz', sample['gz']),
                _chip('roll', sample['roll']),
                _chip('pitch', sample['pitch']),
                _chip('yaw', sample['yaw']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String key, double? val) {
    return Chip(
      label: Text('$key: ${val?.toStringAsFixed(2) ?? 'N/A'}'),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      body: _state == RunState.recording
          ? _buildRecordingView()
          : _state == RunState.processing
              ? _buildProcessingView()
              : _buildResultsView(),
    );
  }
}
