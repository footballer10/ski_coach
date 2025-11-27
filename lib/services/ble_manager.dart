import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
// Note: emit plain maps for samples to avoid analyzer import resolution issues

class BleManager {
  // -------------------------------------------------------------
  // Singleton setup (you only want ONE BLE manager)
  // -------------------------------------------------------------
  BleManager._internal();
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // UUIDs for WT9011DCL BLE
  static final Uuid _service =
      Uuid.parse("0000FFE0-0000-1000-8000-00805F9B34FB");
  static final Uuid _char =
      Uuid.parse("0000FFE1-0000-1000-8000-00805F9B34FB");

  // For storing Bluetooth connections
  final Map<String, StreamSubscription> _connSubs = {};

  // For outputting IMU samples as maps: {ax,ay,az,gx,gy,gz,roll,pitch,yaw}
  final Map<String, StreamController<Map<String, double>>> _sampleControllers = {};

  Stream<DiscoveredDevice> get scanStream =>
      _ble.scanForDevices(withServices: [_service]).asBroadcastStream();

  /// Scan for devices with the WT9011 service UUID
  Stream<DiscoveredDevice> scanForDevices() {
    // Scan with service UUID for better iOS discovery
    return _ble.scanForDevices(withServices: [_service]).asBroadcastStream();
  }

  /// Connect to device and wait until connected (or timeout). Returns true on success.
  Future<bool> connectAndWait(String deviceId, {Duration timeout = const Duration(seconds: 8)}) async {
    if (_connSubs.containsKey(deviceId)) return true;

    _sampleControllers[deviceId] = StreamController<Map<String, double>>.broadcast();

    final completer = Completer<bool>();

    final sub = _ble.connectToDevice(id: deviceId).listen((update) {
      if (update.connectionState == DeviceConnectionState.connected) {
        _subscribeCharacteristic(deviceId);
        if (!completer.isCompleted) completer.complete(true);
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        if (!completer.isCompleted) completer.complete(false);
      }
    }, onError: (err) {
      if (!completer.isCompleted) completer.complete(false);
    });

    _connSubs[deviceId] = sub;

    try {
      return await completer.future.timeout(timeout, onTimeout: () {
        // timeout -> cancel
        try {
          sub.cancel();
        } catch (_) {}
        _connSubs.remove(deviceId);
        return false;
      });
    } catch (_) {
      return false;
    }
  }

  /// Disconnect a device and cleanup resources
  Future<void> disconnectDevice(String deviceId) async {
    try {
      await _connSubs[deviceId]?.cancel();
    } catch (_) {}
    _connSubs.remove(deviceId);
    try {
      await _sampleControllers[deviceId]?.close();
    } catch (_) {}
    _sampleControllers.remove(deviceId);
    _latest.remove(deviceId);
  }

  // -------------------------------------------------------------
  // Connect to device
  // -------------------------------------------------------------
  Future<void> connectToDevice(String deviceId) async {
    final sub = _ble.connectToDevice(id: deviceId).listen((update) {
      if (update.connectionState == DeviceConnectionState.connected) {
        if (kDebugMode) debugPrint("Connected to $deviceId");
        _subscribeCharacteristic(deviceId);
      }
    });

    _connSubs[deviceId] = sub;

    // Create output stream controller for this device
    _sampleControllers[deviceId] = StreamController<Map<String, double>>.broadcast();
  }

