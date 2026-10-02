import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nts/components/canvas/_asset_cache.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/data/editor/editor_history.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/services/editor_commit.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:sbn/has_size.dart';

/// What was copied with the lasso: copies of the strokes, and the images as
/// they're saved in a note (json plus their bytes), so they can be pasted
/// into any note even after the original changes.
typedef SelectionClip = ({
  List<Stroke> strokes,
  List<Map<String, dynamic>> images,
  List<Uint8List> assets,
  Path path,
});

/// The lasso's cut/copy/paste clipboard.
///
/// ponytail: in memory only, so it's empty after the app restarts and other
/// apps can't paste it. Put it on the system clipboard as a custom format if
/// that's needed.
abstract final class SelectionClipboard {
  static final content = ValueNotifier<SelectionClip?>(null);

  /// Whether [content] was copied since the app last lost focus, so another
  /// app can't have put something newer on the system clipboard.
  static var isNewest = false;
  static AppLifecycleListener? _lifecycle;

  /// Down and right a bit, and further for each paste.
  static const pasteOffset = Offset(25, 25);
  static var _pastes = 0;

  static Future<void> copy(SelectResult selection, EditorPage page) async {
    final assets = OrderedAssetCache();
    final images = [for (final image in selection.images) image.toJson(assets)];
    content.value = (
      strokes: [
        for (final stroke in selection.strokes)
          // don't keep the page alive
          stroke.copy()..page = HasSize(page.size),
      ],
      images: images,
      assets: [
        for (var i = 0; i < assets.length; i++)
          Uint8List.fromList(await assets.getBytes(i)),
      ],
      path: selection.path.shift(Offset.zero),
    );
    _pastes = 0;
    isNewest = true;
    _lifecycle ??= AppLifecycleListener(onInactive: () => isNewest = false);
  }

  /// Pastes onto [pageIndex] (the page in view if null), centered on [at]
  /// if given (e.g. where a right-click was), and selects what was pasted.
  static void paste(EditorState editor, {int? pageIndex, Offset? at}) {
    final clip = content.value;
    final coreInfo = editor.coreInfo;
    if (clip == null || coreInfo.readOnly) return;

    pageIndex ??= editor.currentPageIndex;
    final page = coreInfo.pages[pageIndex];
    final offset = at != null
        ? at - clip.path.getBounds().center
        : pasteOffset * (++_pastes).toDouble();

    final strokes = [
      for (final stroke in clip.strokes)
        stroke.copy()
          ..pageIndex = pageIndex
          ..page = page
          ..shift(offset),
    ];
    final images = [
      for (final json in clip.images)
        EditorImage.fromJson(
            {
              ...json,
              'i': pageIndex,
              'x': (json['x'] as num) + offset.dx,
              'y': (json['y'] as num) + offset.dy,
            },
            inlineAssets: clip.assets,
            sbnPath: coreInfo.filePath,
            assetCache: coreInfo.assetCache,
          )
          ..id = coreInfo.nextImageId++
          ..onMoveImage = editor.onMoveImage
          ..onDeleteImage = editor.onDeleteImage
          ..onMiscChange = editor.autosaveAfterDelay,
    ];

    editor.commit(
      EditorHistoryItem(
        type: .draw,
        pageIndex: pageIndex,
        strokes: strokes,
        images: images,
      ),
    );

    // Select it so it can be moved straight away
    editor.currentTool = Select.currentSelect;
    Select.currentSelect
      ..selectResult = SelectResult(
        pageIndex: pageIndex,
        strokes: strokes,
        images: images,
        path: clip.path.shift(offset),
      )
      ..doneSelecting = true;
  }
}
