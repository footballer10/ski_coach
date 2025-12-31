import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../models.dart';

class BleManager {
  // -------------------------------------------------------------
  // Singleton setup (you only want ONE BLE manager)
  // -------------------------------------------------------------
  BleManager._internal();
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // Track active scan subscription to ensure proper cleanup
  StreamSubscription<DiscoveredDevice>? _activeScanSubscription;

  // UUIDs for WT9011DCL BLE - CORRECTED from LightBlue inspection
  static final Uuid _service = Uuid.parse(
    "0000FFE5-0000-1000-8000-00805F9A34FB",
  );
  static final Uuid _char = Uuid.parse("0000FFE4-0000-1000-8000-00805F9A34FB");
  static final Uuid _charWrite = Uuid.parse(
    "0000FFE9-0000-1000-8000-00805F9A34FB",
  );

  // For storing Bluetooth connections
  final Map<String, StreamSubscription> _connSubs = {};
  final Map<String, StreamSubscription> _charSubs = {};

  // For outputting IMU samples as maps: {ax,ay,az,gx,gy,gz,roll,pitch,yaw}
  final Map<String, StreamController<Map<String, double>>> _sampleControllers =
      {};

  // Recording storage: device ID -> list of timestamped samples
  final Map<String, List<ImuSample>> _recordedSamples = {};
  bool _isRecording = false;
  DateTime? _recordingStartTime;

  // Yaw calibration: offset between left and right sensors at connection
  double? _yawOffsetRightMinusLeft;

  // Device ID to sensor side mapping (deviceId -> 'left' or 'right')
  final Map<String, String> _deviceSideMapping = {};

  // Axis remapping for mirrored sensor mounting
  // When sensors are mounted on opposite feet, their axes are mirrored
  // Set this to true if right sensor shows gravity in different axis than left
  static const bool _mirrorRightSensorAxes = true;

  // Calibration state: collect samples when both sensors connect
  bool _isCalibrating = false;
  final Map<String, List<double>> _calibrationSamples = {};
  static const int _calibrationSampleCount =
      100; // Increased from 50 to allow more settling time
  static const int _calibrationStartSample = 80; // Skip first 80 samples
  static const int _calibrationEndSample = 100; // Use samples 80-100

  /// Get the calibrated yaw offset (right - left) established at connection
  double? get yawOffset => _yawOffsetRightMinusLeft;

  /// Check if sensors are currently calibrating
  bool get isCalibrating => _isCalibrating;

  /// Register which device ID corresponds to which sensor side ('left' or 'right')
  void registerDeviceSide(String deviceId, String side) {
    _deviceSideMapping[deviceId] = side;
    if (kDebugMode) {
      debugPrint('🎯 Registered device $deviceId as $side sensor');
    }
  }

  /// Send acceleration calibration command to a device
  Future<void> calibrateAcceleration(String deviceId) async {
    try {
      final char = QualifiedCharacteristic(
        serviceId: _service,
        characteristicId: _charWrite,
        deviceId: deviceId,
      );

      // Step 1: Unlock (must complete within 10 seconds)
      await _ble.writeCharacteristicWithoutResponse(
        char,
        value: [0xFF, 0xAA, 0x69, 0x88, 0xB5],
      );
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 2: Acceleration calibration command
      await _ble.writeCharacteristicWithoutResponse(
        char,
        value: [0xFF, 0xAA, 0x01, 0x01, 0x00],
      );
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 3: Save command
      await _ble.writeCharacteristicWithoutResponse(
        char,
        value: [0xFF, 0xAA, 0x00, 0x00, 0x00],
      );

      if (kDebugMode) {
        debugPrint('✅ Acceleration calibration command sent to $deviceId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to send acceleration calibration: $e');
      }
    }
  }

  /// Stream of BLE status (ready, unauthorized, etc)
  Stream<BleStatus> get statusStream => _ble.statusStream;

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
    // Cancel any existing scan first
    _activeScanSubscription?.cancel();
    _activeScanSubscription = null;

