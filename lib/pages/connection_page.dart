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
  StreamSubscription<dynamic>? _scanSub;
  StreamSubscription<BleStatus>? _statusSub;
  bool _scanning = false;

  String? _leftId;
  String? _rightId;

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
      // Fall back to mock on iOS if BLE fails
      _bleMgr = MockBleManager();
      _useMock = true;
    }
  }

  void startScan() {
    _devices.clear();
    setState(() => _scanning = true);
    _scanSub?.cancel();
    _statusSub?.cancel();

    if (_useMock) {
      if (kDebugMode) debugPrint('Using mock BLE manager - starting scan immediately');
      _beginScanningSequence();
      return;
    }

    // Listen to BLE status once, then cancel.
    final bleMgr = _bleMgr as BleManager;
    _statusSub = bleMgr.statusStream.listen((status) {
      if (kDebugMode) debugPrint('BLE Status update: $status');
      if (status == BleStatus.ready) {
        _statusSub?.cancel();
        _beginScanningSequence();
      } else if (status == BleStatus.unauthorized) {
        // Inform user they must enable Bluetooth permissions in Settings.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth permission not granted. Please enable in Settings.')),
        );
      } else if (status == BleStatus.poweredOff) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth is off. Please enable Bluetooth.')),
        );
      }
    });

    // Fallback: if not ready within 6s start scan anyway.
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      if (_scanSub == null) {
        if (kDebugMode) debugPrint('BLE not reported ready after timeout - attempting scan anyway');
        _beginScanningSequence();
      }
    });
  }

  void _beginScanningSequence({bool noServiceFilter = false}) {
    try {
      if (kDebugMode) debugPrint('Starting BLE scan (${noServiceFilter ? 'NO service filter' : 'service UUID filter'})');
      final scanStream = noServiceFilter
          ? (_bleMgr as BleManager).rawScanStream()
          : _bleMgr.scanForDevices();
      _scanSub = scanStream.listen((d) {
        setState(() {
          if (_isWindows) {
            final Map<String, String> m = Map<String, String>.from(d);
            if (!_devices.any((e) => e['id'] == m['id'])) _devices.add(m);
          } else {
            final id = (d as dynamic).id as String;
            final name = (d as dynamic).name as String;
            if (kDebugMode) debugPrint('Found device: $name ($id)');
            // Only add devices named WTLeft or WTRight
            if ((name == 'WTLeft' || name == 'WTRight') && !_devices.any((e) => e['id'] == id)) {
              _devices.add({'id': id, 'name': name});
              if (kDebugMode) debugPrint('Added $name sensor');
              
              // Auto-assign based on name
              if (name == 'WTLeft' && _leftId == null) {
                _leftId = id;
              } else if (name == 'WTRight' && _rightId == null) {
                _rightId = id;
              }
              
              // Auto-connect when both found
              if (_leftId != null && _rightId != null) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) _connectBoth();
                });
              }
            }
          }
        });
      }, onDone: () {
        if (mounted) setState(() => _scanning = false);
      });

      // Fallback: if no devices with service filter after 7s, retry without filter.
      if (!noServiceFilter) {
        Future.delayed(const Duration(seconds: 7), () {
          if (!mounted) return;
          if (_devices.isEmpty) {
            if (kDebugMode) debugPrint('No devices found with service filter - retrying raw scan');
            _scanSub?.cancel();
            _beginScanningSequence(noServiceFilter: true);
          }
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error starting scan: $e');
      if (mounted) setState(() => _scanning = false);
    }
  }

  void stopScan() {
    _scanSub?.cancel();
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
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final leftOk = await _bleMgr.connectAndWait(_leftId!);
    final rightOk = await _bleMgr.connectAndWait(_rightId!);

    if (!mounted) return;
    Navigator.of(context).pop(); // close loading dialog

    if (leftOk && rightOk) {
      // Call the callback to notify AppController
      widget.onConnected?.call(_bleMgr, _leftId!, _rightId!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to one or both sensors')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bothConnected = _leftId != null && _rightId != null;
    final leftConnected = _leftId != null;
    final rightConnected = _rightId != null;

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
                const SizedBox(height: 40),
                
                // Left sensor status
                _buildSensorStatus(
                  'Left Sensor',
                  leftConnected,
                  Colors.blue,
                ),
                const SizedBox(height: 20),
                
                // Right sensor status
                _buildSensorStatus(
                  'Right Sensor',
                  rightConnected,
                  Colors.green,
                ),
                const SizedBox(height: 40),
                
                // Scanning indicator
                if (_scanning && !bothConnected) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'Searching for sensors...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],

                if (!bothConnected && !_scanning) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text('Use Known IDs'),
                    onPressed: () {
                      setState(() {
                        _leftId ??= 'd4:54:bd:e8:b6:f4';
                        _rightId ??= 'ee:71:bb:5f:97:63';
                      });
                      _connectBoth();
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fallback manual connect using provided IDs',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
                
                if (bothConnected)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 32),
                      SizedBox(width: 8),
                      Text(
                        'Connected!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
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
  
  Widget _buildSensorStatus(String label, bool connected, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: connected ? color : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        color: connected ? color.withValues(alpha: 0.1) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: connected ? color : Colors.grey,
            ),
          ),
          Icon(
            connected ? Icons.check_circle : Icons.circle_outlined,
            color: connected ? color : Colors.grey[300],
            size: 32,
          ),
        ],
      ),
    );
  }
}
