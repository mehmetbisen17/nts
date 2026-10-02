import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/data/editor/page.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/change.dart';

class EditorHistory {
  static const maxHistoryLength = 100;

  /// A stack of the changes that have been made in the editor.
  /// The last element is used when undoing.
  ///
  /// See also: [_future]
  final List<EditorHistoryItem> _past = [];

  /// A stack of the changes that have been undone in the editor.
  /// The last element is used when redoing.
  ///
  /// See also: [_past]
  final List<EditorHistoryItem> _future = [];

  /// The last saved state in the history.
  /// This is used to determine whether an autosave is needed.
  EditorHistoryItem? _lastSaved;

  /// True if redo is possible.
  /// We don't directly clear [_future] because we sometimes need to
  /// reject strokes (i.e. accidental strokes when zooming).
  var _isRedoPossible = false;

  /// Removes an element from the [_past] stack,
  /// adds it to the [_future] stack, and returns it.
  ///
  /// Please check [canUndo] first: this method will
  /// throw an exception if there is nothing to undo.
  EditorHistoryItem undo() {
    if (_past.isEmpty) throw Exception('Nothing to undo');
    final item = _past.removeLast();
    _future.add(item);
    return item;
  }

  /// Removes an element from the [_future] stack,
  /// adds it to the [_past] stack, and returns it.
  ///
  /// Please check [canRedo] first: this method will
  /// throw an exception if there is nothing to redo.
  EditorHistoryItem redo() {
    if (_future.isEmpty) throw Exception('Nothing to redo');
    final item = _future.removeLast();
    _past.add(item);
    return item;
  }

  /// Allows you to see the last item in the [_past] stack
  /// without removing it.
  ///
  /// Please check [canUndo] first: this method will
  /// throw an exception if there is nothing to undo.
  EditorHistoryItem peekUndo() {
    if (_past.isEmpty) throw Exception('Nothing to undo');
    return _past.last;
  }

  /// Allows you to see the last item in the [_future] stack
  /// without removing it.
  ///
  /// Please check [canRedo] first: this method will
  /// throw an exception if there is nothing to redo.
  EditorHistoryItem peekRedo() {
    if (_future.isEmpty) throw Exception('Nothing to redo');
    return _future.last;
  }

  /// Adds an item to the [_past] stack.
  void recordChange(EditorHistoryItem item) {
    assert(
      item.type != .quillUndoneChange,
      'EditorHistoryItemType.quillUndoneChange is just a hack to make undoing quill changes easier. It should just be recorded as a quill change.',
    );

    _past.add(item);
    if (_past.length > maxHistoryLength) _past.removeAt(0);
    _isRedoPossible = false;
  }

  /// Marks the last change as saved to disk.
  /// This does not modify the history stacks, but allows us to know
  /// whether the current state is saved or not.
  void markLastChangeAsSaved() {
    _lastSaved = _past.lastOrNull;
  }

  /// Whether the current state is saved to disk.
  ///
  /// Note that this explicitly checks the last change in the history,
  /// not whether _past is empty. This is because _past items can be discarded
  /// if the history exceeds [maxHistoryLength].
  bool get isCurrentStateSaved {
    return _past.lastOrNull == _lastSaved;
  }

  /// Removes the last history item due to a rejected stroke.
  /// This does essentially the opposite of [recordChange].
  EditorHistoryItem? removeAccidentalStroke() {
    _isRedoPossible = true;
    if (_past.isEmpty) return null;
    // (An erase if the stroke was a scribble that erased, see
    // [Stroke.isScribble].)
    assert(
      _past.last.type == .draw || _past.last.type == .erase,
      'Accidental stroke is not a draw',
    );
    assert(
      _past.last.type != .draw || _past.last.strokes.length == 1,
      'Accidental strokes should be single-stroke',
    );
    assert(
      _past.last.images.isEmpty,
      'Accidental strokes should not contain images',
    );
    return _past.removeLast();
  }

  /// Returns true if there is something to undo.
  bool get canUndo {
    return _past.isNotEmpty;
  }

  /// Returns true if there is something to redo.
  bool get canRedo {
    return _isRedoPossible && _future.isNotEmpty;
  }

  set canRedo(bool isRedoPossible) {
    _isRedoPossible = isRedoPossible;
  }

  void clearRedo() {
    _future.clear();
  }
}

