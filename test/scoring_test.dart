import 'package:flutter_test/flutter_test.dart';
import 'package:ski_coach/services/scoring.dart';

void main() {
  group('Scoring.duration', () {
    test('peaks at 100 for a 1 s turn', () {
      expect(Scoring.duration(1.0), closeTo(100, 1e-9));
    });

    test('gives 50 for turns twice as fast or twice as slow', () {
      expect(Scoring.duration(0.5), closeTo(50, 1e-9));
      expect(Scoring.duration(2.0), closeTo(50, 1e-9));
    });

    test('gives 0 for non-positive durations', () {
      expect(Scoring.duration(0), 0);
      expect(Scoring.duration(-1), 0);
    });
  });

  group('Scoring.edgeAngle', () {
    test('rises from 0 toward 100 as edge angle grows', () {
      expect(Scoring.edgeAngle(0), closeTo(0, 1e-9));
      expect(Scoring.edgeAngle(20), lessThan(Scoring.edgeAngle(40)));
      expect(Scoring.edgeAngle(90), closeTo(100, 0.5));
    });

    test('treats non-finite input as 0', () {
      expect(Scoring.edgeAngle(double.nan), 0);
    });
  });

  group('Scoring.parallel and turnShape', () {
    test('give 100 at the optimum of 0', () {
      expect(Scoring.parallel(0), closeTo(100, 1e-9));
      expect(Scoring.turnShape(0), closeTo(100, 1e-9));
    });

    test('give 100/e at their scale value', () {
      expect(Scoring.parallel(30), closeTo(36.788, 0.001));
      expect(Scoring.turnShape(46.2), closeTo(36.788, 0.001));
    });
  });

  group('Scoring.symmetry', () {
    test('gives 100 for perfectly symmetric turns', () {
      expect(Scoring.symmetry(1.0), closeTo(100, 1e-9));
    });

    test('gives 25 when one side takes twice as long', () {
      expect(Scoring.symmetry(2.0), closeTo(25, 1e-9));
    });
  });
}
