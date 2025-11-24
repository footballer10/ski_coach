import 'dart:async';

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
      _samples.add(Map<String, double>.from(s));
    });
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
