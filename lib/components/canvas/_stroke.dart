import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:nts/components/canvas/_calligraphy_stroke.dart';
import 'package:nts/components/canvas/_circle_stroke.dart';
import 'package:nts/components/canvas/_rectangle_stroke.dart';
import 'package:nts/data/extensions/list_extensions.dart';
import 'package:nts/data/extensions/matrix4_extensions.dart';
import 'package:nts/data/extensions/point_extensions.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:sbn/has_size.dart';
import 'package:sbn/tool_id.dart';

class Stroke {
  static final log = Logger('Stroke');

  @visibleForTesting
  @protected
  final List<PointVector> points = [];

  bool get isEmpty => points.isEmpty;
  int get length => points.length;

  int pageIndex;
  HasSize page;
  final ToolId toolId;

  static const defaultColor = Colors.black;
  static const defaultPressureEnabled = true;

  Color color;
  bool pressureEnabled;
  final StrokeOptions options;

  /// The color inside the stroke if it [isClosed] and was filled
  /// with the fill tool, or null. Saved as `fc`.
  Color? fillColor;

  /// Whether the stroke is a loop that can be filled.
  bool get isClosed =>
      points.length > 2 &&
      (points.first - points.last).distance <= max(2 * options.size, 12);

  /// The area inside the stroke's centerline, for [fillColor].
  Path get fillPath => Path()..addPolygon(points, true);

  List<Offset>? _lowQualityPolygon, _highQualityPolygon;
  List<Offset> get lowQualityPolygon =>
      _lowQualityPolygon ??= getPolygon(quality: .low);
  List<Offset> get highQualityPolygon =>
      _highQualityPolygon ??= getPolygon(quality: .high);

  Path? _lowQualityPath, _highQualityPath;
  Path get lowQualityPath =>
      _lowQualityPath ??= getPath(lowQualityPolygon, smooth: false);
  Path get highQualityPath => _highQualityPath ??= getPath(highQualityPolygon);

  Rect? _bounds;

