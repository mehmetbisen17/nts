import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/data/editor/editor_history.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:sbn/change.dart';
import 'package:sbn/tool_id.dart';

/// How the lasso selects, see [Stows.lassoMode].
enum LassoMode { freehand, rectangle }

/// A handle on a selection: the corners resize it, [rotate] turns it.
enum SelectionHandle { topLeft, topRight, bottomRight, bottomLeft, rotate }

class Select extends Tool {
  new _();

  static final _currentSelect = Select._();
  static Select get currentSelect => _currentSelect;

  /// The minimum ratio of points inside a stroke or image
  /// for it to be selected.
  static const minPercentInside = 0.7;

  var selectResult = SelectResult(
    pageIndex: -1,
    strokes: const [],
    images: const [],
    path: Path(),
  );
  var doneSelecting = false;

  /// [Stows.lassoMode], fixed at the start of a drag.
  var _dragMode = LassoMode.freehand;
  var _dragOrigin = Offset.zero;

  @override
  ToolId get toolId => .select;

  void unselect() {
    doneSelecting = false;
    selectResult.pageIndex = -1;
    _transform = null;
  }

  Color? getDominantStrokeColor() {
    if (!doneSelecting) return null;
    if (selectResult.strokes.isEmpty) return null;

    final colorDistribution = <Color, int>{};
    for (final stroke in selectResult.strokes) {
      colorDistribution.update(
        stroke.color,
        (value) => value + stroke.length,
        ifAbsent: () => stroke.length,
      );
    }
    assert(colorDistribution.isNotEmpty);

    return colorDistribution.entries.reduce((a, b) {
      return a.value > b.value ? a : b;
    }).key;
  }

  void onDragStart(Offset position, int pageIndex) {
    doneSelecting = false;
    _transform = null;
    selectResult = SelectResult(
      pageIndex: pageIndex,
      strokes: [],
      images: [],
      path: Path(),
    );
    selectResult.path.moveTo(position.dx, position.dy);
    _dragMode = stows.lassoMode.value;
    _dragOrigin = position;
    onDragUpdate(position);
  }

  void onDragUpdate(Offset position) {
    switch (_dragMode) {
      case .freehand:
        selectResult.path.lineTo(position.dx, position.dy);
      case .rectangle:
        selectResult.path = Path()
          ..addRect(Rect.fromPoints(_dragOrigin, position));
    }
  }

