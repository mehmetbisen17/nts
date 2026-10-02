import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:path_drawing/path_drawing.dart';

/// Stroke weights (logical px, independent of size) and anther radius
/// (drawing units), as in the mockup's `LILY(w)`.
enum HiganLilyVariant {
  /// Headers and sidebar (~22-26px).
  mark(petal: 1.15, stamen: 0.75, anther: 2.6),

  /// Medium sizes: empty states, loading (~48-160px).
  thin(petal: 1.25, stamen: 0.8, anther: 2.4),

  /// Large hero drawings (~300px).
  hero(petal: 1.9, stamen: 0.95, anther: 2.1);

  new({required this.petal, required this.stamen, required this.anther});

  final double petal, stamen, anther;
}

/// The higanbana (red spider lily): 7 recurved petals, 7 stamens with gold
/// anthers, 1 pistil and a stem.
///
/// It barely moves: the flower sways, each stamen drifts out of step and the
/// petals breathe. With [drawIn] the filaments draw themselves in, in a
/// gentle loop (use [HiganLoading]). Motion stops when
/// [MediaQuery.disableAnimations] is on or the ticker is muted.
class HiganLily extends StatefulWidget {
  const new({
    super.key,
    this.size = 24,
    this.variant = .mark,
    this.animate = true,
    this.drawIn = false,
  });

  /// Width in logical px. Height is `size * 214 / 200`.
  final double size;
  final HiganLilyVariant variant;
  final bool animate;
  final bool drawIn;

  @override
  State<HiganLily> createState() => _HiganLilyState();
}

class _HiganLilyState extends State<HiganLily>
    with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(_onTick);

  /// Seconds since the ticker started.
  final _time = ValueNotifier<double>(0);

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    // ponytail: ~30fps is plenty for sub-degree motion; lift if it looks choppy.
    if (t - _time.value >= 1 / 30) _time.value = t;
  }

  bool get _shouldMove =>
      (widget.animate || widget.drawIn) &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _sync() {
    if (_shouldMove) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
      _time.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(HiganLily oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.higan;
    final moving = _shouldMove;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(widget.size, widget.size * _LilyPainter.aspect),
          painter: _LilyPainter(
            time: _time,
            variant: widget.variant,
            sway: widget.animate && moving,
            drawIn: widget.drawIn && moving,
            petal: colors.higan,
            anther: colors.stamen,
            stem: colors.stem,
          ),
        ),
      ),
    );
  }
}

