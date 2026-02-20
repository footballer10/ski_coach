import 'package:flutter/material.dart';
import 'dart:math' as math;

class GraphPoint {
  final double time; // seconds from start
  final double value;

  GraphPoint(this.time, this.value);
}

/// Time series graph widget for edge angle and parallelness over time
class TimeSeriesGraph extends StatelessWidget {
  final List<GraphPoint> dataPoints;
  final double? optimalValue;
  final bool showOptimalLine;
  final String yAxisLabel;
  final double durationSeconds;
  final double height;

  const TimeSeriesGraph({
    super.key,
    required this.dataPoints,
    this.optimalValue,
    this.showOptimalLine = true,
    required this.yAxisLabel,
    required this.durationSeconds,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    final filteredPoints = dataPoints
        .where((p) => p.time.isFinite && p.value.isFinite)
        .toList(growable: false);

    if (filteredPoints.isEmpty || !durationSeconds.isFinite || durationSeconds <= 0) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No data')),
      );
    }

    final maxDataValue = filteredPoints.map((p) => p.value).reduce(math.max);
    final hasFiniteOptimal =
        showOptimalLine && optimalValue != null && optimalValue!.isFinite;
    final maxYValue = hasFiniteOptimal
        ? math.max(maxDataValue, optimalValue!)
        : maxDataValue;

    if (!maxYValue.isFinite || maxYValue <= 0) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No data')),
      );
    }

    // Determine y-axis increment
    final double yIncrement;
    if (maxYValue <= 8) {
      yIncrement = 1;
    } else if (maxYValue <= 20) {
      yIncrement = 2;
    } else {
      yIncrement = 5;
    }

    // Calculate y-axis max (round up to next increment)
    final yMax = (maxYValue / yIncrement).ceil() * yIncrement;
    final numYTicks = (yMax / yIncrement).toInt() + 1;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 10, 10, 30),
        child: CustomPaint(
          painter: TimeSeriesGraphPainter(
            dataPoints: filteredPoints,
            optimalValue: optimalValue,
            showOptimalLine: showOptimalLine,
            yMax: yMax.toDouble(),
            yIncrement: yIncrement,
            durationSeconds: durationSeconds,
            numYTicks: numYTicks,
          ),
          child: Container(),
        ),
      ),
    );
  }
}

class TimeSeriesGraphPainter extends CustomPainter {
  final List<GraphPoint> dataPoints;
  final double? optimalValue;
  final bool showOptimalLine;
  final double yMax;
  final double yIncrement;
  final double durationSeconds;
  final int numYTicks;

  TimeSeriesGraphPainter({
    required this.dataPoints,
    required this.optimalValue,
    required this.showOptimalLine,
    required this.yMax,
    required this.yIncrement,
    required this.durationSeconds,
    required this.numYTicks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!durationSeconds.isFinite || durationSeconds <= 0) return;
    if (!yMax.isFinite || yMax <= 0) return;

    final axisPaint = Paint()
      ..color = Colors.grey[700]!
      ..strokeWidth = 1.5;

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    final optimalLinePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Draw axes
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), axisPaint);

    // Draw y-axis grid and labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    for (int i = 0; i < numYTicks; i++) {
      final yValue = i * yIncrement;
      final yPos = size.height - (yValue / yMax) * size.height;

      // Grid line
      canvas.drawLine(Offset(0, yPos), Offset(size.width, yPos), gridPaint);

      // Y-axis label
      textPainter.text = TextSpan(
        text: yValue.toStringAsFixed(yValue % 1 == 0 ? 0 : 1),
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width - 5, yPos - textPainter.height / 2),
      );
    }

    // Draw x-axis labels (time)
    final numXTicks = math.min(6, durationSeconds.ceil() + 1);
    for (int i = 0; i <= numXTicks; i++) {
      final xValue = (i * durationSeconds / numXTicks);
      final xPos = (xValue / durationSeconds) * size.width;

      textPainter.text = TextSpan(
        text: xValue.toStringAsFixed(1),
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(xPos - textPainter.width / 2, size.height + 5),
      );
    }

    // Draw optimal value dotted line (optional)
    if (showOptimalLine && optimalValue != null) {
      final optimalY = size.height - (optimalValue! / yMax) * size.height;
      if (optimalValue! <= yMax) {
        _drawDottedLine(
          canvas,
          Offset(0, optimalY),
          Offset(size.width, optimalY),
          optimalLinePaint,
        );
      }
    }

    // Draw data points
    for (final point in dataPoints) {
      if (!point.time.isFinite || !point.value.isFinite) continue;
      final x = (point.time / durationSeconds) * size.width;
      final y = size.height - (point.value / yMax) * size.height;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  void _drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double distance = (end - start).distance;
    double traveled = 0;

    while (traveled < distance) {
      final startOffset = Offset.lerp(start, end, traveled / distance)!;
      traveled += dashWidth;
      final endOffset = Offset.lerp(
        start,
        end,
        math.min(traveled, distance) / distance,
      )!;
      canvas.drawLine(startOffset, endOffset, paint);
      traveled += dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
