import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/i18n/strings.g.dart';

/// Opaque tape that hides what's under it, for active recall:
/// tap a tape to see what's under it, and tap again to cover it.
///
/// Tape strokes are ordinary strokes (so the eraser, lasso and exports
/// treat them like ink) that are drawn above everything else.
class Tape extends Pen {
  new()
    : super(
        name: t.editor.canvasTools.tape,
        sizeMin: 10,
        sizeMax: 60,
        sizeStep: 5,
        icon: tapeIcon,
        options: stows.lastTapeOptions.value,
        pressureEnabled: false,
        color: defaultColor,
        toolId: .tape,
      );

  static var currentTape = Tape();

  static const tapeIcon = Symbols.rectangle;

  /// Higan's quiet blue.
  static const defaultColor = Color(0xFF6C8CA8);

  /// Tape is always opaque.
  @override
  set color(Color color) => super.color = color.withAlpha(255);

  /// The topmost tape on [page] at [position], if any.
  static Stroke? tapeAt(EditorPage page, Offset position) =>
      page.strokes.reversed.firstWhereOrNull(
        (stroke) =>
            stroke.toolId == .tape && stroke.lowQualityPath.contains(position),
      );

  /// Shows what's under [tape], or covers it again.
  static void toggle(EditorPage page, Stroke tape) {
    if (!page.revealedTapes.remove(tape)) page.revealedTapes.add(tape);
    page.redrawStrokes();
  }
}
