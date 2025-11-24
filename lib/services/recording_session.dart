import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';


class RecordingSession {
  final String deviceId;
  IOSink? _sink;
  StreamSubscription<Map<String, double>>? _sub;
  File? _file;

  RecordingSession(this.deviceId);

  Future<void> start(Stream<Map<String, double>> samples) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeId = deviceId.replaceAll(RegExp(r"[^a-zA-Z0-9_-]"), '_');
    final file = File('${dir.path}/imu_${safeId}_${DateTime.now().toIso8601String()}.csv');
    _file = file;
    _sink = file.openWrite(mode: FileMode.write);
    _sink!.writeln('timestamp,ax,ay,az,gx,gy,gz,roll,pitch,yaw');
    _sub = samples.listen((s) {
      final t = DateTime.now().toIso8601String();
      final ax = s['ax'] ?? 0.0;
      final ay = s['ay'] ?? 0.0;
      final az = s['az'] ?? 0.0;
      final gx = s['gx'] ?? 0.0;
      final gy = s['gy'] ?? 0.0;
      final gz = s['gz'] ?? 0.0;
      final roll = s['roll'] ?? 0.0;
      final pitch = s['pitch'] ?? 0.0;
      final yaw = s['yaw'] ?? 0.0;
      _sink!.writeln('$t,$ax,$ay,$az,$gx,$gy,$gz,$roll,$pitch,$yaw');
    });
  }

  Future<void> stop() async {
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink = null;
  }

  /// Returns the file path if recording produced a file
  String? get filePath => _file?.path;
}