    return _ble.scanForDevices(withServices: []);
  }

  /// Stop any active scan
  Future<void> stopScan() async {
    await _activeScanSubscription?.cancel();
    _activeScanSubscription = null;
    // Give iOS BLE stack time to fully stop
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Connect to device and wait until connected (or timeout). Returns true on success.
  Future<bool> connectAndWait(
    String deviceId, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_connSubs.containsKey(deviceId)) {
      return true;
    }

    final completer = Completer<bool>();

    final sub = _ble
        .connectToDevice(id: deviceId)
        .listen(
          (update) {
            if (update.connectionState == DeviceConnectionState.connected) {
              // Ensure a sample controller exists only upon successful connection
              _sampleControllers[deviceId] ??=
                  StreamController<Map<String, double>>.broadcast();
              _subscribeCharacteristic(deviceId);

              // Calibration will start automatically when both sensors start streaming data

              if (!completer.isCompleted) completer.complete(true);
            } else if (update.connectionState ==
                DeviceConnectionState.disconnected) {
              if (!completer.isCompleted) completer.complete(false);
            }
          },
          onError: (err) {
            if (!completer.isCompleted) completer.complete(false);
          },
        );

    _connSubs[deviceId] = sub;

    try {
      final ok = await completer.future.timeout(
        timeout,
        onTimeout: () {
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
        },
      );
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

    // Reset calibration if either sensor disconnects
    _isCalibrating = false;
    _calibrationSamples.clear();
    _yawOffsetRightMinusLeft = null;
    if (kDebugMode) {
      debugPrint('🎯 Calibration reset due to sensor disconnect');
    }
  }

  /// Check if a device is currently connected (subscription active)
  bool isConnected(String deviceId) {
    return _connSubs.containsKey(deviceId);
  }

  /// Check if both sensors are streaming data and start calibration
  void _checkAndStartCalibration() {
    // Only start calibration if we've received data from both sensors
    final hasLeftData = _latest.keys.any(
      (id) => _deviceSideMapping[id] == 'left',
    );
    final hasRightData = _latest.keys.any(
      (id) => _deviceSideMapping[id] == 'right',
    );

    if (hasLeftData &&
        hasRightData &&
        !_isCalibrating &&
        _yawOffsetRightMinusLeft == null) {
      _startCalibration();
      if (kDebugMode) {
        debugPrint('🎯 Both sensors streaming - starting calibration');
      }
    }
  }

  /// Start calibration process - collect samples from both sensors
  void _startCalibration() {
    // Show calibration overlay immediately
    _isCalibrating = true;
    _calibrationSamples.clear();
    _calibrationSamples['left'] = [];
    _calibrationSamples['right'] = [];
    
    if (kDebugMode) {
      debugPrint(
        '🎯 ════════════════════════════════════════════════════════════════',
      );
      debugPrint('🎯 CALIBRATION OVERLAY SHOWN - Waiting for sensors to settle...');
      debugPrint(
        '🎯 ════════════════════════════════════════════════════════════════',
      );
    }
    
    // Wait 5 seconds before starting to collect calibration samples to allow sensors to settle
    Future.delayed(const Duration(seconds: 5), () {
      if (_isCalibrating && _yawOffsetRightMinusLeft == null) {
        if (kDebugMode) {
          debugPrint(
            '🎯 STARTING YAW CALIBRATION (after 5s settling time)',
          );
          debugPrint(
            '🎯 Collecting $_calibrationSampleCount samples from each sensor...',
          );
        }
      }
    });
  }

  /// Try to calibrate with current samples
  void _tryCalibrate(String deviceId, double yaw) {
    if (!_isCalibrating) return;

    // Determine which sensor this is using the mapping
    final sensorKey = _deviceSideMapping[deviceId];
    if (sensorKey == null) {
      if (kDebugMode) {
        debugPrint(
          '⚠️  Warning: Device $deviceId not registered for calibration',
        );
      }
      return;
    }

    // Add sample to calibration buffer
    if (_calibrationSamples[sensorKey] != null &&
        _calibrationSamples[sensorKey]!.length < _calibrationSampleCount) {
      _calibrationSamples[sensorKey]!.add(yaw);
    }

    // Check if we have enough samples from both sensors
    final leftCount = _calibrationSamples['left']?.length ?? 0;
    final rightCount = _calibrationSamples['right']?.length ?? 0;

    if (leftCount >= _calibrationSampleCount &&
        rightCount >= _calibrationSampleCount) {
      // Calculate offset using samples 40-50
      final leftSamples = _calibrationSamples['left']!;
      final rightSamples = _calibrationSamples['right']!;

      final leftAvg =
          leftSamples
              .skip(_calibrationStartSample)
              .take(_calibrationEndSample - _calibrationStartSample)
              .reduce((a, b) => a + b) /
          (_calibrationEndSample - _calibrationStartSample);
      final rightAvg =
          rightSamples
              .skip(_calibrationStartSample)
              .take(_calibrationEndSample - _calibrationStartSample)
              .reduce((a, b) => a + b) /
          (_calibrationEndSample - _calibrationStartSample);

      _yawOffsetRightMinusLeft = rightAvg - leftAvg;
      _isCalibrating = false;
      _calibrationSamples.clear();

      if (kDebugMode) {
        debugPrint(
          '🎯 ════════════════════════════════════════════════════════════════',
        );
        debugPrint('🎯 YAW OFFSET CALIBRATION COMPLETE');
        debugPrint(
          '🎯 Used samples $_calibrationStartSample-$_calibrationEndSample after connection',
        );
        debugPrint('🎯 Left sensor average: ${leftAvg.toStringAsFixed(2)}°');
        debugPrint('🎯 Right sensor average: ${rightAvg.toStringAsFixed(2)}°');
        debugPrint(
          '🎯 Offset (right - left): ${_yawOffsetRightMinusLeft!.toStringAsFixed(2)}°',
        );
        debugPrint(
          '🎯 ════════════════════════════════════════════════════════════════',
        );
      }
    } else if (kDebugMode && (leftCount % 10 == 0 || rightCount % 10 == 0)) {
      debugPrint(
        '🎯 Calibration progress: Left=$leftCount/$_calibrationSampleCount, Right=$rightCount/$_calibrationSampleCount',
      );
    }
  }

  /// Disconnect all connected devices
  Future<void> disconnectAll() async {
    if (kDebugMode) {
      debugPrint('🔌 Disconnecting ${_connSubs.length} devices');
    }
    final ids = _connSubs.keys.toList();
    for (final id in ids) {
      try {
        await disconnectDevice(id);
      } catch (_) {}
    }
    // Small delay to allow iOS to finalize disconnections
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // -------------------------------------------------------------
  // Recording control
  // -------------------------------------------------------------

  /// Start recording IMU data from all connected sensors
  void startRecording() {
    if (_isRecording) return;
    _isRecording = true;
    _recordingStartTime = DateTime.now();
    _recordedSamples.clear();
    // Keep existing calibration - don't reset it
    if (kDebugMode) {
      debugPrint('🔴 Recording started');
      if (_yawOffsetRightMinusLeft != null) {
        debugPrint(
          '🔴 Using calibrated yaw offset: ${_yawOffsetRightMinusLeft!.toStringAsFixed(2)}°',
        );
      } else {
        debugPrint('⚠️  WARNING: Recording started without calibration!');
      }
    }
  }

  /// Stop recording and return the recorded data
  Map<String, List<ImuSample>> stopRecording() {
    if (!_isRecording) return {};
    _isRecording = false;
    final duration = DateTime.now().difference(_recordingStartTime!);
    if (kDebugMode) {
      final leftCount = _recordedSamples['WTLeft']?.length ?? 0;
      final rightCount = _recordedSamples['WTRight']?.length ?? 0;
      final avgHz = duration.inSeconds > 0
          ? ((leftCount + rightCount) / 2 / duration.inSeconds).toStringAsFixed(
              1,
            )
          : '0';
      debugPrint(
        '⏹️ Recording stopped: ${duration.inSeconds}s, ${leftCount}L/${rightCount}R samples (~$avgHz Hz)',
      );
    }
    return Map.from(_recordedSamples);
  }

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Get recorded sample count for a device
  int getRecordedCount(String deviceId) =>
      _recordedSamples[deviceId]?.length ?? 0;

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
    _sampleControllers[deviceId] =
        StreamController<Map<String, double>>.broadcast();
  }

  // -------------------------------------------------------------
  // Subscribe to the IMU data stream
  // -------------------------------------------------------------
  Future<void> _subscribeCharacteristic(String deviceId) async {
    try {
      // Try requesting a larger MTU to potentially trigger service discovery
      try {
        await _ble.requestMtu(deviceId: deviceId, mtu: 512);
      } catch (e) {
        if (kDebugMode) debugPrint('[$deviceId] MTU request failed: $e');
      }

      // Wait a moment
      await Future.delayed(const Duration(milliseconds: 500));

      // Try discovering services
      try {
        await _ble.discoverAllServices(deviceId);
      } catch (e) {
        if (kDebugMode) debugPrint('[$deviceId] Service discovery error: $e');
      }

      // Wait for iOS to populate services
      await Future.delayed(const Duration(milliseconds: 5000));

      final char = QualifiedCharacteristic(
        serviceId: _service,
        characteristicId: _char,
        deviceId: deviceId,
      );

      // Subscribe
      _charSubs[deviceId] = _ble
          .subscribeToCharacteristic(char)
          .listen(
            (data) {
              _handleRawPacket(deviceId, data);
            },
            onError: (e) {
              if (kDebugMode) {
                debugPrint('[$deviceId] ❌ Subscription error: $e');
              }
            },
            onDone: () {
              if (kDebugMode) debugPrint('[$deviceId] Subscription closed');
            },
          );
    } catch (e) {
      if (kDebugMode) debugPrint('[$deviceId] ❌ Subscribe error: $e');
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

      // ---------------- PACKET TYPE 0x61 (20 bytes total) ----------------
      // WT9011DCL default output: acceleration + angular velocity + angle
      // Packet format: 0x55 0x61 AXL AXH AYL AYH AZL AZH WXL WXH WYL WYH WZL WZH RollL RollH PitchL PitchH YawL YawH
      if (type == 0x61 && i + 20 <= bytes.length) {
        // Acceleration (bytes 2-7): Low byte first, high byte second
        double ax = _toScaledAccel(bytes[i + 2], bytes[i + 3]);
        double ay = _toScaledAccel(bytes[i + 4], bytes[i + 5]);
        double az = _toScaledAccel(bytes[i + 6], bytes[i + 7]);

        // Apply axis remapping for right sensor (mirrored mounting)
        final sensorSide = _deviceSideMapping[deviceId];
        if (_mirrorRightSensorAxes && sensorSide == 'right') {
          // Swap Y and Z axes for right sensor to match left sensor orientation
          final temp = ay;
          ay = az;
          az = temp;
        }

        // Angular velocity / Gyro (bytes 8-13)
        final gx = _toScaledGyro(bytes[i + 8], bytes[i + 9]);
        final gy = _toScaledGyro(bytes[i + 10], bytes[i + 11]);
        final gz = _toScaledGyro(bytes[i + 12], bytes[i + 13]);

        // Angles (bytes 14-19)
        final roll = _toScaledAngle(bytes[i + 14], bytes[i + 15]);
        final pitch = _toScaledAngle(bytes[i + 16], bytes[i + 17]);
        final yaw = _toScaledAngle(bytes[i + 18], bytes[i + 19]);

        _latest[deviceId]!["ax"] = ax;
        _latest[deviceId]!["ay"] = ay;
        _latest[deviceId]!["az"] = az;
        _latest[deviceId]!["gx"] = gx;
        _latest[deviceId]!["gy"] = gy;
        _latest[deviceId]!["gz"] = gz;
        _latest[deviceId]!["roll"] = roll;
        _latest[deviceId]!["pitch"] = pitch;
        _latest[deviceId]!["yaw"] = yaw;

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
          // Accel data parsed
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
          // Gyro data parsed
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
          // Angle data parsed
        }
        i += 11;
        continue;
      }

      i++;
    }

    // If all values exist, emit sample
    final map = _latest[deviceId]!;
    if (_hasAllFields(map)) {
      final timestamp = DateTime.now();

      // Check if we should start calibration (both sensors now have data)
      if (!_isCalibrating && _yawOffsetRightMinusLeft == null) {
        _checkAndStartCalibration();
      }

      // Feed calibration system if active
      if (_isCalibrating) {
        _tryCalibrate(deviceId, map['yaw']!);
      }

      // Compute parallelness if we have a calibrated offset and paired sample
      double? parallelness;
      if (_yawOffsetRightMinusLeft != null && _isRecording) {
        final otherDeviceId = deviceId == 'left' ? 'right' : 'left';
        final otherSamples = _recordedSamples[otherDeviceId];
        if (otherSamples != null && otherSamples.isNotEmpty) {
          // Find the most recent sample from the other device
          final otherYaw = otherSamples.last.yaw;
          final actualDiff = deviceId == 'left'
              ? otherYaw -
                    map['yaw']! // right - left
              : map['yaw']! - otherYaw; // right - left
          parallelness = actualDiff.abs(); // Yaw difference for parallelness
        }
      }

      // Create ImuSample for storage with parallelness
      final imuSample = ImuSample(
        timestamp: timestamp,
        ax: map['ax']!,
        ay: map['ay']!,
        az: map['az']!,
        gx: map['gx']!,
        gy: map['gy']!,
        gz: map['gz']!,
        roll: map['roll']!,
        pitch: map['pitch']!,
        yaw: map['yaw']!,
        parallelness: parallelness,
      );

      // Store sample if recording
      if (_isRecording) {
        _recordedSamples.putIfAbsent(deviceId, () => []);
        _recordedSamples[deviceId]!.add(imuSample);
      }

      // Also emit as map for backward compatibility with UI streams
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

      if (_sampleControllers.containsKey(deviceId)) {
        _sampleControllers[deviceId]!.add(sample);
      }
      map.clear(); // reset for next sample
    }
  }

  // -------------------------------------------------------------
  // Byte conversion helpers
  // -------------------------------------------------------------
  bool _hasAllFields(Map<String, double> m) {
    const req = ["ax", "ay", "az", "gx", "gy", "gz", "roll", "pitch", "yaw"];
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
