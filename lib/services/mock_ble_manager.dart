import 'dart:async';
import 'dart:math';

/// MockBleManager: simple mock used for Windows testing.
/// Matches the small API used by `ble_page.dart`:
/// - `scanForDevices({nameFilter})` -> `Stream<Map<String,String>>`
/// - `connectAndWait(String)` -> `Future<bool>`
/// - `disconnectDevice(String)` -> `Future<void>`
/// - `sampleStream(String)` -> `Stream<Map<String,double>>`
class MockBleManager {
  MockBleManager._internal();
  static final MockBleManager _instance = MockBleManager._internal();
  factory MockBleManager() => _instance;

  final Map<String, Stream<Map<String, double>>> _streams = {};

  Stream<Map<String, String>> scanForDevices({String? nameFilter}) async* {
    await Future.delayed(const Duration(milliseconds: 100));
    yield {'id': 'MOCK-1', 'name': 'WT-Mock-1'};
    await Future.delayed(const Duration(milliseconds: 50));
    yield {'id': 'MOCK-2', 'name': 'WT-Mock-2'};
  }

  Future<bool> connectAndWait(String deviceId, {Duration timeout = const Duration(seconds: 4)}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  Future<void> disconnectDevice(String deviceId) async {
    _streams.remove(deviceId);
  }

  Stream<Map<String, double>>? sampleStream(String deviceId) {
    return _streams.putIfAbsent(deviceId, () {
      final rnd = Random(deviceId.hashCode);
      double t = 0.0;
      return Stream<Map<String, double>>.periodic(const Duration(milliseconds: 50), (_) {
        t += 0.05;
        final ax = sin(t * 2.0) * 0.5 + (rnd.nextDouble() - 0.5) * 0.02;
        final ay = cos(t * 1.6) * 0.4 + (rnd.nextDouble() - 0.5) * 0.02;
        final az = 9.81 + sin(t * 0.9) * 0.2 + (rnd.nextDouble() - 0.5) * 0.02;
        final gx = sin(t * 3.0) * 10.0 + (rnd.nextDouble() - 0.5) * 0.5;
        final gy = cos(t * 2.5) * 8.0 + (rnd.nextDouble() - 0.5) * 0.5;
        final gz = sin(t * 1.8) * 6.0 + (rnd.nextDouble() - 0.5) * 0.5;
        final roll = sin(t * 0.7) * 5.0;
        final pitch = cos(t * 0.6) * 4.0;
        final yaw = (t * 10.0) % 360.0;

        return {
          'ax': ax,
          'ay': ay,
          'az': az,
          'gx': gx,
          'gy': gy,
          'gz': gz,
          'roll': roll,
          'pitch': pitch,
          'yaw': yaw,
        };
      }).asBroadcastStream();
    });
  }
}
