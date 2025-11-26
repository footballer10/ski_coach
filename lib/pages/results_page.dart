import 'package:flutter/material.dart';
import 'recording_page.dart';

class ResultsPage extends StatelessWidget {
  final Map<String, dynamic> results;
  final dynamic bleMgr;
  final String leftId;
  final String rightId;

  const ResultsPage({
    super.key,
    required this.results,
    required this.bleMgr,
    required this.leftId,
    required this.rightId,
  });

  @override
  Widget build(BuildContext context) {
    final leftCount = results['leftSampleCount'] ?? 0;
    final rightCount = results['rightSampleCount'] ?? 0;
    final leftSegments = results['leftSegments'] as List? ?? [];
    final rightSegments = results['rightSegments'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Run Analysis'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recording Summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text('Left Sensor: $leftCount samples'),
                    Text('Right Sensor: $rightCount samples'),
                    const SizedBox(height: 8),
                    Text('Left Segments: ${leftSegments.length}'),
                    Text('Right Segments: ${rightSegments.length}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detailed Analysis',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    Text('(Analysis metrics will appear here once implemented)'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                // Return to recording page to start a new run
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (ctx) => RecordingPage(
                      bleMgr: bleMgr,
                      leftId: leftId,
                      rightId: rightId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Record Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