class _LilyPainter extends CustomPainter {
  new({
    required this.time,
    required this.variant,
    required this.sway,
    required this.drawIn,
    required this.petal,
    required this.anther,
    required this.stem,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final HiganLilyVariant variant;
  final bool sway, drawIn;
  final Color petal, anther, stem;

  /// viewBox 0 0 200 214
  static const aspect = 214 / 200;
  static const _center = Offset(100, 124);
  static const _base = Offset(100, 214);

  static final _petals = [
    'M100 124 C86 116 66 110 50 114 C41 116 40 127 49 127 C54 127 55 121 50 120',
    'M100 124 C90 106 78 90 66 84 C58 80 51 88 58 93 C62 96 66 93 63 89',
    'M100 124 C95 102 93 86 96 74 C98 67 106 67 106 74 C106 79 101 80 100 76',
    'M100 124 C107 104 119 90 132 86 C140 83 145 92 138 96 C134 98 131 94 134 91',
    'M100 124 C114 116 134 110 150 114 C159 116 160 127 151 127 C146 127 145 121 150 120',
    'M100 124 C93 118 82 126 75 137 C71 144 78 149 84 145 C87 142 85 138 81 139',
    'M100 124 C107 118 118 126 125 137 C129 144 122 149 116 145 C113 142 115 138 119 139',
  ].map(parseSvgPathData).toList(growable: false);

  static final _stamens = [
    'M100 124 C82 110 50 102 16 106 C10 107 10 113 16 112',
    'M100 124 C80 94 50 74 26 70 C20 69 17 74 22 76',
    'M100 124 C86 88 66 56 44 40 C39 37 34 40 38 44',
    'M100 124 C93 90 83 52 73 24 C71 18 65 19 67 24',
    'M100 124 C112 90 128 56 146 34 C150 29 156 33 151 37',
    'M100 124 C118 96 146 74 173 66 C179 64 182 70 176 71',
    'M100 124 C120 108 152 100 185 102 C191 102 191 108 185 107',
  ].map(parseSvgPathData).toList(growable: false);
  static const _anthers = [
    Offset(14, 109),
    Offset(21, 73),
    Offset(38, 41),
    Offset(68, 21),
    Offset(151, 33),
    Offset(177, 67),
    Offset(187, 104),
  ];

  /// Negative animation-delay of each stamen, in seconds.
  static const _stamenDelays = [2.3, 4.1, 0.0, 5.2, 1.4, 3.3, 6.1];

  static final _pistil = parseSvgPathData('M100 124 C98 86 94 46 91 8');
  static const _pistilTip = Offset(91, 8);
  static final _stem = parseSvgPathData('M100 124 C99 154 102 184 100 214');
  static final _leaf = parseSvgPathData('M100 150 C93 156 90 166 92 174');

  static final _lengths = Expando<double>();
  static double _length(Path path) => _lengths[path] ??= path
      .computeMetrics()
      .fold<double>(0, (sum, m) => sum + m.length);

  /// CSS `ease-in-out` + `alternate`: 0 -> 1 -> 0 over 2 * [period].
  static double _wave(double t, double period, [double delay = 0]) {
    final phase = (t + delay) / period;
    final frac = phase - phase.floorToDouble();
    final eased = Curves.easeInOut.transform(frac);
    return phase.floor().isEven ? eased : 1 - eased;
  }

  static double _deg(double degrees) => degrees * math.pi / 180;

  static void _rotateAbout(Canvas canvas, Offset pivot, double radians) {
    canvas
      ..translate(pivot.dx, pivot.dy)
      ..rotate(radians)
      ..translate(-pivot.dx, -pivot.dy);
  }

  /// Draw-in progress of a filament that starts at [start]s
  /// and takes [duration]s, within one loading loop.
  static double _grow(double t, double start, [double duration = 0.9]) =>
      Curves.easeOutCubic.transform(((t - start) / duration).clamp(0.0, 1.0));

  /// Loading loop length in seconds.
  static const _loop = 3.2;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final scale = size.width / 200;

    // Loading: draw in (0-1.6s), hold, fade out (2.5-3.2s), repeat.
    final lt = t % _loop;
    final opacity = drawIn
        ? 1 - Curves.easeIn.transform(((lt - 2.5) / 0.7).clamp(0.0, 1.0))
        : 1.0;
    if (opacity <= 0) return;
    double grow(double start, [double duration = 0.9]) =>
        drawIn ? _grow(lt, start, duration) : 1;

    Color fade(Color color, [double alpha = 1]) =>
        color.withValues(alpha: color.a * alpha * opacity);
    Paint stroke(Color color, double px, [double alpha = 1]) => Paint()
      ..style = .stroke
      ..strokeCap = .round
      ..strokeJoin = .round
      ..strokeWidth = px / scale
      ..color = fade(color, alpha);
    void drawPart(Path path, Paint paint, double progress) {
      if (progress <= 0) return;
      if (progress >= 1) return canvas.drawPath(path, paint);
      var remaining = _length(path) * progress;
      for (final metric in path.computeMetrics()) {
        if (remaining <= 0) break;
        canvas.drawPath(metric.extractPath(0, remaining), paint);
        remaining -= metric.length;
      }
    }

    canvas
      ..save()
      ..scale(scale);
    if (sway) _rotateAbout(canvas, _base, _deg(-0.45 + 0.9 * _wave(t, 13)));

    // Stem (drawn upward from the base while loading).
    final stemPaint = stroke(stem, variant.petal * 1.05);
    if (drawIn) {
      final g = grow(0, 0.6);
      final metric = _stem.computeMetrics().first;
      if (g > 0) {
        canvas.drawPath(
          metric.extractPath(metric.length * (1 - g), metric.length),
          stemPaint,
        );
      }
    } else {
      canvas.drawPath(_stem, stemPaint);
    }
    drawPart(_leaf, stroke(stem, variant.petal * 0.8), grow(0.35, 0.5));

    // Stamens and anthers
    final stamenPaint = stroke(petal, variant.stamen, 0.92);
    final antherPaint = Paint()..color = fade(anther);
    final ar = variant.anther;
    for (var i = 0; i < _stamens.length; i++) {
      final g = grow(0.45 + i * 0.07);
      if (g <= 0) continue;
      canvas.save();
      if (sway) {
        final period = 8 + (i % 3) * 1.7;
        _rotateAbout(
          canvas,
          _center,
          _deg(-0.9 + 1.8 * _wave(t, period, _stamenDelays[i])),
        );
      }
      drawPart(_stamens[i], stamenPaint, g);
      if (g >= 1) {
        canvas.drawOval(
          Rect.fromCenter(
            center: _anthers[i],
            width: ar * 2,
            height: ar * 2 * 0.62,
          ),
          antherPaint,
        );
      }
      canvas.restore();
    }

    // Pistil
    final pg = grow(0.5);
    if (pg > 0) {
      canvas.save();
      if (sway)
        _rotateAbout(canvas, _center, _deg(-0.9 + 1.8 * _wave(t, 11, 3)));
      drawPart(_pistil, stroke(petal, variant.stamen * 1.2, 0.92), pg);
      if (pg >= 1) {
        canvas.drawCircle(_pistilTip, ar * 0.75, Paint()..color = fade(petal));
      }
      canvas.restore();
    }

    // Petals, breathing
    canvas.save();
    if (sway) {
      final s = 0.992 + 0.02 * _wave(t, 7);
      canvas
        ..translate(_center.dx, _center.dy)
        ..scale(s)
        ..translate(-_center.dx, -_center.dy);
    }
    final petalPaint = stroke(petal, variant.petal);
    for (var i = 0; i < _petals.length; i++) {
      drawPart(_petals[i], petalPaint, grow(0.2 + i * 0.06));
    }
    canvas
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_LilyPainter old) =>
      old.variant != variant ||
      old.sway != sway ||
      old.drawIn != drawIn ||
      old.petal != petal ||
      old.anther != anther ||
      old.stem != stem;
}

/// The app mark: the lily next to "nts" in mono.
class HiganMark extends StatelessWidget {
  const new({super.key, this.size = 24, this.animate = true});

  /// Lily width (26 in headers, 24 in the sidebar).
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      spacing: 10,
      children: [
        HiganLily(size: size, animate: animate),
        Text(
          'nts',
          style: HiganText.label(
            context,
            size: 13,
            color: context.higan.text,
            tracking: 0.08,
          ),
        ),
      ],
    );
  }
}

/// Loading indicator: the lily drawing itself in, centered.
class HiganLoading extends StatelessWidget {
  const new({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: HiganLily(size: size, variant: .thin, drawIn: true),
    );
  }
}
