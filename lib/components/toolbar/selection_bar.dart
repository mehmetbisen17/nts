import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/ai/ai_menu.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/toolbar/floating_bar.dart';
import 'package:nts/components/toolbar/toolbar_button.dart';
import 'package:nts/data/editor/editor_history.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/services/editor_commit.dart';
import 'package:nts/data/services/handwriting.dart';
import 'package:nts/data/services/selection_clipboard.dart';
import 'package:nts/data/services/selection_image.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// The lasso's actions, next to the toolbar once something is selected.
class SelectionBar extends StatelessWidget {
  final VoidCallback duplicateSelection;
  final VoidCallback deleteSelection;

  /// The toolbar's axis.
  final Axis axis;

  const new({
    super.key,
    required this.duplicateSelection,
    required this.deleteSelection,
    this.axis = .horizontal,
  });

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.all(2);
    final editor = context.findAncestorStateOfType<EditorState>();
    final selection = Select.currentSelect.selectResult;
    final editable = editor != null && !editor.coreInfo.readOnly;

    return ValueListenableBuilder(
      valueListenable: SelectionClipboard.content,
      // Two rows (or columns) where one doesn't fit, e.g. on phones
      builder: (context, clip, _) => Wrap(
        direction: axis,
        alignment: .center,
        children: [
          ToolbarIconButton(
            onPressed: duplicateSelection,
            tooltip: t.editor.selectionBar.duplicate,
            padding: padding,
            child: const Icon(Symbols.library_add),
          ),
          if (editor != null) ...[
            ToolbarIconButton(
              tooltip: t.editor.otherTools.copy,
              enabled: !selection.isEmpty,
              onPressed: () => SelectionActions.copy(editor),
              padding: padding,
              child: const Icon(Symbols.content_copy),
            ),
            ToolbarIconButton(
              tooltip: t.editor.otherTools.cut,
              enabled: editable && !selection.isEmpty,
              onPressed: () => SelectionActions.cut(editor),
              padding: padding,
              child: const Icon(Symbols.content_cut),
            ),
            if (clip != null)
              ToolbarIconButton(
                tooltip: t.editor.otherTools.paste,
                enabled: editable,
                onPressed: () => SelectionClipboard.paste(editor),
                padding: padding,
                child: const Icon(Symbols.content_paste),
              ),
            Builder(
              builder: (context) => ToolbarIconButton(
                tooltip: t.editor.otherTools.screenshot,
                onPressed: () => SelectionActions.screenshot(context, editor),
                padding: padding,
                child: const Icon(Symbols.screenshot_region),
              ),
            ),
            if (Handwriting.isSupported)
              Builder(
                builder: (context) => ToolbarIconButton(
                  tooltip: t.editor.otherTools.handwriting,
                  enabled: Handwriting.inkOf(selection.strokes).isNotEmpty,
                  onPressed: () =>
                      SelectionActions.handwriting(context, editor),
                  padding: padding,
                  child: const Icon(Symbols.convert_to_text),
                ),
              ),
            // The menu itself says if no AI account is signed in
            Builder(
              builder: (context) => ToolbarIconButton(
                tooltip: t.ai.askAi,
                enabled: !selection.isEmpty,
                onPressed: () => showAiMenu(context, editor),
                padding: padding,
                child: const Icon(Symbols.auto_awesome),
              ),
            ),
          ],
          if (editor != null)
            ToolbarIconButton(
              tooltip: t.editor.canvasTools.addLink,
              enabled: editable && !selection.isEmpty,
              onPressed: editor.editSelectionLink,
              padding: padding,
              child: const Icon(Symbols.add_link),
            ),
          ToolbarIconButton(
            onPressed: deleteSelection,
            tooltip: t.editor.selectionBar.delete,
            padding: padding,
            child: const Icon(Symbols.delete),
          ),
        ],
      ),
    );
  }
}

/// What the selection bar and the toolbar's lasso buttons (see
/// `ToolCatalog`) do with the lasso's selection.
abstract final class SelectionActions {
  static final log = Logger('SelectionActions');

  /// The lasso's selection, if [tool] is the lasso and it's done selecting.
  static SelectResult? selectionOf(Tool tool) {
    final select = Select.currentSelect;
    return tool == select && select.doneSelecting ? select.selectResult : null;
  }

  static Future<void> copy(EditorState editor) async {
    final selection = selectionOf(editor.currentTool);
    if (selection == null || selection.isEmpty) return;
    await SelectionClipboard.copy(
      selection,
      editor.coreInfo.pages[selection.pageIndex],
    );
  }

