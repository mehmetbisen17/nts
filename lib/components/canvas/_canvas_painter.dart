import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nts/components/canvas/_circle_stroke.dart';
import 'package:nts/components/canvas/_rectangle_stroke.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/extensions/color_extensions.dart';
import 'package:nts/data/tools/highlighter.dart';
import 'package:nts/data/tools/insert_space.dart';
import 'package:nts/data/tools/laser_pointer.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/data/tools/shape_pen.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class CanvasPainter extends CustomPainter {
  const new({
    super.repaint,
    this.invert = false,
    required this.strokes,
    required this.laserStrokes,
    required this.currentStroke,
    required this.currentSelection,
    required this.primaryColor,
    required this.page,
    required this.showPageIndicator,
    required this.pageIndex,
    required this.totalPages,
    required this.currentScale,
    required this.defaultTextStyle,
    this.linkColor,
  });

  final bool invert;
  final List<Stroke> strokes;
  final List<LaserStroke> laserStrokes;
  final Stroke? currentStroke;
  final SelectResult? currentSelection;
  final Color primaryColor;
  final EditorPage page;
  final bool showPageIndicator;
  final int pageIndex;
  final int totalPages;
  final double currentScale;
  final TextStyle defaultTextStyle;

  /// The color of the marks on [EditorPage.links], or null to hide them
  /// (e.g. in exports, where they wouldn't work).
  final Color? linkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final canvasRect = Offset.zero & size;

    _drawHighlighterStrokes(canvas, canvasRect);
    _drawNonHighlighterStrokes(canvas);
    for (final stroke in laserStrokes) _drawLaserStroke(canvas, stroke);
    _drawCurrentStroke(canvas);
    _drawDetectedShape(canvas);
    _drawLinks(canvas);
    _drawInsertSpace(canvas, size);
    _drawSelection(canvas);
    _drawPageIndicator(canvas, size);
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    return false ||
        // Current stroke is being drawn, so always repaint if present
        (currentStroke != null || oldDelegate.currentStroke != null) ||
        // Laser strokes are always fading out, so always repaint if present
        (laserStrokes.isNotEmpty || oldDelegate.laserStrokes.isNotEmpty) ||
        // Check for any other changes
        invert != oldDelegate.invert ||
        strokes.length != oldDelegate.strokes.length ||
        currentSelection != oldDelegate.currentSelection ||
        primaryColor != oldDelegate.primaryColor ||
        page != oldDelegate.page ||
        showPageIndicator != oldDelegate.showPageIndicator ||
        pageIndex != oldDelegate.pageIndex ||
        totalPages != oldDelegate.totalPages ||
        currentScale != oldDelegate.currentScale;
  }

  void _drawHighlighterStrokes(Canvas canvas, Rect canvasRect) {
    final layerPaint = Paint()
      ..blendMode = invert ? BlendMode.lighten : BlendMode.darken
      ..color = Colors.white.withAlpha(Highlighter.alpha);
    bool needToRestoreCanvasLayer = false;

    Color? lastColor;
    for (final stroke in strokes) {
      if (stroke.toolId != .highlighter) continue;

      final color = stroke.color.withValues(alpha: 1).withInversion(invert);

      if (color != lastColor) {
        // new layer for each color
        if (needToRestoreCanvasLayer) canvas.restore();
        canvas.saveLayer(canvasRect, layerPaint);

        needToRestoreCanvasLayer = true;
        lastColor = color;
      }

      canvas.drawPath(_selectPath(stroke), Paint()..color = color);
    }

    if (needToRestoreCanvasLayer) canvas.restore();
  }

  void _drawNonHighlighterStrokes(Canvas canvas) {
    late final paint = Paint();

    for (final stroke in strokes) {
      if (stroke.toolId == .highlighter) continue;

      var color = stroke.color.withInversion(invert);
      if (currentSelection?.strokes.contains(stroke) ?? false) {
        color = Color.lerp(color, primaryColor, 0.5)!;
      }

      paint.color = color;
      paint.shader = null;
      paint.maskFilter = null;
      if (stroke.toolId == .pencil) {
        if (shouldUsePencilShader(stroke.options.size)) {
          paint.color = Colors.white;
          paint.shader = page.pencilShader
            ..setFloat(0, color.r)
            ..setFloat(1, color.g)
            ..setFloat(2, color.b);
          paint.maskFilter = _getPencilMaskFilter(stroke.options.size);
        } else {
          // Fast imitation of pencil when zoomed out
          final background = invert ? Colors.black : Colors.white;
          paint.color = Color.lerp(background, color, 0.6)!;
        }
      }

      late final shapePaint = Paint()
        ..color = paint.color
        ..shader = paint.shader
        ..maskFilter = paint.maskFilter
        ..style = .stroke
        ..strokeWidth = stroke.options.size;

      if (stroke.toolId == .tape && page.revealedTapes.contains(stroke)) {
        // A revealed tape is just its outline
        canvas.drawPath(
          _selectPath(stroke),
          Paint()
            ..color = color.withValues(alpha: 0.8)
            ..style = .stroke
            ..strokeWidth = 1.5 / currentScale,
        );
      } else if (stroke is CircleStroke) {
        canvas.drawCircle(stroke.center, stroke.radius, shapePaint);
      } else if (stroke is RectangleStroke) {
        final strokeSize = stroke.options.size;
        canvas.drawRRect(
          RRect.fromRectAndRadius(stroke.rect, Radius.circular(strokeSize / 4)),
          shapePaint,
        );
      } else {
        canvas.drawPath(_selectPath(stroke), paint);
      }
    }
  }

  void _drawCurrentStroke(Canvas canvas) {
    if (currentStroke == null) return;

    if (currentStroke! is LaserStroke) {
      return _drawLaserStroke(canvas, currentStroke as LaserStroke);
    }

    final color = currentStroke!.color.withInversion(invert);
    final paint = Paint();

    paint.color = color;
    paint.shader = null;
    paint.maskFilter = null;
    if (currentStroke!.toolId == .pencil) {
      paint.color = Colors.white;
      paint.shader = page.pencilShader
        ..setFloat(0, color.r)
        ..setFloat(1, color.g)
        ..setFloat(2, color.b);
      paint.maskFilter = _getPencilMaskFilter(currentStroke!.options.size);
    }

    // Current stroke always uses high quality
    canvas.drawPath(currentStroke!.highQualityPath, paint);
  }

  void _drawLaserStroke(Canvas canvas, LaserStroke stroke) {
    canvas.drawPath(
      _selectPath(stroke),
      Paint()
        ..color = stroke.color.withInversion(invert)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.solid,
          stroke.options.size * 0.4,
        ),
    );
    canvas.drawPath(stroke.innerPath, Paint()..color = const Color(0xDDffffff));
  }

  void _drawDetectedShape(Canvas canvas) {
    final shape = ShapePen.detectedShape;
    if (shape == null) return;

    final color = currentStroke?.color.withInversion(invert) ?? Colors.black;
    final shapePaint = Paint()
      ..color = Color.lerp(color, primaryColor, 0.5)!.withValues(alpha: 0.7)
      ..style = .stroke
      ..strokeWidth = currentStroke?.options.size ?? 3;

    switch (shape.name) {
      case null:
        break;
      case DefaultUnistrokeNames.line:
        var (firstPoint, lastPoint) = shape.convertToLine();
        (firstPoint, lastPoint) = Stroke.snapLine(
          firstPoint is PointVector
              ? firstPoint
              : PointVector.fromOffset(offset: firstPoint),
          lastPoint is PointVector
              ? lastPoint
              : PointVector.fromOffset(offset: lastPoint),
        );
        canvas.drawLine(firstPoint, lastPoint, shapePaint);
      case DefaultUnistrokeNames.rectangle:
        final rect = shape.convertToRect();
        canvas.drawRect(rect, shapePaint);
      case DefaultUnistrokeNames.circle:
        final (center, radius) = shape.convertToCircle();
        canvas.drawCircle(center, radius, shapePaint);
      case DefaultUnistrokeNames.triangle:
      case DefaultUnistrokeNames.star:
        final polygon = shape.convertToCanonicalPolygon();
        canvas.drawPath(Path()..addPolygon(polygon, true), shapePaint);
    }
  }

  void _drawLinks(Canvas canvas) {
    final color = linkColor;
    if (color == null) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5 / currentScale;
    final mark = 10 / currentScale;
    for (final link in page.links) {
      final rect = link.rect;
      canvas.drawLine(rect.bottomLeft, rect.bottomRight, paint);
      canvas.drawPath(
        Path()
          ..moveTo(rect.right - mark, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.top + mark)
          ..close(),
        paint,
      );
    }
  }

  /// The line [InsertSpace] is dragging, and the space it adds or removes.
  void _drawInsertSpace(Canvas canvas, Size size) {
    final preview = InsertSpace.currentInsertSpace.preview;
    if (preview == null || preview.pageIndex != pageIndex) return;
    final from = preview.y, to = preview.y + preview.dy;
    canvas.drawRect(
      Rect.fromLTRB(0, min(from, to), size.width, max(from, to)),
      Paint()..color = primaryColor.withValues(alpha: 0.08),
    );
    final line = Paint()
      ..color = primaryColor
      ..strokeWidth = 1.5 / currentScale;
    canvas.drawLine(Offset(0, from), Offset(size.width, from), line);
    canvas.drawLine(Offset(0, to), Offset(size.width, to), line);
  }

  void _drawSelection(Canvas canvas) {
    if (currentSelection == null) return;

    // draw translucent fill
    canvas.drawPath(
      currentSelection!.path,
      Paint()..color = primaryColor.withValues(alpha: 0.1),
    );

    // draw dashed stroke
    canvas.drawPath(
      dashPath(
        currentSelection!.path,
        dashArray: CircularIntervalList([10, 10]),
      ),
      Paint()
        ..color = primaryColor
        ..strokeWidth = 3
        ..style = .stroke,
    );

    _drawSelectionHandles(canvas);
  }

  /// Hairline bounds with handles to resize (corners) and rotate (top).
  void _drawSelectionHandles(Canvas canvas) {
    final select = Select.currentSelect;
    final handles = select.handles;
    final bounds = select.selectionBounds;
    if (handles.isEmpty || bounds == null) return;

    final radius = select.handleRadius;
    final line = Paint()
      ..color = primaryColor.withValues(alpha: 0.6)
      ..style = .stroke
      ..strokeWidth = radius / 10;
    canvas.drawRect(bounds, line);
    if (handles[SelectionHandle.rotate] case final rotate?) {
      final edge = rotate.dy < bounds.top
          ? bounds.topCenter
          : bounds.bottomCenter;
      canvas.drawLine(edge, rotate, line);
    }

    final fill = Paint()..color = invert ? Colors.black : Colors.white;
    final border = Paint()
      ..color = primaryColor
      ..style = .stroke
      ..strokeWidth = radius / 7;
    for (final center in handles.values) {
      canvas.drawCircle(center, radius * 0.45, fill);
      canvas.drawCircle(center, radius * 0.45, border);
    }
  }

  static const double _pageIndicatorFontSize = 20;
  static const double _pageIndicatorPadding = 5;
  void _drawPageIndicator(Canvas canvas, Size pageSize) {
    if (!showPageIndicator) return;

    final style = ui.ParagraphStyle(
      textAlign: .end,
      textDirection: .ltr,
      maxLines: 1,
    );

    final builder = ui.ParagraphBuilder(style)
      ..pushStyle(
        ui.TextStyle(
          color: Colors.black.withInversion(invert).withValues(alpha: 0.5),
          fontSize: _pageIndicatorFontSize,
          fontFamily: defaultTextStyle.fontFamily,
          fontFamilyFallback: defaultTextStyle.fontFamilyFallback,
        ),
      )
      ..addText('${pageIndex + 1} / $totalPages');

    final paragraph = builder.build();
    paragraph.layout(
      ui.ParagraphConstraints(
        width: pageSize.width - 2 * _pageIndicatorPadding,
      ),
    );

    canvas.drawParagraph(
      paragraph,
      Offset(
        _pageIndicatorPadding,
        pageSize.height - _pageIndicatorPadding - _pageIndicatorFontSize * 1.2,
      ),
    );
  }

  static MaskFilter _getPencilMaskFilter(double size) =>
      MaskFilter.blur(BlurStyle.normal, min(size * 0.2, 3));
  bool shouldUsePencilShader(double strokeSize) =>
      currentScale >= _zoomThreshold && (strokeSize * currentScale) >= 3;

  static const _zoomThreshold = 0.9;
  Path _selectPath(Stroke stroke) => switch (currentScale) {
    < _zoomThreshold => stroke.lowQualityPath,
    _ => stroke.highQualityPath,
  };
}

/// Fills the closed strokes that have a [Stroke.fillColor].
///
/// It's a layer of its own, under the page's text and images,
/// so a filled shape never hides anything.
class CanvasFillPainter extends CustomPainter {
  const new({super.repaint, required this.strokes, required this.invert});

  final List<Stroke> strokes;
  final bool invert;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final stroke in strokes) {
      final color = stroke.fillColor;
      if (color == null) continue;
      canvas.drawPath(
        stroke.fillPath,
        paint..color = color.withInversion(invert),
      );
    }
  }

  /// [strokes] is changed in place (e.g. by undo) without always
  /// notifying [repaint], and this is cheap.
  @override
  bool shouldRepaint(CanvasFillPainter oldDelegate) => true;
}
