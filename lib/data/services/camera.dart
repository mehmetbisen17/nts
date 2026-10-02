import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/data/editor/editor_history.dart';
import 'package:nts/data/services/editor_commit.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:path/path.dart' as p;

abstract final class Camera {
  static final log = Logger('Camera');

  /// image_picker only opens the camera on iOS and Android.
  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

  /// Takes a photo and puts it on the page in view.
  static Future<void> takePhoto(EditorState editor) async {
    if (editor.coreInfo.readOnly) return;
    final XFile? photo;
    try {
      photo = await ImagePicker().pickImage(source: .camera);
    } on PlatformException catch (e) {
      // e.g. camera_access_denied after "Don't Allow"
      log.warning('No camera: $e');
      if (!editor.mounted) return;
      ScaffoldMessenger.maybeOf(editor.context)?.showSnackBar(
        SnackBar(content: Text(t.editor.otherTools.cameraFailed)),
      );
      return;
    }
    if (photo == null || !editor.mounted) return;
    final extension = p.extension(photo.name);
    addPhoto(
      editor,
      await photo.readAsBytes(),
      extension: extension.isEmpty ? '.jpg' : extension,
    );
  }

  /// Adds a photo like the image button does: undoable, and with the
  /// lasso tool so it can be moved. On [pageIndex], else the page in view.
  static void addPhoto(
    EditorState editor,
    Uint8List bytes, {
    required String extension,
    int? pageIndex,
  }) {
    final coreInfo = editor.coreInfo;
    pageIndex ??= editor.currentPageIndex;
    final image = PngEditorImage(
      id: coreInfo.nextImageId++,
      extension: extension,
      imageProvider: MemoryImage(bytes),
      pageIndex: pageIndex,
      pageSize: coreInfo.pages[pageIndex].size,
      onMoveImage: editor.onMoveImage,
      onDeleteImage: editor.onDeleteImage,
      onMiscChange: editor.autosaveUnrecordedChange,
      assetCache: coreInfo.assetCache,
    );
    editor.currentTool = Select.currentSelect;
    editor.commit(
      EditorHistoryItem(
        type: .draw,
        pageIndex: pageIndex,
        strokes: const [],
        images: [image],
      ),
    );
  }
}
