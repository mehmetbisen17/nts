import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/editor/editor_history.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:sbn/change.dart';
import 'package:sbn/tool_id.dart';

/// Fills the closed stroke (a loop or shape) that's tapped with [color].
/// Tapping it again with the same color clears the fill.
class Fill extends CanvasTool {
  new _();

  static final currentFill = Fill._();

  @override
  ToolId get toolId => .fill;

  /// Higan's quiet yellow.
  var color = const Color(0xFFE2B46C);

  /// The smallest closed stroke around [position], if any.
  static Stroke? strokeAt(List<Stroke> strokes, Offset position) => strokes
      .where(
        (stroke) =>
            stroke.toolId != .tape &&
            stroke.isClosed &&
            stroke.fillPath.contains(position),
      )
      .sortedBy<num>((stroke) => stroke.bounds.width * stroke.bounds.height)
      .firstOrNull;

  @override
  EditorHistoryItem? onDrawEnd(CanvasToolInput input) {
    final stroke = strokeAt(input.page.strokes, input.position);
    if (stroke == null) return null;
    final change = Change(
      previous: stroke.fillColor,
      current: stroke.fillColor == color ? null : color,
    );
    stroke.fillColor = change.current;
    return EditorHistoryItem(
      type: .fillChange,
      pageIndex: input.pageIndex,
      strokes: [stroke],
      images: [],
      fillChange: {stroke: change},
    );
  }
}
