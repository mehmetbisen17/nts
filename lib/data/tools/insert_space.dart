import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/data/editor/editor_history.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:sbn/tool_id.dart';

/// Drag down from a line to push the ink and images below it further down
/// the page, or up to remove space. Typed text isn't moved (it flows).
class InsertSpace extends CanvasTool {
  new _();

  static final currentInsertSpace = InsertSpace._();

  @override
  ToolId get toolId => .insertSpace;

  /// The drag in progress, which the canvas draws: what's below [y]
  /// on page [pageIndex] is moving by [dy].
  ({int pageIndex, double y, double dy})? preview;

  @override
  void onDrawStart(CanvasToolInput input) =>
      preview = (pageIndex: input.pageIndex, y: input.position.dy, dy: 0);

  @override
  void onDrawUpdate(CanvasToolInput input) {
    final preview = this.preview;
    if (preview == null) return;
    this.preview = (
      pageIndex: preview.pageIndex,
      y: preview.y,
      dy: clampDy(input.page, preview.y, input.position.dy - preview.y),
    );
  }

  @override
  EditorHistoryItem? onDrawEnd(CanvasToolInput input) {
    final preview = this.preview;
    this.preview = null;
    if (preview == null || preview.dy.abs() < 1) return null;

    final (strokes, images) = below(input.page, preview.y);
    if (strokes.isEmpty && images.isEmpty) return null;
    final offset = Offset(0, preview.dy);
    for (final stroke in strokes) {
      stroke.shift(offset);
    }
    for (final image in images) {
      image.dstRect = image.dstRect.shift(offset);
    }
    return EditorHistoryItem(
      type: .move,
      pageIndex: preview.pageIndex,
      strokes: strokes,
      images: images,
      offset: .fromLTRB(0, preview.dy, 0, preview.dy),
    );
  }

  /// The ink and images that start below [y].
  static (List<Stroke>, List<EditorImage>) below(EditorPage page, double y) => (
    [
      for (final stroke in page.strokes)
        if (stroke.bounds.top >= y) stroke,
    ],
    [
      for (final image in page.images)
        if (image.dstRect.top >= y) image,
    ],
  );

  /// Limits [dy] so what moves stays on the page (it isn't moved onto the
  /// next page) and removing space stops at the content above.
  static double clampDy(EditorPage page, double y, double dy) {
    final (strokes, images) = below(page, y);
    Rect rectOf(Stroke stroke) =>
        stroke.bounds.inflate(stroke.options.size / 2);
    final moving = [...strokes.map(rectOf), for (final i in images) i.dstRect];
    if (moving.isEmpty) return dy;
    final top = moving.map((rect) => rect.top).reduce(min);
    final bottom = moving.map((rect) => rect.bottom).reduce(max);

    // The lowest content above what's moving
    final moved = <Object>{...strokes, ...images};
    var floor = 0.0;
    for (final rect in [
      for (final stroke in page.strokes)
        if (!moved.contains(stroke)) rectOf(stroke),
      for (final image in page.images)
        if (!moved.contains(image)) image.dstRect,
    ]) {
      if (rect.bottom <= top) floor = max(floor, rect.bottom);
    }
    return dy.clamp(min(0.0, floor - top), max(0.0, page.size.height - bottom));
  }
}
