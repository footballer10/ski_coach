import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../services/ble_manager.dart';
import '../services/mock_ble_manager.dart';

bool _safeIsWindows() {
  try {
    return !kIsWeb && Platform.isWindows;
  } catch (_) {
    return false;
  }
}

class ConnectionPage extends StatefulWidget {
  final void Function(dynamic bleMgr, String leftId, String rightId)? onConnected;

  const ConnectionPage({super.key, this.onConnected});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final bool _isWindows = _safeIsWindows();
  bool _useMock = _safeIsWindows();
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
    if (kDebugMode) debugPrint('ConnectionPage: initState starting');
    // Delay BLE initialization to not block UI rendering
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _applyManager();
        if (kDebugMode) debugPrint('ConnectionPage: BLE manager initialized');
        startScan();
        if (kDebugMode) debugPrint('ConnectionPage: Scan started');
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
    try {
      _bleMgr = _useMock ? MockBleManager() : BleManager();
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing BLE manager: $e');
      _bleMgr = MockBleManager();
      _useMock = true;
    }
  }

  void startScan() {
    setState(() {
      _devices.clear();
      _scanning = true;
      _leftId = null;
      _rightId = null;
    });
    _scanSub?.cancel();
    _statusSub?.cancel();

    if (_useMock) {
      _beginNameScan();
      return;
    }
    final bleMgr = _bleMgr as BleManager;
    _statusSub = bleMgr.statusStream.listen((status) {
      _lastStatus = status;
      if (kDebugMode) debugPrint('BLE Status: $status');
      if (status == BleStatus.ready) {
        _statusSub?.cancel();
        _beginNameScan();
      }
    });
    // Fallback if never reaches ready
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (_scanSub == null) {
        if (kDebugMode) debugPrint('Status not ready after timeout -> raw scan anyway');
        _beginNameScan();
      }
    });
  }

  void _beginNameScan() {
    try {
      if (kDebugMode) {
        debugPrint('========================================');
        debugPrint('NAME SCAN START (service-filtered)');
        debugPrint('Looking for: "$_targetLeftName" and "$_targetRightName"');
        debugPrint('BLE Status: $_lastStatus');
        debugPrint('========================================');
      }
      // Prefer service-filtered scan for stability on iOS
      final stream = (_bleMgr as BleManager).scanForDevices();
      
      // Fallback: if no devices found after 5 seconds, try raw scan
      Future.delayed(const Duration(seconds: 5), () async {
        if (!mounted) return;
        if (_devices.isEmpty && _scanning) {
          if (kDebugMode) debugPrint('⚠️ No devices found with service filter. Switching to RAW SCAN...');
          
          // Explicitly stop the current scan
          stopScan();
          
          // Wait longer for iOS BLE stack to fully stop scanning
          await Future.delayed(const Duration(milliseconds: 1000));
          
          if (mounted) {
            setState(() => _scanning = true);
            _beginRawScan();
          }
        }
      });
      
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
        if (kDebugMode) debugPrint('Comparing "$name" against "$_targetLeftName" and "$_targetRightName"');
        if (name == _targetLeftName && _leftId == null) {
          _leftId = id;
          updated = true;
          if (kDebugMode) debugPrint('✓ MATCHED LEFT by name -> $id');
        }
        if (name == _targetRightName && _rightId == null) {
          _rightId = id;
          updated = true;
          if (kDebugMode) debugPrint('✓ MATCHED RIGHT by name -> $id');
        }
        if (updated && mounted) {
          setState(() {});
        }
        if (_leftId != null && _rightId != null) {
          if (kDebugMode) debugPrint('🎯 BOTH SENSORS FOUND! Stopping scan and connecting...');
          // Stop scanning before connecting to avoid overlapping operations
          _scanSub?.cancel();
          setState(() => _scanning = false);
          // Slight delay to let scanning settle on iOS
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) _connectBoth();
          });
        }
      }, onError: (e) {
        if (kDebugMode) debugPrint('❌ SCAN ERROR: $e');
        if (mounted) setState(() => _scanning = false);
      }, onDone: () {
        if (kDebugMode) debugPrint('Scan stream completed (onDone)');
        if (mounted) setState(() => _scanning = false);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ BEGIN NAME SCAN EXCEPTION: $e');
      setState(() => _scanning = false);
    }
  }

  void _beginRawScan() {
    try {
      if (kDebugMode) {
        debugPrint('========================================');
        debugPrint('RAW SCAN START (no service filter)');
        debugPrint('Looking for: "$_targetLeftName" and "$_targetRightName"');
        debugPrint('========================================');
      }
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
        if (kDebugMode) debugPrint('Comparing "$name" against "$_targetLeftName" and "$_targetRightName"');
        if (name == _targetLeftName && _leftId == null) {
          _leftId = id;
          updated = true;
          if (kDebugMode) debugPrint('✓ MATCHED LEFT by name -> $id');
        }
        if (name == _targetRightName && _rightId == null) {
          _rightId = id;
          updated = true;
          if (kDebugMode) debugPrint('✓ MATCHED RIGHT by name -> $id');
        }
        if (updated && mounted) {
          setState(() {});
        }
        if (_leftId != null && _rightId != null) {
          if (kDebugMode) debugPrint('🎯 BOTH SENSORS FOUND! Stopping scan and connecting...');
          // Stop scanning before connecting to avoid overlapping operations
          _scanSub?.cancel();
          setState(() => _scanning = false);
          // Slight delay to let scanning settle on iOS
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) _connectBoth();
          });
        }
      }, onError: (e) {
        if (kDebugMode) debugPrint('❌ RAW SCAN ERROR: $e');
        if (mounted) setState(() => _scanning = false);
      }, onDone: () {
        if (kDebugMode) debugPrint('Raw scan stream completed (onDone)');
        if (mounted) setState(() => _scanning = false);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ BEGIN RAW SCAN EXCEPTION: $e');
      setState(() => _scanning = false);
    }
  }

  void stopScan() {
    if (kDebugMode) debugPrint('stopScan called - canceling subscription');
    _scanSub?.cancel();
    _scanSub = null;
    setState(() => _scanning = false);
  }

  Future<void> _connectBoth() async {
    if (kDebugMode) debugPrint('_connectBoth called: left=$_leftId, right=$_rightId');
    if (_leftId == null || _rightId == null) {
      if (kDebugMode) debugPrint('❌ Cannot connect: missing sensor IDs');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign both left and right sensors')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    if (kDebugMode) debugPrint('Connecting to LEFT: $_leftId');
    final leftOk = await _bleMgr.connectAndWait(_leftId!);
    if (kDebugMode) debugPrint('LEFT connection result: $leftOk');
    
    if (kDebugMode) debugPrint('Connecting to RIGHT: $_rightId');
    final rightOk = await _bleMgr.connectAndWait(_rightId!);
    if (kDebugMode) debugPrint('RIGHT connection result: $rightOk');

    if (!mounted) return;
    Navigator.of(context).pop(); // close loading dialog

    if (leftOk && rightOk) {
      if (kDebugMode) debugPrint('✓ BOTH SENSORS CONNECTED SUCCESSFULLY');
      // Call the callback to notify AppController
      widget.onConnected?.call(_bleMgr, _leftId!, _rightId!);
    } else {
      if (kDebugMode) debugPrint('❌ CONNECTION FAILED: left=$leftOk, right=$rightOk');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to one or both sensors')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bothSelected = _leftId != null && _rightId != null;
    final leftSelected = _leftId != null;
    final rightSelected = _rightId != null;

    return Scaffold(
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
                  
                if (_isWindows) ...[
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Mock Mode'),
                      Switch(
                        value: _useMock,
                        onChanged: (v) {
                          setState(() {
                            _useMock = v;
                            _leftId = null;
                            _rightId = null;
                            _applyManager();
                            startScan();
                          });
                        },
                      ),
                    ],
                  ),
                ],
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
