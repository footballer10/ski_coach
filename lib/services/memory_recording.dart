import 'dart:async';
import 'turn_detector.dart';

/// Simple in-memory recorder.
/// Collects incoming `Map<String,double>` samples while recording.
class MemoryRecording {
  final String deviceId;
  final List<Map<String, double>> _samples = [];
  StreamSubscription<Map<String, double>>? _sub;
  DateTime? _startTime;

  MemoryRecording(this.deviceId);

  /// Start collecting samples from the provided stream.
  Future<void> start(Stream<Map<String, double>> samples) async {
    _samples.clear();
    _startTime = DateTime.now();
    _sub = samples.listen((s) {
      // clone the sample map to prevent later mutation
      final sample = Map<String, double>.from(s);
      // attach timestamp in seconds with millisecond precision (3 dp).
      // Use microsecondsSinceEpoch but round to milliseconds precision.
      final us = DateTime.now().microsecondsSinceEpoch;
      final seconds = us / 1e6;
      final secondsMsPrecision = ((seconds * 1000).round()) / 1000.0;
      sample['t'] = secondsMsPrecision; // seconds since epoch, 3 decimal places
      _samples.add(sample);
    });
  }

  /// Stop and optionally run the user-provided segmentation function.
  /// Returns a map with `samples` and `segments` (segments may be empty).
  Future<Map<String, dynamic>> stopAndSegment() async {
    final recorded = await stop();
    List<dynamic> segments = [];
    try {
      segments = segmenter(recorded);
    } catch (_) {
      segments = [];
    }
    return {'samples': recorded, 'segments': segments};
  }

  /// Stop collecting and return the collected samples.
  /// The internal buffer is cleared after returning.
  Future<List<Map<String, double>>> stop() async {
    await _sub?.cancel();
    _sub = null;
    final out = List<Map<String, double>>.from(_samples);
    _samples.clear();
    _startTime = null;
    return out;
  }

  /// Returns the number of samples currently buffered.
  int get count => _samples.length;

  /// If started, returns the recording start time.
  DateTime? get startTime => _startTime;
}
