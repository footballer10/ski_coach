import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ski_coach/services/scoring.dart';
import 'package:ski_coach/models/analysis_results.dart';
import '../models/imu_sample.dart';
import '../services/ble_manager.dart';
import '../services/segmentation.dart';
import '../services/imu_preprocessor.dart';
import '../services/metrics/symmetry_calculator.dart';
import '../widgets/results_view.dart';
import '../services/ai_mode.dart';

/// Single page that handles the full run lifecycle:
/// recording → processing → results
class RunPage extends StatefulWidget {
  final dynamic bleMgr;
  final String leftId;
  final String rightId;
  final VoidCallback onRecordAgain;
  final VoidCallback onDisconnect;
  final VoidCallback? onManualReconnect;
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
    this.onManualReconnect,
    this.onResultsShown,
    this.onReconnected,
    this.autoStart = false,
  });

  @override
  State<RunPage> createState() => RunPageState();
}

enum RunState { recording, processing, results }

 class RunPageState extends State<RunPage> with AutomaticKeepAliveClientMixin {
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
  static const _dataTimeout = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    
    // Register which device is left and which is right for calibration
    widget.bleMgr.registerDeviceSide(widget.leftId, 'left');
    widget.bleMgr.registerDeviceSide(widget.rightId, 'right');
    
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
          _disconnectHandled = true;
          timer.cancel();
          debugPrint('⚠️ Left sensor timeout (${timeSinceData.inSeconds}s)');
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
          _disconnectHandled = true;
          timer.cancel();
          debugPrint('⚠️ Right sensor timeout (${timeSinceData.inSeconds}s)');
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
            }
            debugPrint('⚠️ Left sensor disconnected');
            _handleSensorDisconnect('Left sensor disconnected');
          }
        },
        onError: (error) {
          if (mounted) {
            if (!_disconnectHandled) {
              _disconnectHandled = true;
            }
            debugPrint('⚠️ Left sensor error: $error');
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
            }
            debugPrint('⚠️ Right sensor disconnected');
            _handleSensorDisconnect('Right sensor disconnected');
          }
        },
        onError: (error) {
          if (mounted) {
            if (!_disconnectHandled) {
              _disconnectHandled = true;
            }
            debugPrint('⚠️ Right sensor error: $error');
            _handleSensorDisconnect('Right sensor connection error');
          }
        },
      );
    }
  }

  void _handleSensorDisconnect(String message) {
    debugPrint('⚠️ Disconnect: $message');
    
    // Stop watchdogs
    _leftWatchdog?.cancel();
    _rightWatchdog?.cancel();
    
    // Stop recording if active
    if (_recording) {
      widget.bleMgr.stopRecording();
    }
    
    // Cancel subscriptions
    _leftSub?.cancel();
    _rightSub?.cancel();
    _leftSub = null;
    _rightSub = null;
    
    // Notify controller to handle disconnect (will show error UI)
    widget.onDisconnect();
  }

  // No auto-reconnect logic needed

  bool get hasDisconnectError => _analysisResults != null && _analysisResults!['isSensorDisconnect'] == true;
  bool get isSummaryWithValidResults => _state == RunState.results && _analysisResults != null && _analysisResults!['error'] == null;

  // Show disconnect error with manual reconnect button
  void showDisconnectErrorWithReconnectButton() {
    setState(() {
      _recording = false;
      _state = RunState.results;
      _analysisResults = {
        'error': 'Sensors disconnected. Reconnect to continue.',
        'isSensorDisconnect': true,
        'showReconnectButton': true,
      };
    });
  }

  // After reconnect, show error with 'Start Another Run' option
  void showPostReconnectErrorStartNewRun() {
    setState(() {
      _recording = false;
      _state = RunState.results;
      _analysisResults = {
        'error': 'Sensors reconnected. Yaw calibration was reset.',
        'isSensorDisconnect': true,
        'startAnotherRun': true,
      };
    });
  }

  Future<void> _startRecording() async {
    // Use BleManager's built-in recording
    widget.bleMgr.startRecording();
    setState(() => _recording = true);
  }

  // ...existing code...

  Future<void> _stopRecording() async {
    setState(() {
      _recording = false;
      _state = RunState.processing;
    });

    // Abort analysis if disconnect was handled or state is not recording
    if (_disconnectHandled || _state != RunState.processing) {
      debugPrint('⚠️ Analysis aborted');
      return;
    }

    // Get recorded data from BleManager
    final recordedData = widget.bleMgr.stopRecording();
    
    // Extract samples for each sensor
    final leftSamples = recordedData[widget.leftId] ?? [];
    final rightSamples = recordedData[widget.rightId] ?? [];

    debugPrint('📊 Recording: ${leftSamples.length}L/${rightSamples.length}R samples');

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
    final yawOffset = BleManager().yawOffset ?? 0.0;
    
    // Calculate approximate sampling rate (Hz)
    double samplingRate = 100.0; // Default assumption
    if (leftImu.length > 1) {
      final duration = leftImu.last.timestamp.difference(leftImu.first.timestamp);
      if (duration.inMilliseconds > 0) {
        samplingRate = (leftImu.length - 1) * 1000.0 / duration.inMilliseconds;
      }
    }
    
    final segments = TurnSegmentation.segment(
      leftSamples: leftImu,
      rightSamples: rightImu,
      yawOffset: yawOffset,
      samplingRate: samplingRate,
    );
    
    // Store processed data for graphs (we need the processed samples from segmentation)
    // Re-process to get the corrected samples (same pipeline as segmentation)
    final unwrappedLeft = ImuPreprocessor.unwrapAngles(leftImu, 'LEFT');
    final unwrappedRight = ImuPreprocessor.unwrapAngles(rightImu, 'RIGHT');
    final correctedRightYaw = ImuPreprocessor.applyYawOffset(unwrappedRight, yawOffset, 'RIGHT');
    
    final turnDurations = segments.map((s) => s.durationSeconds).toList();
    final edgeAngles = segments.map((s) => s.maxEdgeAngle).toList();
    final turnDirections = segments.map((s) => s.direction).toList();
    final parallelBeginning = segments.map((s) => s.beginningParallelness).toList();
    final parallelMiddle = segments.map((s) => s.middleParallelness).toList();
    final parallelEnd = segments.map((s) => s.endParallelness).toList();
    final parallelAvg = segments.map((s) => s.avgParallelness).toList();
    final turnShapeBeginning = segments.map((s) => s.beginningTurnShapeSD).toList();
    final turnShapeMiddle = segments.map((s) => s.middleTurnShapeSD).toList();
    final turnShapeEnd = segments.map((s) => s.endTurnShapeSD).toList();
    final turnShapeAvg = segments.map((s) => s.avgTurnShapeSD).toList();

    debugPrint('📊 Analysis: ${segments.length} turns detected');

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

    // Compute turn symmetry (main page only)
    double? turnSymmetryRatio;
    double? turnSymmetryScore;
    if (turnDirections.isNotEmpty && turnDurations.isNotEmpty) {
      final symmetryResult = SymmetryCalculator.calculate(
        turnDurations: turnDurations,
        turnDirections: turnDirections,
      );
      
      turnSymmetryRatio = symmetryResult.ratio;
      if (turnSymmetryRatio != null && turnSymmetryRatio > 0) {
        turnSymmetryScore = Scoring.symmetry(turnSymmetryRatio);
      }
    }

    // Simulate analysis delay
    await Future.delayed(const Duration(milliseconds: 300));

    final results = {
      'leftSampleCount': leftSamples.length,
      'rightSampleCount': rightSamples.length,
      'leftSamples': leftSamples,
      'rightSamples': rightSamples,
      'processedLeftSamples': unwrappedLeft,
      'processedRightSamples': correctedRightYaw,
      'segments': segments,
      'duration': leftSamples.isNotEmpty && leftSamples.length > 1
          ? leftSamples.last.timestamp.difference(leftSamples.first.timestamp).inSeconds
          : 0,
      'startTime': leftSamples.isNotEmpty ? leftSamples.first.timestamp : null,
      'turnCount': segments.length,
      'turnDurations': turnDurations,
      'edgeAngles': edgeAngles,
      'turnDirections': turnDirections,
      'parallelBeginning': parallelBeginning,
      'parallelMiddle': parallelMiddle,
      'parallelEnd': parallelEnd,
      'parallelAvg': parallelAvg,
      'turnShapeBeginning': turnShapeBeginning,
      'turnShapeMiddle': turnShapeMiddle,
      'turnShapeEnd': turnShapeEnd,
      'turnShapeAvg': turnShapeAvg,
      'turnSymmetryRatio': turnSymmetryRatio,
      'turnSymmetryScore': turnSymmetryScore,
    };

    if (!mounted) return;

    setState(() {
      _analysisResults = results;
      _state = RunState.results;
    });
    widget.onResultsShown?.call();
  }

  Widget _buildRecordingView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recording Session',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              _buildAIModeToggle(),
            ],
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
            ),
          if (_recording)
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

  Widget _buildAIModeToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AIPreferences.currentMode == AIMode.local
                ? Icons.phone_android
                : Icons.cloud,
            size: 18,
            color: AIPreferences.currentMode == AIMode.local
                ? Colors.green
                : Colors.blue,
          ),
          const SizedBox(width: 4),
          Text(
            AIPreferences.currentMode == AIMode.local ? 'Local' : 'API',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Switch(
            value: AIPreferences.currentMode == AIMode.api,
            onChanged: (value) {
              setState(() {
                AIPreferences.setMode(value ? AIMode.api : AIMode.local);
              });
            },
            activeThumbColor: Colors.blue,
            inactiveThumbColor: Colors.green,
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
      final showReconnectButton = _analysisResults!['showReconnectButton'] == true;
      final startAnotherRun = _analysisResults!['startAnotherRun'] == true;
       return ResultsView(
         results: null,
         errorMessage: error,
         onNewRun: widget.onRecordAgain,
         onReconnect: showReconnectButton ? widget.onManualReconnect : null,
         // ...existing code...
         showReconnectButton: showReconnectButton,
         showTryAgainButton: startAnotherRun || (!isSensorDisconnect),
       );
    }

    final leftCount = _analysisResults!['leftSampleCount'] ?? 0;
    final rightCount = _analysisResults!['rightSampleCount'] ?? 0;
    final leftSegments = (_analysisResults!['leftSegments'] as List?)?.cast<List<int>>() ?? [];
    final rightSegments = (_analysisResults!['rightSegments'] as List?)?.cast<List<int>>() ?? [];
    final duration = _analysisResults!['duration'] ?? 0;
    final startTime = _analysisResults!['startTime'] as DateTime?;
    final processedLeftSamples = _analysisResults!['processedLeftSamples'];
    final processedRightSamples = _analysisResults!['processedRightSamples'];
    final segments = _analysisResults!['segments'];
    final turnCount = _analysisResults!['turnCount'] ?? 0;
    final turnDurations = (_analysisResults!['turnDurations'] as List?)?.cast<double>() ?? [];
    final edgeAngles = (_analysisResults!['edgeAngles'] as List?)?.cast<double>() ?? [];
    final turnDirections = (_analysisResults!['turnDirections'] as List?)?.cast<int>() ?? [];
    final parallelBeginning = (_analysisResults!['parallelBeginning'] as List?)?.cast<double>() ?? [];
    final parallelMiddle = (_analysisResults!['parallelMiddle'] as List?)?.cast<double>() ?? [];
    final parallelEnd = (_analysisResults!['parallelEnd'] as List?)?.cast<double>() ?? [];
    final parallelAvg = (_analysisResults!['parallelAvg'] as List?)?.cast<double>() ?? [];
    final turnShapeBeginning = (_analysisResults!['turnShapeBeginning'] as List?)?.cast<double>() ?? [];
    final turnShapeMiddle = (_analysisResults!['turnShapeMiddle'] as List?)?.cast<double>() ?? [];
    final turnShapeEnd = (_analysisResults!['turnShapeEnd'] as List?)?.cast<double>() ?? [];
    final turnShapeAvg = (_analysisResults!['turnShapeAvg'] as List?)?.cast<double>() ?? [];
    final turnSymmetryRatio = _analysisResults!['turnSymmetryRatio'] as double?;
    final turnSymmetryScore = _analysisResults!['turnSymmetryScore'] as double?;

    // Compute per-turn scores (average of 4 categories: duration, edge, parallel, smooth)
    final turnScores = <double>[];
    for (int i = 0; i < turnCount; i++) {
      double scoreSum = 0.0;
      int scoreCount = 0;
      
      if (i < turnDurations.length) {
        scoreSum += Scoring.duration(turnDurations[i]);
        scoreCount++;
      }
      if (i < edgeAngles.length) {
        scoreSum += Scoring.edgeAngle(edgeAngles[i]);
        scoreCount++;
      }
      if (i < parallelAvg.length) {
        scoreSum += Scoring.parallel(parallelAvg[i]);
        scoreCount++;
      }
      if (i < turnShapeAvg.length) {
        scoreSum += Scoring.turnShape(turnShapeAvg[i]);
        scoreCount++;
      }
      
      turnScores.add(scoreCount > 0 ? scoreSum / scoreCount : 0.0);
    }

    // Compute overall score: average of 5 categories
    double? overallScore;
    double sum = 0.0;
    int count = 0;
    if (turnDurations.isNotEmpty) {
      final ds = turnDurations.map((x) => Scoring.duration(x)).toList();
      sum += ds.reduce((a,b)=>a+b) / ds.length; count++;
    }
    if (edgeAngles.isNotEmpty) {
      final es = edgeAngles.map((x) => Scoring.edgeAngle(x)).toList();
      sum += es.reduce((a,b)=>a+b) / es.length; count++;
    }
    if (parallelAvg.isNotEmpty) {
      final ps = parallelAvg.map((x) => Scoring.parallel(x)).toList();
      sum += ps.reduce((a,b)=>a+b) / ps.length; count++;
    }
    if (turnShapeAvg.isNotEmpty) {
      final ss = turnShapeAvg.map((x) => Scoring.turnShape(x)).toList();
      sum += ss.reduce((a,b)=>a+b) / ss.length; count++;
    }
    if (turnSymmetryScore != null) { sum += turnSymmetryScore; count++; }
    if (count > 0) overallScore = sum / count;

    final resultsModel = AnalysisResults(
      leftSampleCount: leftCount,
      rightSampleCount: rightCount,
      leftSegments: leftSegments,
      rightSegments: rightSegments,
      runDurationSeconds: duration,
      runStartTime: startTime,
      turnCount: turnCount,
      turnDurationsSeconds: turnDurations,
      edgeAngles: edgeAngles,
      turnDirections: turnDirections,
      parallelBeginning: parallelBeginning,
      parallelMiddle: parallelMiddle,
      parallelEnd: parallelEnd,
      parallelAvg: parallelAvg,
      turnShapeBeginning: turnShapeBeginning,
      turnShapeMiddle: turnShapeMiddle,
      turnShapeEnd: turnShapeEnd,
      turnShapeAvg: turnShapeAvg,
      turnScores: turnScores,
      turnSymmetryRatio: turnSymmetryRatio,
      turnSymmetryScore: turnSymmetryScore,
      overallScore: overallScore,
      processedLeftSamples: processedLeftSamples,
      processedRightSamples: processedRightSamples,
      segments: segments,
    );
    return ResultsView(
      results: resultsModel,
      onNewRun: widget.onRecordAgain,
      // ...existing code...
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
