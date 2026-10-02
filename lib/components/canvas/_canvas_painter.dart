import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nts/components/canvas/_circle_stroke.dart';
import 'package:nts/components/canvas/_rectangle_stroke.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/text_boxes.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/extensions/color_extensions.dart';
import 'package:nts/data/tools/highlighter.dart';
import 'package:nts/data/tools/insert_space.dart';
import 'package:nts/data/tools/laser_pointer.dart';
import 'package:nts/data/tools/pen.dart';
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
    this.cardLabel,
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

  /// E.g. "3 · FRONT" in the top left of a flashcard, or null.
  final String? cardLabel;

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
    _drawCardLabel(canvas);
  }

  void _drawCardLabel(Canvas canvas) {
    final label = cardLabel;
    if (label == null) return;
    final builder =
        ui.ParagraphBuilder(ui.ParagraphStyle(textDirection: .ltr, maxLines: 1))
          ..pushStyle(
            ui.TextStyle(
              color: Colors.black.withInversion(invert).withValues(alpha: 0.4),
              fontSize: 18,
              letterSpacing: 1.5,
              fontFamily: defaultTextStyle.fontFamily,
              fontFamilyFallback: defaultTextStyle.fontFamilyFallback,
            ),
          )
          ..addText(label);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 400));
    canvas.drawParagraph(paragraph, const Offset(20, 16));
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
        currentScale != oldDelegate.currentScale ||
        cardLabel != oldDelegate.cardLabel;
  }

  void _drawHighlighterStrokes(Canvas canvas, Rect pageRect) {
    // The layers reach beside the page too, or highlighter there is clipped
    final canvasRect = Rect.fromLTRB(
      pageRect.left - page.sideWidth,
      pageRect.top,
      pageRect.right + page.sideWidth,
      pageRect.bottom,
    );
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

    // Held still: the shape it snaps to, instead of the wobbly stroke
    switch (Pen.snapPreview) {
      case final CircleStroke circle:
        canvas.drawCircle(
          circle.center,
          circle.radius,
          _outline(paint, circle),
        );
      case final RectangleStroke rect:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.rect,
            Radius.circular(rect.options.size / 4),
          ),
          _outline(paint, rect),
        );
      case final Stroke shape:
        canvas.drawPath(shape.highQualityPath, paint);
      case null:
        // Current stroke always uses high quality
        canvas.drawPath(currentStroke!.highQualityPath, paint);
    }
  }

  static Paint _outline(Paint fill, Stroke stroke) => Paint()
    ..color = fill.color
    ..shader = fill.shader
    ..maskFilter = fill.maskFilter
    ..style = .stroke
    ..strokeWidth = stroke.options.size;

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

  /// Always the smooth path: the low quality one (every 4th point, no
  /// smoothing) made zoomed-out handwriting jagged and hard to read.
  /// Paths are cached per stroke, so this only costs the first paint.
  Path _selectPath(Stroke stroke) => stroke.highQualityPath;
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

/// Cards behind what's beside the page (see [EditorPage.areaWithSides]):
/// one per group of things that touch, in the page's colour so ink is as
/// readable as it was on the page, and edged with [accent] so it's clear
/// what sits beside the page.
class SideCardsPainter extends CustomPainter {
  const new({
    super.repaint,
    required this.page,
    required this.invert,
    required this.pageColor,
    required this.accent,
    required this.backdrop,
  });

  final EditorPage page;
  final bool invert;

  /// The page's colour before [invert]ing it.
  final Color pageColor;
  final Color accent;

  /// The colour around the pages, which a card must stand out from.
  final Color backdrop;

  static const _radius = Radius.circular(14);

  @override
  void paint(Canvas canvas, Size size) {
    final pageColor = this.pageColor.withInversion(invert);
    final border = Paint()
      ..style = .stroke
      ..strokeWidth = 1.5
      ..color = accent.withValues(alpha: 0.5);
    for (final (rect, ink) in sideGroups(page)) {
      final card = RRect.fromRectAndRadius(rect, _radius);
      canvas
        ..drawRRect(
          card,
          Paint()
            ..color = cardColor(
              pageColor,
              [for (final color in ink) color.withInversion(invert)],
              accent,
              backdrop: backdrop,
            ),
        )
        ..drawRRect(card, border);
    }
  }

