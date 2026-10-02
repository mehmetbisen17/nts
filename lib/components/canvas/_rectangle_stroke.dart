import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/extensions/matrix4_extensions.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:sbn/has_size.dart';

class RectangleStroke extends Stroke {
  Rect rect;

  new({
    required super.color,
    required super.pressureEnabled,
    required super.options,
    required super.pageIndex,
    required super.page,
    required super.toolId,
    required this.rect,
  }) {
    options.isComplete = true;
  }

  factory fromJson(
    Map<String, dynamic> json, {
    required int fileVersion,
    required int pageIndex,
    required HasSize page,
  }) {
    assert(json['shape'] == 'rect');
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

    return RectangleStroke(
      color: color,
      pressureEnabled: json['pe'] ?? Stroke.defaultPressureEnabled,
      options: StrokeOptions.fromJson(json),
      pageIndex: pageIndex,
      page: page,
      toolId: .parsePenType(json['ty'], fallback: .shapePen),
      rect: .fromLTWH(
        json['rl'] ?? 0,
        json['rt'] ?? 0,
        json['rw'] ?? 0,
        json['rh'] ?? 0,
      ),
    )..fillColor = Stroke.colorFromJson(json['fc']);
  }
  @override
  Map<String, dynamic> toJson() {
    return {
      'shape': 'rect',
      'i': pageIndex,
      'ty': toolId.id,
      'rl': rect.left,
      'rt': rect.top,
      'rw': rect.width,
      'rh': rect.height,
      'pe': pressureEnabled,
      'c': color.toARGB32(),
      if (fillColor != null) 'fc': fillColor!.toARGB32(),
    }..addAll(options.toJson());
  }

  @override
  bool get isEmpty => rect.isEmpty;
  @override
  int get length => 100;

  /// A list of points that form the rectangle's perimeter.
  /// Each side has 24/N points.
  @override
  List<Offset> getPolygon({required StrokeQuality quality}) => [
    // left side
    for (int i = 0; i < 24 / quality.N; ++i)
      Offset(rect.left, rect.top + rect.height * i / 24),
    // bottom side
    for (int i = 0; i < 24 / quality.N; ++i)
      Offset(rect.left + rect.width * i / 24, rect.bottom),
    // right side
    for (int i = 0; i < 24 / quality.N; ++i)
      Offset(rect.right, rect.bottom - rect.height * i / 24),
    // top side
    for (int i = 0; i < 24 / quality.N; ++i)
      Offset(rect.right - rect.width * i / 24, rect.top),
  ];

  @override
  Rect get bounds => rect;

  @override
  bool get isClosed => true;

  /// With the rounded corners that the canvas draws.
  @override
  Path get fillPath => Path()
    ..addRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(options.size / 4)),
    );

  /// The rectangle as a closed polyline, so it can be partially erased.
  @override
  List<PointVector> get erasablePoints {
    final first = PointVector(rect.left, rect.top, 0.5);
    return [
      first,
      PointVector(rect.right, rect.top, 0.5),
      PointVector(rect.right, rect.bottom, 0.5),
      PointVector(rect.left, rect.bottom, 0.5),
      first,
    ];
  }

  /// Returns a [Path] with four lines for each side of the rectangle.
  @override
  Path getPath(List<Offset> polygon, {bool smooth = true}) =>
      Path()..addRect(rect);

  @override
  @Deprecated('Cannot add points to a rectangle stroke.')
  void addPoint(Offset point, [double? pressure]) {
    throw UnsupportedError('Cannot add points to a rectangle stroke.');
  }

  @override
  @Deprecated('Cannot pop points from a rectangle stroke.')
  void popFirstPoint() {
    throw UnsupportedError('Cannot pop points from a rectangle stroke.');
  }

  @override
  void optimisePoints({double thresholdMultiplier = 0}) {
    // no-op
  }

  @override
  String toSvgPath() {
    return 'M${rect.left},${rect.top} '
        'L${rect.right},${rect.top} '
        'L${rect.right},${rect.bottom} '
        'L${rect.left},${rect.bottom} '
        'Z';
  }

  @override
  double get maxY {
    return rect.bottom;
  }

  @override
  void shift(Offset offset) {
    rect = rect.shift(offset);
    super.shift(offset);
  }

  @override
  @Deprecated('We already know the shape is a rectangle.')
  RecognizedUnistroke detectShape() {
    return RecognizedUnistroke(
      DefaultUnistrokeNames.rectangle,
      1,
      originalPoints: lowQualityPolygon,
      referenceUnistrokes: default$1Unistrokes,
    );
  }

  @override
  @Deprecated('We already know the shape is a rectangle.')
  bool isStraightLine([int minLength = 0]) => false;

  /// Stays a rectangle if it's still upright, or becomes a closed polyline.
  @override
  Stroke transformed(Matrix4 transform) {
    final scale = transform.uniformScale;
    final quarterTurns = transform.rotation / (pi / 2);
    if ((quarterTurns - quarterTurns.round()).abs() < 1e-6) {
      return copy()
        ..rect = MatrixUtils.transformRect(transform, rect)
        ..options.size *= scale
        ..markPolygonNeedsUpdating();
    }
    return Stroke(
        color: color,
        pressureEnabled: false,
        options: options.copyWith(
          size: options.size * scale,
          smoothing: 0,
          streamline: 0,
          simulatePressure: false,
        ),
        pageIndex: pageIndex,
        page: page,
        toolId: toolId,
      )
      ..addPoints([
        for (final corner in [
          rect.topLeft,
          rect.topRight,
          rect.bottomRight,
          rect.bottomLeft,
          rect.topLeft,
        ])
          MatrixUtils.transformPoint(transform, corner),
      ])
      ..fillColor = fillColor;
  }

  @override
  RectangleStroke copy() => RectangleStroke(
    color: color,
    pressureEnabled: pressureEnabled,
    options: options.copyWith(),
    pageIndex: pageIndex,
    page: page,
    toolId: toolId,
    rect: rect,
  )..fillColor = fillColor;
}
