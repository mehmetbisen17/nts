import 'package:nts/data/editor/editor_history.dart';
import 'package:nts/pages/editor/editor.dart';

extension EditorCommit on EditorState {
  /// Records [item] (a draw or erase) in the undo history and applies it,
  /// then rebuilds and autosaves.
  ///
  /// It's applied like [EditorState.redo] does: `undo(item)` applies the
  /// opposite of an item without touching the history.
  void commit(EditorHistoryItem item) {
    history.recordChange(item);
    undo(
      item.copyWith(
        type: switch (item.type) {
          .draw => .erase,
          .erase => .draw,
          _ => throw UnsupportedError('commit(${item.type})'),
        },
      ),
    );
  }
}