  /// [pageColor] with a hint of [accent], unless some of the [ink] is hard
  /// to read on it (e.g. light ink moved off a dark PDF): then paper or
  /// dark, whichever all the ink stands out on best. Nudged lighter or
  /// darker if it would look just like the [backdrop] around the pages
  /// (e.g. black pages in Night), so the card itself shows.
  static Color cardColor(
    Color pageColor,
    List<Color> ink,
    Color accent, {
    Color? backdrop,
  }) {
    const paper = Color(0xFFF4F2ED), dark = Color(0xFF1B1A19);
    double worst(Color card) => ink.isEmpty
        ? 21
        : ink
              .map(
                (color) => _contrast(
                  color.computeLuminance(),
                  card.computeLuminance(),
                ),
              )
              .reduce(min);
    var card = Color.lerp(pageColor, accent, 0.05)!;
    if (worst(card) < 3) {
      card = [card, paper, dark].reduce((a, b) => worst(b) > worst(a) ? b : a);
    }
    if (backdrop != null &&
        _contrast(card.computeLuminance(), backdrop.computeLuminance()) <
            1.25) {
      final lighter = card.computeLuminance() < 0.5;
      card = Color.lerp(card, lighter ? Colors.white : Colors.black, 0.1)!;
    }
    return card;
  }

  static double _contrast(double a, double b) =>
      (max(a, b) + 0.05) / (min(a, b) + 0.05);

  /// What's beside [page], grouped where it touches (within [gap]):
  /// each group's card and the colours of its ink.
  /// Cards stop at the page's edge.
  /// ponytail: merges pairs until none touch, O(n²) per pass; fine for
  /// the handful of things people put beside a page.
  static List<(Rect, List<Color>)> sideGroups(
    EditorPage page, {
    double gap = 16,
  }) {
    final width = page.size.width;
    bool beside(Rect rect) => rect.center.dx < 0 || rect.center.dx > width;
    final groups = <(Rect, List<Color>)>[
      for (final stroke in page.strokes)
        if (stroke.toolId != .laserPointer &&
            stroke.bounds.isFinite &&
            beside(stroke.bounds))
          (
            stroke.bounds.inflate(stroke.options.size / 2 + gap),
            [if (stroke.toolId != .highlighter) stroke.color],
          ),
      for (final image in page.images)
        if (beside(image.dstRect)) (image.dstRect.inflate(gap), const []),
      for (final box in page.textBoxes)
        if (TextBoxes.boundsOf(box) case final bounds when beside(bounds))
          (bounds.inflate(gap), [box.color ?? Colors.black]),
    ];

    for (var merged = true; merged;) {
      merged = false;
      outer:
      for (var i = 0; i < groups.length; i++) {
        for (var j = i + 1; j < groups.length; j++) {
          final (a, inkA) = groups[i];
          final (b, inkB) = groups[j];
          if (a.center.dx < 0 != b.center.dx < 0) continue; // other side
          if (!a.overlaps(b)) continue;
          groups[i] = (a.expandToInclude(b), [...inkA, ...inkB]);
          groups.removeAt(j);
          merged = true;
          break outer;
        }
      }
    }

    return [
      for (final (rect, ink) in groups)
        (
          rect.center.dx < 0
              ? Rect.fromLTRB(
                  rect.left,
                  rect.top,
                  min(rect.right, -2),
                  rect.bottom,
                )
              : Rect.fromLTRB(
                  max(rect.left, width + 2),
                  rect.top,
                  rect.right,
                  rect.bottom,
                ),
          ink,
        ),
    ];
  }

  @override
  bool shouldRepaint(SideCardsPainter oldDelegate) => true;
}
