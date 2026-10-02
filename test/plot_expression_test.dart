import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nts/data/services/plot_expression.dart';
import 'package:nts/data/services/plot_spec.dart';

void main() {
  group('parseExpression', () {
    final cases = <String, (double, double)>{
      'x^2 - 4x + 3': (2, -1),
      'y = x^2 - 4x + 3': (3, 0),
      'e^{-0.2t} * cos(2t)': (0, 1),
      'exp(-0.2*x)*cos(2*x)': (1, math.exp(-0.2) * math.cos(2)),
      '2*sin(x)+1': (math.pi / 2, 3),
      'x(x-1)': (3, 6),
      '2(x+1)^2': (1, 8),
      '-x^2': (3, -9),
      '2^-x': (1, 0.5),
      '3x^2 - 2x + 1': (2, 9),
      'sqrt(x) + ln(e)': (4, 3),
      'f(x) = 1/x': (4, 0.25),
      'ATP = 3*x': (2, 6), // "name =" in front is dropped
      'x² − 2π': (3, 9 - 2 * math.pi),
      '2**x': (3, 8),
      'log(x)': (100, 2),
      'abs(x)': (-2, 2),
    };
    cases.forEach((source, value) {
      test(source, () {
        expect(parseExpression(source)(value.$1), closeTo(value.$2, 1e-9));
      });
    });

    for (final bad in ['2 +', 'foo(x)', '', 'x + |x|', 'x; rm', '(x']) {
      test('rejects "$bad"', () {
        expect(() => parseExpression(bad), throwsFormatException);
      });
    }
  });

  group('FunctionPlot', () {
    test('fromJson', () {
      final plot = FunctionPlot.fromJson({
        'title': ' Parabola ',
        'expression': 'x^2',
        'xMin': -2,
        'xMax': 2.5,
        'xLabel': 'x',
        'yLabel': 'y',
      });
      expect(plot.title, 'Parabola');
      expect((plot.xMin, plot.xMax), (-2, 2.5));
      expect(plot.samples, hasLength(FunctionPlot.sampleCount));
      expect(plot.samples.first, const Offset(-2, 4));
      expect(plot.samples.last, const Offset(2.5, 6.25));
    });

    test('bad x range becomes -10..10', () {
      final plot = FunctionPlot(title: '', expression: 'x', xMin: 3, xMax: 3);
      expect((plot.xMin, plot.xMax), (-10, 10));
    });

    test('throws FormatException for unreadable or empty plots', () {
      expect(
        () => FunctionPlot(title: '', expression: 'ATP', xMin: 0, xMax: 1),
        throwsFormatException,
      );
      expect(
        () =>
            FunctionPlot(title: '', expression: 'sqrt(x)', xMin: -5, xMax: -1),
        throwsFormatException,
      );
      expect(
        () => FunctionPlot.fromJson({'title': 't', 'expression': 'x'}),
        throwsFormatException,
      );
    });
  });

  group('DataPlot', () {
    test('fromJson', () {
      final plot = DataPlot.fromJson({
        'title': 'Rain',
        'kind': 'bar',
        'xLabel': 'Month',
        'yLabel': 'mm',
        'points': [
          {'label': 'Jan', 'y': 78},
          {'label': 'Feb', 'y': 52.5},
        ],
      });
      expect(plot.kind, DataPlotKind.bar);
      expect(plot.points, [('Jan', 78.0), ('Feb', 52.5)]);
    });

    test('throws FormatException for bad points', () {
      expect(
        () => DataPlot.fromJson({
          'title': 'Rain',
          'kind': 'line',
          'points': [
            {'label': 'Jan', 'y': 'lots'},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => DataPlot.fromJson({'title': 'Rain', 'kind': 'line'}),
        throwsFormatException,
      );
    });
  });
}
