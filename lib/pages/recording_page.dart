import 'dart:async';
import 'package:flutter/material.dart';
import '../services/memory_recording.dart';
import 'processing_page.dart';

class RecordingPage extends StatefulWidget {
  final dynamic bleMgr;
  final String leftId;
  final String rightId;

  const RecordingPage({
    super.key,
    required this.bleMgr,
    required this.leftId,
    required this.rightId,
  });

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  MemoryRecording? _leftRec;
  MemoryRecording? _rightRec;
  StreamSubscription<Map<String, double>>? _leftSub;
  StreamSubscription<Map<String, double>>? _rightSub;
  Map<String, double>? _leftLatest;
  Map<String, double>? _rightLatest;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _subscribeToSamples();
  }

  @override
  void dispose() {
    _leftSub?.cancel();
    _rightSub?.cancel();
    super.dispose();
  }

  void _subscribeToSamples() {
    final leftStream = widget.bleMgr.sampleStream(widget.leftId);
    final rightStream = widget.bleMgr.sampleStream(widget.rightId);

    _leftSub = leftStream?.listen((s) {
      if (mounted) setState(() => _leftLatest = s);
    });

    _rightSub = rightStream?.listen((s) {
      if (mounted) setState(() => _rightLatest = s);
    });
  }

  Future<void> _startRecording() async {
    final leftStream = widget.bleMgr.sampleStream(widget.leftId);
    final rightStream = widget.bleMgr.sampleStream(widget.rightId);

    if (leftStream == null || rightStream == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample streams not available')),
      );
      return;
    }

    _leftRec = MemoryRecording(widget.leftId);
    _rightRec = MemoryRecording(widget.rightId);

    await _leftRec!.start(leftStream);
    await _rightRec!.start(rightStream);

    setState(() => _recording = true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recording started on both sensors')),
    );
  }

  Future<void> _stopRecording() async {
    if (_leftRec == null || _rightRec == null) return;

    setState(() => _recording = false);

    // Stop and retrieve samples (with segmentation hook called internally)
    final leftData = await _leftRec!.stopAndSegment();
    final rightData = await _rightRec!.stopAndSegment();

    if (!mounted) return;

    // Navigate to processing page (which will trigger analysis and show results)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => ProcessingPage(
          leftData: leftData,
          rightData: rightData,
          bleMgr: widget.bleMgr,
          leftId: widget.leftId,
          rightId: widget.rightId,
        ),
      ),
    );
  }

  Widget _buildSampleCard(String label, Map<String, double>? sample, Color color) {
    if (sample == null) {
      return Card(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Waiting for data...'),
            ],
          ),
        ),
      );
    }

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip('ax', sample['ax']),
                _chip('ay', sample['ay']),
                _chip('az', sample['az']),
                _chip('gx', sample['gx']),
                _chip('gy', sample['gy']),
                _chip('gz', sample['gz']),
                _chip('roll', sample['roll']),
                _chip('pitch', sample['pitch']),
                _chip('yaw', sample['yaw']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String key, double? val) {
    return Chip(
      label: Text('$key: ${val?.toStringAsFixed(2) ?? 'N/A'}'),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording Session'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSampleCard('LEFT Sensor', _leftLatest, Colors.green),
            const SizedBox(height: 12),
            _buildSampleCard('RIGHT Sensor', _rightLatest, Colors.blue),
            const Spacer(),
            if (!_recording)
              ElevatedButton.icon(
                onPressed: _startRecording,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Start Recording'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _stopRecording,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Recording'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
