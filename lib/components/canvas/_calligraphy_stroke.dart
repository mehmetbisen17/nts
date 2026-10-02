import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/extensions/matrix4_extensions.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

/// A flat-nib (reed) pen stroke: the nib keeps its [nibAngle], so the line
/// is thick across the nib and thin along it.
///
/// Saved like a [Stroke], plus its nib angle as `na`.
class CalligraphyStroke extends Stroke {
  new({
    required super.color,
    required super.pressureEnabled,
    required super.options,
    required super.pageIndex,
    required super.page,
    required super.toolId,
    this.nibAngle = defaultNibAngle,
  });

  /// In degrees, anticlockwise from the x axis (like a protractor),
  /// so 45° is the usual italic nib: thin strokes go up to the right.
  double nibAngle;

  static const defaultNibAngle = 45.0;

  /// The angles offered in the top bar.
  static const nibAnglePresets = [0.0, 30.0, 45.0, 60.0, 90.0];

  /// The nib's thickness relative to its width ([StrokeOptions.size]),
  /// so lines along the nib don't vanish.
  static const _thickness = 0.12;

  /// The outline as convex pieces: one per segment, the nib swept from
  /// one point to the next. They all wind the same way, so filling them
  /// with [PathFillType.nonZero] draws their union.
  List<List<Offset>> _pieces(List<PointVector> points) {
    if (points.isEmpty) return const [];
    final a = -nibAngle * pi / 180; // (y points down)
    final along = Offset(cos(a), sin(a)) * (options.size / 2);
    final across = Offset(-sin(a), cos(a)) * (options.size * _thickness / 2);
    List<Offset> nib(Offset p) => [
      p + along + across,
      p + along - across,
      p - along - across,
      p - along + across,
    ];

    // Streamline like perfect_freehand, so jitter doesn't show as bumps
    final t = 1 - options.streamline.clamp(0.0, 0.9);
    final centerline = <Offset>[points.first];
    for (final point in points.skip(1)) {
      centerline.add(Offset.lerp(centerline.last, point, t)!);
    }
    if (points.length > 1) centerline.add(points.last);

    if (centerline.length == 1) return [nib(centerline.single)];
    return [
      for (int i = 0; i + 1 < centerline.length; ++i)
        _convexHull([...nib(centerline[i]), ...nib(centerline[i + 1])]),
    ];
  }

  @override
  List<Offset> getPolygon({required StrokeQuality quality}) => [
    for (final piece in _pieces(Stroke.skipPoints(points, quality.N))) ...piece,
  ];

  @override
  Path getPath(List<Offset> polygon, {bool smooth = true}) {
    final path = Path();
    for (final piece in _pieces(points)) {
      path.addPolygon(piece, true);
    }
    return path;
  }

  @override
  String toSvgPath() => [
    for (final piece in _pieces(points))
      'M${piece.map((p) => '${p.dx} ${page.size.height - p.dy}').join('L')}Z',
  ].join();

  @override
  List<Stroke>? erasePartially(Offset from, Offset to, double eraserRadius) =>
      super
          .erasePartially(from, to, eraserRadius)
          ?.map(
            (fragment) => CalligraphyStroke(
              color: color,
              pressureEnabled: pressureEnabled,
              options: fragment.options,
              pageIndex: pageIndex,
              page: page,
              toolId: toolId,
              nibAngle: nibAngle,
            )..points.addAll(fragment.points),
          )
          .toList();

  /// Turns the nib too.
  @override
  CalligraphyStroke transformed(Matrix4 transform) =>
      (super.transformed(transform) as CalligraphyStroke)
        ..nibAngle = nibAngle - transform.rotation * 180 / pi;

  @override
  Map<String, dynamic> toJson() => super.toJson()..['na'] = nibAngle;

  @override
  CalligraphyStroke copy() =>
      CalligraphyStroke(
          color: color,
          pressureEnabled: pressureEnabled,
          options: options.copyWith(),
          pageIndex: pageIndex,
          page: page,
          toolId: toolId,
          nibAngle: nibAngle,
        )
        ..points.addAll(points)
        ..fillColor = fillColor;
}

/// The convex hull of [points], counter-clockwise (in y-up coordinates),
/// by Andrew's monotone chain.
List<Offset> _convexHull(List<Offset> points) {
  points.sort(
    (a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy),
  );
  double cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

  final hull = <Offset>[];
  for (final pass in [points, points.reversed]) {
    final start = hull.length;
    for (final p in pass) {
      while (hull.length >= start + 2 &&
          cross(hull[hull.length - 2], hull.last, p) <= 0) {
        hull.removeLast();
      }
      hull.add(p);
    }
    hull.removeLast();
  }
  return hull;
}
