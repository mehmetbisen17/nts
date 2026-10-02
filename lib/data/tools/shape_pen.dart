import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:logging/logging.dart';
import 'package:nts/components/canvas/_circle_stroke.dart';
import 'package:nts/components/canvas/_rectangle_stroke.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';

class ShapePen extends Pen {
  new()
    : super(
        name: t.editor.pens.shapePen,
        sizeMin: 1,
        sizeMax: 25,
        sizeStep: 1,
        icon: shapePenIcon,
        options: stows.lastShapePenOptions.value,
        pressureEnabled: false,
        color: Color(stows.lastShapePenColor.value),
        toolId: .shapePen,
      );

  static final log = Logger('ShapePen');

  static const shapePenIcon = FontAwesomeIcons.shapes;

  static RecognizedUnistroke? detectedShape;
  void _detectShape() {
    detectedShape = Pen.currentStroke?.detectShape();
  }

  static Timer? _detectShapeDebouncer;
  static var debounceDuration = getDebounceFromPref();
  static Duration getDebounceFromPref() {
    assert(stows.shapeRecognitionDelay.loaded);
    final ms = stows.shapeRecognitionDelay.value;
    if (ms < 0) {
      return const Duration(hours: 1);
    } else {
      return Duration(milliseconds: ms);
    }
  }

  @override
  void onDragUpdate(Offset position, double? pressure) {
    super.onDragUpdate(position, pressure);

    final isPreviewEnabled = debounceDuration < const Duration(hours: 1);
    final isTimerActive = _detectShapeDebouncer?.isActive ?? false;
    if (isPreviewEnabled && !isTimerActive) {
      _detectShapeDebouncer = Timer(debounceDuration, _detectShape);
    }
  }

  @override
  Stroke? onDragEnd() {
    _detectShapeDebouncer?.cancel();
    _detectShapeDebouncer = null;
    _detectShape();

    final rawStroke = super.onDragEnd();
    if (rawStroke == null) return null;
    assert(rawStroke.options.isComplete == true);

    final detectedShape = ShapePen.detectedShape;
    ShapePen.detectedShape = null;

    if (detectedShape == null) return rawStroke;
    return applyDetectedShape(rawStroke, detectedShape);
  }

  /// Replaces [raw] with the clean [shape] it was recognized as,
  /// in the same color and pen.
  static Stroke applyDetectedShape(Stroke raw, RecognizedUnistroke shape) {
    switch (shape.name) {
      case null:
        log.info('Detected unknown shape');
        return raw;
      case DefaultUnistrokeNames.line:
        log.info('Detected line');
        return raw..convertToLine();
      case DefaultUnistrokeNames.rectangle:
        // As drawn, even if it's tilted: its smallest box
        final (center, size, angle) = _smallestBox(shape.originalPoints);
        final sides = _equalIfClose(size);
        if (angle == 0) {
          final rect = Rect.fromCenter(
            center: center,
            width: sides.width,
            height: sides.height,
          );
          log.info('Detected rectangle: $rect');
          return RectangleStroke(
            color: raw.color,
            pressureEnabled: raw.pressureEnabled,
            options: raw.options,
            pageIndex: raw.pageIndex,
            page: raw.page,
            toolId: raw.toolId,
            rect: rect,
          );
        }
        log.info('Detected tilted rectangle: $center, $sides, $angle');
        return _polygon(raw, [
          for (final (x, y) in const [
            (-1, -1),
            (1, -1),
            (1, 1),
            (-1, 1),
            (-1, -1),
          ])
            center +
                _rotate(
                  Offset(x * sides.width / 2, y * sides.height / 2),
                  angle,
                ),
        ]);
      case DefaultUnistrokeNames.circle:
        final (center, size, angle) = _smallestBox(shape.originalPoints);
        final radii = _equalIfClose(size) / 2;
        if (radii.width != radii.height) {
          log.info('Detected oval: c=$center, r=$radii, $angle');
          return _polygon(raw, [
            for (int i = 0; i <= _ovalPoints; ++i)
              center +
                  _rotate(
                    Offset(
                      radii.width * cos(2 * pi * i / _ovalPoints),
                      radii.height * sin(2 * pi * i / _ovalPoints),
                    ),
                    angle,
                  ),
          ]);
        }
        final radius = radii.width;
        log.info('Detected circle: c=$center, r=$radius');
        return CircleStroke(
          color: raw.color,
          pressureEnabled: raw.pressureEnabled,
          options: raw.options,
          pageIndex: raw.pageIndex,
          page: raw.page,
          toolId: raw.toolId,
          radius: radius,
          center: center,
        );
      case DefaultUnistrokeNames.triangle:
      case DefaultUnistrokeNames.star:
        log.info('Detected ${shape.name}');
        return _polygon(raw, shape.convertToCanonicalPolygon());
    }
  }

