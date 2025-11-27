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

  // UUIDs for WT9011DCL BLE - CORRECTED from LightBlue inspection
  static final Uuid _service =
      Uuid.parse("0000FFE5-0000-1000-8000-00805F9A34FB");
  static final Uuid _char =
      Uuid.parse("0000FFE4-0000-1000-8000-00805F9A34FB");

  // For storing Bluetooth connections
  final Map<String, StreamSubscription> _connSubs = {};
  final Map<String, StreamSubscription> _charSubs = {};

  // For outputting IMU samples as maps: {ax,ay,az,gx,gy,gz,roll,pitch,yaw}
  final Map<String, StreamController<Map<String, double>>> _sampleControllers = {};

  /// Stream of BLE status (ready, unauthorized, etc)
  Stream<BleStatus> get statusStream => _ble.statusStream;

  Stream<DiscoveredDevice> get scanStream =>
      _ble.scanForDevices(withServices: [_service]).asBroadcastStream();

  /// Scan for devices with the WT9011 service UUID
  Stream<DiscoveredDevice> scanForDevices() {
    return _ble.scanForDevices(withServices: [_service]).asBroadcastStream();
  }

  /// Raw scan without service filter (fallback if service-based scan finds nothing)
  Stream<DiscoveredDevice> rawScanStream() {
    return _ble.scanForDevices(withServices: []).asBroadcastStream();
  }

  /// Verbose raw scan with logging for diagnostics
  Stream<DiscoveredDevice> verboseRawScan() {
    return _ble.scanForDevices(withServices: []).asBroadcastStream();
  }

  /// Connect to device and wait until connected (or timeout). Returns true on success.
  Future<bool> connectAndWait(String deviceId, {Duration timeout = const Duration(seconds: 8)}) async {
    if (_connSubs.containsKey(deviceId)) {
      return true;
    }

    final completer = Completer<bool>();

    final sub = _ble.connectToDevice(id: deviceId).listen((update) {
      if (update.connectionState == DeviceConnectionState.connected) {
        // Ensure a sample controller exists only upon successful connection
        _sampleControllers[deviceId] ??= StreamController<Map<String, double>>.broadcast();
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
      final ok = await completer.future.timeout(timeout, onTimeout: () {
        // timeout -> cleanup
        try {
          sub.cancel();
        } catch (_) {}
        _connSubs.remove(deviceId);
        // Ensure we also clean up controllers/state on timeout
        try {
          _sampleControllers[deviceId]?.close();
        } catch (_) {}
        _sampleControllers.remove(deviceId);
        _latest.remove(deviceId);
        return false;
      });
      if (!ok) {
        // Defensive cleanup on failed connect
        try {
          await disconnectDevice(deviceId);
        } catch (_) {}
      }
      return ok;
    } catch (_) {
      // Defensive cleanup on error
      try {
        await disconnectDevice(deviceId);
      } catch (_) {}
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
      await _charSubs[deviceId]?.cancel();
    } catch (_) {}
    _charSubs.remove(deviceId);
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
      if (kDebugMode) debugPrint('[$deviceId] Starting characteristic subscription process...');
      
      // Try requesting a larger MTU to potentially trigger service discovery
      try {
        if (kDebugMode) debugPrint('[$deviceId] Requesting MTU...');
        final mtu = await _ble.requestMtu(deviceId: deviceId, mtu: 512);
        if (kDebugMode) debugPrint('[$deviceId] MTU set to: $mtu');
      } catch (e) {
        if (kDebugMode) debugPrint('[$deviceId] MTU request failed: $e');
      }
      
      // Wait a moment
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Try discovering services
      try {
        if (kDebugMode) debugPrint('[$deviceId] Calling discoverAllServices...');
        await _ble.discoverAllServices(deviceId);
        if (kDebugMode) debugPrint('[$deviceId] discoverAllServices completed');
      } catch (e) {
        if (kDebugMode) debugPrint('[$deviceId] discoverAllServices error: $e');
      }
      
      // Much longer wait for iOS to populate everything
      if (kDebugMode) debugPrint('[$deviceId] Waiting 5 seconds for iOS to cache services...');
      await Future.delayed(const Duration(milliseconds: 5000));
      
      final char = QualifiedCharacteristic(
        serviceId: _service,
        characteristicId: _char,
        deviceId: deviceId,
      );
      
      if (kDebugMode) {
        debugPrint('[$deviceId] Target Service: $_service');
        debugPrint('[$deviceId] Target Char: $_char');
        debugPrint('[$deviceId] Attempting to subscribe to notifications...');
      }
      
      // Subscribe
      _charSubs[deviceId] = _ble.subscribeToCharacteristic(char).listen((data) {
        if (kDebugMode) debugPrint('[$deviceId] ✓ DATA RECEIVED! ${data.length} bytes');
        _handleRawPacket(deviceId, data);
      }, onError: (e) {
        if (kDebugMode) {
          debugPrint('[$deviceId] ❌ Subscription stream error: $e');
          debugPrint('[$deviceId] ');
          debugPrint('[$deviceId] TROUBLESHOOTING:');
          debugPrint('[$deviceId] 1. Install "LightBlue" app from App Store');
          debugPrint('[$deviceId] 2. Scan for your sensor (WTLeft or WTRight)');
          debugPrint('[$deviceId] 3. Connect and view its services');
          debugPrint('[$deviceId] 4. Look for service FFE0 and note what characteristics it has');
          debugPrint('[$deviceId] 5. Share the characteristic UUIDs you see');
        }
      }, onDone: () {
        if (kDebugMode) debugPrint('[$deviceId] Subscription stream closed');
      });
      
      if (kDebugMode) debugPrint('[$deviceId] ✓ Subscribe call completed (waiting for data...)');
      
    } catch (e) {
      if (kDebugMode) debugPrint('[$deviceId] ❌ Exception in _subscribeCharacteristic: $e');
    }
  }

  // Public getter for UI
  Stream<Map<String, double>>? sampleStream(String deviceId) {
    final stream = _sampleControllers[deviceId]?.stream;
    if (kDebugMode) {
      debugPrint('[$deviceId] sampleStream() called - controller exists: ${_sampleControllers.containsKey(deviceId)}, stream: ${stream != null}');
    }
    return stream;
  }

  // -------------------------------------------------------------
  // Packet parsing state
  // -------------------------------------------------------------
  final Map<String, Map<String, double>> _latest = {};

  // -------------------------------------------------------------
  // Handle incoming packets
  // -------------------------------------------------------------
  void _handleRawPacket(String deviceId, List<int> bytes) {
    // DEBUG: Log raw bytes received
    if (kDebugMode) {
      final hexStr = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      debugPrint('[$deviceId] RAW DATA (${bytes.length} bytes): $hexStr');
    }

    int i = 0;

    _latest.putIfAbsent(deviceId, () => {});

    while (i < bytes.length) {
      if (bytes[i] != 0x55) {
        i++;
        continue;
      }

      if (i + 1 >= bytes.length) break;
      final type = bytes[i + 1];

      // ---------------- PACKET TYPE 0x61 (20 bytes total) ----------------
      // This appears to be a combined packet with all 9DOF data
      if (type == 0x61 && i + 20 <= bytes.length) {
        // Parse all values from the 0x61 packet
        // Bytes 2-3: unknown (seems to be a counter or value)
        // Bytes 4-19: appear to contain sensor data
        
        // Let's parse assuming 16-bit little-endian values
        // We have 9 int16 values to extract for ax,ay,az,gx,gy,gz,roll,pitch,yaw
        
        final ax = _toScaledAccel(bytes[i + 4], bytes[i + 5]);
        final ay = _toScaledAccel(bytes[i + 6], bytes[i + 7]);
        final az = _toScaledAccel(bytes[i + 8], bytes[i + 9]);
        final gx = _toScaledGyro(bytes[i + 10], bytes[i + 11]);
        final gy = _toScaledGyro(bytes[i + 12], bytes[i + 13]);
        final gz = _toScaledGyro(bytes[i + 14], bytes[i + 15]);
        final roll = _toScaledAngle(bytes[i + 16], bytes[i + 17]);
        final pitch = _toScaledAngle(bytes[i + 18], bytes[i + 19]);
        // Yaw might be in next packet or bytes 2-3
        
        _latest[deviceId]!["ax"] = ax;
        _latest[deviceId]!["ay"] = ay;
        _latest[deviceId]!["az"] = az;
        _latest[deviceId]!["gx"] = gx;
        _latest[deviceId]!["gy"] = gy;
        _latest[deviceId]!["gz"] = gz;
        _latest[deviceId]!["roll"] = roll;
        _latest[deviceId]!["pitch"] = pitch;
        
        // Try to get yaw from bytes 2-3
        final yaw = _toScaledAngle(bytes[i + 2], bytes[i + 3]);
        _latest[deviceId]!["yaw"] = yaw;
        
        if (kDebugMode) {
          debugPrint('[$deviceId] 0x61 PACKET: ax=$ax, ay=$ay, az=$az, gx=$gx, gy=$gy, gz=$gz, roll=$roll, pitch=$pitch, yaw=$yaw');
        }
        i += 20;
        continue;
      }

      // ---------------- ACCEL PACKET (legacy 0x51) ----------------
      if (type == 0x51 && i + 11 <= bytes.length) {
        final ax = _toScaledAccel(bytes[i + 2], bytes[i + 3]);
        final ay = _toScaledAccel(bytes[i + 4], bytes[i + 5]);
        final az = _toScaledAccel(bytes[i + 6], bytes[i + 7]);
        _latest[deviceId]!["ax"] = ax;
        _latest[deviceId]!["ay"] = ay;
        _latest[deviceId]!["az"] = az;
        if (kDebugMode) {
          debugPrint('[$deviceId] ACCEL: ax=$ax, ay=$ay, az=$az');
        }
        i += 11;
        continue;
      }

      // ---------------- GYRO PACKET (legacy 0x52) ----------------
      if (type == 0x52 && i + 11 <= bytes.length) {
        final gx = _toScaledGyro(bytes[i + 2], bytes[i + 3]);
        final gy = _toScaledGyro(bytes[i + 4], bytes[i + 5]);
        final gz = _toScaledGyro(bytes[i + 6], bytes[i + 7]);
        _latest[deviceId]!["gx"] = gx;
        _latest[deviceId]!["gy"] = gy;
        _latest[deviceId]!["gz"] = gz;
        if (kDebugMode) {
          debugPrint('[$deviceId] GYRO: gx=$gx, gy=$gy, gz=$gz');
        }
        i += 11;
        continue;
      }

      // ---------------- ANGLE PACKET (legacy 0x53) ----------------
      if (type == 0x53 && i + 11 <= bytes.length) {
        final roll = _toScaledAngle(bytes[i + 2], bytes[i + 3]);
        final pitch = _toScaledAngle(bytes[i + 4], bytes[i + 5]);
        final yaw = _toScaledAngle(bytes[i + 6], bytes[i + 7]);
        _latest[deviceId]!["roll"] = roll;
        _latest[deviceId]!["pitch"] = pitch;
        _latest[deviceId]!["yaw"] = yaw;
        if (kDebugMode) {
          debugPrint('[$deviceId] ANGLE: roll=$roll, pitch=$pitch, yaw=$yaw');
        }
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
      if (kDebugMode) {
        debugPrint('[$deviceId] ✓ COMPLETE SAMPLE EMITTED: roll=${sample['roll']!.toStringAsFixed(1)}°, pitch=${sample['pitch']!.toStringAsFixed(1)}°, yaw=${sample['yaw']!.toStringAsFixed(1)}°');
      }
      if (_sampleControllers.containsKey(deviceId)) {
        _sampleControllers[deviceId]!.add(sample);
        if (kDebugMode) debugPrint('[$deviceId] ✓ Sample added to controller (listeners: ${_sampleControllers[deviceId]!.hasListener})');
      } else {
        if (kDebugMode) debugPrint('[$deviceId] ❌ ERROR: Controller missing when trying to emit sample!');
      }
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
