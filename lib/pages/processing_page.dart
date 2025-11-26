import 'package:flutter/material.dart';
import 'results_page.dart';

class ProcessingPage extends StatefulWidget {
  final Map<String, dynamic> leftData;
  final Map<String, dynamic> rightData;
  final dynamic bleMgr;
  final String leftId;
  final String rightId;

  const ProcessingPage({
    super.key,
    required this.leftData,
    required this.rightData,
    required this.bleMgr,
    required this.leftId,
    required this.rightId,
  });

  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    // Placeholder: simulate analysis delay
    // In the future, call your segmentation/analysis functions here
    await Future.delayed(const Duration(seconds: 2));

    // For now, just pass the raw data to results page
    // You can add real analysis logic later
    final analysisResults = {
      'leftSampleCount': (widget.leftData['samples'] as List).length,
      'rightSampleCount': (widget.rightData['samples'] as List).length,
      'leftSegments': widget.leftData['segments'],
      'rightSegments': widget.rightData['segments'],
    };

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => ResultsPage(
          results: analysisResults,
          bleMgr: widget.bleMgr,
          leftId: widget.leftId,
          rightId: widget.rightId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('Analyzing run data...', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