  // -------------------------------------------------------------
  // Subscribe to the IMU data stream
  // -------------------------------------------------------------
  Future<void> _subscribeCharacteristic(String deviceId) async {
    try {
      // First, discover all services
      await _ble.discoverAllServices(deviceId);
      
      // Small delay to ensure discovery completes
      await Future.delayed(const Duration(milliseconds: 500));
      
      final char = QualifiedCharacteristic(
        serviceId: _service,
        characteristicId: _char,
        deviceId: deviceId,
      );

      _ble.subscribeToCharacteristic(char).listen((data) {
        _handleRawPacket(deviceId, data);
      }, onError: (error) {
        if (kDebugMode) debugPrint('Error subscribing to characteristic for $deviceId: $error');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error in _subscribeCharacteristic for $deviceId: $e');
    }
  }

  // Public getter for UI
  Stream<Map<String, double>>? sampleStream(String deviceId) {
    return _sampleControllers[deviceId]?.stream;
  }

  // -------------------------------------------------------------
  // Packet parsing state
  // -------------------------------------------------------------
  final Map<String, Map<String, double>> _latest = {};

  // -------------------------------------------------------------
  // Handle incoming packets
  // -------------------------------------------------------------
  void _handleRawPacket(String deviceId, List<int> bytes) {
    int i = 0;

    _latest.putIfAbsent(deviceId, () => {});

    while (i < bytes.length) {
      if (bytes[i] != 0x55) {
        i++;
        continue;
      }

      if (i + 1 >= bytes.length) break;
      final type = bytes[i + 1];

      // ---------------- ACCEL PACKET ----------------
      if (type == 0x51 && i + 11 <= bytes.length) {
        _latest[deviceId]!["ax"] = _toScaledAccel(bytes[i + 2], bytes[i + 3]);
        _latest[deviceId]!["ay"] = _toScaledAccel(bytes[i + 4], bytes[i + 5]);
        _latest[deviceId]!["az"] = _toScaledAccel(bytes[i + 6], bytes[i + 7]);
        i += 11;
        continue;
      }

      // ---------------- GYRO PACKET ----------------
      if (type == 0x52 && i + 11 <= bytes.length) {
        _latest[deviceId]!["gx"] = _toScaledGyro(bytes[i + 2], bytes[i + 3]);
        _latest[deviceId]!["gy"] = _toScaledGyro(bytes[i + 4], bytes[i + 5]);
        _latest[deviceId]!["gz"] = _toScaledGyro(bytes[i + 6], bytes[i + 7]);
        i += 11;
        continue;
      }

      // ---------------- ANGLE PACKET ----------------
      if (type == 0x53 && i + 11 <= bytes.length) {
        _latest[deviceId]!["roll"] =
            _toScaledAngle(bytes[i + 2], bytes[i + 3]);
        _latest[deviceId]!["pitch"] =
            _toScaledAngle(bytes[i + 4], bytes[i + 5]);
        _latest[deviceId]!["yaw"] =
            _toScaledAngle(bytes[i + 6], bytes[i + 7]);
        i += 11;
        continue;
      }

      i++;
    }

    // If all values exist, emit sample
    final map = _latest[deviceId]!;
    if (_hasAllFields(map)) {
      final sample = <String, double>{
        'ax': map['ax']!,
        'ay': map['ay']!,
        'az': map['az']!,
        'gx': map['gx']!,
        'gy': map['gy']!,
        'gz': map['gz']!,
        'roll': map['roll']!,
        'pitch': map['pitch']!,
        'yaw': map['yaw']!,
      };
      _sampleControllers[deviceId]!.add(sample);
      map.clear(); // reset for next sample
    }
  }

  // -------------------------------------------------------------
  // Byte conversion helpers
  // -------------------------------------------------------------
  bool _hasAllFields(Map<String, double> m) {
    const req = [
      "ax", "ay", "az",
      "gx", "gy", "gz",
      "roll", "pitch", "yaw"
    ];
    return req.every((key) => m.containsKey(key));
  }

  double _toScaledAccel(int low, int high) {
    int raw = _toSigned(low, high);
    return raw / 32768.0 * 16.0;
  }

  double _toScaledGyro(int low, int high) {
    int raw = _toSigned(low, high);
    return raw / 32768.0 * 2000.0;
  }

  double _toScaledAngle(int low, int high) {
    int raw = _toSigned(low, high);
    return raw / 32768.0 * 180.0;
  }

  int _toSigned(int low, int high) {
    int raw = (high << 8) | low;
    if (raw > 32767) raw -= 65536;
    return raw;
  }
}