  /// The bounding box of the stroke's centerline (excluding its thickness).
  Rect get bounds => _bounds ??= () {
    var left = double.infinity, top = double.infinity;
    var right = double.negativeInfinity, bottom = double.negativeInfinity;
    for (final point in points) {
      left = min(left, point.x);
      top = min(top, point.y);
      right = max(right, point.x);
      bottom = max(bottom, point.y);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }();

  void shift(Offset offset) {
    if (offset == .zero) return;

    points.shift(offset);
    _bounds = _bounds?.shift(offset);
    _lowQualityPolygon?.shift(offset);
    _highQualityPolygon?.shift(offset);
    _lowQualityPath = _lowQualityPath?.shift(offset);
    _highQualityPath = _highQualityPath?.shift(offset);
  }

  void markPolygonNeedsUpdating() {
    _bounds = null;
    _lowQualityPolygon = null;
    _highQualityPolygon = null;
    _lowQualityPath = null;
    _highQualityPath = null;
  }

  new({
    required this.color,
    required this.pressureEnabled,
    required this.options,
    required this.pageIndex,
    required this.page,
    required this.toolId,
  });

  factory fromJson(
    Map<String, dynamic> json, {
    required int fileVersion,
    required int pageIndex,
    required HasSize page,
  }) {
    assert(json['i'] == pageIndex || json['i'] == null);
    switch (json['shape'] as String?) {
      case null:
        break;
      case 'circle':
        return CircleStroke.fromJson(
          json,
          fileVersion: fileVersion,
          pageIndex: pageIndex,
          page: page,
        );
      case 'rect':
        return RectangleStroke.fromJson(
          json,
          fileVersion: fileVersion,
          pageIndex: pageIndex,
          page: page,
        );
      default:
        log.severe('Unknown shape: ${json['shape']}');
    }

    final ToolId toolId = .parsePenType(json['ty'], fallback: .fountainPen);

    final options = StrokeOptions.fromJson(json);
    final pressureEnabled = json['pe'] ?? defaultPressureEnabled;
    if (toolId == .shapePen) {
      // Set smoothing and streamline to 0 for ShapePen
      // to mitigate https://github.com/saber-notes/saber/issues/1587
      options.smoothing = 0;
      options.streamline = 0;
    }

    final Color color;
    switch (json['c']) {
      case (final int value):
        color = Color(value);
      case (final Int64 value):
        color = Color(value.toInt());
      case null:
        color = defaultColor;
      default:
        throw Exception(
          'Invalid color value: (${json['c'].runtimeType}) ${json['c']}',
        );
    }

    final offset = Offset(json['ox'] ?? 0, json['oy'] ?? 0);
    final pointsJson = json['p'] as List<dynamic>;
    final Iterable<PointVector> points;
    if (fileVersion >= 13) {
      points = pointsJson.map(
        (point) => PointExtensions.fromBsonBinary(json: point, offset: offset),
      );
    } else {
      points = pointsJson.map(
        // ignore: deprecated_member_use_from_same_package
        (point) => PointExtensions.fromJson(
          json: Map<String, dynamic>.from(point),
          offset: offset,
        ),
      );
    }

    final stroke = toolId == .calligraphyPen
        ? CalligraphyStroke(
            color: color,
            pressureEnabled: pressureEnabled,
            options: options,
            pageIndex: pageIndex,
            page: page,
            toolId: toolId,
            nibAngle:
                (json['na'] as num?)?.toDouble() ??
                CalligraphyStroke.defaultNibAngle,
          )
        : Stroke(
            color: color,
            pressureEnabled: pressureEnabled,
            options: options,
            pageIndex: pageIndex,
            page: page,
            toolId: toolId,
          );
    return stroke
      ..points.addAll(points)
      ..fillColor = colorFromJson(json['fc']);
  }

  /// Parses an optional color saved with [Color.toARGB32].
  static Color? colorFromJson(Object? json) => switch (json) {
    null => null,
    final int value => Color(value),
    final Int64 value => Color(value.toInt()),
    _ => throw Exception('Invalid color value: (${json.runtimeType}) $json'),
  };

  Map<String, dynamic> toJson() {
    // these json keys should not be the same as the ones in [StrokeOptions.toJson]
    return {
      'shape': null,
      'p': points
          .where((point) => point.isFinite)
          .map((PointVector point) => point.toBsonBinary())
          .toList(),
      'i': pageIndex,
      'ty': toolId.id,
      'pe': pressureEnabled,
      'c': color.toARGB32(),
      if (fillColor != null) 'fc': fillColor!.toARGB32(),
    }..addAll(options.toJson());
  }

  void addPoint(Offset point, [double? pressure]) {
    if (!pressureEnabled) {
      pressure = null;
    } else if (pressure != null) {
      options.simulatePressure = false;
    }

    points.add(PointVector(point.dx, point.dy, pressure));
    markPolygonNeedsUpdating();
  }

  void addPoints(List<Offset> points) {
    for (final point in points) {
      addPoint(point);
    }
  }

  void popFirstPoint() {
    points.removeAt(0);
    markPolygonNeedsUpdating();
  }

  /// Removes every point but the first, e.g. so the next [addPoint]
  /// makes a straight line from it.
  void keepFirstPoint() {
    if (points.length <= 1) return;
    points.removeRange(1, points.length);
    markPolygonNeedsUpdating();
  }

  /// Points that are closer than this
  /// threshold multiplied by the stroke's size
  /// will be counted as duplicates.
  static const _optimisePointsThreshold = 0.1;

  /// Removes points that are too close together. See [_optimisePointsThreshold].
  ///
  /// This function is idempotent, so running it multiple times
  /// will not change the result.
  ///
  /// This function does not change [_polygonNeedsUpdating].
  void optimisePoints({double thresholdMultiplier = _optimisePointsThreshold}) {
    if (points.length <= 3) return;

    final minDistance = options.size * thresholdMultiplier;

    // Remove points with null pressure because they were duplicates
    points.removeWhere((point) => point.pressure == null);

    for (int i = 1; i < points.length - 1; i++) {
      final point = points[i];
      final prev = points[i - 1];
      final next = points[i + 1];

      if (prev.distanceSquaredTo(point) < minDistance * minDistance &&
          point.distanceSquaredTo(next) < minDistance * minDistance) {
        points.removeAt(i);
        i--;
      }
    }
  }

  @protected
  List<Offset> getPolygon({required StrokeQuality quality}) {
    if (!pressureEnabled) {
      options.simulatePressure = false;
    }
    final rememberSimulatedPressure =
        quality == .high && options.simulatePressure && options.isComplete;

    final polygon = getStroke(
      skipPoints(points, quality.N),
      options: switch (quality) {
        .low => options.copyWith(
          simulatePressure: false,
          smoothing: 0,
          streamline: 0,
        ),
        .high => options,
      },
      rememberSimulatedPressure: rememberSimulatedPressure,
    );

    if (rememberSimulatedPressure) {
      // Ensure we don't simulate pressure again
      options.simulatePressure = false;
      // Remove points that are too close together
      optimisePoints();
    }

    return polygon;
  }

  /// Returns a [Path] that represents the stroke.
  ///
  /// If [smooth] is true, and the stroke is complete,
  /// the path will be a smooth curve between the points in [polygon].
  ///
  /// Otherwise, the path will use straight lines between each point
  /// in [polygon] for performance.
  @protected
  Path getPath(List<Offset> polygon, {bool smooth = true}) {
    if (smooth && options.isComplete) {
      return smoothPathFromPolygon(polygon);
    }

    return Path()..addPolygon(polygon, true);
  }

  /// Returns a list with every Nth point in [points].
  static List<PointVector> skipPoints(List<PointVector> points, int N) {
    // Nothing is being skipped, just return [points].
    if (N <= 1) return points;

    // If we have too few points, skip less points
    final divided = points.length / N;
    const minDivided = 8;
    if (divided < minDivided) {
      N = (N * divided / minDivided).floor();
      if (N <= 1) return points;
    }

    return [
      for (int i = 0; i < points.length - 1; i += N) points[i],
      points.last,
    ];
  }

  static Path smoothPathFromPolygon(List<Offset> polygon) {
    final path = Path();
    path.moveTo(polygon.first.dx, polygon.first.dy);
    for (int i = 1; i < polygon.length - 1; i++) {
      final p1 = polygon[i];
      final p2 = polygon[i + 1];
      final mid = (p1 + p2) / 2;
      path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
    }
    return path..close();
  }

  String toSvgPath() {
    String toSvgPoint(Offset point) {
      return '${point.dx} '
          '${page.size.height - point.dy}';
    }

    // Remove NaN points, and convert to SVG coordinates
    final svgPoints = highQualityPolygon
        .where((offset) => offset.isFinite)
        .map(toSvgPoint);

    return svgPoints.isNotEmpty ? 'M${svgPoints.join('L')}' : '';
  }

  double get maxY {
    return points.isEmpty ? 0 : points.map((point) => point.y).reduce(max);
  }

  RecognizedUnistroke? detectShape() {
    if (points.length < 3) return null;
    return recognizeUnistroke(points);
  }

  /// Uses the one_dollar_unistroke_recognizer package
  /// only to recognize straight lines.
  ///
  /// In addition, the line must be sufficiently long
  /// relative to [options.size].
  bool isStraightLine([int minLength = 5]) {
    if (points.length < 3) return false;

    final recognized = recognizeUnistroke(
      points,
      overrideReferenceUnistrokes: default$1Unistrokes
          .where((unistroke) => unistroke.name == DefaultUnistrokeNames.line)
          .toList(),
    );
    if (recognized == null) return false;
    assert(recognized.name == DefaultUnistrokeNames.line);
    if (recognized.score < 0.7) return false;

    final sqrLength = points.first.distanceSquaredTo(points.last);
    final sqrMinLength = minLength * minLength * options.size * options.size;
    return sqrLength >= sqrMinLength;
  }

  /// Whether this is a quick zig-zag, back and forth along its longer side
  /// at least 4 times, like scribbling something out.
  /// Handwriting like "mmm" isn't: it only goes one way along.
  bool isScribble() {
    final horizontal = bounds.width >= bounds.height;
    final extent = horizontal ? bounds.width : bounds.height;
    if (points.length < 5 || extent <= 0) return false;

    // A turn counts after going back a fifth of the way, ignoring wobbles
    final minTravel = max(extent / 5, options.size);
    var reversals = 0;
    var direction = 0; // 1 or -1 once it's moved far enough
    var extreme = horizontal ? points.first.dx : points.first.dy;
    for (final point in points) {
      final x = horizontal ? point.dx : point.dy;
      if (direction == 0) {
        if ((x - extreme).abs() < minTravel) continue;
        direction = (x - extreme).sign.toInt();
        extreme = x;
      } else if ((x - extreme) * direction > 0) {
        extreme = x; // further the same way
      } else if ((extreme - x) * direction >= minTravel) {
        reversals++;
        direction = -direction;
        extreme = x;
      }
    }
    return reversals >= 4 && _polylineLength(points) >= 3 * extent;
  }

  /// Replaces the points in this stroke with a straight line.
  ///
  /// If the resulting line is close to horizontal or vertical,
  /// it will be snapped to be exactly horizontal or vertical.
  void convertToLine() {
    assert(points.length >= 2);

    // Use the average pressure
    final pressure = points.map((point) => point.pressure ?? 0.5).average;
    var firstPoint = PointVector.fromOffset(
      offset: points.first,
      pressure: pressure,
    );
    var lastPoint = PointVector.fromOffset(
      offset: points.last,
      pressure: pressure,
    );

    // Snap to the horizontal or vertical axis
    (firstPoint, lastPoint) = snapLine(firstPoint, lastPoint);

    points.clear();
    points.add(firstPoint);
    points.add(lastPoint);
    points.add(lastPoint);
    options.isComplete = true;
    options.start.taperEnabled = false;
    options.end.taperEnabled = false;
  }

  /// Snaps a line to either horizontal or vertical
  /// if the angle is close enough.
  static (PointVector firstPoint, PointVector lastPoint) snapLine(
    PointVector firstPoint,
    PointVector lastPoint,
  ) {
    final dx = (lastPoint.dx - firstPoint.dx).abs();
    final dy = (lastPoint.dy - firstPoint.dy).abs();
    final angle = atan2(dy, dx);

    const snapAngle = 5 * pi / 180; // 5 degrees
    if (angle < snapAngle) {
      // snap to horizontal
      return (
        firstPoint,
        PointVector(lastPoint.dx, firstPoint.dy, lastPoint.pressure),
      );
    } else if (angle > pi / 2 - snapAngle) {
      // snap to vertical
      return (
        firstPoint,
        PointVector(firstPoint.dx, lastPoint.dy, lastPoint.pressure),
      );
    } else {
      return (firstPoint, lastPoint);
    }
  }

  /// The centerline that [erasePartially] cuts up.
  @protected
  List<PointVector> get erasablePoints => points;

  /// Erases the parts of this stroke touched by an eraser of [eraserRadius]
  /// that moved in a straight line from [from] to [to].
  /// The stroke counts as touched where its visible edge is touched.
  ///
  /// Returns null if the stroke wasn't touched, otherwise the remaining
  /// fragments (possibly none) which look like the untouched parts.
  List<Stroke>? erasePartially(Offset from, Offset to, double eraserRadius) {
    // The drawn half-width is at most [options.size]
    final maxRadius = eraserRadius + options.size;
    if (!bounds.inflate(maxRadius).overlaps(Rect.fromPoints(from, to))) {
      return null;
    }

    // Save any simulated pressure into [points] so fragments keep the width
    if (pressureEnabled && options.simulatePressure && options.isComplete) {
      _highQualityPolygon = getPolygon(quality: .high);
    }

    /// The drawn half-width at [point], like perfect_freehand's
    /// getStrokeRadius (ignoring tapers).
    double radiusAt(PointVector point) =>
        eraserRadius +
        (options.thinning == 0
            ? options.size / 2
            : options.size *
                  options.easing(
                    0.5 - options.thinning * (0.5 - (point.pressure ?? 0.5)),
                  ));

    final original = erasablePoints;
    final runs = splitPolyline(original, from, to, radiusAt);
    if (runs == null) return null;

    // An uncut length-based taper would shrink to the fragment's length
    final originalLength = max(options.size, _polylineLength(original));
    StrokeEndOptions keepEnd(StrokeEndOptions end) =>
        end.taperEnabled && end.customTaper == null
        ? end.copyWith(customTaper: originalLength)
        : end;

    final minLength = options.size * _optimisePointsThreshold;
    return [
      for (final run in runs)
        if (_polylineLength(run) >= minLength)
          Stroke(
            color: color,
            pressureEnabled: pressureEnabled,
            options: options.copyWith(
              simulatePressure: false,
              isComplete: true,
              // Shapes ignore these, but fragments are drawn as polylines.
              // Like [Stroke.fromJson] for old shapes with nonzero values.
              smoothing: toolId == .shapePen ? 0 : null,
              streamline: toolId == .shapePen ? 0 : null,
              // Cut ends get a round cap, not a new taper
              start: identical(run.first, original.first)
                  ? keepEnd(options.start)
                  : StrokeEndOptions.start(taperEnabled: false, cap: true),
              end: identical(run.last, original.last)
                  ? keepEnd(options.end)
                  : StrokeEndOptions.end(taperEnabled: false, cap: true),
            ),
            pageIndex: pageIndex,
            page: page,
            toolId: toolId,
          )..points.addAll(run),
    ];
  }

  /// Splits the polyline [points] into the runs that are at least [radius]
  /// away from the line segment [a]-[b], cutting it exactly where it
  /// crosses that boundary (interpolating pressure).
  /// Each segment uses the larger [radius] of its two ends.
  ///
  /// If [points] is a closed loop (its first and last points are identical),
  /// the runs either side of the start are joined back together.
  ///
  /// Returns null if no part of [points] is within [radius].
  @visibleForTesting
  static List<List<PointVector>>? splitPolyline(
    List<PointVector> points,
    Offset a,
    Offset b,
    double Function(PointVector point) radius,
  ) {
    if (points.isEmpty) return null;
    if (points.length == 1) {
      final point = points.single;
      return _capsuleHitRange(point, point, a, b, radius(point)) == null
          ? null
          : const [];
    }

    var touched = false;
    final runs = <List<PointVector>>[];
    var run = <PointVector>[points.first];
    for (int i = 0; i + 1 < points.length; ++i) {
      final p = points[i], q = points[i + 1];
      final r = max(radius(p), radius(q));
      final hit = _capsuleHitRange(p, q, a, b, r);
      if (hit == null) {
        if (run.isEmpty) run.add(p);
        run.add(q);
        continue;
      }

      touched = true;
      final (t0, t1) = hit;
      if (t0 > 0) {
        if (run.isEmpty) run.add(p);
        run.add(p.lerp(t0, q));
      }
      runs.add(run);
      run = t1 < 1 ? [p.lerp(t1, q), q] : [];
    }
    if (!touched) return null;
    runs.add(run);
    runs.removeWhere((run) => run.length < 2);

    if (runs.length >= 2 &&
        identical(points.first, points.last) &&
        identical(runs.first.first, points.first) &&
        identical(runs.last.last, points.last)) {
      runs.first = [...runs.removeLast(), ...runs.first.skip(1)];
    }
    return runs;
  }

  /// A copy of this stroke moved by [transform], which may only translate,
  /// rotate and scale uniformly. Its thickness scales too.
  Stroke transformed(Matrix4 transform) {
    final scale = transform.uniformScale;
    final copy = this.copy();
    copy.points.setAll(0, [
      for (final point in points)
        PointVector.fromOffset(
          offset: MatrixUtils.transformPoint(transform, point),
          pressure: point.pressure,
        ),
    ]);
    final options = copy.options..size *= scale;
    // (The end options are shared with this stroke, so replace them.)
    if (options.start.customTaper case final taper?) {
      options.start = options.start.copyWith(customTaper: taper * scale);
    }
    if (options.end.customTaper case final taper?) {
      options.end = options.end.copyWith(customTaper: taper * scale);
    }
    return copy..markPolygonNeedsUpdating();
  }

  Stroke copy() =>
      Stroke(
          color: color,
          pressureEnabled: pressureEnabled,
          options: options.copyWith(),
          pageIndex: pageIndex,
          page: page,
          toolId: toolId,
        )
        ..points.addAll(points)
        ..fillColor = fillColor;
}

double _polylineLength(List<PointVector> points) {
  var length = 0.0;
  for (int i = 0; i + 1 < points.length; ++i) {
    length += (points[i + 1] - points[i]).distance;
  }
  return length;
}

/// The range of t within [0, 1] for which `p + t(q - p)` is closer than
/// [r] to the line segment [a]-[b] (i.e. inside that capsule), or null.
(double, double)? _capsuleHitRange(
  Offset p,
  Offset q,
  Offset a,
  Offset b,
  double r,
) {
  // The capsule is convex so its intersection with the line is one range:
  // the union of the ranges for its two end circles and middle rectangle.
  var lo = double.infinity, hi = double.negativeInfinity;
  void include((double, double)? range) {
    if (range == null) return;
    lo = min(lo, range.$1);
    hi = max(hi, range.$2);
  }

  include(_circleHitRange(p, q, a, r));
  if (a != b) {
    include(_circleHitRange(p, q, b, r));
    include(_rectangleHitRange(p, q, a, b, r));
  }

  lo = max(lo, 0);
  hi = min(hi, 1);
  return lo < hi ? (lo, hi) : null;
}

/// The range of t for which `p + t(q - p)` is closer than [r] to [c].
(double, double)? _circleHitRange(Offset p, Offset q, Offset c, double r) {
  final d = q - p, f = p - c;
  final dd = d.distanceSquared;
  final fd = f.dx * d.dx + f.dy * d.dy;
  final ff = f.distanceSquared - r * r;
  if (dd == 0) {
    return ff < 0 ? (double.negativeInfinity, double.infinity) : null;
  }
  final discriminant = fd * fd - dd * ff;
  if (discriminant <= 0) return null;
  final root = sqrt(discriminant);
  return ((-fd - root) / dd, (-fd + root) / dd);
}

/// The range of t for which `p + t(q - p)` is in the rectangle
/// of half-width [r] around the line segment [a]-[b].
(double, double)? _rectangleHitRange(
  Offset p,
  Offset q,
  Offset a,
  Offset b,
  double r,
) {
  final ab = b - a;
  final length = ab.distance;
  final u = ab / length;
  final d = q - p, f = p - a;
  final along = _linearRange(
    f.dx * u.dx + f.dy * u.dy,
    d.dx * u.dx + d.dy * u.dy,
    0,
    length,
  );
  final across = _linearRange(
    f.dx * u.dy - f.dy * u.dx,
    d.dx * u.dy - d.dy * u.dx,
    -r,
    r,
  );
  if (along == null || across == null) return null;
  final lo = max(along.$1, across.$1), hi = min(along.$2, across.$2);
  return lo < hi ? (lo, hi) : null;
}

/// The range of t for which `lo < x + t * dx < hi`.
(double, double)? _linearRange(double x, double dx, double lo, double hi) {
  if (dx == 0) {
    return lo < x && x < hi ? (double.negativeInfinity, double.infinity) : null;
  }
  final t0 = (lo - x) / dx, t1 = (hi - x) / dx;
  return t0 < t1 ? (t0, t1) : (t1, t0);
}

enum StrokeQuality(
  /// We use every Nth point for this quality level.
  final int N,
) {
  low(4),
  high(1),
}
