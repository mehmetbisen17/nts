import 'dart:math';
import 'dart:ui';

import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/editor/editor_history.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:sbn/tool_id.dart';

double square(double x) => x * x;
double sqrDistanceBetween(Offset p1, Offset p2) =>
    square(p1.dx - p2.dx) + square(p1.dy - p2.dy);

/// The squared distance from [p] to the line segment from [a] to [b].
double sqrDistanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.distanceSquared;
  if (lengthSquared == 0) return sqrDistanceBetween(p, a);
  final ap = p - a;
  final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
  return sqrDistanceBetween(p, a + ab * t);
}

enum EraserMode {
  /// Erases every stroke the eraser touches, entirely.
  stroke,

  /// Erases only the parts of strokes that the eraser passes over.
  partial,
}

class Eraser extends Tool {
  new({this._size});

  final double? _size;

  /// The eraser's radius, [stows.eraserSize] unless given explicitly.
  double get size => _size ?? stows.eraserSize.value;

  /// [stows.eraserMode], fixed at the start of a drag so it can't change
  /// mid-drag.
  EraserMode? _dragMode;

  List<Stroke> _erased = [];

  /// In [EraserMode.partial]: the page's strokes before this drag
  /// first changed them, and the (since mutated) list itself.
  List<Stroke>? _strokesBefore, _strokesAfter;

  /// In [EraserMode.partial]: the original strokes this drag cut,
  /// and the fragments that replaced them (and weren't cut again).
  final _cut = <Stroke>{}, _fragments = <Stroke>{};

  @override
  ToolId get toolId => .eraser;

  /// Erases what the eraser touched while moving in a straight line
  /// from [from] (if given) to [eraserPos], modifying [strokes] in place.
  ///
  /// A null [from] starts a new drag, discarding any state left by a drag
  /// that never reached [finishDrag].
  ///
  /// Returns whether anything was erased.
  bool erase(Offset eraserPos, List<Stroke> strokes, {Offset? from}) {
    if (from == null) _resetPartialDrag();
    _dragMode ??= stows.eraserMode.value;
    var erased = false;
    switch (_dragMode!) {
      case .stroke:
        for (final stroke in checkForOverlappingStrokes(
          eraserPos,
          strokes,
          from: from,
        )) {
          strokes.remove(stroke);
          erased = true;
        }
      case .partial:
        // Backwards so replacing a stroke doesn't shift unvisited indices
        for (int i = strokes.length - 1; i >= 0; --i) {
          final fragments = strokes[i].erasePartially(
            from ?? eraserPos,
            eraserPos,
            size,
          );
          if (fragments == null) continue;
          erased = true;
          _strokesBefore ??= List.of(strokes);
          _strokesAfter = strokes;
          if (!_fragments.remove(strokes[i])) _cut.add(strokes[i]);
          _fragments.addAll(fragments);
          // Fragments take the original stroke's place (z-order)
          strokes.replaceRange(i, i + 1, fragments);
        }
    }
    return erased;
  }

  /// Ends the current drag, returning the history item describing
  /// what was erased, or null if nothing was.
  EditorHistoryItem? finishDrag(int pageIndex) {
    final erased = onDragEnd();
    final before = _strokesBefore, after = _strokesAfter;
    // Only what the eraser replaced, not other changes made mid-drag
    final change = before == null
        ? null
        : StrokeListChange(
            removed: [
              for (final (i, stroke) in before.indexed)
                if (_cut.contains(stroke)) (i, stroke),
            ],
            added: [
              for (final (i, stroke) in after!.indexed)
                if (_fragments.contains(stroke)) (i, stroke),
            ],
          );
    _resetPartialDrag();

    if (change != null) {
      return EditorHistoryItem(
        type: .partialErase,
        pageIndex: pageIndex,
        strokes: [],
        images: [],
        strokeListChange: change,
      );
    }
    if (erased.isEmpty) return null;
    return EditorHistoryItem(
      type: .erase,
      pageIndex: pageIndex,
      strokes: erased,
      images: [],
    );
  }

  void _resetPartialDrag() {
    _dragMode = null;
    _strokesBefore = _strokesAfter = null;
    _cut.clear();
    _fragments.clear();
  }

  /// Returns any [strokes] that are close to the given [eraserPos],
  /// or to the line from [from] to [eraserPos] if [from] is given.
  List<Stroke> checkForOverlappingStrokes(
    Offset eraserPos,
    List<Stroke> strokes, {
    Offset? from,
  }) {
    final sqrSize = square(size);
    final List<Stroke> overlapping = [];
    for (int i = 0; i < strokes.length; i++) {
      final stroke = strokes[i];
      if (_shouldStrokeBeErased(
        from ?? eraserPos,
        eraserPos,
        stroke,
        sqrSize,
      )) {
        overlapping.add(stroke);
        _erased.add(stroke);
      }
    }
    return overlapping;
  }

  /// Returns the strokes that have been erased during this drag.
  List<Stroke> onDragEnd() {
    final List<Stroke> erased = _erased;
    _erased = [];
    return erased;
  }

  /// The [strokes] mostly (at least half) inside the bounds of [scribble]
  /// (see [Stroke.isScribble]), which scribbling erases
  /// when [Stows.scribbleToErase] is on.
  static List<Stroke> strokesUnderScribble(
    Stroke scribble,
    Iterable<Stroke> strokes,
  ) {
    final area = scribble.bounds.inflate(scribble.options.size / 2);
    return [
      for (final stroke in strokes)
        if (!identical(stroke, scribble) &&
            stroke.lowQualityPolygon.isNotEmpty &&
            stroke.lowQualityPolygon.where(area.contains).length * 2 >=
                stroke.lowQualityPolygon.length)
          stroke,
    ];
  }

  static bool _shouldStrokeBeErased(
    Offset from,
    Offset eraserPos,
    Stroke stroke,
    double sqrSize,
  ) {
    // Most strokes are nowhere near: skip them without visiting points
    final reach = sqrt(sqrSize) + stroke.options.size;
    if (!stroke.bounds
        .inflate(reach)
        .overlaps(Rect.fromPoints(from, eraserPos))) {
      return false;
    }
    if (stroke.length <= 3) {
      if (stroke.lowQualityPath.contains(eraserPos)) return true;
    }

    /// skip checking every few vertices for performance
    final int verticesToSkip = switch (stroke.lowQualityPolygon.length) {
      < 100 => 0,
      < 1000 => 1,
      _ => 2,
    };

    for (
      int i = 0;
      i < stroke.lowQualityPolygon.length;
      i += verticesToSkip + 1
    ) {
      final Offset strokeVertex = stroke.lowQualityPolygon[i];
      if (sqrDistanceToSegment(strokeVertex, from, eraserPos) <= sqrSize) {
        return true;
      }
    }
    return false;
  }
}
