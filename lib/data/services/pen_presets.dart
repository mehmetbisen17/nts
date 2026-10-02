import 'package:flutter/material.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/data/tools/calligraphy_pen.dart';
import 'package:nts/data/tools/highlighter.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/pencil.dart';
import 'package:nts/data/tools/shape_pen.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:sbn/tool_id.dart';

/// A favorite pen: its type, color and size. Saved in
/// [Stows.penPresets], not in notes.
class PenPreset {
  const new({required this.toolId, required this.color, required this.size});

  final ToolId toolId;
  final Color color;
  final double size;

  /// The toolbar has room for this many.
  static const max = 5;

  static const _toolIds = {
    ToolId.fountainPen,
    ToolId.ballpointPen,
    ToolId.pencil,
    ToolId.highlighter,
    ToolId.shapePen,
    ToolId.brushPen,
    ToolId.calligraphyPen,
  };

  /// [tool] as a preset, or null if it isn't a pen.
  static PenPreset? of(Tool tool) =>
      tool is Pen && _toolIds.contains(tool.toolId)
      ? PenPreset(
          toolId: tool.toolId,
          color: tool.color,
          size: tool.options.size,
        )
      : null;

  /// A new pen of this type, color and size.
  Pen toPen() {
    final Pen pen = switch (toolId) {
      .ballpointPen => Pen.ballpointPen(),
      .pencil => Pencil(),
      .highlighter => Highlighter(),
      .shapePen => ShapePen(),
      .brushPen => Pen.brushPen(),
      .calligraphyPen => CalligraphyPen(),
      _ => Pen.fountainPen(),
    };
    return pen
      ..color = color
      ..options.size = size.clamp(pen.sizeMin, pen.sizeMax);
  }

  String get name => switch (toolId) {
    .ballpointPen => t.editor.pens.ballpointPen,
    .pencil => t.editor.pens.pencil,
    .highlighter => t.editor.pens.highlighter,
    .shapePen => t.editor.pens.shapePen,
    .brushPen => t.editor.canvasTools.brushPen,
    .calligraphyPen => t.editor.canvasTools.calligraphyPen,
    _ => t.editor.pens.fountainPen,
  };

  /// Saved by [ToolId.id] (not index), so new tools don't shift them.
  Map<String, Object> toJson() => {
    'toolId': toolId.id,
    'color': color.toARGB32(),
    'size': size,
  };

  /// Skips presets of unknown pen types, e.g. from a newer version.
  static List<PenPreset> listFromJson(Object json) => [
    for (final preset in (json as List).cast<Map>())
      for (final toolId in _toolIds)
        if (toolId.id == preset['toolId'])
          PenPreset(
            toolId: toolId,
            color: Color(preset['color'] as int),
            size: (preset['size'] as num).toDouble(),
          ),
  ];

  static void add(PenPreset preset) {
    final presets = stows.penPresets.value;
    if (presets.contains(preset) || presets.length >= max) return;
    stows.penPresets.value = [...presets, preset];
  }

  static void remove(PenPreset preset) => stows.penPresets.value = [
    for (final saved in stows.penPresets.value)
      if (saved != preset) saved,
  ];

  @override
  bool operator ==(Object other) =>
      other is PenPreset &&
      other.toolId == toolId &&
      other.color.toARGB32() == color.toARGB32() && // e.g. MaterialColors
      other.size == size;

  @override
  int get hashCode => Object.hash(toolId, color.toARGB32(), size);
}
