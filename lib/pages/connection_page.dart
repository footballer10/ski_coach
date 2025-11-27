import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
  bool _scanning = false;

  String? _leftId;
  String? _rightId;

  @override
  void initState() {
    super.initState();
    print('ConnectionPage: initState starting');
    // Delay BLE initialization to not block UI rendering
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _applyManager();
        print('ConnectionPage: BLE manager initialized');
        startScan();
        print('ConnectionPage: Scan started');
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
      print('Error initializing BLE manager: $e');
      // Fall back to mock on iOS if BLE fails
      _bleMgr = MockBleManager();
      _useMock = true;
    }
  }

  void startScan() {
    _devices.clear();
    setState(() => _scanning = true);
    _scanSub?.cancel();
    try {
      final scanStream = _bleMgr.scanForDevices(nameFilter: null);
      _scanSub = scanStream.listen((d) {
        setState(() {
          if (_isWindows) {
            final Map<String, String> m = Map<String, String>.from(d);
            if (!_devices.any((e) => e['id'] == m['id'])) _devices.add(m);
          } else {
            final id = (d as dynamic).id as String;
            final name = (d as dynamic).name as String;
            // Only add devices named WTLEFT or WTRIGHT
            if ((name == 'WTLEFT' || name == 'WTRIGHT') && !_devices.any((e) => e['id'] == id)) {
              _devices.add({'id': id, 'name': name});
              
              // Auto-assign based on name
              if (name == 'WTLEFT' && _leftId == null) {
                _leftId = id;
              } else if (name == 'WTRIGHT' && _rightId == null) {
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
    } catch (e) {
      print('Error starting scan: $e');
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
    final bothAssigned = _leftId != null && _rightId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Sensors'),
        actions: [
          if (_isWindows)
            Row(
              children: [
                const Text('Mock'),
                Switch(
                  value: _useMock,
                  onChanged: (v) {
                    setState(() {
                      _useMock = v;
                      _applyManager();
                      startScan();
                    });
                  },
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Assign Sensors:',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: _leftId != null ? Colors.green.shade100 : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              const Text('LEFT', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(_leftId != null
                                  ? _devices.firstWhere((d) => d['id'] == _leftId)['name'] ?? _leftId!
                                  : 'Not assigned'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        color: _rightId != null ? Colors.blue.shade100 : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              const Text('RIGHT', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(_rightId != null
                                  ? _devices.firstWhere((d) => d['id'] == _rightId)['name'] ?? _rightId!
                                  : 'Not assigned'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: bothAssigned ? _connectBoth : null,
                  child: const Text('Connect Both Sensors'),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Available Devices', style: Theme.of(context).textTheme.titleMedium),
                _scanning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(icon: const Icon(Icons.refresh), onPressed: startScan),
              ],
            ),
          ),
          Expanded(
            child: _devices.isEmpty
                ? Center(child: _scanning ? const CircularProgressIndicator() : const Text('No devices found'))
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (ctx, i) {
                      final dev = _devices[i];
                      final id = dev['id']!;
                      final name = dev['name'] ?? 'Unknown';
                      final isLeft = _leftId == id;
                      final isRight = _rightId == id;

                      return ListTile(
                        title: Text(name),
                        subtitle: Text(id),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isLeft ? Colors.green : null,
                              ),
                              onPressed: () => setState(() => _leftId = id),
                              child: const Text('LEFT'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRight ? Colors.blue : null,
                              ),
                              onPressed: () => setState(() => _rightId = id),
                              child: const Text('RIGHT'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