class EditorHistoryItem {
  new({
    required this.type,
    required this.pageIndex,
    required this.strokes,
    required this.images,
    this.offset,
    this.page,
    this.quillChange,
    this.colorChange,
    this.backgroundPatternChange,
    this.strokeListChange,
    this.imageRectChange,
    this.fillChange,
    this.linkChange,
  }) : assert(
         type != .move || offset != null,
         'Offset must be provided for move',
       ),
       assert(
         type != .deletePage || page != null,
         'Page must be provided for deletePage',
       ),
       assert(
         type != .insertPage || page != null,
         'Page must be provided for insertPage',
       ),
       assert(
         type != .quillChange || quillChange != null,
         'Quill change must be provided for quillChange',
       ),
       assert(
         type != .quillUndoneChange || quillChange != null,
         'Quill change must be provided for quillUndoneChange',
       ),
       assert(
         type != .changeColor || colorChange?.length == strokes.length,
         'colorChange must be provided and contain each of strokes',
       ),
       assert(
         type != .backgroundPattern || backgroundPatternChange != null,
         'Background pattern change must be provided for backgroundPattern',
       ),
       assert(
         type != .partialErase || strokeListChange != null,
         'Stroke list change must be provided for partialErase',
       ),
       assert(
         type != .fillChange || fillChange?.length == strokes.length,
         'fillChange must be provided and contain each of strokes',
       ),
       assert(
         type != .links || linkChange != null,
         'Link change must be provided for links',
       );

  final EditorHistoryItemType type;
  final int pageIndex;
  final List<Stroke> strokes;
  final List<EditorImage> images;
  final Rect? offset;
  final EditorPage? page;
  final DocChange? quillChange;
  final Map<Stroke, Change<Color>>? colorChange;
  final Change<CanvasBackgroundPattern>? backgroundPatternChange;
  final StrokeListChange? strokeListChange;

  /// With [strokeListChange]: images that were resized with the strokes.
  final Map<EditorImage, Change<Rect>>? imageRectChange;
  final Map<Stroke, Change<Color?>>? fillChange;

  /// The page's links before and after.
  final Change<List<PageLink>>? linkChange;

  EditorHistoryItem copyWith({
    EditorHistoryItemType? type,
    int? pageIndex,
    List<Stroke>? strokes,
    List<EditorImage>? images,
    Rect? offset,
    EditorPage? page,
    DocChange? quillChange,
    Map<Stroke, Change<Color>>? colorChange,
    Change<CanvasBackgroundPattern>? backgroundPatternChange,
    StrokeListChange? strokeListChange,
    Map<EditorImage, Change<Rect>>? imageRectChange,
    Map<Stroke, Change<Color?>>? fillChange,
    Change<List<PageLink>>? linkChange,
  }) {
    return EditorHistoryItem(
      type: type ?? this.type,
      pageIndex: pageIndex ?? this.pageIndex,
      strokes: strokes ?? this.strokes,
      images: images ?? this.images,
      offset: offset ?? this.offset,
      page: page ?? this.page,
      quillChange: quillChange ?? this.quillChange,
      colorChange: colorChange ?? this.colorChange,
      backgroundPatternChange:
          backgroundPatternChange ?? this.backgroundPatternChange,
      strokeListChange: strokeListChange ?? this.strokeListChange,
      imageRectChange: imageRectChange ?? this.imageRectChange,
      fillChange: fillChange ?? this.fillChange,
      linkChange: linkChange ?? this.linkChange,
    );
  }
}

enum EditorHistoryItemType {
  draw,
  erase,
  deletePage,
  insertPage,
  move,
  quillChange,
  quillUndoneChange,
  changeColor,
  backgroundPattern,

  /// Strokes on one page were replaced by others, see [StrokeListChange]:
  /// partly erased, or resized and rotated (maybe with images, see
  /// [EditorHistoryItem.imageRectChange]).
  partialErase,

  /// Closed strokes were filled, see [EditorHistoryItem.fillChange].
  fillChange,

  /// A page's links changed, see [EditorHistoryItem.linkChange].
  links,
}

/// A change to a page's stroke list: the [removed] strokes were
/// replaced by the [added] strokes.
///
/// Each removed stroke is paired with its index in the list before the
/// change, and each added stroke with its index in the list after it,
/// so the change can be undone without changing the strokes' order.
class StrokeListChange {
  const new({required this.removed, required this.added});

  /// Sorted by index.
  final List<(int, Stroke)> removed, added;

  StrokeListChange reverse() =>
      StrokeListChange(removed: added, added: removed);

  /// Applies this change to [strokes], which should be as before the change.
  void apply(List<Stroke> strokes) {
    final toRemove = {for (final (_, stroke) in removed) stroke};
    strokes.removeWhere(toRemove.contains);
    for (final (i, stroke) in added) {
      strokes.insert(min(i, strokes.length), stroke);
    }
  }
}
