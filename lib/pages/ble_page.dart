import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../services/ble_manager.dart';
import '../services/memory_recording.dart';
import '../services/mock_ble_manager.dart';

class BlePage extends StatefulWidget {
  const BlePage({super.key});

  @override
  State<BlePage> createState() => _BlePageState();
}

class _BlePageState extends State<BlePage> {
  final bool _isWindows = Platform.isWindows;
  bool _useMock = Platform.isWindows; // default to mock on Windows
  late dynamic _bleMgr;
  final List<Map<String, String>> _devices = [];
  StreamSubscription<dynamic>? _scanSub;
  final Map<String, StreamSubscription<Map<String, double>>> _sampleSubs = {};
  final Set<String> _connectedIds = {};
  final Map<String, MemoryRecording> _recSessions = {};
  final Map<String, Map<String, double>> _latestSamples = {};
  bool _scanning = false;

  void startScan() {
    _devices.clear();
    setState(() {
      _scanning = true;
    });
    _scanSub?.cancel();
    final scanStream = _bleMgr.scanForDevices(nameFilter: null);
    _scanSub = scanStream.listen((d) {
      setState(() {
        // Normalize both real and mock device shapes into Map<String,String>
        if (_isWindows) {
          final Map<String, String> m = Map<String, String>.from(d);
          if (!_devices.any((e) => e['id'] == m['id'])) _devices.add(m);
        } else {
          // `d` is a DiscoveredDevice from flutter_reactive_ble
          final id = (d as dynamic).id as String;
          final name = (d as dynamic).name as String;
          if (!_devices.any((e) => e['id'] == id)) _devices.add({'id': id, 'name': name});
        }
      });
    }, onDone: () {
      setState(() => _scanning = false);
    });
  }

  void _applyManager() {
    // Cancel any ongoing scan/connection and reset state when switching managers
    _scanSub?.cancel();
    for (final s in _sampleSubs.values) {
      s.cancel();
    }
    _sampleSubs.clear();
    _scanSub = null;
    _devices.clear();
    _connectedIds.clear();
    _recSessions.clear();
    _latestSamples.clear();

    _bleMgr = _useMock ? MockBleManager() : BleManager();
  }

  void stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
    setState(() => _scanning = false);
  }

  Future<void> connect(String id) async {
    final ok = await _bleMgr.connectAndWait(id);
    if (!mounted) return;
    if (ok) {
      setState(() => _connectedIds.add(id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connected')));
      _subscribeToSamples(id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to connect')));
    }
  }

  Future<void> disconnect(String id) async {
    try {
      await _bleMgr.disconnectDevice(id);
    } catch (_) {}
    _sampleSubs[id]?.cancel();
    _sampleSubs.remove(id);
    setState(() {
      _connectedIds.remove(id);
      _recSessions.remove(id);
      _latestSamples.remove(id);
    });
  }

  void _subscribeToSamples(String deviceId) {
    _sampleSubs[deviceId]?.cancel();
    final stream = _bleMgr.sampleStream(deviceId);
    if (stream == null) return;
    final sub = stream.listen((m) {
      if (!mounted) return;
      setState(() {
        _latestSamples[deviceId] = m;
      });
    });
    _sampleSubs[deviceId] = sub;
  }

  Future<void> startRecording(String id) async {
    final stream = _bleMgr.sampleStream(id);
    if (stream == null) return;
    setState(() {
      _recSessions[id] = MemoryRecording(id);
    });
    await _recSessions[id]!.start(stream);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording started (in memory)')));
  }

  Future<void> stopRecording(String id) async {
    final session = _recSessions[id];
    if (session == null) return;
    final samples = await session.stop();
    final count = samples.length;
    _recSessions.remove(id);
    double meanAx = 0.0;
    if (count > 0) {
      final sum = samples.map((s) => s['ax'] ?? 0.0).fold<double>(0.0, (a, b) => a + b);
      meanAx = sum / count;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recording stopped — $count samples, mean ax=${meanAx.toStringAsFixed(3)}')));
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _bleMgr = _useMock ? MockBleManager() : BleManager();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE IMU')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Text('Use Mock BLE (Windows only):'),
                const SizedBox(width: 8),
                Switch(
                  value: _useMock,
                  onChanged: (v) {
                    if (!_isWindows && v) return; // only allow mock by default on Windows
                    setState(() {
                      _useMock = v;
                      _applyManager();
                    });
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ElevatedButton(onPressed: _scanning ? null : startScan, child: const Text('Scan')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _scanning ? stopScan : null, child: const Text('Stop')),
                const SizedBox(width: 12),
                const SizedBox.shrink(),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, idx) {
                    final d = _devices[idx];
                    final id = d['id'] ?? '';
                    final name = d['name'] ?? id;
                    final isConnected = _connectedIds.contains(id);
                    final isRecording = _recSessions.containsKey(id);
                    return ListTile(
                      title: Text(name.isNotEmpty ? name : id),
                      subtitle: Text(id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: isConnected ? () => disconnect(id) : () => connect(id),
                            child: Text(isConnected ? 'Disconnect' : 'Connect'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isConnected ? (isRecording ? () => stopRecording(id) : () => startRecording(id)) : null,
                            child: Text(isRecording ? 'Stop' : 'Record'),
                          ),
                        ],
                      ),
                    );
              },
            ),
          )
          ,
          // Live sample panels for each connected device
          for (final entry in _latestSamples.entries)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Live Sample — ${entry.key}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _buildSampleChipFor(entry.key, 'ax'),
                          _buildSampleChipFor(entry.key, 'ay'),
                          _buildSampleChipFor(entry.key, 'az'),
                          _buildSampleChipFor(entry.key, 'gx'),
                          _buildSampleChipFor(entry.key, 'gy'),
                          _buildSampleChipFor(entry.key, 'gz'),
                          _buildSampleChipFor(entry.key, 'roll'),
                          _buildSampleChipFor(entry.key, 'pitch'),
                          _buildSampleChipFor(entry.key, 'yaw'),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSampleChipFor(String deviceId, String key) {
    final val = _latestSamples[deviceId]?[key];
    final text = val == null ? '--' : val.toStringAsFixed(3);
    return Chip(label: Text('$key: $text'));
  }
}
