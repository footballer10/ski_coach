import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../services/ble_manager.dart';

class ConnectionPage extends StatefulWidget {
  final void Function(dynamic bleMgr, String leftId, String rightId)? onConnected;
  final bool showCloseButton;

  const ConnectionPage({
    super.key,
    this.onConnected,
    this.showCloseButton = false,
  });

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  late dynamic _bleMgr;
  final List<Map<String, String>> _devices = [];
  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<BleStatus>? _statusSub;
  bool _scanning = false;
  BleStatus _lastStatus = BleStatus.unknown;

  String? _leftId;
  String? _rightId;

  static const String _targetLeftName = 'WTLeft';
  static const String _targetRightName = 'WTRight';

  @override
  void initState() {
    super.initState();
    // Longer delay to ensure any previous scans are fully stopped
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _applyManager();
        startScan();
      }
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  void _applyManager() {
    _scanSub?.cancel();
    _devices.clear();
    _bleMgr = BleManager();
  }

  void startScan() {
    // Cancel any existing scan first and stop any active scanning
    _scanSub?.cancel();
    _scanSub = null;
    _statusSub?.cancel();
    _statusSub = null;
    
    setState(() {
      _devices.clear();
      _scanning = true;
      _leftId = null;
      _rightId = null;
    });

    final bleMgr = _bleMgr as BleManager;
    
    if (kDebugMode) {
      debugPrint('🔵 ConnectionPage: Waiting 2000ms before starting new scan to ensure BLE stack is ready');
    }
    
    // Much longer delay to ensure BLE stack fully stops (prevents iOS assertion failure)
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      
      if (kDebugMode) {
        debugPrint('🔵 ConnectionPage: Starting new scan after 2000ms delay');
      }
      
      _statusSub = bleMgr.statusStream.listen((status) {
        _lastStatus = status;
        if (status == BleStatus.ready) {
          _statusSub?.cancel();
          _beginRawScan();
        }
      });
      // Fallback if never reaches ready
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        if (_scanSub == null) {
          _beginRawScan();
        }
      });
    });
  }

  void _beginRawScan() {
    try {
      final stream = (_bleMgr as BleManager).verboseRawScan();
      _scanSub = stream.listen((d) {
        final id = d.id;
        final name = d.name.isEmpty ? '' : d.name;
        // Track encountered devices for visibility/debug (optional)
        if (!_devices.any((e) => e['id'] == id)) {
          setState(() {
            _devices.add({'id': id, 'name': name.isEmpty ? '(no name)' : name});
          });
        }

        bool updated = false;
        if (name == _targetLeftName && _leftId == null) {
          _leftId = id;
          updated = true;
        }
        if (name == _targetRightName && _rightId == null) {
          _rightId = id;
          updated = true;
        }
        if (updated && mounted) {
          setState(() {});
        }
        if (_leftId != null && _rightId != null) {
          // Stop scanning before connecting to avoid overlapping operations
          _scanSub?.cancel();
          setState(() => _scanning = false);
          // Slight delay to let scanning settle on iOS
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) _connectBoth();
          });
        }
      }, onError: (e) {
        if (mounted) setState(() => _scanning = false);
      }, onDone: () {
        if (mounted) setState(() => _scanning = false);
      });
    } catch (e) {
      setState(() => _scanning = false);
    }
  }

  void stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
    setState(() => _scanning = false);
  }

  Future<void> _connectBoth() async {
    if (_leftId == null || _rightId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign both left and right sensors')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting to sensors...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    final leftOk = await _bleMgr.connectAndWait(_leftId!);
    final rightOk = await _bleMgr.connectAndWait(_rightId!);

    if (!mounted) return;

    if (!leftOk || !rightOk) {
      Navigator.of(context).pop(); // close loading dialog
      if (kDebugMode) debugPrint('❌ CONNECTION FAILED: left=$leftOk, right=$rightOk');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to one or both sensors')),
      );
      return;
    }

    // Wait for actual data from both sensors before proceeding
    if (kDebugMode) debugPrint('✓ Sensors connected, waiting for data...');
    
    // Update dialog message
    if (mounted) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Waiting for sensor data...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    bool leftDataReceived = false;
    bool rightDataReceived = false;

    final leftStream = _bleMgr.sampleStream(_leftId!);
    final rightStream = _bleMgr.sampleStream(_rightId!);

    StreamSubscription? leftDataSub;
    StreamSubscription? rightDataSub;

    final dataCompleter = Completer<bool>();

    leftDataSub = leftStream?.listen((data) {
      if (kDebugMode) debugPrint('✓ Left sensor data received');
      leftDataReceived = true;
      if (rightDataReceived && !dataCompleter.isCompleted) {
        dataCompleter.complete(true);
      }
    });

    rightDataSub = rightStream?.listen((data) {
      if (kDebugMode) debugPrint('✓ Right sensor data received');
      rightDataReceived = true;
      if (leftDataReceived && !dataCompleter.isCompleted) {
        dataCompleter.complete(true);
      }
    });

    // Wait for data with timeout
    try {
      await dataCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) debugPrint('⚠️ Timeout waiting for sensor data');
          return false;
        },
      );
    } finally {
      leftDataSub?.cancel();
      rightDataSub?.cancel();
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close loading dialog

    if (leftDataReceived && rightDataReceived) {
      if (kDebugMode) debugPrint('✓ Both sensors sending data, proceeding to run page');
      // Call the callback to notify AppController
      widget.onConnected?.call(_bleMgr, _leftId!, _rightId!);
    } else {
      if (kDebugMode) debugPrint('❌ Failed to receive data from sensors');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            leftDataReceived
                ? 'No data from right sensor'
                : rightDataReceived
                    ? 'No data from left sensor'
                    : 'No data from either sensor',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bothSelected = _leftId != null && _rightId != null;
    final leftSelected = _leftId != null;
    final rightSelected = _rightId != null;

    return Scaffold(
      appBar: widget.showCloseButton
          ? AppBar(
              title: const Text('Reconnecting'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Cancel reconnection',
              ),
              automaticallyImplyLeading: false,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Connecting to Sensors',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSensorStatus('Left', leftSelected, Colors.blue),
                    _buildSensorStatus('Right', rightSelected, Colors.green),
                  ],
                ),
                const SizedBox(height: 16),
                if (_scanning) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text('Scanning (status: $_lastStatus)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ] else ...[
                  Text('Scan stopped (status: $_lastStatus)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rescan'),
                    onPressed: () => startScan(),
                  ),
                  if (bothSelected)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.link),
                      label: const Text('Connect'),
                      onPressed: _connectBoth,
                    ),
                ]),
                const SizedBox(height: 16),
                // Keep a minimal log of discovered devices (optional visibility)
                Expanded(
                  child: _devices.isEmpty
                      ? const Center(child: Text('Searching for WTLeft/WTRight...'))
                      : ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (ctx, i) {
                            final dev = _devices[i];
                            final id = dev['id']!;
                            final name = dev['name']!;
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(name),
                              subtitle: Text(id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSensorStatus(String label, bool selected, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      decoration: BoxDecoration(
        border: Border.all(color: selected ? color : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        color: selected ? color.withValues(alpha: 0.12) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? color : Colors.grey[400], size: 26),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : Colors.grey[600])),
        ],
      ),
    );
  }
}