  /// Adds the indices of any [strokes] that are inside the selection area
  /// to [selectResult.indices].
  void onDragEnd(List<Stroke> strokes, List<EditorImage> images) {
    selectResult.path.close();
    doneSelecting = true;

    for (int i = 0; i < strokes.length; i++) {
      final stroke = strokes[i];
      final percentInside = polygonPercentInside(
        selectResult.path,
        stroke.lowQualityPolygon,
      );
      if (percentInside > minPercentInside) {
        selectResult.strokes.add(stroke);
      }
    }

    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      final percentInside = rectPercentInside(selectResult.path, image.dstRect);
      if (percentInside >= minPercentInside) {
        selectResult.images.add(image);
      }
    }
  }

  /// The handles' size in page units, set by the editor so they're
  /// the same size on screen at any zoom.
  var handleRadius = 12.0;

  /// The bounds of the selected strokes (with their thickness) and images.
  Rect? get selectionBounds => [
    for (final stroke in selectResult.strokes)
      stroke.bounds.inflate(stroke.options.size / 2),
    for (final image in selectResult.images) image.dstRect,
  ].fold<Rect?>(null, (bounds, rect) => bounds?.expandToInclude(rect) ?? rect);

  /// Where the handles are. There's no [SelectionHandle.rotate] if images
  /// are selected, because images can't be rotated.
  Map<SelectionHandle, Offset> get handles {
    final bounds = selectionBounds;
    if (!doneSelecting || bounds == null) return const {};
    return {
      .topLeft: bounds.topLeft,
      .topRight: bounds.topRight,
      .bottomRight: bounds.bottomRight,
      .bottomLeft: bounds.bottomLeft,
      if (selectResult.images.isEmpty)
        .rotate: switch (bounds.topCenter - Offset(0, 4 * handleRadius)) {
          // Below if above would be off the page
          final above when above.dy >= 0 => above,
          _ => bounds.bottomCenter + Offset(0, 4 * handleRadius),
        },
    };
  }

  SelectionHandle? handleAt(Offset position) {
    for (final MapEntry(key: handle, value: center) in handles.entries) {
      if ((position - center).distance <= handleRadius) return handle;
    }
    return null;
  }

  _Transform? _transform;
  bool get isTransforming => _transform != null;

  /// Starts resizing or rotating the selection if [position] is on a handle.
  /// Until [finishTransform], the selected strokes in [pageStrokes] are
  /// replaced by transformed copies.
  bool startTransform(Offset position, List<Stroke> pageStrokes) {
    final handle = handleAt(position);
    final bounds = selectionBounds;
    if (handle == null || bounds == null) return false;
    // Its own list, since history items may hold the one it had
    // (e.g. a move or recolor of this selection)
    selectResult = selectResult.copyWith(
      strokes: List.of(selectResult.strokes),
    );
    _transform = _Transform(
      handle: handle,
      pivot: switch (handle) {
        .topLeft => bounds.bottomRight,
        .topRight => bounds.bottomLeft,
        .bottomRight => bounds.topLeft,
        .bottomLeft => bounds.topRight,
        .rotate => bounds.center,
      },
      start: position,
      strokes: List.of(selectResult.strokes),
      indices: [
        for (final stroke in selectResult.strokes) pageStrokes.indexOf(stroke),
      ],
      imageRects: [for (final image in selectResult.images) image.dstRect],
      path: selectResult.path,
    );
    return true;
  }

  /// The smallest a resize can make the selection.
  static const minScale = 0.05;

  /// Rotations this close to a right angle snap to it.
  static const _snapAngle = 4 * pi / 180;

  /// With Shift held, rotations snap to multiples of this.
  static const shiftSnapAngle = pi / 12;

  void updateTransform(Offset position, List<Stroke> pageStrokes) {
    final transform = _transform;
    if (transform == null) return;
    if (!_inPlace(transform, pageStrokes)) return unselect();
    final pivot = transform.pivot, start = transform.start;
    final Matrix4 change;
    if (transform.handle == .rotate) {
      var angle = (position - pivot).direction - (start - pivot).direction;
      final rightAngle = (angle / (pi / 2)).roundToDouble() * (pi / 2);
      if (HardwareKeyboard.instance.isShiftPressed) {
        angle = (angle / shiftSnapAngle).roundToDouble() * shiftSnapAngle;
      } else if ((angle - rightAngle).abs() < _snapAngle) {
        angle = rightAngle;
      }
      change = Matrix4.rotationZ(angle);
    } else {
      // Always in proportion, so no need for Shift
      final from = start - pivot, to = position - pivot;
      final scale = max(
        minScale,
        (to.dx * from.dx + to.dy * from.dy) / from.distanceSquared,
      );
      change = Matrix4.diagonal3Values(scale, scale, 1);
    }
    _applyTransform(
      Matrix4.translationValues(pivot.dx, pivot.dy, 0)
        ..multiply(change)
        ..multiply(Matrix4.translationValues(-pivot.dx, -pivot.dy, 0)),
      pageStrokes,
    );
  }

  /// Whether the page still has the selected strokes where the transform
  /// put them, which e.g. an undo in the middle of a drag can change.
  bool _inPlace(_Transform transform, List<Stroke> pageStrokes) {
    for (final (i, index) in transform.indices.indexed) {
      if (index < 0) continue;
      if (index >= pageStrokes.length ||
          i >= selectResult.strokes.length ||
          !identical(pageStrokes[index], selectResult.strokes[i])) {
        return false;
      }
    }
    return true;
  }

  void _applyTransform(Matrix4 matrix, List<Stroke> pageStrokes) {
    final transform = _transform!..matrix = matrix;
    final identity = matrix.isIdentity();
    for (final (i, original) in transform.strokes.indexed) {
      final stroke = identity ? original : original.transformed(matrix);
      selectResult.strokes[i] = stroke;
      final index = transform.indices[i];
      if (index >= 0) pageStrokes[index] = stroke;
    }
    for (final (i, image) in selectResult.images.indexed) {
      image.dstRect = MatrixUtils.transformRect(
        matrix,
        transform.imageRects[i],
      );
    }
    selectResult.path = transform.path.transform(matrix.storage);
  }

  /// Ends a resize or rotation, returning the history item describing it,
  /// or null if nothing changed.
  EditorHistoryItem? finishTransform(int pageIndex, List<Stroke> pageStrokes) {
    final transform = _transform;
    if (transform == null) return null;
    if (!_inPlace(transform, pageStrokes)) {
      unselect();
      return null;
    }
    if (transform.matrix.isIdentity()) {
      _applyTransform(transform.matrix, pageStrokes);
      _transform = null;
      return null;
    }
    _transform = null;

    List<(int, Stroke)> byIndex(List<Stroke> strokes) => [
      for (final (i, stroke) in strokes.indexed)
        if (transform.indices[i] >= 0) (transform.indices[i], stroke),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return EditorHistoryItem(
      type: .partialErase,
      pageIndex: pageIndex,
      strokes: [],
      images: [],
      strokeListChange: StrokeListChange(
        removed: byIndex(transform.strokes),
        added: byIndex(selectResult.strokes),
      ),
      imageRectChange: {
        for (final (i, image) in selectResult.images.indexed)
          image: Change(
            previous: transform.imageRects[i],
            current: image.dstRect,
          ),
      },
    );
  }

  static double rectPercentInside(Path selection, Rect rect) {
    const int gridSize = 5;
    final gridCellWidth = rect.width / (gridSize - 1);
    final gridCellHeight = rect.height / (gridSize - 1);

    int pointsInside = 0;
    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        if (selection.contains(
          Offset(rect.left + gridCellWidth * x, rect.top + gridCellHeight * y),
        )) {
          pointsInside++;
        }
      }
    }

    // times 1.25 because the grid is not very accurate
    return pointsInside / (gridSize * gridSize) * 1.25;
  }

  static double polygonPercentInside(Path selection, List<Offset> polygon) {
    int pointsInside = 0;
    for (final point in polygon) {
      if (selection.contains(point)) {
        pointsInside++;
      }
    }
    return pointsInside / polygon.length;
  }
}

class SelectResult {
  int pageIndex;
  final List<Stroke> strokes;
  final List<EditorImage> images;
  Path path;

  new({
    required this.pageIndex,
    required this.strokes,
    required this.images,
    required this.path,
  });

  bool get isEmpty {
    return strokes.isEmpty && images.isEmpty;
  }

  SelectResult copyWith({
    int? pageIndex,
    List<Stroke>? strokes,
    List<EditorImage>? images,
    Path? path,
  }) {
    return SelectResult(
      pageIndex: pageIndex ?? this.pageIndex,
      strokes: strokes ?? this.strokes,
      images: images ?? this.images,
      path: path ?? this.path,
    );
  }
}

/// A resize or rotation of the selection in progress.
class _Transform {
  new({
    required this.handle,
    required this.pivot,
    required this.start,
    required this.strokes,
    required this.indices,
    required this.imageRects,
    required this.path,
  });

  final SelectionHandle handle;

  /// The point that stays still: the opposite corner, or the center.
  final Offset pivot;
  final Offset start;

  /// The selected strokes as they were, and their indices in the page.
  final List<Stroke> strokes;
  final List<int> indices;
  final List<Rect> imageRects;
  final Path path;
  var matrix = Matrix4.identity();
}
