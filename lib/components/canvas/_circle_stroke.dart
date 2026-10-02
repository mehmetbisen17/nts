import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/extensions/matrix4_extensions.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:sbn/has_size.dart';

class CircleStroke extends Stroke {
  Offset center;
  double radius;

  new({
    required super.color,
    required super.pressureEnabled,
    required super.options,
    required super.pageIndex,
    required super.page,
    required super.toolId,
    required this.center,
    required this.radius,
  }) {
    options.isComplete = true;
  }

  factory fromJson(
    Map<String, dynamic> json, {
    required int fileVersion,
    required int pageIndex,
    required HasSize page,
  }) {
    assert(json['shape'] == 'circle');
    assert(json['i'] == pageIndex || json['i'] == null);

    final Color color;
    switch (json['c']) {
      case (final int value):
        color = Color(value);
      case (final Int64 value):
        color = Color(value.toInt());
      case null:
        color = Stroke.defaultColor;
      default:
        throw Exception(
          'Invalid color value: (${json['c'].runtimeType}) ${json['c']}',
        );
    }

    return CircleStroke(
      color: color,
      pressureEnabled: json['pe'] ?? Stroke.defaultPressureEnabled,
      options: StrokeOptions.fromJson(json),
      pageIndex: pageIndex,
      page: page,
      toolId: .parsePenType(json['ty'], fallback: .shapePen),
      center: Offset(json['cx'] ?? 0, json['cy'] ?? 0),
      radius: json['r'] ?? 0,
    )..fillColor = Stroke.colorFromJson(json['fc']);
  }
  @override
  Map<String, dynamic> toJson() {
    return {
      'shape': 'circle',
      'i': pageIndex,
      'ty': toolId.id,
      'cx': center.dx,
      'cy': center.dy,
      'r': radius,
      'pe': pressureEnabled,
      'c': color.toARGB32(),
      if (fillColor != null) 'fc': fillColor!.toARGB32(),
    }..addAll(options.toJson());
  }

  @override
  bool get isEmpty => radius <= 0;
  @override
  int get length => 25;

  /// A list of 24/N points that form a circle
  /// with [center] and [radius].
  @override
  List<Offset> getPolygon({required StrokeQuality quality}) {
    final numPoints = 24 ~/ quality.N;
    return List.generate(numPoints, (i) => i / numPoints * 2 * pi)
        .map((radians) => Offset(cos(radians), sin(radians)))
        .map((unitDir) => unitDir * radius + center)
        .toList();
  }

  @override
  Rect get bounds => Rect.fromCircle(center: center, radius: radius);

  @override
  bool get isClosed => true;

  @override
  Path get fillPath => Path()..addOval(bounds);

  /// The circle as a closed polyline, so it can be partially erased.
  @override
  List<PointVector> get erasablePoints {
    // About one point per 2 units of circumference
    final n = (pi * radius).ceil().clamp(24, 360);
    final first = PointVector(center.dx + radius, center.dy, 0.5);
    return [
      first,
      for (int i = 1; i < n; ++i)
        PointVector(
          center.dx + radius * cos(2 * pi * i / n),
          center.dy + radius * sin(2 * pi * i / n),
          0.5,
        ),
      first,
    ];
  }

  /// Returns a [Path] that forms a circle with [center] and [radius].
  @override
  Path getPath(List<Offset> polygon, {bool smooth = true}) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  @Deprecated('Cannot add points to a circle stroke.')
  void addPoint(Offset point, [double? pressure]) {
    throw UnsupportedError('Cannot add points to a circle stroke.');
  }

  @override
  @Deprecated('Cannot pop points from a circle stroke.')
  void popFirstPoint() {
    throw UnsupportedError('Cannot pop points from a circle stroke.');
  }

  @override
  void optimisePoints({double thresholdMultiplier = 0}) {
    // no-op
  }

  @override
  String toSvgPath() {
    return 'M${center.dx},${center.dy} m${-radius},0 a$radius,$radius 0 1,0 ${radius * 2},0 a$radius,$radius 0 1,0 ${-radius * 2},0';
  }

  @override
  double get maxY {
    return center.dy + radius;
  }

  @override
  void shift(Offset offset) {
    center += offset;
    super.shift(offset);
  }

  @override
  @Deprecated('We already know the shape is a circle.')
  RecognizedUnistroke detectShape() {
    return RecognizedUnistroke(
      DefaultUnistrokeNames.circle,
      1,
      originalPoints: lowQualityPolygon,
      referenceUnistrokes: default$1Unistrokes,
    );
  }

  @override
  @Deprecated('We already know the shape is a circle.')
  bool isStraightLine([int minLength = 0]) => false;

  @override
  CircleStroke transformed(Matrix4 transform) {
    final scale = transform.uniformScale;
    return copy()
      ..center = MatrixUtils.transformPoint(transform, center)
      ..radius = radius * scale
      ..options.size *= scale
      ..markPolygonNeedsUpdating();
  }

  @override
  CircleStroke copy() => CircleStroke(
    color: color,
    pressureEnabled: pressureEnabled,
    options: options.copyWith(),
    pageIndex: pageIndex,
    page: page,
    toolId: toolId,
    center: center,
    radius: radius,
  )..fillColor = fillColor;
}