  static Future<void> cut(EditorState editor) async {
    final selection = selectionOf(editor.currentTool);
    if (selection == null || selection.isEmpty) return;
    await copy(editor);
    if (!editor.mounted) return;
    editor.commit(
      EditorHistoryItem(
        type: .erase,
        pageIndex: selection.pageIndex,
        strokes: selection.strokes,
        images: selection.images,
      ),
    );
  }

  /// Offers to copy or save the selected area as an image,
  /// in a menu at [at] (global), or else at [context]'s button.
  static Future<void> screenshot(
    BuildContext context,
    EditorState editor, {
    Offset? at,
  }) => _menu(
    context,
    at: at,
    title: t.editor.otherTools.screenshot,
    actions: [
      if (SystemClipboard.instance != null)
        (
          t.editor.otherTools.copyImage,
          (messenger) async {
            final png = await _screenshot(editor);
            if (png == null) return;
            await SystemClipboard.instance!.write([
              DataWriterItem()..add(Formats.png(png)),
            ]);
            _snack(messenger, t.editor.otherTools.imageCopied);
          },
        ),
      (
        t.editor.otherTools.saveImage,
        (_) async {
          final png = await _screenshot(editor);
          if (png == null || !context.mounted) return;
          await FileManager.exportFile(
            // unique, since saving to the gallery skips existing names
            '${editor.coreInfo.fileName} '
            '${DateTime.now().millisecondsSinceEpoch}.png',
            png,
            isImage: true,
            context: context,
          );
        },
      ),
    ],
  );

  static Future<Uint8List?> _screenshot(EditorState editor) async {
    final selection = selectionOf(editor.currentTool);
    if (selection == null) return null;
    return pageAreaPng(
      editor.coreInfo,
      selection.pageIndex,
      selectionBounds(selection),
    );
  }

  /// Offers to copy the selected handwriting as text,
  /// or to replace it with typed text (see [screenshot] for [at]).
  static Future<void> handwriting(
    BuildContext context,
    EditorState editor, {
    Offset? at,
  }) {
    final selection = selectionOf(editor.currentTool);
    if (selection == null) return Future.value();
    final ink = Handwriting.inkOf(selection.strokes);
    return _menu(
      context,
      at: at,
      title: t.editor.otherTools.handwriting,
      actions: [
        (
          t.editor.otherTools.copyAsText,
          (messenger) async {
            final text = await _recognize(ink, messenger);
            if (text == null) return;
            await Clipboard.setData(ClipboardData(text: text));
            _snack(messenger, t.editor.otherTools.textCopied(text: text));
          },
        ),
        if (!editor.coreInfo.readOnly)
          (
            t.editor.otherTools.convertToText,
            (messenger) async {
              final text = await _recognize(ink, messenger);
              if (text == null || !editor.mounted) return;
              convertToText(editor, selection.pageIndex, ink, text);
            },
          ),
      ],
    );
  }

  /// Adds [text] to the end of the page's typed text, and erases [ink].
  /// These are two steps in the undo history.
  static void convertToText(
    EditorState editor,
    int pageIndex,
    List<Stroke> ink,
    String text,
  ) {
    addText(editor, pageIndex, text);
    editor.commit(
      EditorHistoryItem(
        type: .erase,
        pageIndex: pageIndex,
        strokes: ink,
        images: const [],
      ),
    );
  }

  /// Adds [text] to the end of the page's typed text (undoable).
  static void addText(EditorState editor, int pageIndex, String text) {
    final controller = editor.coreInfo.pages[pageIndex].quill.controller;
    final document = controller.document;
    controller.replaceText(
      document.length - 1, // before the last newline
      0,
      document.isEmpty() ? text : '\n$text',
      null,
      ignoreFocus: true,
    );
  }

  static Future<String?> _recognize(
    List<Stroke> ink,
    ScaffoldMessengerState? messenger,
  ) async {
    try {
      final text = await Handwriting.recognize(ink);
      if (text.isNotEmpty) return text;
      _snack(messenger, t.editor.otherTools.noHandwriting);
    } on Exception catch (e, st) {
      log.warning('Failed to recognize handwriting', e, st);
      _snack(messenger, t.editor.otherTools.handwritingFailed);
    }
    return null;
  }

  /// A menu at [at], or else at the button that [context] belongs to.
  static Future<void> _menu(
    BuildContext context, {
    Offset? at,
    required String title,
    required List<(String, void Function(ScaffoldMessengerState?))> actions,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final box = context.findRenderObject()! as RenderBox;
    return showBarMenu(
      context,
      at ?? box.localToGlobal(box.size.center(Offset.zero)),
      title: title,
      actions: [
        for (final (label, onSelected) in actions)
          (label, () => onSelected(messenger)),
      ],
    );
  }

  static void _snack(ScaffoldMessengerState? messenger, String message) =>
      messenger?.showSnackBar(SnackBar(content: Text(message)));
}
