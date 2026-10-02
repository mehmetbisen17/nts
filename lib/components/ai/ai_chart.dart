import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/services/plot_spec.dart';
import 'package:sbn/font_fallbacks.dart';

/// A [PlotSpec] drawn in Higan style: light title, hairline grid and axes,
/// mono tick labels, a bone/ink line and one red highlight (the formula's
/// zeros, or the largest number).
///
/// [renderPng] draws the same chart on paper, for adding to a note page.
class AiChart extends StatelessWidget {
  const new(this.spec, {super.key});

  final PlotSpec spec;

  static const aspectRatio = 3 / 2;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: spec.title,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: CustomPaint(
          painter: _ChartPainter(
            spec,
            colors: context.higan,
            sans: HiganText.body(context),
          ),
        ),
      ),
    );
  }

  /// Ink on paper, whatever the app theme, so it looks right on a page.
  static final _paper = HiganColors.paper.copyWith(
    bg: const Color(0xFFF4F2ED),
    text: const Color(0xFF23211F),
  );

  /// The chart as a PNG on paper (#F4F2ED) with dark ink.
  /// [size] is in pixels; the chart is laid out as if 600 wide, then scaled.
  static Future<Uint8List> renderPng(
    PlotSpec spec, {
    Size size = const Size(1200, 800),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(_paper.bg, .src);
    _ChartPainter(
      spec,
      colors: _paper,
      sans: const TextStyle(
        fontFamily: HiganText.sans,
        fontFamilyFallback: saberSansSerifFontFallbacks,
      ),
      scale: size.width / 600,
    ).paint(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    picture.dispose();
    try {
      final bytes = await image.toByteData(format: .png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

class _ChartPainter extends CustomPainter {
  new(this.spec, {required this.colors, required this.sans, this.scale = 1});

  final PlotSpec spec;
  final HiganColors colors;

  /// Font for the title (the theme's, so Atkinson Hyperlegible if enabled).
  final TextStyle sans;

  /// 1 in the app; bigger for [AiChart.renderPng].
  final double scale;

  double get u => scale;

  late final _titleStyle = sans.copyWith(
    fontSize: 20 * u,
    fontWeight: .w300,
    letterSpacing: -0.4 * u,
    height: 1.15,
    color: colors.text,
  );
  late final _tickStyle = TextStyle(
    fontFamily: HiganText.mono,
    fontFamilyFallback: saberMonoFontFallbacks,
    fontSize: 10 * u,
    letterSpacing: 0.4 * u,
    color: colors.textSecondary,
  );

  /// Axis names, as written: never in caps, "mm" isn't "MM".
  late final _nameStyle = _tickStyle.copyWith(fontSize: 10.5 * u);

  @override
  void paint(Canvas canvas, Size size) {
    final pad = 16 * u;
    var top = pad;
    if (spec.title.isNotEmpty) {
      top +=
          _text(
            canvas,
            spec.title,
            _titleStyle,
            Offset(pad, top),
            maxWidth: size.width - 2 * pad,
            maxLines: 2,
          ).height +
          10 * u;
    }
    if (spec.yLabel.isNotEmpty) {
      top +=
          _text(
            canvas,
            spec.yLabel,
            _nameStyle,
            Offset(pad, top),
            maxWidth: size.width - 2 * pad,
          ).height +
          8 * u;
    }
    var bottom = size.height - pad;
    if (spec.xLabel.isNotEmpty) {
      bottom -=
          _text(
            canvas,
            spec.xLabel,
            _nameStyle,
            Offset(size.width - pad, bottom),
            anchor: .bottomRight,
            maxWidth: size.width - 2 * pad,
          ).height +
          6 * u;
    }
    bottom -= _tickStyle.fontSize! * 1.3 + 8 * u; // x tick labels

    final (y0, y1, yTicks) = switch (spec) {
      final FunctionPlot plot => _functionYRange(plot),
      final DataPlot plot => _dataYRange(plot),
    };
    final yStep = yTicks.length > 1 ? yTicks[1] - yTicks[0] : y1 - y0;
    final yTickLabels = [for (final y in yTicks) _format(y, yStep)];
    final left =
        pad + yTickLabels.map(_width).fold<double>(0, math.max) + 10 * u;
    final plot = Rect.fromLTRB(left, top, size.width - pad, bottom);
    if (plot.width < 20 || plot.height < 20) return;
    double sy(double y) => plot.bottom - (y - y0) / (y1 - y0) * plot.height;

    final hairline = Paint()
      ..color = colors.hairline
      ..strokeWidth = u;
    for (final (i, y) in yTicks.indexed) {
      final dy = sy(y);
      canvas.drawLine(Offset(plot.left, dy), Offset(plot.right, dy), hairline);
      _text(
        canvas,
        yTickLabels[i],
        _tickStyle,
        Offset(plot.left - 8 * u, dy),
        anchor: .centerRight,
      );
    }

    switch (spec) {
      case final FunctionPlot spec:
        _paintFunction(canvas, spec, plot, y0, y1, sy);
      case final DataPlot spec:
        _paintData(canvas, spec, plot, y0, sy);
    }

    // Axes on top of the grid.
    final axis = Paint()
      ..color = colors.hairlineStrong
      ..strokeWidth = u;
    canvas
      ..drawLine(plot.bottomLeft, plot.bottomRight, axis)
      ..drawLine(plot.bottomLeft, plot.topLeft, axis);
  }

  void _paintFunction(
    Canvas canvas,
    FunctionPlot spec,
    Rect plot,
    double y0,
    double y1,
    double Function(double) sy,
  ) {
    final (x0, x1) = (spec.xMin, spec.xMax);
    double sx(double x) => plot.left + (x - x0) / (x1 - x0) * plot.width;

    final xStep = _step(x0, x1, (plot.width / (70 * u)).clamp(2, 10).round());
    final xTicks = _ticks(x0, x1, xStep);
    final hairline = Paint()
      ..color = colors.hairline
      ..strokeWidth = u;
    for (final x in xTicks) {
      final dx = sx(x);
      canvas.drawLine(Offset(dx, plot.top), Offset(dx, plot.bottom), hairline);
      _text(
        canvas,
        _format(x, xStep),
        _tickStyle,
        Offset(dx, plot.bottom + 8 * u),
        anchor: .topCenter,
      );
    }

    // Zero lines, a little stronger than the grid.
    final zero = Paint()
      ..color = colors.textTertiary
      ..strokeWidth = u;
    if (y0 < 0 && y1 > 0) {
      canvas.drawLine(
        Offset(plot.left, sy(0)),
        Offset(plot.right, sy(0)),
        zero,
      );
    }
    if (x0 < 0 && x1 > 0) {
      canvas.drawLine(
        Offset(sx(0), plot.top),
        Offset(sx(0), plot.bottom),
        zero,
      );
    }

    // The curve: breaks where f isn't defined or jumps across the chart
    // (e.g. 1/x at 0). Far-off values are clamped so the path stays sane.
    final range = y1 - y0;
    bool outside(double y) => y < y0 || y > y1;
    bool jump(Offset a, Offset b) =>
        outside(a.dy) && outside(b.dy) && (a.dy < y0) != (b.dy < y0);
    final path = Path();
    Offset? last;
    for (final p in spec.samples) {
      if (!p.dy.isFinite) {
        last = null;
        continue;
      }
      final point = Offset(
        sx(p.dx),
        sy(p.dy.clamp(y0 - 10 * range, y1 + 10 * range)),
      );
      if (last == null || jump(last, p)) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      last = p;
    }
    canvas
      ..save()
      ..clipRect(plot.inflate(u))
      ..drawPath(path, _line)
      ..restore();

    // Zeros in red (none if there are too many to be useful).
    final zeros = <double>[];
    for (var i = 0; i + 1 < spec.samples.length; i++) {
      final a = spec.samples[i], b = spec.samples[i + 1];
      if (!a.dy.isFinite || !b.dy.isFinite || outside(a.dy) || outside(b.dy)) {
        continue;
      }
      if (a.dy == 0) {
        zeros.add(a.dx);
      } else if (a.dy * b.dy < 0) {
        zeros.add(a.dx - a.dy * (b.dx - a.dx) / (b.dy - a.dy));
      }
    }
    if (zeros.length <= 8) {
      final red = Paint()..color = colors.higanText;
      for (final x in zeros) {
        canvas.drawCircle(Offset(sx(x), sy(0)), 3.5 * u, red);
      }
    }
  }

  void _paintData(
    Canvas canvas,
    DataPlot spec,
    Rect plot,
    double y0,
    double Function(double) sy,
  ) {
    final points = spec.points;
    if (points.isEmpty) return;
    final slot = plot.width / points.length;
    double cx(int i) => plot.left + slot * (i + 0.5);
    var maxIndex = 0;
    for (var i = 1; i < points.length; i++) {
      if (points[i].$2 > points[maxIndex].$2) maxIndex = i;
    }

    // Category labels: every n-th one if they don't all fit.
    const maxChars = 12;
    final labels = [
      for (final (label, _) in points)
        if (label.length > maxChars)
          '${label.substring(0, maxChars - 1)}…'
        else
          label,
    ];
    final widest = labels.map(_width).fold<double>(0, math.max) + 8 * u;
    final every = (widest / slot).ceil().clamp(1, points.length);
    for (var i = 0; i < points.length; i += every) {
      _text(
        canvas,
        labels[i],
        _tickStyle,
        Offset(cx(i), plot.bottom + 8 * u),
        anchor: .topCenter,
      );
    }

    final red = colors.higanText;
    final valueStyle = _tickStyle.copyWith(color: colors.text);
    final showValues = slot > 26 * u;

    switch (spec.kind) {
      case .bar:
        final base = sy(math.max(y0, 0));
        final width = math.min(slot * 0.62, 56 * u);
        for (final (i, (_, y)) in points.indexed) {
          final isMax = i == maxIndex;
          final rect = Rect.fromLTRB(
            cx(i) - width / 2,
            math.min(sy(y), base),
            cx(i) + width / 2,
            math.max(sy(y), base),
          );
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              rect,
              topLeft: Radius.circular(y >= 0 ? 2 * u : 0),
              topRight: Radius.circular(y >= 0 ? 2 * u : 0),
              bottomLeft: Radius.circular(y < 0 ? 2 * u : 0),
              bottomRight: Radius.circular(y < 0 ? 2 * u : 0),
            ),
            Paint()..color = isMax ? red : colors.text.withValues(alpha: 0.78),
          );
          if (showValues || isMax) {
            _text(
              canvas,
              value(y),
              isMax ? valueStyle.copyWith(color: red) : valueStyle,
              Offset(cx(i), y >= 0 ? rect.top - 5 * u : rect.bottom + 5 * u),
              anchor: y >= 0 ? .bottomCenter : .topCenter,
            );
          }
        }
      case .line:
        final path = Path();
        for (final (i, (_, y)) in points.indexed) {
          if (i == 0) {
            path.moveTo(cx(i), sy(y));
          } else {
            path.lineTo(cx(i), sy(y));
          }
        }
        canvas.drawPath(path, _line);
        final dot = Paint()..color = colors.text;
        for (final (i, (_, y)) in points.indexed) {
          if (i == maxIndex) continue;
          canvas.drawCircle(Offset(cx(i), sy(y)), 2.5 * u, dot);
        }
        final y = points[maxIndex].$2;
        canvas.drawCircle(
          Offset(cx(maxIndex), sy(y)),
          4 * u,
          Paint()..color = red,
        );
        _text(
          canvas,
          value(y),
          valueStyle.copyWith(color: red),
          Offset(cx(maxIndex), sy(y) - 9 * u),
          anchor: .bottomCenter,
        );
    }
  }

  late final _line = Paint()
    ..color = colors.text
    ..style = .stroke
    ..strokeWidth = 1.75 * u
    ..strokeJoin = .round
    ..strokeCap = .round;

  /// y range and ticks for a formula: the middle 90% of its values, grown by
  /// up to half again towards the real min/max, so a parabola shows its
  /// top but 1/x doesn't shoot off to ±400.
  (double, double, List<double>) _functionYRange(FunctionPlot spec) {
    final ys = [
      for (final p in spec.samples)
        if (p.dy.isFinite) p.dy,
    ]..sort();
    double at(double q) => ys[(q * (ys.length - 1)).round()];
    final (p5, p95) = (at(0.05), at(0.95));
    final spread = p95 - p5;
    return _niceRange(
      math.max(ys.first, p5 - spread / 2),
      math.min(ys.last, p95 + spread / 2),
    );
  }

  /// Bars start at 0; lines fit their numbers with a little room.
  (double, double, List<double>) _dataYRange(DataPlot spec) {
    if (spec.points.isEmpty) return _niceRange(0, 1);
    final ys = spec.points.map((p) => p.$2);
    var (lo, hi) = (ys.reduce(math.min), ys.reduce(math.max));
    if (spec.kind == .bar) {
      (lo, hi) = (math.min(lo, 0), math.max(hi, 0));
      final room = (hi - lo) * 0.12; // for the numbers above bars
      if (hi > 0) hi += room;
      if (lo < 0) lo -= room;
    } else {
      final room = (hi - lo) * 0.1;
      (lo, hi) = (lo - room, hi + room);
    }
    return _niceRange(lo, hi);
  }

  /// Grows [lo]..[hi] to whole ticks (about 5 of them).
  (double, double, List<double>) _niceRange(double lo, double hi) {
    if (hi - lo < 1e-9 * math.max(1, hi.abs())) {
      final d = math.max(1.0, hi.abs() * 0.1);
      (lo, hi) = (lo - d, hi + d);
    }
    final step = _step(lo, hi, 5);
    lo = (lo / step + 1e-9).floorToDouble() * step;
    hi = (hi / step - 1e-9).ceilToDouble() * step;
    return (lo, hi, _ticks(lo, hi, step));
  }

  /// A "nice" distance between ticks (1, 2 or 5 × 10ⁿ), for about [count]
  /// ticks in [lo]..[hi].
  static double _step(double lo, double hi, int count) {
    final raw = (hi - lo) / count;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floorToDouble())
        .toDouble();
    final norm = raw / magnitude;
    return magnitude *
        (norm < 1.5
            ? 1
            : norm < 3
            ? 2
            : norm < 7
            ? 5
            : 10);
  }

  /// Multiples of [step] in [lo]..[hi].
  static List<double> _ticks(double lo, double hi, double step) {
    final first = (lo / step - 1e-9).ceil();
    final last = (hi / step + 1e-9).floor();
    return [for (var i = first; i <= last; i++) i * step];
  }

  static final _compact = NumberFormat.compact();

  /// A number from the notes, e.g. "12", "0.35", "1.2M".
  static String value(double y) {
    if (y.abs() >= 100000) return _compact.format(y);
    return y
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceFirst(RegExp(r'^-0$'), '0');
  }

  /// A tick or value label, e.g. "0.25", "-3", "12K".
  static String _format(double value, double step) {
    if (value.abs() < step * 1e-6) return '0';
    if (value.abs() >= 10000) return _compact.format(value);
    final decimals = (-(math.log(step) / math.ln10).floor()).clamp(0, 6);
    return value.toStringAsFixed(decimals);
  }

  double _width(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _tickStyle),
      textDirection: .ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Paints [text] with its [anchor] point at [at]; returns its size.
  Size _text(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at, {
    Alignment anchor = .topLeft,
    double maxWidth = .infinity,
    int maxLines = 1,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: .ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final size = painter.size;
    painter.paint(canvas, at - anchor.alongSize(size));
    painter.dispose();
    return size;
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.spec != spec ||
      old.colors != colors ||
      old.sans != sans ||
      old.scale != scale;
}