  /// A stroke through [points] in [raw]'s pen, with sharp corners
  /// and an even width, like the shape pen, and no taper (which would
  /// pinch where a closed shape's ends meet).
  static Stroke _polygon(Stroke raw, List<Offset> points) => Stroke(
    color: raw.color,
    pressureEnabled: raw.pressureEnabled,
    options: raw.options.copyWith(
      smoothing: 0,
      streamline: 0,
      simulatePressure: false,
      isComplete: true,
      // (New end options, so the pen's own aren't changed)
      start: raw.options.start.copyWith(taperEnabled: false, customTaper: null),
      end: raw.options.end.copyWith(taperEnabled: false, customTaper: null),
    ),
    pageIndex: raw.pageIndex,
    page: raw.page,
    toolId: raw.toolId,
  )..addPoints(points);

  static const _ovalPoints = 72;

  /// Sides (or radii) within this ratio of each other are drawn equal:
  /// a slightly squashed square is a square, a round-ish oval a circle.
  static const _equalRatio = 1.2;

  /// [size], or a square of its average side if they're nearly equal.
  static Size _equalIfClose(Size size) {
    final long = max(size.width, size.height);
    final short = min(size.width, size.height);
    if (long > _equalRatio * short) return size;
    return Size.square((long + short) / 2);
  }

  /// Turns are snapped upright within this.
  static const _uprightAngle = 6 * pi / 180;

  /// The smallest box around [points], which lines up with a drawn
  /// rectangle's sides or an oval's axes: its centre, its size and how
  /// far it's turned (0 when it's nearly upright).
  /// ponytail: tries every whole degree; rotating calipers on the hull if
  /// it's ever too slow (it runs once, when a shape snaps).
  static (Offset, Size, double) _smallestBox(List<Offset> points) {
    var best = (Offset.zero, Size.infinite, 0.0);
    for (var degrees = 0; degrees < 90; ++degrees) {
      final angle = degrees * pi / 180;
      var left = double.infinity, top = double.infinity;
      var right = double.negativeInfinity, bottom = double.negativeInfinity;
      for (final point in points) {
        final turned = _rotate(point, -angle);
        left = min(left, turned.dx);
        right = max(right, turned.dx);
        top = min(top, turned.dy);
        bottom = max(bottom, turned.dy);
      }
      final size = Size(right - left, bottom - top);
      if (size.width * size.height < best.$2.width * best.$2.height) {
        final middle = Offset((left + right) / 2, (top + bottom) / 2);
        best = (_rotate(middle, angle), size, angle);
      }
    }
    // Nearly upright: upright (a quarter turn just swaps the sides)
    final (center, size, angle) = best;
    if (angle < _uprightAngle) return (center, size, 0.0);
    if (angle > pi / 2 - _uprightAngle) return (center, size.flipped, 0.0);
    return best;
  }

  static Offset _rotate(Offset point, double angle) => Offset(
    point.dx * cos(angle) - point.dy * sin(angle),
    point.dx * sin(angle) + point.dy * cos(angle),
  );
}
