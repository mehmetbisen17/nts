import 'dart:ui' show Offset;

import 'package:nts/data/services/plot_expression.dart';

/// What "Create a graph of it" draws: a formula ([FunctionPlot]) or numbers
/// from the notes ([DataPlot]). Made from the on-device model's JSON with
/// `fromJson`, drawn by `AiChart`.
sealed class PlotSpec {
  const new({required this.title, this.xLabel = '', this.yLabel = ''});

  final String title, xLabel, yLabel;
}

class FunctionPlot extends PlotSpec {
  /// Throws [FormatException] if [expression] can't be read, or if it has
  /// fewer than two points to draw between [xMin] and [xMax] (e.g. sqrt(x)
  /// for x < 0). An empty or backwards x range becomes -10..10.
  new({
    required super.title,
    required this.expression,
    required double xMin,
    required double xMax,
    super.xLabel,
    super.yLabel,
  }) : xMin = _isRange(xMin, xMax) ? xMin : -10,
       xMax = _isRange(xMin, xMax) ? xMax : 10 {
    if (samples.where((p) => p.dy.isFinite).length < 2) {
      throw FormatException('Nothing to draw', expression);
    }
  }

  factory fromJson(Map<String, dynamic> json) => FunctionPlot(
    title: _string(json['title']),
    expression: _string(json['expression']),
    xMin: _number(json['xMin']),
    xMax: _number(json['xMax']),
    xLabel: _string(json['xLabel']),
    yLabel: _string(json['yLabel']),
  );

  /// The right-hand side of the formula, e.g. "3*x^2 - 2*x + 1".
  final String expression;
  final double xMin, xMax;

  static const sampleCount = 400;

  /// (x, f(x)) at [sampleCount] evenly spaced x. y isn't finite where f
  /// isn't defined (the line breaks there).
  late final samples = () {
    final f = parseExpression(expression);
    return List.generate(sampleCount, (i) {
      final x = xMin + (xMax - xMin) * i / (sampleCount - 1);
      return Offset(x, f(x));
    });
  }();

  static bool _isRange(double min, double max) =>
      min.isFinite && max.isFinite && min < max;
}

enum DataPlotKind { line, bar }

class DataPlot extends PlotSpec {
  const new({
    required super.title,
    required this.kind,
    required this.points,
    super.xLabel,
    super.yLabel,
  });

  /// Throws [FormatException] if a field is missing or has the wrong type.
  /// Doesn't check the numbers against the notes: do that before drawing.
  factory fromJson(Map<String, dynamic> json) => DataPlot(
    title: _string(json['title']),
    kind: json['kind'] == 'bar' ? .bar : .line,
    xLabel: _string(json['xLabel']),
    yLabel: _string(json['yLabel']),
    points: [
      for (final point in _list(json['points']))
        if (point case {'label': final label, 'y': final y})
          (_string(label), _number(y))
        else
          throw FormatException('Bad point', point),
    ],
  );

  final DataPlotKind kind;

  /// Category name (or x value as written) and its number, in order.
  final List<(String label, double y)> points;
}

String _string(Object? value) => switch (value) {
  final String s => s.trim(),
  null => '',
  _ => throw FormatException('Not a string', value),
};

double _number(Object? value) => switch (value) {
  final num n when n.isFinite => n.toDouble(),
  final String s when double.tryParse(s.trim())?.isFinite ?? false =>
    double.parse(s.trim()),
  _ => throw FormatException('Not a number', value),
};

List<Object?> _list(Object? value) => switch (value) {
  final List<Object?> list => list,
  _ => throw FormatException('Not a list', value),
};
