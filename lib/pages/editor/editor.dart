import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:collapsible/collapsible.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as flutter_quill;
import 'package:keybinder/keybinder.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/ai/ai_menu.dart';
import 'package:nts/components/canvas/_asset_cache.dart';
import 'package:nts/components/canvas/_canvas_painter.dart';
import 'package:nts/components/canvas/_circle_stroke.dart';
import 'package:nts/components/canvas/_rectangle_stroke.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/canvas.dart';
import 'package:nts/components/canvas/canvas_gesture_detector.dart';
import 'package:nts/components/canvas/canvas_image.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/components/canvas/inner_canvas.dart';
import 'package:nts/components/canvas/link_dialog.dart';
import 'package:nts/components/canvas/ruler.dart';
import 'package:nts/components/canvas/save_indicator.dart';
import 'package:nts/components/canvas/text_boxes.dart';
import 'package:nts/components/editor/read_only_banner.dart';
import 'package:nts/components/navbar/responsive_navbar.dart';
import 'package:nts/components/theming/adaptive_alert_dialog.dart';
import 'package:nts/components/theming/dynamic_material_app.dart';
import 'package:nts/components/theming/higan/higan_lily.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/components/toolbar/color_bar.dart';
import 'package:nts/components/toolbar/editor_bottom_sheet.dart';
import 'package:nts/components/toolbar/editor_page_manager.dart';
import 'package:nts/components/toolbar/floating_bar.dart';
import 'package:nts/components/toolbar/selection_bar.dart';
import 'package:nts/components/toolbar/toolbar.dart';
import 'package:nts/components/toolbar/top_bar.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/editor/editor_exporter.dart';
import 'package:nts/data/editor/editor_history.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/extensions/change_notifier_extensions.dart';
import 'package:nts/data/extensions/matrix4_extensions.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/is_this_a_test.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/services/handwriting.dart';
import 'package:nts/data/services/selection_clipboard.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/data/tools/calligraphy_pen.dart';
import 'package:nts/data/tools/eraser.dart';
import 'package:nts/data/tools/fill.dart';
import 'package:nts/data/tools/highlighter.dart';
import 'package:nts/data/tools/insert_space.dart';
import 'package:nts/data/tools/laser_pointer.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/pencil.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/data/tools/shape_pen.dart';
import 'package:nts/data/tools/tape.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/flashcard_study.dart';
import 'package:nts/pages/home/whiteboard.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:sbn/change.dart';
import 'package:sbn/tool_id.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:url_launcher/url_launcher.dart';

typedef _PhotoInfo = ({Uint8List bytes, String extension});

class Editor extends StatefulWidget {
  new({
    super.key,
    String? path,
    this.embedded = false,
    this.pdfPath,
    this.noteType,
  }) : initialPath = path != null
           ? Future.value(path)
           : FileManager.newFilePath('/'),
       needsNaming = path == null;

  /// The kind of note to make, if it's new.
  final NoteType? noteType;

  final Future<String> initialPath;
  final bool needsNaming;

  /// The whiteboard tab, under the home shell's header: no back button or
  /// title of its own, and the shell's gutters.
  final bool embedded;
  final String? pdfPath;

  /// The file extension used by the app.
  /// Files with this extension are
  /// encoded in BSON format.
  static const extension = '.sbn2';

  /// The old file extension used by the app.
  /// Files with this extension are
  /// encoded in JSON format.
  static const extensionOldJson = '.sbn';

  static const double gapBetweenPages = 16;

  /// Control, or Command on a Mac, for keyboard shortcuts:
  /// either works on any platform.
  static const ctrlOrCmd = KeyCode({
    0x00200000100, 0x00200000101, // controlLeft, controlRight
    0x00200000106, 0x00200000107, // metaLeft, metaRight
  }, label: 'ctrl');

  /// Returns true if [path] belongs to a hidden file
  /// used by other functions of the app
  static bool isReservedPath(String path) {
    return _reservedFilePaths.any((regex) => regex.hasMatch(path));
  }

  static final _reservedFilePaths = <RegExp>[
    RegExp(RegExp.escape(Whiteboard.filePath)),
  ];

  /// Whether the platform can rasterize a pdf
  static var canRasterPdf = true;

  @override
  State<Editor> createState() => EditorState();
}

class EditorState extends State<Editor> {
  final log = Logger('EditorState');

  late var coreInfo = EditorCoreInfo.placeholder;

  final _canvasGestureDetectorKey = GlobalKey<CanvasGestureDetectorState>();
  final _transformationController = TransformationController();

  /// The area below the header where the toolbar and top bar can be moved.
  final _barAreaKey = GlobalKey();
  late final _toolbarBar = FloatingBar(
    'toolbar',
    areaKey: _barAreaKey,
    turns: true,
  );
  late final _topBarBar = FloatingBar('topBar', areaKey: _barAreaKey);

  double get scrollY {
    final transformation = _transformationController.value;
    final scale = transformation.approxScale;
    final translation = transformation.getTranslation();
    final gestureDetector = _canvasGestureDetectorKey.currentState;

    if (gestureDetector == null) {
      log.warning('scrollY: Could not find CanvasGestureDetectorState');
      return translation.y / scale;
    } else {
      final middle = gestureDetector.containerBounds.maxHeight / 2;
      return (translation.y - middle) / scale + middle;
    }
  }

  var history = EditorHistory();

  late bool needsNaming = widget.needsNaming && stows.editorPromptRename.value;

  late Tool _currentTool = () {
    switch (stows.lastTool.value) {
      case .fountainPen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = Pen.fountainPen();
        }
        return Pen.currentPen;
      case .ballpointPen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = Pen.ballpointPen();
        }
        return Pen.currentPen;
      case .shapePen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = ShapePen();
        }
        return Pen.currentPen;
      case .brushPen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = Pen.brushPen();
        }
        return Pen.currentPen;
      case .calligraphyPen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = CalligraphyPen();
        }
        return Pen.currentPen;
      case .tape:
        return Tape.currentTape;
      case .fill:
        return Fill.currentFill;
      case .insertSpace:
        return InsertSpace.currentInsertSpace;
      case .highlighter:
        return Highlighter.currentHighlighter;
      case .pencil:
        return Pencil.currentPencil;
      case .textEditing:
        return Tool.textEditing;
      // On a computer, opening a note with these makes the pen look broken
      // (they're no longer saved there, but may have been before)
      case .eraser || .select || .laserPointer when _isComputer:
        return Pen.currentPen;
      case .eraser:
        return Eraser();
      case .select:
        return Select.currentSelect;
      case .laserPointer:
        return LaserPointer.currentLaserPointer;
    }
  }();
  Tool get currentTool => _currentTool;
  set currentTool(Tool tool) {
    _currentTool = tool;
    AiMenu.lassoArmed = false; // "Ask AI" lasts until the next tool
    if (tool is! Eraser) _lastNonEraserTool = tool;
    // On a computer, notes open with the last tool that writes,
    // see [_currentTool]
    if (!_isComputer ||
        (tool is! Eraser && tool is! Select && tool is! LaserPointer)) {
      stows.lastTool.value = tool.toolId;
    }
  }

  /// A Mac, Windows or Linux, where the mouse is the pen. Not an iPad or
  /// Android tablet, whose mouse and trackpad follow "Draw with finger".
  static bool get _isComputer => switch (defaultTargetPlatform) {
    .macOS || .windows || .linux => true,
    .iOS || .android || .fuchsia => false,
  };

  ValueNotifier<SavingState> savingState = ValueNotifier(SavingState.saved);
  Timer? _delayedSaveTimer;

  /// The note file's last modified time when we loaded or last saved it
  /// (null if it didn't exist), to notice when iCloud Drive replaced it
  /// with another device's version.
  DateTime? _fileLastModified;
  static DateTime? _lastModifiedOf(String filePath) {
    final file = FileManager.getFile(filePath + Editor.extension);
    return file.existsSync() ? file.lastModifiedSync() : null;
  }

  // used to prevent accidentally drawing when pinch zooming
  var lastSeenPointerCount = 0;
  Timer? _lastSeenPointerCountTimer;

  ValueNotifier<QuillStruct?> quillFocus = ValueNotifier(null);

  /// The last non-Eraser [currentTool] value.
  late Tool _lastNonEraserTool = Pen.currentPen;

  /// If the stylus button is pressed, or was pressed, during the current draw gesture.
  ///
  /// For now, this also includes when an [PointerDeviceKind.inverseStylus] is
  /// used since the stylus rear-end and stylus button currently act the same.
  /// If we add customized button bindings, we may have to separate this again.
  var stylusButtonWasPressed = false;

  /// The page shown in the header's readout, following the canvas.
  final _readoutPageIndex = ValueNotifier(0);
  void _onTransformChanged() {
    void update() {
      if (mounted) _readoutPageIndex.value = currentPageIndex;
    }

    // The canvas can move while it's being laid out
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => update());
    } else {
      update();
    }
  }

  /// Saves when the app is put away or quit, before the autosave delay.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    _lifecycle = AppLifecycleListener(
      onHide: () => unawaited(saveToFile()),
      onExitRequested: () async {
        // (The note is written first; the thumbnail after it can wait)
        await saveToFile().timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
        return .exit;
      },
    );
    DynamicMaterialApp.addFullscreenListener(_setState);
    _transformationController.addListener(_onTransformChanged);

    _initAsync();
    _assignKeybindings();
    HardwareKeyboard.instance.addHandler(_onKey);

    super.initState();
  }

  /// Running just after the editor opens, when the mouse doesn't draw:
  /// the second click of a double-click that opened the note lands here.
  final _opening = Timer(const Duration(milliseconds: 500), () {});

  void _initAsync() async {
    final filePath = await widget.initialPath;
    filenameTextEditingController.text = p.basename(filePath);

    if (needsNaming) {
      filenameTextEditingController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: filenameTextEditingController.text.length,
      );
    }

    await _loadCoreInfo(filePath);

    if (widget.pdfPath != null) {
      await importPdfFromFilePath(widget.pdfPath!);
    }
  }

  Future _loadCoreInfo(String filePath) async {
    // Before reading, so a version arriving meanwhile counts as a change
    _fileLastModified = _lastModifiedOf(filePath);
    coreInfo = await EditorCoreInfo.loadFromFilePath(filePath);
    if (coreInfo.readOnly) {
      log.info('Loaded file as read-only: ${coreInfo.readOnlyReason}');
    }

    for (int pageIndex = 0; pageIndex < coreInfo.pages.length; pageIndex++) {
      listenToQuillChanges(coreInfo.pages[pageIndex].quill, pageIndex);
    }

    // A new note of the kind asked for
    // A new note (or an empty one, like a cleared whiteboard tab) of the
    // kind asked for
    final newType = widget.noteType;
    if (newType != null &&
        coreInfo.noteType != newType &&
        coreInfo.isEmpty &&
        !coreInfo.readOnly) {
      coreInfo.noteType = newType;
      coreInfo.pages = [];
    }

    if (coreInfo.isEmpty) {
      createPage(-1);
    } else {
      for (final page in coreInfo.pages) {
        page.backgroundImage?.onMoveImage = onMoveImage;
        page.backgroundImage?.onDeleteImage = onDeleteImage;
        page.backgroundImage?.onMiscChange = autosaveUnrecordedChange;
        for (final image in page.images) {
          image.onMoveImage = onMoveImage;
          image.onDeleteImage = onDeleteImage;
          image.onMiscChange = autosaveUnrecordedChange;
        }
      }
    }

    if (coreInfo.filePath == Whiteboard.filePath &&
        stows.autoClearWhiteboardOnExit.value &&
        Whiteboard.needsToAutoClearWhiteboard) {
      // clear whiteboard (and add to history)
      clearAllPages();

      // save cleared whiteboard
      await saveToFile();
      Whiteboard.needsToAutoClearWhiteboard = false;
    } else {
      setState(() {});
    }
  }

  void _setState() => setState(() {});

  Keybinding? _ctrlZ, _ctrlY, _ctrlShiftZ;
  void _assignKeybindings() {
    _ctrlZ = Keybinding([
      Editor.ctrlOrCmd,
      KeyCode.from(LogicalKeyboardKey.keyZ),
    ], inclusive: true);
    _ctrlY = Keybinding([
      Editor.ctrlOrCmd,
      KeyCode.from(LogicalKeyboardKey.keyY),
    ], inclusive: true);
    _ctrlShiftZ = Keybinding([
      Editor.ctrlOrCmd,
      KeyCode.shift,
      KeyCode.from(LogicalKeyboardKey.keyZ),
    ], inclusive: true);
    // Ctrl+Z matches Ctrl+Shift+Z too, which would undo and then redo.
    // Text (the note's, or a text field like its name) has its own undo.
    Keybinder.bind(_ctrlZ!, () {
      if (!HardwareKeyboard.instance.isShiftPressed && !_isTyping) undo();
    });
    void redoUnlessTyping() {
      if (!_isTyping) redo();
    }

    Keybinder.bind(_ctrlY!, redoUnlessTyping);
    Keybinder.bind(_ctrlShiftZ!, redoUnlessTyping);
  }

  void _removeKeybindings() {
    if (_ctrlZ != null) Keybinder.remove(_ctrlZ!);
    if (_ctrlY != null) Keybinder.remove(_ctrlY!);
    if (_ctrlShiftZ != null) Keybinder.remove(_ctrlShiftZ!);
  }

  /// Creates pages until the given page index exists,
  /// plus an extra blank page (or card, see [EditorCoreInfo.addBlankEnd]).
  /// An endless page grows instead.
  void createPage(int pageIndex) {
    final type = coreInfo.noteType;
    if (type.singlePage) {
      if (coreInfo.pages.isEmpty) _addPage(coreInfo.newPage());
      if (type == .endless) coreInfo.pages.first.growToFit();
      return;
    }
    while (type != .flashcards && pageIndex >= coreInfo.pages.length - 1) {
      _addPage(coreInfo.newPage());
    }
    // A blank card after the card that was written on
    if (type == .flashcards) {
      if (coreInfo.pages.length.isOdd) _addPage(coreInfo.newPage());
      final card = pageIndex < 0 ? -1 : pageIndex ~/ 2;
      while (card >= coreInfo.pages.length ~/ 2 - 1) {
        _addPage(coreInfo.newPage());
        _addPage(coreInfo.newPage());
      }
    }
  }

  void _addPage(EditorPage page) {
    coreInfo.pages.add(page);
    listenToQuillChanges(page.quill, coreInfo.pages.length - 1);
  }

  void removeExcessPages() {
    if (coreInfo.noteType.singlePage) return;
    if (coreInfo.noteType == .flashcards) return _removeExcessCards();
    bool removedAPage = false;

    // remove excess pages if all pages >= this one are empty
    for (int i = coreInfo.pages.length - 1; i >= 1; --i) {
      final thisPage = coreInfo.pages[i];
      final prevPage = coreInfo.pages[i - 1];
      if (thisPage.isEmpty && prevPage.isEmpty) {
        final page = coreInfo.pages.removeAt(i);
        page.dispose();
        removedAPage = true;
      } else {
        break;
      }
    }

    if (removedAPage) {
      // scroll to the last page (only if we're below the last page)

      final scrollY = this.scrollY;
      late final topOfLastPage = -CanvasGestureDetector.getTopOfPage(
        pageIndex: coreInfo.pages.length - 1,
        pages: coreInfo.pages,
        screenWidth: MediaQuery.sizeOf(context).width,
      );
      final bottomOfLastPage = -CanvasGestureDetector.getTopOfPage(
        pageIndex: coreInfo.pages.length,
        pages: coreInfo.pages,
        screenWidth: MediaQuery.sizeOf(context).width,
      );

      if (scrollY < bottomOfLastPage) {
        _transformationController.value = Matrix4.translationValues(
          0,
          // Slight upwards offset so that the page is not flush with the top of the screen
          topOfLastPage + 50,
          0,
        );
      }
    }
  }

  /// Like [removeExcessPages] for flashcards: leaves one blank card at
  /// the end.
  void _removeExcessCards() {
    final pages = coreInfo.pages;
    bool cardIsEmpty(int end) =>
        pages[end - 1].isEmpty && pages[end - 2].isEmpty;
    while (pages.length >= 4 &&
        pages.length.isEven &&
        cardIsEmpty(pages.length) &&
        cardIsEmpty(pages.length - 2)) {
      pages.removeLast().dispose();
      pages.removeLast().dispose();
    }
  }

  void undo([EditorHistoryItem? item]) {
    final byUser = item == null;
    if (item == null) {
      // Typing in a text box is recorded first, so it's what's undone
      _commitTextBox();
      if (!history.canUndo) return;

      // if we disabled redo, re-enable it
      if (!history.canRedo) {
        // no redo is possible, so clear the redo stack
        history.clearRedo();
        // don't disable redoing anymore
        history.canRedo = true;
      }

      item = history.undo();
    }

    setState(() {
      switch (item!.type) {
        case .draw:
          for (final stroke in item.strokes) {
            coreInfo.pages[stroke.pageIndex].strokes.remove(stroke);
          }
          for (final image in item.images) {
            coreInfo.pages[image.pageIndex].images.remove(image);
          }
          removeExcessPages();

        case .erase:
          for (final stroke in item.strokes) {
            createPage(stroke.pageIndex);
            coreInfo.pages[stroke.pageIndex].insertStroke(stroke);
          }
          for (final image in item.images) {
            createPage(image.pageIndex);
            coreInfo.pages[image.pageIndex].images.add(image);
            image.newImage = true;
          }

        case .partialErase:
          createPage(item.pageIndex);
          final page = coreInfo.pages[item.pageIndex];
          item.strokeListChange!.reverse().apply(page.strokes);
          item.imageRectChange?.forEach(
            (image, change) => image.dstRect = change.previous,
          );
          page.redrawStrokes();
          removeExcessPages();

        case .fillChange:
          for (final stroke in item.strokes) {
            stroke.fillColor = item.fillChange![stroke]!.previous;
          }
          coreInfo.pages[item.pageIndex].redrawStrokes();

        case .links:
          createPage(item.pageIndex);
          coreInfo.pages[item.pageIndex]
            ..links = item.linkChange!.previous
            ..redrawStrokes();

        case .textBoxes:
          createPage(item.pageIndex);
          coreInfo.pages[item.pageIndex].textBoxes =
              item.textBoxChange!.previous;

        case .deletePage:
          // A card comes back half at a time, with an odd page count
          // in between, which createPage would pad with an extra page.
          // (Trailing blank cards may have been trimmed since.)
          final cards = coreInfo.noteType == .flashcards;
          // make sure we already have a (blank/otherwise) page at this index
          if (!cards) createPage(item.pageIndex - 1);
          final at = cards
              ? min(item.pageIndex, coreInfo.pages.length)
              : item.pageIndex;

          // insert the page at the correct index
          coreInfo.pages.insert(at, item.page!);

          // fix the page indices of all pages after this one
          for (int i = at; i < coreInfo.pages.length; ++i) {
            final page = coreInfo.pages[i];
            page.updatePageIndex(i);
          }

        case .insertPage:
          // remove the page at the given index
          coreInfo.pages.removeAt(item.pageIndex);

          // fix the page indices of all pages after this one
          for (int i = item.pageIndex; i < coreInfo.pages.length; ++i) {
            final page = coreInfo.pages[i];
            page.updatePageIndex(i);
          }

        case .move:
          for (final stroke in item.strokes) {
            stroke.shift(Offset(-item.offset!.left, -item.offset!.top));
          }
          final select = Select.currentSelect;
          if (select.doneSelecting) {
            select.selectResult.path = select.selectResult.path.shift(
              Offset(-item.offset!.left, -item.offset!.top),
            );
          }
          for (final image in item.images) {
            image.dstRect = .fromLTRB(
              image.dstRect.left - item.offset!.left,
              image.dstRect.top - item.offset!.top,
              image.dstRect.right - item.offset!.right,
              image.dstRect.bottom - item.offset!.bottom,
            );
          }
        // (Text boxes moved with it are restored below)

        case .quillChange:
          final quill = coreInfo.pages[item.pageIndex].quill;
          quill.controller.undo();

        case .quillUndoneChange:
          final quill = coreInfo.pages[item.pageIndex].quill;
          quill.controller.redo();

        case .changeColor:
          for (final stroke in item.strokes) {
            stroke.color = item.colorChange![stroke]!.previous;
          }

        case .backgroundPattern:
          coreInfo.backgroundPattern = item.backgroundPatternChange!.previous;
      }

      // Text boxes deleted, added or moved along with ink (e.g. with the
      // lasso, or by clearing a page)
      if (item.type != .textBoxes && item.textBoxChange != null) {
        final page = coreInfo.pages[item.pageIndex];
        page.textBoxes = item.textBoxChange!.previous;
        final select = Select.currentSelect;
        if (item.type == .move && select.doneSelecting) {
          final ids = {for (final box in select.selectResult.textBoxes) box.id};
          select.selectResult.textBoxes = [
            for (final box in page.textBoxes)
              if (ids.contains(box.id)) box,
          ];
        }
      }

      if (item.type != .move) {
        Select.currentSelect.unselect();
      }
    });

    autosaveAfterDelay();

    // A flashcard is added or removed as its front and back: undo both
    if (byUser && _halfACard(history.canUndo ? history.peekUndo() : null)) {
      undo();
    }
  }

  /// Whether a card was only half added or removed, and [next] (the next
  /// step in the history) is its other half.
  bool _halfACard(EditorHistoryItem? next) =>
      coreInfo.noteType == .flashcards &&
      coreInfo.pages.length.isOdd &&
      (next?.type == .insertPage || next?.type == .deletePage);

  void redo() {
    _commitTextBox();
    if (!history.canRedo) return;
    final item = history.redo();
    // (See [_halfACard])
    void redoTheOtherHalf() {
      if (_halfACard(history.canRedo ? history.peekRedo() : null)) redo();
    }

    // Text boxes that changed along with ink go forward again
    final textBoxes = item.textBoxChange?.reverse();
    switch (item.type) {
      case .draw:
        undo(item.copyWith(type: .erase, textBoxChange: textBoxes));
      case .erase:
        undo(item.copyWith(type: .draw, textBoxChange: textBoxes));
      case .deletePage:
        undo(item.copyWith(type: .insertPage));
        redoTheOtherHalf();
      case .insertPage:
        undo(item.copyWith(type: .deletePage));
        redoTheOtherHalf();
      case .move:
        undo(
          item.copyWith(
            offset: .fromLTRB(
              -item.offset!.left,
              -item.offset!.top,
              -item.offset!.right,
              -item.offset!.bottom,
            ),
            textBoxChange: textBoxes,
          ),
        );
      case .quillChange:
        undo(item.copyWith(type: .quillUndoneChange));
      case .quillUndoneChange: // this will never happen
        throw Exception('history should not contain quillUndoneChange items');
      case .changeColor:
        undo(
          item.copyWith(
            colorChange: item.colorChange!.map(
              (key, value) => MapEntry(key, value.reverse()),
            ),
          ),
        );
      case .backgroundPattern:
        undo(
          item.copyWith(
            backgroundPatternChange: item.backgroundPatternChange!.reverse(),
          ),
        );
      case .partialErase:
        undo(
          item.copyWith(
            strokeListChange: item.strokeListChange!.reverse(),
            imageRectChange: item.imageRectChange?.map(
              (image, change) => MapEntry(image, change.reverse()),
            ),
          ),
        );
      case .fillChange:
        undo(
          item.copyWith(
            fillChange: item.fillChange!.map(
              (stroke, change) => MapEntry(stroke, change.reverse()),
            ),
          ),
        );
      case .links:
        undo(item.copyWith(linkChange: item.linkChange!.reverse()));
      case .textBoxes:
        undo(item.copyWith(textBoxChange: item.textBoxChange!.reverse()));
    }
  }

  /// The page at [focalPoint], counting the space beside it
  /// (see [EditorPage.areaWithSides]).
  int? onWhichPageIsFocalPoint(Offset focalPoint) {
    for (int i = 0; i < coreInfo.pages.length; ++i) {
      if (coreInfo.pages[i].renderBox == null) continue;
      if (coreInfo.pages[i].areaWithSides.contains(
        coreInfo.pages[i].renderBox!.globalToLocal(focalPoint),
      ))
        return i;
    }
    return null;
  }

  /// The position of the previous draw gesture event.
  /// Used to move a selection.
  Offset previousPosition = .zero;

  /// The total offset of the current move gesture.
  /// Used to record a move in the history.
  Offset moveOffset = .zero;

  var isHovering = true;
  int? dragPageIndex;
  PointerDeviceKind? currentPointerKind;
  double? currentPressure;

  /// The current pointer's buttons, e.g. [kPrimaryMouseButton].
  var currentPointerButtons = 0;

  /// Whether Space is held (and not typed): then dragging pans,
  /// like the hand tool in design apps.
  bool get _spaceHeld =>
      HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.space) &&
      !_isTyping;

  bool isDrawGesture(ScaleStartDetails details) {
    if (coreInfo.readOnly) return false;

    CanvasImage.activeListener
        .notifyListenersPlease(); // un-select active image

    _lastSeenPointerCountTimer?.cancel();
    if (lastSeenPointerCount >= 2) {
      // was a zoom gesture, ignore
      lastSeenPointerCount = lastSeenPointerCount;
      return false;
    } else if (details.pointerCount >= 2) {
      // is a zoom gesture, remove accidental stroke
      if (lastSeenPointerCount == 1 &&
          _drawRecorded &&
          stows.editorFingerDrawing.value &&
          (currentTool is Pen || currentTool is Eraser)) {
        final item = history.removeAccidentalStroke();
        if (item != null) undo(item);
      }
      lastSeenPointerCount = details.pointerCount;
      return false;
    } else {
      // is a stroke
      lastSeenPointerCount = details.pointerCount;
    }

    dragPageIndex = onWhichPageIsFocalPoint(details.focalPoint);
    if (dragPageIndex == null) return false;

    if (currentTool == Tool.textEditing || _spaceHeld) {
      return false;
    } else if (currentPointerKind == PointerDeviceKind.mouse && _isComputer) {
      // On a computer, the mouse (and a trackpad's click) is like a stylus:
      // finger drawing is for touch screens. Its other buttons pan.
      return currentPointerButtons == kPrimaryMouseButton && !_opening.isActive;
    } else if (stows.editorFingerDrawing.value ||
        currentPointerKind == PointerDeviceKind.stylus ||
        currentPointerKind == PointerDeviceKind.invertedStylus ||
        currentPressure != null) {
      return true;
    } else {
      log.fine('Non-stylus found, rejected stroke');
      return false;
    }
  }

  /// Where the current draw gesture started, to tell taps from drags.
  var _drawStartFocalPoint = Offset.zero;
  var _drawIsTap = true;

  /// Where the last pointer went down, which is where a draw gesture
  /// really started if it had to move before it was accepted.
  Offset? _pointerDownPosition;

  /// Whether the last draw gesture added to the history,
  /// so a pinch that follows it can take it back.
  var _drawRecorded = false;

  /// Taps move less than this, in logical pixels.
  static const _tapSlop = 4.0;

  /// The on-screen ruler, or null when it's hidden.
  final ruler = ValueNotifier<RulerPosition?>(null);
  final _rulerKey = GlobalKey();
  RenderBox? get _rulerBox =>
      _rulerKey.currentContext?.findRenderObject() as RenderBox?;

  /// The ruler edge the current pen stroke follows (see [RulerSnapping]).
  int? _rulerEdge;

  void toggleRuler() {
    if (ruler.value != null) {
      ruler.value = null;
    } else {
      final size = _rulerBox?.size ?? MediaQuery.sizeOf(context);
      ruler.value = (center: size.center(Offset.zero), angle: 0);
    }
  }

  /// [focalPoint] moved onto the ruler edge the stroke follows, if any.
  Offset _snapToRuler(Offset focalPoint) {
    final edge = _rulerEdge, ruler = this.ruler.value, box = _rulerBox;
    if (edge == null || ruler == null || box == null) return focalPoint;
    return box.localToGlobal(ruler.snap(box.globalToLocal(focalPoint), edge));
  }

  void onDrawStart(ScaleStartDetails details) {
    final page = coreInfo.pages[dragPageIndex!];
    _drawStartFocalPoint = details.focalPoint;
    _drawIsTap = true;
    _drawRecorded = false;
    _rulerEdge = null;
    if ((ruler.value, _rulerBox) case (final ruler?, final box?)
        when currentTool is Pen) {
      _rulerEdge = ruler.edgeNear(box.globalToLocal(details.focalPoint));
    }
    Pen.followsRuler = _rulerEdge != null;
    final position = page.renderBox!.globalToLocal(
      _snapToRuler(details.focalPoint),
    );
    history.canRedo = false;

    if (currentTool is Pen) {
      (currentTool as Pen).onDragStart(
        position,
        page,
        dragPageIndex!,
        currentPressure,
      );
    } else if (currentTool is Eraser) {
      (currentTool as Eraser).erase(position, page.strokes);
    } else if (currentTool is Select) {
      final select = currentTool as Select;
      final onSelectedPage =
          select.doneSelecting &&
          select.selectResult.pageIndex == dragPageIndex!;
      // Where the pointer went down, since the gesture may have moved
      // before it started (e.g. on an image, which also takes taps)
      final down = page.renderBox!.globalToLocal(
        _pointerDownPosition ?? details.focalPoint,
      );
      if (onSelectedPage && select.startTransform(down, page.strokes)) {
        // resize or rotate the selection in onDrawUpdate
      } else if (onSelectedPage &&
          select.selectResult.path.contains(position)) {
        // drag selection in onDrawUpdate
        _textBoxesBeforeMove = page.textBoxes;
      } else {
        select.onDragStart(position, dragPageIndex!);
        history.canRedo = true; // selection doesn't affect history
      }
    } else if (currentTool is LaserPointer) {
      (currentTool as LaserPointer).onDragStart(position, page, dragPageIndex!);
    } else if (currentTool case final CanvasTool tool) {
      tool.onDrawStart(_canvasToolInput(page, position));
    }

    previousPosition = position;
    moveOffset = .zero;

    if (currentTool is! Select) {
      Select.currentSelect.unselect();
    }

    // setState to let canvas know about currentStroke
    setState(() {});
  }

  void onDrawUpdate(ScaleUpdateDetails details) {
    final page = coreInfo.pages[dragPageIndex!];
    final position = page.renderBox!.globalToLocal(
      _snapToRuler(details.focalPoint),
    );
    final offset = position - previousPosition;
    if ((details.focalPoint - _drawStartFocalPoint).distance > _tapSlop) {
      _drawIsTap = false;
    }

    if (currentTool is Pen) {
      // Just the first point and this one
      if (_straightLine) Pen.currentStroke?.keepFirstPoint();
      (currentTool as Pen).onDragUpdate(position, currentPressure);
      page.redrawStrokes();
    } else if (currentTool is Eraser) {
      // Only repainted when something was erased
      if ((currentTool as Eraser).erase(
        position,
        page.strokes,
        from: previousPosition,
      )) {
        page.redrawStrokes();
      }
    } else if (currentTool is Select) {
      final select = currentTool as Select;
      if (select.isTransforming) {
        select.updateTransform(position, page.strokes);
      } else if (select.doneSelecting) {
        for (final stroke in select.selectResult.strokes) {
          stroke.shift(offset);
        }
        for (final image in select.selectResult.images) {
          image.dstRect = image.dstRect.shift(offset);
        }
        _shiftSelectedTextBoxes(page, offset);
        select.selectResult.path = select.selectResult.path.shift(offset);
      } else {
        select.onDragUpdate(position);
      }
      page.redrawStrokes();
    } else if (currentTool is LaserPointer) {
      (currentTool as LaserPointer).onDragUpdate(position);
      page.redrawStrokes();
    } else if (currentTool case final CanvasTool tool) {
      tool.onDrawUpdate(_canvasToolInput(page, position));
      page.redrawStrokes();
    }
    previousPosition = position;
    moveOffset += offset;
  }

  void onDrawEnd(ScaleEndDetails details) {
    final page = coreInfo.pages[dragPageIndex!];
    bool shouldSave = true;
    var askAi = false;
    setState(() {
      if (currentTool is Pen) {
        // Shift means a straight line, not the shape it would snap to
        if (_straightLine) Pen.snapPreview = null;
        final newStroke = (currentTool as Pen).onDragEnd();
        if (newStroke == null) return;
        if (newStroke.isEmpty) return;

        // Tapping a tape shows or hides what's under it
        if (currentTool is Tape && _drawIsTap) {
          if (Tape.tapeAt(page, previousPosition) case final tape?) {
            Tape.toggle(page, tape);
            shouldSave = false;
            history.canRedo = true;
            return;
          }
        }

        if (stows.scribbleToErase.value &&
            _canScribbleToErase.contains(newStroke.toolId) &&
            newStroke.isScribble()) {
          final erased = Eraser.strokesUnderScribble(newStroke, page.strokes);
          if (erased.isNotEmpty) {
            final erasedSet = erased.toSet();
            page.strokes.removeWhere(erasedSet.contains);
            history.recordChange(
              EditorHistoryItem(
                type: .erase,
                pageIndex: dragPageIndex!,
                strokes: erased,
                images: [],
              ),
            );
            _drawRecorded = true;
            removeExcessPages();
            return;
          }
        }

        // (Not along the ruler: it's straight already, and snapping it
        // level would pull it off the ruler)
        if (_rulerEdge == null &&
            newStroke is! CircleStroke &&
            newStroke is! RectangleStroke &&
            (_straightLine
                ? newStroke.length > 1
                : stows.autoStraightenLines.value &&
                      currentTool is! ShapePen &&
                      newStroke.isStraightLine())) {
          newStroke.convertToLine();
        }

        createPage(newStroke.pageIndex);
        page.insertStroke(newStroke);
        history.recordChange(
          EditorHistoryItem(
            type: .draw,
            pageIndex: dragPageIndex!,
            strokes: [newStroke],
            images: [],
          ),
        );
        _drawRecorded = true;
      } else if (currentTool is Eraser) {
        final item = (currentTool as Eraser).finishDrag(dragPageIndex!);
        // Not mid-drag, which could remove the page being erased
        removeExcessPages();
        if (stylusButtonWasPressed || stows.disableEraserAfterUse.value) {
          // restore previous tool
          stylusButtonWasPressed = false;
          currentTool = _lastNonEraserTool;
        }
        if (item == null) return;
        history.recordChange(item);
        _drawRecorded = true;
      } else if (currentTool is Select) {
        final select = currentTool as Select;
        if (select.isTransforming) {
          final item = select.finishTransform(dragPageIndex!, page.strokes);
          if (item == null) {
            shouldSave = false;
            history.canRedo = true;
          } else {
            history.recordChange(item);
          }
          return;
        }
        if (!select.doneSelecting &&
            _drawIsTap &&
            _tapLinkOrTape(page, previousPosition)) {
          shouldSave = false;
          select.unselect();
          return;
        }
        if (select.doneSelecting) {
          // A lasso that closes where it started also adds up to zero
          if (moveOffset == .zero) return;
          final textBoxesBefore = _textBoxesBeforeMove;
          _textBoxesBeforeMove = null;
          history.recordChange(
            EditorHistoryItem(
              type: .move,
              pageIndex: dragPageIndex!,
              strokes: select.selectResult.strokes,
              images: select.selectResult.images,
              offset: .fromLTRB(
                moveOffset.dx,
                moveOffset.dy,
                moveOffset.dx,
                moveOffset.dy,
              ),
              textBoxChange:
                  textBoxesBefore == null ||
                      select.selectResult.textBoxes.isEmpty
                  ? null
                  : Change(previous: textBoxesBefore, current: page.textBoxes),
            ),
          );
        } else {
          shouldSave = false;
          select.onDragEnd(page.strokes, page.images, page.textBoxes);

          // "Ask AI" also reads imported pages and typed text, or says
          // there's nothing to read
          askAi = AiMenu.lassoArmed && !_drawIsTap;
          if (select.selectResult.isEmpty && !askAi) {
            Select.currentSelect.unselect();
          }
        }
      } else if (currentTool is LaserPointer) {
        shouldSave = false;
        if (_drawIsTap) _tapLinkOrTape(page, previousPosition);
        final newStroke = (currentTool as LaserPointer).onDragEnd(
          page.redrawStrokes,
          (Stroke stroke) {
            page.laserStrokes.remove(stroke);
          },
        );
        if (newStroke != null) page.laserStrokes.add(newStroke);
      } else if (currentTool case final CanvasTool tool) {
        final item = tool.onDrawEnd(_canvasToolInput(page, previousPosition));
        page.redrawStrokes();
        if (item == null) {
          shouldSave = false;
        } else {
          history.recordChange(item);
        }
      }
    });

    if (askAi) unawaited(_askAi());
    if (shouldSave) autosaveAfterDelay();
  }

  /// The AI menu for the "Ask AI" lasso. A lasso that selected nothing
  /// was only for the AI, so it goes when the AI is done.
  Future<void> _askAi() async {
    await showAiMenu(context, this);
    final select = Select.currentSelect;
    if (mounted && select.doneSelecting && select.selectResult.isEmpty) {
      setState(select.unselect);
    }
  }

  /// Whether the pen draws a straight line: Shift is held,
  /// as in design apps. (The shape pen makes its own shapes.)
  bool get _straightLine =>
      HardwareKeyboard.instance.isShiftPressed && currentTool is! ShapePen;

  /// The pens whose scribbles can erase (see [Stows.scribbleToErase]).
  static const _canScribbleToErase = {
    ToolId.fountainPen,
    ToolId.ballpointPen,
    ToolId.pencil,
    ToolId.brushPen,
    ToolId.calligraphyPen,
  };

  /// Opens the link, or shows or hides the tape, at [position] on [page].
  /// Returns whether there was one.
  bool _tapLinkOrTape(EditorPage page, Offset position) {
    for (final link in page.links.reversed) {
      if (!link.rect.contains(position)) continue;
      unawaited(_openLink(link));
      return true;
    }
    if (Tape.tapeAt(page, position) case final tape?) {
      Tape.toggle(page, tape);
      return true;
    }
    return false;
  }

  /// Ends typing in a text box now (see [TextBoxes.commit]), so the undo
  /// history has it before anything else changes.
  static void _commitTextBox() {
    final commit = TextBoxes.commit;
    TextBoxes.commit = null;
    commit?.call();
  }

  /// Replaces [pageIndex]'s text boxes while they're typed in or moved.
  void _editTextBoxes(int pageIndex, List<PageTextBox> boxes) {
    if (coreInfo.readOnly) return;
    coreInfo.pages[pageIndex].textBoxes = boxes;
    createPage(pageIndex); // e.g. so an endless page grows
    _setStateSoon();
    // Saved while typing, before it's in the history
    history.markUnrecordedChange();
    autosaveAfterDelay();
  }

  /// Makes the change to [pageIndex]'s text boxes since [before]
  /// one step in the undo history.
  void _recordTextBoxes(int pageIndex, List<PageTextBox> before) {
    final page = coreInfo.pages.elementAtOrNull(pageIndex);
    if (page == null || listEquals(before, page.textBoxes)) return;
    history.recordChange(
      EditorHistoryItem(
        type: .textBoxes,
        pageIndex: pageIndex,
        strokes: const [],
        images: const [],
        textBoxChange: Change(previous: before, current: page.textBoxes),
      ),
    );
    _setStateSoon();
    autosaveAfterDelay();
  }

  /// [setState], after this frame if it's being built (e.g. when a text
  /// box finishes as the Text tool is put down).
  void _setStateSoon() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  /// Pans the canvas so [rect] (in global coordinates) isn't under the
  /// keyboard or off the top or bottom of the canvas, e.g. a text box
  /// being typed in. (A text field would scroll itself into view, but the
  /// canvas isn't a scrolling list.)
  void _revealGlobalRect(Rect rect) {
    final box =
        _canvasGestureDetectorKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (!mounted || box == null || !box.attached) return;
    const margin = 24.0;
    final canvas = box.localToGlobal(Offset.zero) & box.size;
    final keyboardTop =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final bottom = min(canvas.bottom, keyboardTop) - margin;
    final top = canvas.top + margin;
    double shift(double low, double high, double start, double end) {
      var by = 0.0;
      if (end > high) by = high - end;
      if (start + by < low) by = low - start;
      return by;
    }

    final dx = shift(
      canvas.left + margin,
      canvas.right - margin,
      rect.left,
      rect.right,
    );
    final dy = shift(top, bottom, rect.top, rect.bottom);
    if (dx.abs() < 1 && dy.abs() < 1) return;
    _transformationController.value =
        Matrix4.translationValues(dx, dy, 0) * _transformationController.value;
  }

  /// With the Text tool, a tap on a page (or beside it) starts a text box
  /// there. (A tap on a box goes to the box.)
  void _onTextTap(TapUpDetails details) {
    final pageIndex = onWhichPageIsFocalPoint(details.globalPosition);
    if (pageIndex == null) return;
    addTextBox(
      pageIndex,
      coreInfo.pages[pageIndex].renderBox!.globalToLocal(
        details.globalPosition,
      ),
    );
  }

  /// Adds a text box with [text] on [pageIndex] (with its first line
  /// centred on [at]), to type in straight away if [text] is empty.
  /// Kept on the page, or beside it if [at] is.
  PageTextBox addTextBox(
    int pageIndex,
    Offset at, {
    String text = '',
    double? width,
    bool atTopLeft = false,
  }) {
    final page = coreInfo.pages[pageIndex];
    // A fresh id, even if the box being typed in is about to go away
    final id = PageTextBox.nextId(page.textBoxes);
    // The box being typed in is finished first, as its own undo step
    _commitTextBox();
    final area = _areaAt(page, at.dx);
    final before = page.textBoxes;
    const fontSize = PageTextBox.defaultFontSize;
    final boxWidth = min(
      width ?? TextBoxes.newWidth,
      max(PageTextBox.minWidth, area.right - area.left),
    );
    final draft = PageTextBox(
      id: id,
      position: .zero,
      width: boxWidth,
      text: text,
      fontSize: fontSize,
      color: TextBoxes.color,
    );
    // On the page, top to bottom (an endless page grows instead)
    final height = TextBoxes.boundsOf(draft).height;
    final y = atTopLeft
        ? at.dy
        : at.dy - fontSize * PageTextBox.lineSpacing / 2;
    final box = draft.copyWith(
      position: Offset(
        at.dx.clamp(area.left, max(area.left, area.right - boxWidth)),
        coreInfo.noteType == .endless
            ? max(0, y)
            : y.clamp(0, max(0, page.size.height - height)),
      ),
    );
    if (text.isEmpty) {
      TextBoxes.pending = (pageIndex: pageIndex, id: box.id, before: before);
    }
    _editTextBoxes(pageIndex, [...before, box]);
    if (text.isNotEmpty) _recordTextBoxes(pageIndex, before);
    return box;
  }

  /// Recolours the text box being typed in, if any. (Part of its typing,
  /// as one undo step.)
  void _recolorTextBox(Color color) {
    final focused = TextBoxes.focused.value;
    if (focused == null) return; // the colour for the next box
    final (pageIndex, id) = focused;
    final page = coreInfo.pages.elementAtOrNull(pageIndex);
    if (page == null) return;
    _editTextBoxes(pageIndex, [
      for (final box in page.textBoxes)
        if (box.id == id) box.copyWith(color: color) else box,
    ]);
  }

  /// Taps in read-only notes, which can't draw.
  void _onReadOnlyTap(TapUpDetails details) {
    final pageIndex = onWhichPageIsFocalPoint(details.globalPosition);
    if (pageIndex == null) return;
    final page = coreInfo.pages[pageIndex];
    _tapLinkOrTape(page, page.renderBox!.globalToLocal(details.globalPosition));
  }

  Future<void> _openLink(PageLink link) async {
    if (link.pageIndex case final pageIndex?) {
      if (pageIndex >= coreInfo.pages.length) return;
      CanvasGestureDetector.scrollToPage(
        pageIndex: pageIndex,
        pages: coreInfo.pages,
        screenWidth: MediaQuery.sizeOf(context).width,
        transformationController: _transformationController,
      );
      return;
    }
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(link.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      log.warning('Failed to open ${link.url}', e);
    }
    if (!opened && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(t.editor.canvasTools.couldNotOpenLink(url: link.url)),
        ),
      );
    }
  }

  /// Adds a link to the selection, or changes or removes its link.
  Future<void> editSelectionLink() async {
    final select = Select.currentSelect;
    final bounds = select.selectionBounds;
    if (coreInfo.readOnly || !select.doneSelecting || bounds == null) return;
    final pageIndex = select.selectResult.pageIndex;
    final page = coreInfo.pages[pageIndex];
    final existing = page.links
        .where((link) => link.rect.overlaps(bounds))
        .lastOrNull;

    final url = await showDialog<String>(
      context: context,
      builder: (context) =>
          LinkDialog(initial: existing?.url, pageCount: coreInfo.pages.length),
    );
    if (url == null || !mounted) return;

    final change = Change(
      previous: page.links,
      current: [
        for (final link in page.links)
          if (link != existing) link,
        if (url.isNotEmpty) PageLink(bounds, url),
      ],
    );
    setState(() {
      page.links = change.current;
      history.recordChange(
        EditorHistoryItem(
          type: .links,
          pageIndex: pageIndex,
          strokes: const [],
          images: const [],
          linkChange: change,
        ),
      );
    });
    page.redrawStrokes();
    autosaveAfterDelay();
  }

  /// Logical pixels per page unit on [page] at the current zoom.
  double _pixelsPerUnit(EditorPage page) {
    final width =
        _canvasGestureDetectorKey.currentState?.containerBounds.maxWidth ??
        MediaQuery.sizeOf(context).width;
    return _transformationController.value.approxScale *
        (page.isBoard ? 1.0 : min(1.0, width / page.size.width));
  }

  CanvasToolInput _canvasToolInput(EditorPage page, Offset position) => (
    page: page,
    pageIndex: dragPageIndex!,
    position: position,
    pressure: currentPressure,
  );

  void onInteractionEnd(ScaleEndDetails details) {
    // reset after 1ms to keep track of the same gesture only
    _lastSeenPointerCountTimer?.cancel();
    _lastSeenPointerCountTimer = Timer(const Duration(milliseconds: 10), () {
      lastSeenPointerCount = 0;
    });
  }

  void updatePointerData(
    PointerDeviceKind kind,
    double? pressure,
    int buttons,
  ) {
    currentPointerKind = kind;
    currentPressure = pressure;
    currentPointerButtons = buttons;
  }

  void onHovering() {
    isHovering = true;
  }

  void onHoveringEnd() {
    isHovering = false;
  }

  void onStylusButtonChanged(bool buttonIsPressed) {
    stylusButtonWasPressed |= buttonIsPressed;

    if (!isHovering) return;
    if (buttonIsPressed) {
      // button pressed while hovering, switch to Eraser
      if (currentTool is! Eraser) {
        currentTool = Eraser();
      }
    } else {
      // button was released while hovering, switch back to non-Eraser
      if (currentTool is Eraser) {
        currentTool = _lastNonEraserTool;
      }
    }

    if (mounted) setState(() {});
  }

  void onMoveImage(EditorImage image, Rect offset) {
    history.recordChange(
      EditorHistoryItem(
        type: .move,
        pageIndex: image.pageIndex,
        strokes: [],
        images: [image],
        offset: offset,
      ),
    );
    // setState to update undo button
    setState(() {});
    autosaveAfterDelay();
  }

  void onDeleteImage(EditorImage image) {
    history.recordChange(
      EditorHistoryItem(
        type: .erase,
        pageIndex: image.pageIndex,
        strokes: [],
        images: [image],
      ),
    );
    setState(() {
      coreInfo.pages[image.pageIndex].images.remove(image);
    });
    autosaveAfterDelay();
  }

  void listenToQuillChanges(QuillStruct quill, int pageIndex) {
    quill.changeSubscription?.cancel();
    quill.changeSubscription = quill.controller.changes.listen((event) {
      final undoRedoButtonsNeedUpdating = !history.canUndo || history.canRedo;
      _addQuillChangeToHistory(
        quill: quill,
        pageIndex: pageIndex,
        event: event,
      );
      createPage(pageIndex); // create empty last page
      if (undoRedoButtonsNeedUpdating) {
        setState(() {});
      }
      autosaveAfterDelay();
    });
    quill.focusNode.addListener(_onQuillFocusChange);
  }

  void _onQuillFocusChange() {
    for (final page in coreInfo.pages) {
      if (!page.quill.focusNode.hasFocus) continue;
      quillFocus.value = page.quill;
    }
  }

  void _addQuillChangeToHistory({
    required QuillStruct quill,
    required int pageIndex,
    required flutter_quill.DocChange event,
  }) {
    final eventWasUndo = quill.controller.hasRedo;
    if (eventWasUndo) return;

    // the change subscription sometimes fires multiple times for the same change
    // so compare the "before" of each change to merge them
    if (history.canUndo && !history.canRedo) {
      final lastChange = history.peekUndo();
      if (lastChange.type == .quillChange &&
          lastChange.pageIndex == pageIndex &&
          lastChange.quillChange!.before == event.before) {
        history.undo(); // remove the last change, to be replaced
      }
    }

    history.recordChange(
      EditorHistoryItem(
        type: .quillChange,
        pageIndex: pageIndex,
        strokes: const [],
        images: const [],
        quillChange: event,
      ),
    );
  }

  void autosaveAfterDelay() {
    // After any change (a stroke, a moved selection or image, inserted
    // space...), an endless page makes room below what's on it
    if (coreInfo.noteType == .endless &&
        coreInfo.pages.isNotEmpty &&
        coreInfo.pages.first.growToFit()) {
      _setStateSoon();
    }
    // (saveToFile checks for changes made meanwhile once its write ends)
    if (savingState.value == .saving) return;
    if (history.isCurrentStateSaved) return cancelAutosaveAndMarkSaved();

    late final void Function() callback;

    void startTimer() {
      _delayedSaveTimer?.cancel();
      if (stows.autosaveDelay.value < 0) return;
      _delayedSaveTimer = Timer(
        Duration(milliseconds: stows.autosaveDelay.value),
        callback,
      );
    }

    callback = () {
      if (Pen.currentStroke != null) {
        // don't save yet if the pen is currently drawing
        startTimer();
        return;
      }
      saveToFile();
    };

    savingState.value = .waitingToSave;
    startTimer();
  }

  /// Autosaves a change that isn't in the undo history (page order, line
  /// spacing, image options...), which [autosaveAfterDelay] alone skips.
  void autosaveUnrecordedChange() {
    history.markUnrecordedChange();
    autosaveAfterDelay();
  }

  void cancelAutosaveAndMarkSaved() {
    _delayedSaveTimer?.cancel();
    savingState.value = .saved;
    history.takeUnrecordedChanges();
    history.markLastChangeAsSaved();
  }

  Future<void> saveToFile() async {
    if (coreInfo.readOnly) return;

    switch (savingState.value) {
      case .saved:
        // avoid saving if nothing has changed
        return;
      case .saving:
        // avoid saving if already saving
        log.warning('saveToFile() called while already saving');
        return;
      case .waitingToSave:
        // continue
        _delayedSaveTimer?.cancel();
        savingState.value = .saving;
    }
    if (history.isCurrentStateSaved) return cancelAutosaveAndMarkSaved();

    await _renameFileNow();

    final lastModified = _lastModifiedOf(coreInfo.filePath);
    if (lastModified != null && lastModified != _fileLastModified) {
      // Another device's version replaced the file since we loaded it:
      // keep it, and save ours as a copy instead of overwriting it.
      log.warning('${coreInfo.filePath} changed on disk, saving a copy');
      coreInfo.filePath = await FileManager.suffixFilePathToMakeItUnique(
        '${coreInfo.filePath} (conflict)',
      );
      filenameTextEditingController.text = coreInfo.fileName;
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(t.icloud.savedAsCopy(name: coreInfo.fileName)),
          ),
        );
      }
    }

    final filePath = coreInfo.filePath + Editor.extension;
    final Uint8List bson;
    final OrderedAssetCache assets;
    coreInfo.assetCache.allowRemovingAssets = false;
    final hadUnrecordedChanges = history.takeUnrecordedChanges();
    final savedChange = history.lastChange;
    try {
      (bson, assets) = coreInfo.saveToBinary(
        currentPageIndex: currentPageIndex,
      );
    } finally {
      coreInfo.assetCache.allowRemovingAssets = true;
    }
    try {
      await Future.wait([
        FileManager.writeFile(filePath, bson, awaitWrite: true).then(
          // ponytail: iCloud replacing the file in the instant between the
          // write and this check goes unnoticed; needs NSFileCoordinator.
          (_) => _fileLastModified = _lastModifiedOf(coreInfo.filePath),
        ),
        for (int i = 0; i < assets.length; ++i)
          assets
              .getBytes(i)
              .then(
                (bytes) => FileManager.writeFile(
                  '$filePath.$i',
                  bytes,
                  awaitWrite: true,
                ),
              ),
        FileManager.removeUnusedAssets(filePath, numAssets: assets.length),
      ]);
      history.markSaved(savedChange, midChange: hadUnrecordedChanges);
      savingState.value = .saved;
      // Changed while writing: save that too
      if (!history.isCurrentStateSaved) autosaveAfterDelay();
    } catch (e, st) {
      log.severe('Failed to save file: $e', e, st);
      if (hadUnrecordedChanges) history.markUnrecordedChange();
      savingState.value = .waitingToSave;
      if (kDebugMode) rethrow;
      return;
    }

    if (!mounted) return;
    final page = coreInfo.pages.first;
    // (A long endless page: just its top)
    final previewHeight = coreInfo.noteType == .endless
        ? min(
            page.previewHeight(lineHeight: coreInfo.lineHeight),
            page.size.width * 1.5,
          )
        : page.previewHeight(lineHeight: coreInfo.lineHeight);
    // A whiteboard's is what's drawn on it, not the whole board
    final area = page.isBoard ? page.contentRect : null;
    final thumbnailSize = area != null
        ? Size(720, 720 * area.height / area.width)
        : Size(720, 720 * previewHeight / page.size.width);
    final thumbnail = await EditorExporter.screenshotPage(
      coreInfo: coreInfo,
      pageIndex: 0,
      rasterizeAllStrokes: true,
      targetSize: thumbnailSize,
      cropHeight: area == null ? previewHeight : null,
      pixelRatio: 1,
      area: area,
    );
    final thumbnailPng = await thumbnail.toByteData(format: .png);
    thumbnail.dispose();
    await FileManager.writeFile(
      // Note that this ends with .sbn2.p
      '$filePath.p',
      thumbnailPng!.buffer.asUint8List(),
      awaitWrite: true,
    );
  }

  late final _filenameFormKey = GlobalKey<FormState>();
  late final filenameTextEditingController = TextEditingController();
  Timer? _renameTimer;
  void renameFile([String? _]) {
    _renameTimer?.cancel();
    _renameTimer = Timer(const Duration(seconds: 5), _renameFileNow);
  }

  Future<void> _renameFileNow() async {
    final newName = filenameTextEditingController.text.trim();
    if (newName == coreInfo.fileName) return;

    if (_filenameFormKey.currentState?.validate() ??
        _validateFilenameTextField(newName) == null) {
      try {
        coreInfo.filePath = await FileManager.moveFile(
          coreInfo.filePath + Editor.extension,
          newName.trim() + Editor.extension,
        );
        coreInfo.filePath = coreInfo.filePath.substring(
          0,
          coreInfo.filePath.lastIndexOf(Editor.extension),
        );
        needsNaming = false;
      } on FileSystemException catch (e) {
        // e.g. an asset is still downloading from iCloud: keep the old name
        log.warning('Failed to rename ${coreInfo.filePath}: $e', e);
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)
              ?.showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }

    final actualName = coreInfo.fileName;
    if (actualName != newName) {
      // update text field if renamed differently
      filenameTextEditingController.value = filenameTextEditingController.value
          .copyWith(
            text: actualName,
            selection: TextSelection.fromPosition(
              TextPosition(offset: actualName.length),
            ),
            composing: TextRange.empty,
          );
    }
  }

  String? _validateFilenameTextField(String? newName) {
    if (newName == null) return null;
    return FileManager.validateFilename(newName);
  }

  void updateColorBar(Color color) {
    if (stows.recentColorsDontSavePresets.value) {
      if (ColorBar.colorPresets.any(
        (colorPreset) => colorPreset.color == color,
      )) {
        return;
      }
    }

    final newColorString = color.toARGB32().toString();

    // migrate from old pref format
    if (stows.recentColorsChronological.value.length !=
        stows.recentColorsPositioned.value.length) {
      log.info(
        'MIGRATING recentColors: ${stows.recentColorsChronological.value.length} vs ${stows.recentColorsPositioned.value.length}',
      );
      stows.recentColorsChronological.value = List.of(
        stows.recentColorsPositioned.value,
      );
    }

    if (stows.pinnedColors.value.contains(newColorString)) {
      // do nothing, color is already pinned
    } else if (stows.recentColorsPositioned.value.contains(newColorString)) {
      // if it's already a recent color, move it to the top
      stows.recentColorsChronological.value.remove(newColorString);
      stows.recentColorsChronological.value.add(newColorString);
      stows.recentColorsChronological.notifyListeners();
    } else {
      if (stows.recentColorsPositioned.value.length >=
          stows.recentColorsLength.value) {
        // if full, replace the oldest color with the new one
        final removedColorString = stows.recentColorsChronological.value
            .removeAt(0);
        stows.recentColorsChronological.value.add(newColorString);
        final int removedColorPosition = stows.recentColorsPositioned.value
            .indexOf(removedColorString);
        stows.recentColorsPositioned.value[removedColorPosition] =
            newColorString;
      } else {
        // if not full, add the new color to the end
        stows.recentColorsChronological.value.add(newColorString);
        stows.recentColorsPositioned.value.insert(0, newColorString);
      }
      stows.recentColorsChronological.notifyListeners();
      stows.recentColorsPositioned.notifyListeners();
    }
  }

  /// Prompts the user to pick photos from their device.
  /// Returns the number of photos picked.
  ///
  /// If [photoInfos] is provided, it will be used instead of the file picker.
  /// They go on [pageIndex] (the page in view if null), at [at] if given.
  Future<int> _pickPhotos({
    List<_PhotoInfo>? photoInfos,
    int? pageIndex,
    Offset? at,
    List<Rect>? dstRects,
  }) async {
    if (coreInfo.readOnly) return 0;

    final currentPageIndex = pageIndex ?? this.currentPageIndex;

    photoInfos ??= await _pickPhotosWithFilePicker();
    photoInfos = [for (final photo in photoInfos) ?await _toJpeg(photo)];
    if (photoInfos.isEmpty || !mounted) return 0;

    // Where it goes: centred on [at] (on the page or beside it), or else
    // in the middle of what's in view
    final page = coreInfo.pages[currentPageIndex];
    at ??= _inViewOn(page);
    dstRects ??= [
      for (final (i, photoInfo) in photoInfos.indexed)
        await placeImage(
          page,
          // Several fan out a little, so they don't hide each other
          at + Offset(i * 24, i * 24),
          photoInfo,
        ),
    ];

    // use the Select tool so that the user can move the new image
    currentTool = Select.currentSelect;

    final images = [
      for (final (i, photoInfo) in photoInfos.indexed)
        if (photoInfo.extension == '.svg')
          SvgEditorImage(
            id: coreInfo.nextImageId++,
            svgString: utf8.decode(photoInfo.bytes),
            svgFile: null,
            pageIndex: currentPageIndex,
            pageSize: coreInfo.pages[currentPageIndex].size,
            dstRect: dstRects[i],
            onMoveImage: onMoveImage,
            onDeleteImage: onDeleteImage,
            onMiscChange: autosaveUnrecordedChange,
            onLoad: () => setState(() {}),
            assetCache: coreInfo.assetCache,
          )
        else
          PngEditorImage(
            id: coreInfo.nextImageId++,
            extension: photoInfo.extension,
            imageProvider: MemoryImage(photoInfo.bytes),
            pageIndex: currentPageIndex,
            pageSize: coreInfo.pages[currentPageIndex].size,
            dstRect: dstRects[i],
            onMoveImage: onMoveImage,
            onDeleteImage: onDeleteImage,
            onMiscChange: autosaveUnrecordedChange,
            onLoad: () => setState(() {}),
            assetCache: coreInfo.assetCache,
          ),
    ];

    history.recordChange(
      EditorHistoryItem(
        type: .draw,
        pageIndex: currentPageIndex,
        strokes: [],
        images: images,
      ),
    );
    createPage(currentPageIndex);
    coreInfo.pages[currentPageIndex].images.addAll(images);
    autosaveAfterDelay();

    return images.length;
  }

  /// The middle of what's in view of [page], on the page (e.g. where an
  /// inserted photo goes, rather than its top corner, which on a
  /// whiteboard is far away).
  Offset _inViewOn(EditorPage page) {
    final canvas =
        _canvasGestureDetectorKey.currentContext?.findRenderObject()
            as RenderBox?;
    final box = page.renderBox;
    if (canvas == null || box == null || !box.attached || !canvas.attached) {
      return page.size.center(Offset.zero);
    }
    final local = box.globalToLocal(
      canvas.localToGlobal(canvas.size.center(Offset.zero)),
    );
    return Offset(
      local.dx.clamp(0, page.size.width),
      local.dy.clamp(0, page.size.height),
    );
  }

  /// Adds an image near [anchor] on [pageIndex]: below it on the page
  /// ([side] 0), or beside the page at its height (-1 left, 1 right), out
  /// of the way of what's there, and scrolls to it.
  Future<void> addImageNear(
    int pageIndex,
    int side,
    Rect anchor,
    Uint8List bytes,
    String extension,
  ) async {
    final page = coreInfo.pages[pageIndex];
    final photo = (bytes: bytes, extension: extension);
    final Rect rect;
    if (side == 0 || page.isBoard) {
      final placed = await placeImage(page, anchor.bottomCenter, photo);
      rect = placed.translate(0, placed.height / 2 + EditorPage.sideGap);
    } else {
      final sized = await placeImage(
        page,
        Offset(side < 0 ? -1 : page.size.width + 1, anchor.top),
        photo,
      );
      rect = spotBeside(page, side, sized.size, anchor.top) & sized.size;
    }
    if (!mounted) return;
    await _pickPhotos(
      photoInfos: [photo],
      pageIndex: pageIndex,
      dstRects: [rect],
    );
    if (!mounted) return;
    setState(() {});
    revealPageRect(pageIndex, rect);
  }

  /// Where an image dropped or pasted at [at] on [page] goes: centred
  /// there and kept inside the area it's in (the page, or the space beside
  /// it), at most [_maxPlacedImage] of its width.
  /// Zero-sized (sized when it loads, see [EditorImage.firstLoad]) if its
  /// size can't be read, e.g. for an svg.
  @visibleForTesting
  static Future<Rect> placeImage(
    EditorPage page,
    Offset at,
    ({Uint8List bytes, String extension}) photoInfo,
  ) async {
    final area = _areaAt(page, at.dx);
    Size natural;
    try {
      if (photoInfo.extension == '.svg') throw const FormatException('svg');
      final buffer = await ui.ImmutableBuffer.fromUint8List(photoInfo.bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      natural = Size(descriptor.width.toDouble(), descriptor.height.toDouble());
      descriptor.dispose();
      buffer.dispose();
    } catch (_) {
      return Rect.fromLTWH(
        at.dx.clamp(area.left, area.right),
        at.dy.clamp(area.top, area.bottom),
        0,
        0,
      );
    }
    // Smaller beside the page, where there's less of it in view
    final most = area.left < 0 || area.left >= page.size.width
        ? _maxPlacedImageBeside
        : _maxPlacedImage;
    final size = EditorImage.resize(
      natural,
      Size(area.width * most, area.height * most),
    );
    final rect = Rect.fromCenter(
      center: at,
      width: size.width,
      height: size.height,
    );
    return rect.shift(
      Offset(
        rect.left < area.left
            ? area.left - rect.left
            : min(0, area.right - rect.right),
        rect.top < area.top
            ? area.top - rect.top
            : min(0, area.bottom - rect.bottom),
      ),
    );
  }

  static const _maxPlacedImage = 0.6, _maxPlacedImageBeside = 0.45;

  /// The page, or the space beside it on the side of [x].
  static Rect _areaAt(EditorPage page, double x) {
    const gap = EditorPage.sideGap;
    final width = page.size.width, height = page.size.height;
    return switch (x) {
      < 0 => Rect.fromLTRB(-page.sideWidth, 0, -gap, height),
      _ when x > width => Rect.fromLTRB(
        width + gap,
        0,
        width + page.sideWidth,
        height,
      ),
      _ => Offset.zero & page.size,
    };
  }

  /// [child], taking images dragged in from other apps (see
  /// [_onPerformDrop]). Not in tests, which have no drag and drop plugin.
  Widget _dropImages({required Widget child}) {
    if (isThisATest) return child;
    return DropRegion(
      // File links too: Finder and Files hand over an image file as its
      // link, and a drag of a kind no region lists never reaches the app
      formats: [..._imageFormats.keys, Formats.fileUri],
      // (Finder and Files may offer an image file as just its link)
      onDropOver: (event) =>
          !coreInfo.readOnly &&
              event.session.items.any(
                (item) =>
                    _imageFormats.keys.any(item.canProvide) ||
                    item.canProvide(Formats.fileUri),
              )
          ? DropOperation.copy
          : DropOperation.none,
      onPerformDrop: _onPerformDrop,
      child: child,
    );
  }

  /// Images dragged in from other apps (e.g. Photos or Safari beside nts
  /// on an iPad, or Finder on a Mac) go where they're dropped: on the page,
  /// or beside it.
  Future<void> _onPerformDrop(PerformDropEvent event) async {
    log.info('Drop at ${event.position.global}');
    if (coreInfo.readOnly) return;
    final global = event.position.global;
    final pageIndex = onWhichPageIsFocalPoint(global) ?? currentPageIndex;
    final box = coreInfo.pages[pageIndex].renderBox;
    final page = coreInfo.pages[pageIndex];
    final local = box == null
        ? page.size.center(Offset.zero)
        : box.globalToLocal(global);
    final at = Offset(
      local.dx.clamp(page.areaWithSides.left, page.areaWithSides.right),
      local.dy.clamp(0, page.size.height),
    );

    // As asked: beside the page, on the side nearest the drop, at its
    // height. (From there it can be dragged onto the page.)
    final side = at.dx < page.size.width / 2 ? -1 : 1;
    final photoInfos = <_PhotoInfo>[];
    await Future.wait([
      for (final item in event.session.items)
        if (item.dataReader case final reader?)
          if (_imageFormats.keys.where(reader.canProvide).firstOrNull
              case final format?)
            _readFile(reader, format).then((photo) {
              if (photo != null) photoInfos.add(photo);
            })
          else if (reader.canProvide(Formats.fileUri))
            _readImageFileUri(reader).then((photo) {
              if (photo != null) photoInfos.add(photo);
            }),
    ]);
    log.info(
      'Dropped ${event.session.items.length} item(s), '
      '${photoInfos.length} image(s)',
    );
    if (!mounted || photoInfos.isEmpty) return;
    if (page.isBoard) {
      // A whiteboard has no sides: where it was dropped
      await _pickPhotos(photoInfos: photoInfos, pageIndex: pageIndex, at: at);
      if (mounted) setState(() {});
      return;
    }
    for (final photo in photoInfos) {
      if (!mounted) return;
      final drawable = await _toJpeg(photo);
      if (drawable == null) continue;
      final sized = await placeImage(
        page,
        Offset(side < 0 ? -1 : page.size.width + 1, at.dy),
        drawable,
      );
      final top = (at.dy - sized.height / 2)
          .clamp(0, max(0, page.size.height - sized.height))
          .toDouble();
      await addImageNear(
        pageIndex,
        side,
        Rect.fromLTWH(at.dx, top, 0, 0),
        drawable.bytes,
        drawable.extension,
      );
    }
  }

  /// The image file that [reader] links to, or null if it isn't one.
  Future<_PhotoInfo?> _readImageFileUri(DataReader reader) {
    final completer = Completer<_PhotoInfo?>();
    final progress = reader.getValue<Uri>(
      Formats.fileUri,
      (uri) async {
        try {
          final path = uri?.toFilePath();
          final extension = path == null || !path.contains('.')
              ? ''
              : path.substring(path.lastIndexOf('.')).toLowerCase();
          final isImage =
              _imageFormats.values.contains(extension) || extension == '.jpg';
          completer.complete(
            isImage
                ? (bytes: await File(path!).readAsBytes(), extension: extension)
                : null,
          );
        } catch (e) {
          log.warning('Could not read a dropped file', e);
          if (!completer.isCompleted) completer.complete(null);
        }
      },
      onError: (e) {
        log.warning('Could not read a dropped file', e);
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    if (progress == null) completer.complete(null);
    return completer.future;
  }

  /// The image [format] from [reader], or null if it's empty or fails.
  Future<_PhotoInfo?> _readFile(DataReader reader, FileFormat format) {
    final completer = Completer<_PhotoInfo?>();
    final progress = reader.getFile(
      format,
      (file) async {
        try {
          final bytes = <int>[];
          await for (final chunk in file.getStream()) {
            bytes.addAll(chunk);
          }
          final name = file.fileName;
          completer.complete(
            bytes.isEmpty
                ? null
                : (
                    bytes: Uint8List.fromList(bytes),
                    extension: name != null && name.contains('.')
                        ? name.substring(name.lastIndexOf('.'))
                        : _imageFormats[format]!,
                  ),
          );
        } catch (e) {
          log.warning('Could not read a dropped image', e);
          if (!completer.isCompleted) completer.complete(null);
        }
      },
      onError: (e) {
        log.warning('Could not read a dropped image', e);
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    if (progress == null) completer.complete(null);
    return completer.future;
  }

  Future<List<_PhotoInfo>> _pickPhotosWithFilePicker() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      // Taken from
      // https://github.com/brendan-duncan/image/blob/main/doc/formats.md
      // (plus .svg)
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'tiff',
        'bmp',
        'tga',
        'ico',
        'pvrtc',
        'svg',
        'webp',
        'psd',
        'exr',
        'heic',
        'heif',
      ],
    );
    if (files.isEmpty) return const [];

    return Future.wait([
      for (final file in files)
        () async {
          final extension = p.extension(file.path ?? file.name);
          if (extension.isEmpty) return null;
          final bytes = await file.readAsBytes();
          return (bytes: bytes, extension: extension);
        }(),
    ]).then((list) => list.nonNulls.toList());
  }

  /// Prompts the user to pick a PDF to import.
  /// Returns whether a PDF was picked.
  Future<bool> importPdf() async {
    if (coreInfo.readOnly) return false;
    if (!Editor.canRasterPdf) return false;
    // A PDF's pages need a note of pages, not one sheet or flashcards
    if (coreInfo.noteType.singlePage || coreInfo.noteType == .flashcards) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(t.nts.noteTypes.pdfNeedsPages)));
      return false;
    }

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null) return false;

    return importPdfFromFilePath(file.path!);
  }

  Future<bool> importPdfFromFilePath(String path) async {
    final pdfDocument = await coreInfo.assetCache.pdfDocumentCache.load(path);

    final emptyPage = coreInfo.pages.removeLast();
    assert(emptyPage.isEmpty);

    for (final pdfPage in pdfDocument.pages) {
      assert(pdfPage.pageNumber >= 1, 'pdfrx page numbers start at 1');

      // resize to [defaultWidth] to keep pen sizes consistent
      final pageSize = Size(
        EditorPage.defaultWidth,
        EditorPage.defaultWidth * pdfPage.height / pdfPage.width,
      );

      final page = EditorPage(
        size: pageSize,
        backgroundImage: PdfEditorImage(
          id: coreInfo.nextImageId++,
          pdfBytes: null,
          pdfFile: File(path),
          pdfPage: pdfPage.pageNumber - 1,
          pageIndex: coreInfo.pages.length,
          pageSize: pageSize,
          naturalSize: pdfPage.size,
          onMoveImage: onMoveImage,
          onDeleteImage: onDeleteImage,
          onMiscChange: autosaveUnrecordedChange,
          onLoad: () => setState(() {}),
          assetCache: coreInfo.assetCache,
        ),
      );
      coreInfo.pages.add(page);
      // TODO(adil192): Group multiple pages into one atomic change
      history.recordChange(
        EditorHistoryItem(
          type: .insertPage,
          pageIndex: coreInfo.pages.length - 1,
          strokes: const [],
          images: const [],
          page: page,
        ),
      );
    }

    coreInfo.pages.add(emptyPage);
    if (mounted) setState(() {});

    autosaveAfterDelay();

    return true;
  }

  /// The image formats [paste] takes from the system clipboard,
  /// and their file extensions.
  static const Map<SimpleFileFormat, String> _imageFormats = {
    Formats.jpeg: '.jpeg',
    Formats.png: '.png',
    Formats.gif: '.gif',
    Formats.tiff: '.tiff',
    Formats.bmp: '.bmp',
    Formats.ico: '.ico',
    Formats.svg: '.svg',
    Formats.webp: '.webp',
    // iPhone and iPad photos: turned into JPEGs (see [_toJpeg])
    Formats.heic: '.heic',
    Formats.heif: '.heif',
  };

  static const _imageChannel = MethodChannel('nts/image');

  /// [photo] as something Flutter can draw: a HEIC or HEIF photo becomes a
  /// JPEG (with Apple's ImageIO, see `ImageChannel` in AppDelegate.swift
  /// and MainFlutterWindow.swift), anything else stays as it is.
  /// Null if it can't be converted.
  static Future<_PhotoInfo?> _toJpeg(_PhotoInfo photo) async {
    final extension = photo.extension.toLowerCase();
    if (extension != '.heic' && extension != '.heif') return photo;
    try {
      final jpeg = await _imageChannel.invokeMethod<Uint8List>(
        'jpeg',
        photo.bytes,
      );
      return jpeg == null ? null : (bytes: jpeg, extension: '.jpeg');
    } catch (e) {
      Logger('EditorState').warning('Could not convert a $extension photo', e);
      return null;
    }
  }

  /// Whether the system clipboard has an image that [paste] can take
  /// (on iOS, whether it might).
  static Future<bool> _clipboardHasImage() async {
    // Reading iOS's pasteboard asks "Allow Paste?", so only [paste] does
    if (Platform.isIOS) return true;
    try {
      final reader = await SystemClipboard.instance?.read();
      return reader != null && _imageFormats.keys.any(reader.canProvide);
    } catch (_) {
      return false; // e.g. no clipboard plugin in tests
    }
  }

  /// Ctrl+V: what was copied with the lasso, or images on the system
  /// clipboard, whichever was copied last. It goes on [pageIndex] (the page
  /// in view if null), at [at] if given (e.g. where a right-click was).
  Future paste({int? pageIndex, Offset? at}) async {
    // Ctrl+V while typing (a text box, the note's name, a link) is the text's
    if (_textFieldFocused) return;
    void pasteSelection() =>
        SelectionClipboard.paste(this, pageIndex: pageIndex, at: at);
    if (SelectionClipboard.isNewest) return pasteSelection();

    const formats = _imageFormats;
    final reader = await SystemClipboard.instance?.read();
    final List<_PhotoInfo> photoInfos = [];
    if (reader == null || !formats.keys.any(reader.canProvide)) {
      return pasteSelection();
    }

    final List<ReadProgress> progresses = [];

    for (final format in formats.keys) {
      if (!reader.canProvide(format)) continue;
      final progress = reader.getFile(format, (file) async {
        final stream = file.getStream();
        final List<int> bytes = [];
        await for (final chunk in stream) {
          bytes.addAll(chunk);
        }
        if (bytes.isEmpty) {
          log.warning('Pasted empty file: $file (${formats[format]})');
          return;
        }

        String extension;
        if (file.fileName != null) {
          extension = file.fileName!.substring(file.fileName!.lastIndexOf('.'));
        } else {
          extension = formats[format]!;
        }

        photoInfos.add((
          bytes: Uint8List.fromList(bytes),
          extension: extension,
        ));
      });
      if (progress != null) progresses.add(progress);
    }

    while (progresses.isNotEmpty) {
      progresses.removeWhere((progress) => progress.fraction.value == 1);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    await _pickPhotos(photoInfos: photoInfos, pageIndex: pageIndex, at: at);
  }

  Future exportAsPdf(BuildContext context) async {
    final pdf = await EditorExporter.generatePdf(coreInfo, context);
    final bytes = await pdf.save();
    if (!context.mounted) return;
    await FileManager.exportFile(
      '${coreInfo.fileName}.pdf',
      bytes,
      context: context,
    );
  }

  /// Exports the current note as an SBA (sbn archive) file.
  Future exportAsSba(BuildContext context) async {
    final sba = await coreInfo.saveToSba(currentPageIndex: currentPageIndex);
    if (!context.mounted) return;
    await FileManager.exportFile(
      '${coreInfo.fileName}.sba',
      Uint8List.fromList(sba),
      context: context,
    );
  }

  /// Exports the current page as a PNG image file.
  ///
  /// This captures the canvas natively via [EditorExporter.screenshotPage],
  /// which guarantees the correct background color and omits UI elements
  /// like selection bounds or the text cursor. It computes a dynamic [pixelRatio]
  /// to ensure high quality while averting Out-Of-Memory exceptions on large canvases.
  Future exportAsPng(BuildContext context) async {
    final page = coreInfo.pages[currentPageIndex];
    // What's drawn on a whiteboard, or the page and what's beside it
    final area = EditorExporter.areaOf(page);

    const maxRasterizableSize = 3000.0;
    var targetPixelRatio =
        maxRasterizableSize / (area?.size ?? page.size).longestSide;
    if (targetPixelRatio > 1) targetPixelRatio = 1;

    try {
      final image = await EditorExporter.screenshotPage(
        coreInfo: coreInfo,
        pageIndex: currentPageIndex,
        rasterizeAllStrokes: true,
        pixelRatio: targetPixelRatio,
        area: area,
      );
      final pngBytes = await image.toByteData(format: .png);
      image.dispose();

      if (!context.mounted) return;
      await FileManager.exportFile(
        '${coreInfo.fileName}_page_${currentPageIndex + 1}.png',
        pngBytes!.buffer.asUint8List(),
        isImage: true,
        context: context,
      );
    } catch (e, st) {
      log.severe('Failed to export PNG', e, st);
    }
  }

  void setTool(Tool tool) {
    if (tool is Eraser && currentTool is Eraser) {
      // setTool(Eraser) is a special case to toggle the eraser on/off
      tool = _lastNonEraserTool;
    }

    currentTool = tool;

    if (tool is Highlighter) {
      Highlighter.currentHighlighter = tool;
    } else if (tool is Pencil) {
      Pencil.currentPencil = tool;
    } else if (tool is Tape) {
      Tape.currentTape = tool;
    } else if (tool is Pen) {
      Pen.currentPen = tool;
    }

    if (mounted) setState(() {});
  }

  /// The Text tool: tap to start a text box, or tap one to type in it.
  void toggleTextEditing() => setState(() {
    currentTool = currentTool == Tool.textEditing
        ? Pen.currentPen
        : Tool.textEditing;
  });

  void duplicateSelection() {
    final select = Select.currentSelect;
    if (currentTool != select || !select.doneSelecting) return;

    setState(() {
      final page = coreInfo.pages[select.selectResult.pageIndex];
      final strokes = select.selectResult.strokes;
      final images = select.selectResult.images;

      const duplicationFeedbackOffset = Offset(25, -25);

      final duplicatedStrokes = strokes.map((stroke) {
        return stroke.copy()..shift(duplicationFeedbackOffset);
      }).toList();

      final duplicatedImages = images.map((image) {
        return image.copy()
          ..id = coreInfo.nextImageId++
          ..dstRect.shift(duplicationFeedbackOffset);
      }).toList();

      page.strokes.addAll(duplicatedStrokes);
      page.images.addAll(duplicatedImages);

      final textBoxesBefore = page.textBoxes;
      var nextId = PageTextBox.nextId(page.textBoxes);
      final duplicatedTextBoxes = [
        for (final box in select.selectResult.textBoxes)
          PageTextBox(
            id: nextId++,
            position: box.position + duplicationFeedbackOffset,
            width: box.width,
            text: box.text,
            fontSize: box.fontSize,
            color: box.color,
          ),
      ];
      page.textBoxes = [...page.textBoxes, ...duplicatedTextBoxes];

      select.selectResult = select.selectResult.copyWith(
        strokes: duplicatedStrokes,
        images: duplicatedImages,
        path: select.selectResult.path.shift(duplicationFeedbackOffset),
        textBoxes: duplicatedTextBoxes,
      );

      history.recordChange(
        EditorHistoryItem(
          type: .draw,
          pageIndex: select.selectResult.pageIndex,
          strokes: duplicatedStrokes,
          images: duplicatedImages,
          textBoxChange: duplicatedTextBoxes.isEmpty
              ? null
              : Change(previous: textBoxesBefore, current: page.textBoxes),
        ),
      );
      autosaveAfterDelay();
    });
  }

  void deleteSelection() {
    final select = Select.currentSelect;
    if (currentTool != select || !select.doneSelecting) return;

    setState(() {
      final pageIndex = select.selectResult.pageIndex;
      final page = coreInfo.pages[pageIndex];
      final strokes = select.selectResult.strokes;
      final images = select.selectResult.images;
      final textBoxIds = {
        for (final box in select.selectResult.textBoxes) box.id,
      };
      final textBoxesBefore = page.textBoxes;

      for (final stroke in strokes) {
        page.strokes.remove(stroke);
      }
      for (final image in images) {
        page.images.remove(image);
      }
      page.textBoxes = [
        for (final box in page.textBoxes)
          if (!textBoxIds.contains(box.id)) box,
      ];

      select.unselect();

      history.recordChange(
        EditorHistoryItem(
          type: .erase,
          pageIndex: pageIndex,
          strokes: strokes,
          images: images,
          textBoxChange: textBoxIds.isEmpty
              ? null
              : Change(previous: textBoxesBefore, current: page.textBoxes),
        ),
      );
      autosaveAfterDelay();
    });
  }

  /// Selects everything on the page in view, or [pageIndex],
  /// with the lasso.
  void selectAll([int? pageIndex]) {
    pageIndex ??= currentPageIndex;
    final page = coreInfo.pages[pageIndex];
    if (page.strokes.isEmpty && page.images.isEmpty && page.textBoxes.isEmpty) {
      return;
    }
    currentTool = Select.currentSelect;
    final select = Select.currentSelect
      ..unselect()
      ..selectResult = SelectResult(
        pageIndex: pageIndex,
        strokes: [...page.strokes],
        images: [...page.images],
        path: Path(),
        textBoxes: page.textBoxes,
      )
      ..doneSelecting = true;
    select.selectResult.path.addRect(select.selectionBounds!.inflate(8));
    setState(() {});
  }

  /// The page's text boxes when the lasso's selection started moving.
  List<PageTextBox>? _textBoxesBeforeMove;

  /// Moves the text boxes in the lasso's selection on [page] by [offset].
  void _shiftSelectedTextBoxes(EditorPage page, Offset offset) {
    final selection = Select.currentSelect.selectResult;
    if (selection.textBoxes.isEmpty) return;
    final ids = {for (final box in selection.textBoxes) box.id};
    page.textBoxes = [
      for (final box in page.textBoxes)
        if (ids.contains(box.id))
          box.copyWith(position: box.position + offset)
        else
          box,
    ];
    selection.textBoxes = [
      for (final box in page.textBoxes)
        if (ids.contains(box.id)) box,
    ];
  }

  /// Moves the lasso's selection by [offset] (in page units, undoably),
  /// e.g. with the arrow keys.
  void moveSelectionBy(Offset offset) {
    final select = Select.currentSelect;
    final selection = select.selectResult;
    final page = coreInfo.pages[selection.pageIndex];
    final textBoxesBefore = page.textBoxes;
    for (final stroke in selection.strokes) {
      stroke.shift(offset);
    }
    for (final image in selection.images) {
      image.dstRect = image.dstRect.shift(offset);
    }
    _shiftSelectedTextBoxes(page, offset);
    selection.path = selection.path.shift(offset);
    history.recordChange(
      EditorHistoryItem(
        type: .move,
        pageIndex: selection.pageIndex,
        strokes: selection.strokes,
        images: selection.images,
        offset: .fromLTRB(offset.dx, offset.dy, offset.dx, offset.dy),
        textBoxChange: selection.textBoxes.isEmpty
            ? null
            : Change(previous: textBoxesBefore, current: page.textBoxes),
      ),
    );
    coreInfo.pages[selection.pageIndex].redrawStrokes();
    setState(() {});
    autosaveAfterDelay();
  }

  /// Where [bounds] is on its page: -1 beside it on the left, 0 on it,
  /// 1 beside it on the right.
  static int sideOf(Rect bounds, Size pageSize) => bounds.center.dx < 0
      ? -1
      : bounds.center.dx > pageSize.width
      ? 1
      : 0;

  /// Moves the selection one place left ([direction] -1) or right (1):
  /// from the page to the space beside it, or from there back onto the
  /// page, keeping its height. Beside the page, it goes next to anything
  /// already there instead of on top of it.
  void moveSelectionToSide(int direction) {
    final select = Select.currentSelect;
    final bounds = select.selectionBounds;
    if (coreInfo.readOnly || !select.doneSelecting || bounds == null) return;
    final page = coreInfo.pages[select.selectResult.pageIndex];
    if (page.isBoard) return; // a whiteboard has no sides
    final width = page.size.width;
    const gap = EditorPage.sideGap;
    final from = sideOf(bounds, page.size);
    final to = (from + direction).clamp(-1, 1);
    if (to == from) return;

    final left = to == 0
        // Back onto the page, by the edge it came from
        ? (from < 0 ? gap : width - gap - bounds.width)
        : spotBeside(
            page,
            to,
            bounds.size,
            bounds.top,
            ignore: {
              ...select.selectResult.strokes,
              ...select.selectResult.images,
              for (final box in select.selectResult.textBoxes) box.id,
            },
          ).dx;
    moveSelectionBy(Offset(left - bounds.left, 0));
    revealPageRect(
      select.selectResult.pageIndex,
      bounds.shift(Offset(left - bounds.left, 0)),
    );
  }

  /// Where something of [size] goes beside [page] on [side] (-1 left,
  /// 1 right) with its top at [top]: next to the page, further out past
  /// anything already there (except what's in [ignore]: strokes, images
  /// and text box ids), and no further out than the space beside the page,
  /// where the pen can still reach it.
  Offset spotBeside(
    EditorPage page,
    int side,
    Size size,
    double top, {
    Set<Object> ignore = const {},
  }) {
    const gap = EditorPage.sideGap;
    final width = page.size.width;
    var left = side < 0 ? -gap - size.width : width + gap;
    final taken = [
      for (final (rect, _) in SideCardsPainter.sideGroups(page))
        if (sideOf(rect, page.size) == side) rect,
    ];
    // Skip past what's in the way, further from the page
    for (var moved = true; moved;) {
      moved = false;
      final target = Rect.fromLTWH(left, top, size.width, size.height);
      for (final rect in taken) {
        if (!rect.overlaps(target)) continue;
        if (_coversOnly(rect, page, ignore)) continue;
        final next = side < 0 ? rect.left - gap - size.width : rect.right + gap;
        if (next == left) continue;
        left = next;
        moved = true;
      }
    }
    left = side < 0
        ? min(-gap - size.width, max(left, -page.sideWidth))
        : max(width + gap, min(left, width + page.sideWidth - size.width));
    return Offset(left, top);
  }

  /// Whether everything in [rect] beside [page] is in [selected] (strokes,
  /// images, and text boxes by id), so it isn't in the way.
  static bool _coversOnly(Rect rect, EditorPage page, Set<Object> selected) =>
      page.strokes.every(
        (stroke) => selected.contains(stroke) || !rect.overlaps(stroke.bounds),
      ) &&
      page.images.every(
        (image) => selected.contains(image) || !rect.overlaps(image.dstRect),
      ) &&
      page.textBoxes.every(
        (box) =>
            selected.contains(box.id) ||
            !rect.overlaps(TextBoxes.boundsOf(box)),
      );

  /// Shows [rect] on [pageIndex] after the next frame, e.g. something just
  /// added beside the page, which may be off screen.
  void revealPageRect(int pageIndex, Rect rect) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final box = coreInfo.pages.elementAtOrNull(pageIndex)?.renderBox;
        if (!mounted || box == null || !box.attached) return;
        _revealGlobalRect(
          MatrixUtils.transformRect(box.getTransformTo(null), rect),
        );
      });

  /// Typing in a text box (or another text field, like the note's name).
  /// The Text tool on its own isn't typing: shortcuts still work until a
  /// box has the keyboard.
  bool get _isTyping => _textFieldFocused;

  /// Whether the note's keyboard shortcuts apply: not while typing (text
  /// has its own, e.g. ⌘F finds and ⌘0 is normal text in the note's text),
  /// or while a dialog or menu is open.
  bool shortcutsApply() =>
      mounted && !_isTyping && (ModalRoute.isCurrentOf(context) ?? true);

  /// Whether a text field has the keyboard, e.g. the note's name,
  /// but not the note's own text.
  static bool get _textFieldFocused =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  /// Keys that [Keybinder] can't bind, since they'd be taken from text
  /// fields: single keys for tools ([ToolCatalog.shortcuts]) and the
  /// lasso's selection, and Space to pan. Returns whether it used [event].
  bool _onKey(KeyEvent event) {
    if (!mounted) return false;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.space) {
      // For the grab cursor (see [_spaceHeld])
      if (event is! KeyRepeatEvent && !_isTyping) setState(() {});
      return false;
    }
    if (event is KeyUpEvent || keyboard.isAltPressed) return false;
    // Not while typing, or while a dialog or menu is open
    if (coreInfo.readOnly || !(ModalRoute.isCurrentOf(context) ?? true)) {
      return false;
    }
    if (currentTool == Tool.textEditing && key == LogicalKeyboardKey.escape) {
      toggleTextEditing();
      return true;
    }
    if (_isTyping) return false;

    final selection = SelectionActions.selectionOf(currentTool);
    if (keyboard.isMetaPressed || keyboard.isControlPressed) {
      switch (key) {
        case LogicalKeyboardKey.keyA:
          selectAll();
        case LogicalKeyboardKey.keyC when selection != null:
          unawaited(SelectionActions.copy(this));
        case LogicalKeyboardKey.keyX when selection != null:
          unawaited(SelectionActions.cut(this));
        case LogicalKeyboardKey.keyD when selection != null:
          duplicateSelection();
        default:
          return false;
      }
      return true;
    }

    if (selection != null) {
      final step = keyboard.isShiftPressed ? 10.0 : 1.0;
      final nudge = switch (key) {
        LogicalKeyboardKey.arrowLeft => Offset(-step, 0),
        LogicalKeyboardKey.arrowRight => Offset(step, 0),
        LogicalKeyboardKey.arrowUp => Offset(0, -step),
        LogicalKeyboardKey.arrowDown => Offset(0, step),
        _ => null,
      };
      if (nudge != null) {
        moveSelectionBy(nudge);
        return true;
      }
      if (key == LogicalKeyboardKey.delete ||
          key == LogicalKeyboardKey.backspace) {
        deleteSelection();
        return true;
      }
      if (key == LogicalKeyboardKey.escape) {
        setState(Select.currentSelect.unselect);
        return true;
      }
    }
    if (event is KeyRepeatEvent || keyboard.isShiftPressed) return false;

    final id = ToolCatalog.shortcuts.entries
        .where((shortcut) => shortcut.value == key)
        .firstOrNull
        ?.key;
    switch (id) {
      case 'lasso':
        setTool(Select.currentSelect);
      case 'pen':
        setTool(Pen.currentPen);
      case 'highlighter':
        setTool(Highlighter.currentHighlighter);
      case 'eraser':
        setTool(Eraser());
      case 'text':
        toggleTextEditing();
      case 'shapes':
        if (currentTool is! ShapePen) setTool(ShapePen());
      case 'laserPointer':
        setTool(LaserPointer.currentLaserPointer);
      case 'tape':
        setTool(Tape.currentTape);
      case 'ruler':
        toggleRuler();
      case 'image':
        unawaited(_pickPhotos());
      default:
        return false;
    }
    return true;
  }

  /// A right-click (or Control-click) on the canvas at [position]:
  /// the lasso's actions on its selection, or else paste, select all,
  /// undo and redo. Images and the note's text have their own menus.
  Future<void> _showCanvasMenu(Offset position) async {
    // The note's text: its own menu (cut, copy, paste) from its editor
    if (currentTool == Tool.textEditing) return;
    final pageIndex = onWhichPageIsFocalPoint(position);
    if (pageIndex == null) return;
    final page = coreInfo.pages[pageIndex];
    final local = page.renderBox!.globalToLocal(position);
    final selection = SelectionActions.selectionOf(currentTool);
    final onSelection =
        selection != null &&
        selection.pageIndex == pageIndex &&
        (Select.currentSelect.selectionBounds?.contains(local) ?? false);
    // The lasso's images have their own menu
    if (!onSelection &&
        currentTool == Select.currentSelect &&
        page.images.any((image) => image.dstRect.contains(local))) {
      return;
    }

    final editable = !coreInfo.readOnly;
    final ink = onSelection ? Handwriting.inkOf(selection.strokes) : const [];
    final canPaste =
        editable &&
        !onSelection &&
        (SelectionClipboard.content.value != null ||
            await _clipboardHasImage());
    if (!mounted) return;
    final actions = <(String, VoidCallback)>[
      if (onSelection) ...[
        (t.editor.otherTools.copy, () => SelectionActions.copy(this)),
        if (editable) ...[
          (t.editor.otherTools.cut, () => SelectionActions.cut(this)),
          (t.editor.selectionBar.duplicate, duplicateSelection),
          (t.editor.selectionBar.delete, deleteSelection),
          (t.editor.canvasTools.addLink, editSelectionLink),
        ],
        (
          t.editor.otherTools.screenshot,
          () => SelectionActions.screenshot(context, this, at: position),
        ),
        if (Handwriting.isSupported && ink.isNotEmpty)
          (
            t.editor.otherTools.handwriting,
            () => SelectionActions.handwriting(context, this, at: position),
          ),
        (t.ai.askAi, () => showAiMenu(context, this)),
      ] else if (editable) ...[
        // Where the right-click was
        if (canPaste)
          (
            t.editor.otherTools.paste,
            () => paste(pageIndex: pageIndex, at: local),
          ),
        if (page.strokes.isNotEmpty || page.images.isNotEmpty)
          (t.editor.mouse.selectAll, () => selectAll(pageIndex)),
        if (history.canUndo) (t.editor.toolbar.undo, undo),
        if (history.canRedo) (t.editor.toolbar.redo, redo),
      ],
    ];
    if (actions.isEmpty) return;
    await showBarMenu(context, position, actions: actions);
  }

  /// The mouse over the canvas, for its cursor and the eraser's outline.
  /// Null when it's elsewhere.
  final _mouse = ValueNotifier<({Offset position, int buttons})?>(null);

  /// The Pencil or finger erasing (see [_onMouse]), -1 during a pinch.
  int? _outlinePointer;

  void _onMouse(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse) {
      // The Pencil (or an erasing finger) moves the eraser's outline while
      // it erases. (iPadOS reports a hovering Pencil as a mouse, so the
      // outline used to freeze when the Pencil touched down.)
      if (currentTool is! Eraser) return;
      // Fingers that only pan or zoom don't
      if (event.kind == PointerDeviceKind.touch &&
          !stows.editorFingerDrawing.value) {
        return;
      }
      if (event is PointerDownEvent) {
        if (_outlinePointer != null) {
          // A second finger: a pinch, so no outline until they lift
          _outlinePointer = -1;
          _mouse.value = null;
          return;
        }
        _outlinePointer = event.pointer;
      }
      final ended =
          event is PointerUpEvent ||
          event is PointerCancelEvent ||
          // (iPadOS also sends an exit when the Pencil lifts; still down,
          // it only passed over e.g. the toolbar, and comes back)
          (event is PointerExitEvent && !event.down);
      if (ended) {
        if (event.pointer == _outlinePointer || _outlinePointer == -1) {
          _outlinePointer = null;
          _mouse.value = null;
        }
        return;
      }
      if (event.pointer != _outlinePointer) return;
      _mouse.value = (position: event.position, buttons: 0);
      return;
    }
    _mouse.value = event is PointerExitEvent
        ? null
        : (position: event.position, buttons: event.buttons);
  }

  /// [child] with the mouse cursor for the current tool (see [_cursorFor]).
  Widget _withMouseCursor(Widget child) => ValueListenableBuilder(
    valueListenable: _mouse,
    builder: (context, mouse, child) => MouseRegion(
      cursor: _cursorFor(mouse),
      onEnter: _onMouse,
      onHover: _onMouse,
      onExit: _onMouse,
      child: child,
    ),
    child: Listener(
      onPointerDown: _onMouse,
      onPointerMove: _onMouse,
      onPointerUp: _onMouse,
      onPointerCancel: _onMouse,
      child: child,
    ),
  );

  MouseCursor _cursorFor(({Offset position, int buttons})? mouse) {
    if (mouse == null) return MouseCursor.defer;
    final hand = mouse.buttons == 0
        ? SystemMouseCursors.grab
        : SystemMouseCursors.grabbing;
    if (_spaceHeld) return hand;
    // A middle- or right-drag pans
    if (mouse.buttons & (kMiddleMouseButton | kSecondaryMouseButton) != 0) {
      return SystemMouseCursors.grabbing;
    }
    if (switch ((ruler.value, _rulerBox)) {
      (final ruler?, final box?) => ruler.contains(
        box.globalToLocal(mouse.position),
        box.size,
      ),
      _ => false,
    }) {
      return hand;
    }
    return switch (currentTool) {
      _ when coreInfo.readOnly => MouseCursor.defer,
      Tool.textEditing => SystemMouseCursors.text,
      Eraser() => SystemMouseCursors.none, // see [_EraserOutline]
      InsertSpace() => SystemMouseCursors.resizeUpDown,
      final Select select => _selectionCursor(select, mouse.position, hand),
      _ => SystemMouseCursors.precise,
    };
  }

  /// Grab the selection, or resize it from a corner.
  MouseCursor _selectionCursor(
    Select select,
    Offset position,
    MouseCursor hand,
  ) {
    final box = select.doneSelecting
        ? coreInfo.pages
              .elementAtOrNull(select.selectResult.pageIndex)
              ?.renderBox
        : null;
    if (box == null) return SystemMouseCursors.precise;
    final local = box.globalToLocal(position);
    // A Mac has no diagonal resize cursors
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    return switch (select.handleAt(local)) {
      SelectionHandle.topLeft || SelectionHandle.bottomRight when !mac =>
        SystemMouseCursors.resizeUpLeftDownRight,
      SelectionHandle.topRight || SelectionHandle.bottomLeft when !mac =>
        SystemMouseCursors.resizeUpRightDownLeft,
      null when !select.selectResult.path.contains(local) =>
        SystemMouseCursors.precise,
      _ => hand,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final alignment = stows.editorToolbarAlignment.value;
    final isToolbarVertical =
        alignment == AxisDirection.left || alignment == AxisDirection.right;
    final headerShown = !DynamicMaterialApp.isFullscreen;

    final Widget canvas = CanvasGestureDetector(
      key: _canvasGestureDetectorKey,
      filePath: coreInfo.filePath,
      isDrawGesture: isDrawGesture,
      onInteractionEnd: onInteractionEnd,
      onDrawStart: onDrawStart,
      onDrawUpdate: onDrawUpdate,
      onDrawEnd: onDrawEnd,
      onTapUp: coreInfo.readOnly
          ? _onReadOnlyTap
          : currentTool == Tool.textEditing
          ? _onTextTap
          : null,
      // Once the Pencil is in use, fingers (and resting palms) don't start
      // text boxes; they still pan, and move boxes by their grips
      tapDevices:
          currentTool == Tool.textEditing && !stows.editorFingerDrawing.value
          ? const {
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            }
          : null,
      onPointerDown: (position) => _pointerDownPosition = position,
      onSecondaryTap: (position) => unawaited(_showCanvasMenu(position)),
      onHovering: onHovering,
      onHoveringEnd: onHoveringEnd,
      onStylusButtonChanged: onStylusButtonChanged,
      updatePointerData: updatePointerData,
      undo: undo,
      redo: redo,
      pages: coreInfo.pages,
      initialPageIndex: coreInfo.initialPageIndex,
      pageBuilder: pageBuilder,
      // Arrow keys move the text cursor, or nudge the selection
      arrowKeysPan: () =>
          !_isTyping && SelectionActions.selectionOf(currentTool) == null,
      shortcutsApply: shortcutsApply,
      placeholderPageBuilder: (BuildContext context, int pageIndex) {
        return Canvas(
          path: coreInfo.filePath,
          page: coreInfo.pages[pageIndex],
          pageIndex: 0,
          textEditing: false,
          coreInfo: EditorCoreInfo.placeholder,
          currentStroke: null,
          currentStrokeDetectedShape: null,
          currentSelection: null,
          placeholder: true,
          setAsBackground: null,
          currentTool: currentTool,
          currentScale: double.minPositive,
        );
      },
      transformationController: _transformationController,
    );

    final readonlyBanner = ReadOnlyBanner(
      coreInfo.readOnlyReason,
      action: coreInfo.readOnlyReason == .versionTooNew
          ? showVersionTooNewDialog
          : null,
    );

    void setColor(Color color) {
      final tool = currentTool;
      if (tool is Select &&
          (!tool.doneSelecting || tool.selectResult.strokes.isEmpty)) {
        return; // nothing to recolor
      }
      setState(() {
        updateColorBar(color);

        if (currentTool is Highlighter) {
          (currentTool as Highlighter).color = color.withAlpha(
            Highlighter.alpha,
          );
        } else if (currentTool is Pen) {
          (currentTool as Pen).color = color;
        } else if (currentTool is Fill) {
          (currentTool as Fill).color = color;
        } else if (currentTool == Tool.textEditing) {
          TextBoxes.color = color;
          _recolorTextBox(color);
        } else if (currentTool is Select) {
          // Changes color of selected strokes
          final select = currentTool as Select;
          if (select.doneSelecting) {
            final strokes = select.selectResult.strokes;

            final colorChange = <Stroke, Change<Color>>{};
            for (final stroke in strokes) {
              colorChange[stroke] = Change(
                previous: stroke.color,
                current: color,
              );
              stroke.color = color;
            }

            history.recordChange(
              EditorHistoryItem(
                type: .changeColor,
                pageIndex: strokes.first.pageIndex,
                strokes: strokes,
                colorChange: colorChange,
                images: [],
              ),
            );
            autosaveAfterDelay();
          }
        }
      });
    }

    final toolbarHidden =
        DynamicMaterialApp.isFullscreen &&
        !stows.editorToolbarShowInFullscreen.value;

    // Keyed by their [FloatingBar]s, so they keep their state when they
    // move between their default places and floating above the page.
    final toolbarWidget = Toolbar(
      key: _toolbarBar.key,
      bar: _toolbarBar,
      readOnly: coreInfo.readOnly,
      setTool: setTool,
      currentTool: currentTool,
      duplicateSelection: duplicateSelection,
      deleteSelection: deleteSelection,
      setColor: setColor,
      quillFocus: quillFocus,
      textEditing: currentTool == Tool.textEditing,
      toggleTextEditing: toggleTextEditing,
      undo: undo,
      isUndoPossible: history.canUndo,
      redo: redo,
      isRedoPossible: history.canRedo,
      toggleFingerDrawing: () {
        stows.editorFingerDrawing.value = !stows.editorFingerDrawing.value;
        lastSeenPointerCount = 0;
      },
      pickPhoto: _pickPhotos,
      paste: paste,
      shortcutsApply: shortcutsApply,
      exportAsSba: exportAsSba,
      exportAsPdf: exportAsPdf,
      exportAsPng: exportAsPng,
    );

    // Like [ReadOnlyBanner], don't hide it while the note is loading
    final topBarReadOnly =
        coreInfo.readOnly && coreInfo.readOnlyReason != .placeholder;
    final topBarWidget = EditorTopBar(
      key: _topBarBar.key,
      bar: _topBarBar,
      currentTool: currentTool,
      setTool: setTool,
      setColor: setColor,
      readOnly: topBarReadOnly,
    );

    // Moved or minimized bars float above the page, inside the insets
    final viewPadding = MediaQuery.paddingOf(context);
    for (final bar in [_toolbarBar, _topBarBar]) {
      bar.compact = MediaQuery.sizeOf(context).width < 600;
      bar.insets = .fromLTRB(
        viewPadding.left + 8,
        (headerShown ? 0 : viewPadding.top) + 8,
        viewPadding.right + 8,
        viewPadding.bottom + 8,
      );
    }

    final isLoading = coreInfo.readOnlyReason == .placeholder;

    final barsAndCanvas = ListenableBuilder(
      listenable: Listenable.merge([_toolbarBar, _topBarBar]),
      builder: (context, _) {
        final toolbarDocked = _toolbarBar.docked;
        final topBarDocked = _topBarBar.docked;

        final Widget toolbar = Collapsible(
          axis: isToolbarVertical
              ? CollapsibleAxis.horizontal
              : CollapsibleAxis.vertical,
          collapsed: toolbarHidden,
          maintainState: true,
          child: SafeArea(
            top: !headerShown && alignment != AxisDirection.down,
            bottom: alignment != AxisDirection.up,
            left: alignment != AxisDirection.right,
            right: alignment != AxisDirection.left,
            child: Padding(
              padding: switch (alignment) {
                AxisDirection.down => const .fromLTRB(12, 0, 12, 20),
                AxisDirection.up => const .fromLTRB(12, 12, 12, 0),
                AxisDirection.left => const .fromLTRB(16, 12, 12, 12),
                AxisDirection.right => const .fromLTRB(12, 12, 16, 12),
              },
              child: toolbarWidget,
            ),
          ),
        );
        final Widget topBar = Collapsible(
          axis: CollapsibleAxis.vertical,
          collapsed: toolbarHidden || topBarReadOnly,
          maintainState: true,
          child: SafeArea(
            top: !headerShown && alignment != AxisDirection.up,
            bottom: false,
            child: Padding(
              padding: const .fromLTRB(16, 12, 16, 0),
              child: topBarWidget,
            ),
          ),
        );
        Widget floating(FloatingBar bar, Widget child) => Positioned.fill(
          child: Padding(
            padding: bar.insets,
            child: Visibility(
              visible: !toolbarHidden,
              maintainState: true,
              child: child,
            ),
          ),
        );

        return Stack(
          key: _barAreaKey,
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  if (toolbarDocked && alignment == AxisDirection.up) toolbar,
                  if (topBarDocked) topBar,
                  Expanded(
                    child: Row(
                      children: [
                        if (toolbarDocked && alignment == AxisDirection.left)
                          Center(child: toolbar),
                        Expanded(
                          // The canvas runs under the floating bottom toolbar
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _dropImages(
                                  child: _withMouseCursor(
                                    RulerOverlay(
                                      key: _rulerKey,
                                      ruler: ruler,
                                      child: AnimatedOpacity(
                                        opacity: isLoading ? 0 : 1,
                                        duration: HiganMotion.medium,
                                        child: canvas,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  // Repaints on every move, without the canvas
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      painter: _EraserOutline(
                                        this,
                                        color: c.text,
                                        halo: c.bg,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (isLoading)
                                const Positioned.fill(
                                  child: IgnorePointer(child: HiganLoading()),
                                ),
                              if (toolbarDocked &&
                                  alignment == AxisDirection.down)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: toolbar,
                                ),
                            ],
                          ),
                        ),
                        if (toolbarDocked && alignment == AxisDirection.right)
                          Center(child: toolbar),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!topBarDocked) floating(_topBarBar, topBarWidget),
            if (!toolbarDocked) floating(_toolbarBar, toolbarWidget),
          ],
        );
      },
    );

    final body = Column(
      children: [
        if (headerShown) _header(context),
        Expanded(child: barsAndCanvas),
        readonlyBanner,
      ],
    );

    return ValueListenableBuilder(
      valueListenable: savingState,
      builder: (context, savingState, child) {
        // don't allow user to go back until saving is done
        return PopScope(
          canPop: savingState == .saved,
          onPopInvokedWithResult: (didPop, _) {
            switch (savingState) {
              case .waitingToSave:
                assert(!didPop);
                saveToFile(); // trigger save now
                snackBarNeedsToSaveBeforeExiting();
              case .saving:
                assert(!didPop);
                snackBarNeedsToSaveBeforeExiting();
              case .saved:
                break;
            }
          },
          child: child!,
        );
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: body,
        floatingActionButton: toolbarHidden
            ? FloatingActionButton.small(
                tooltip: t.editor.toolbar.fullscreen,
                backgroundColor: c.surface2,
                foregroundColor: c.text,
                shape: CircleBorder(side: BorderSide(color: c.hairlineStrong)),
                onPressed: () {
                  DynamicMaterialApp.setFullscreen(false, updateSystem: true);
                },
                child: const Icon(Symbols.fullscreen_exit, weight: 300),
              )
            : null,
      ),
    );
  }

  /// Back (and save state), the note's title and a mono readout,
  /// then the page and note options.
  Widget _header(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    final titleStyle = HiganText.body(context, size: 16);
    final embedded = widget.embedded;
    final EdgeInsets padding;
    if (embedded) {
      // Line up with the shell's header (e.g. its settings button).
      final gutters = ResponsiveNavbar.pagePadding(context);
      padding = .fromLTRB(gutters.left, 8, gutters.right, 0);
    } else {
      final gutter = isPhone ? 12.0 : 22.0;
      padding = .fromLTRB(gutter, 12, gutter + 8, 0);
    }
    final readout = ListenableBuilder(
      listenable: Listenable.merge([_readoutPageIndex, savingState]),
      builder: (context, _) =>
          HiganLabel(_headerReadout(withFolder: !isPhone), size: 10),
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (embedded)
              Expanded(child: readout)
            else ...[
              SaveIndicator(savingState: savingState, triggerSave: saveToFile),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  mainAxisSize: .min,
                  children: [
                    Form(
                      key: _filenameFormKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: TextFormField(
                        style: titleStyle,
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          contentPadding: .zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                        controller: filenameTextEditingController,
                        onChanged: renameFile,
                        autofocus: needsNaming,
                        validator: _validateFilenameTextField,
                      ),
                    ),
                    const SizedBox(height: 4),
                    readout,
                  ],
                ),
              ),
            ],
            const SizedBox(width: 12),
            if (coreInfo.noteType == .flashcards) ...[
              HiganCircleButton(
                icon: Symbols.school,
                tooltip: t.nts.flashcards.study,
                onPressed: () => showFlashcardStudy(context, coreInfo),
              ),
              const SizedBox(width: 8),
            ],
            // On phones, pages are inserted from the page manager.
            // A whiteboard or an endless page is just the one page.
            if (!isPhone && !coreInfo.noteType.singlePage) ...[
              if (coreInfo.noteType == .flashcards)
                HiganCircleButton(
                  icon: Symbols.add_card,
                  tooltip: t.nts.flashcards.addCard,
                  onPressed: insertPageAfterCurrent,
                )
              else
                HiganCircleButton(
                  icon: Symbols.insert_page_break,
                  tooltip: t.editor.menu.insertPage,
                  onPressed: insertPageAfterCurrent,
                ),
              const SizedBox(width: 8),
            ],
            if (!coreInfo.noteType.singlePage) ...[
              HiganCircleButton(
                icon: Symbols.grid_view,
                tooltip: t.editor.pages,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AdaptiveAlertDialog(
                      title: Text(t.editor.pages),
                      content: pageManager(context),
                      actions: const [],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            HiganCircleButton(
              icon: Symbols.more_horiz,
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              onPressed: showNoteOptions,
            ),
          ],
        ),
      ),
    );
  }

  int get _readoutPage =>
      _readoutPageIndex.value.clamp(0, coreInfo.pages.length - 1);

  /// E.g. "MATHEMATICS · PAGE 2 / 4 · SAVED".
  String _headerReadout({required bool withFolder}) {
    final folder = p.dirname(coreInfo.filePath);
    return [
      if (withFolder && folder != '/' && folder != '.' && folder.isNotEmpty)
        p.basename(folder),
      if (coreInfo.pages.isEmpty ||
          coreInfo.readOnlyReason == .placeholder ||
          coreInfo.noteType.singlePage)
        ...const <String>[]
      else if (coreInfo.noteType == .flashcards)
        t.nts.flashcards.cardOf(
          n: _readoutPage ~/ 2 + 1,
          total: coreInfo.pages.length ~/ 2,
        )
      else
        t.higan.pageOf(n: _readoutPage + 1, total: coreInfo.pages.length),
      if (savingState.value == .saved) t.higan.saved else t.higan.saving,
    ].join(' · ');
  }

  void snackBarNeedsToSaveBeforeExiting() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.editor.needsToSaveBeforeExiting)));
  }

  /// The note's options, e.g. its background pattern.
  void showNoteOptions() => showModalBottomSheet(
    context: context,
    builder: (context) => bottomSheet(context),
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.higan.surface1,
    constraints: const BoxConstraints(maxWidth: 500),
  );

  /// Inserts a page (or a card) after the one in view and scrolls to it.
  void insertPageAfterCurrent() {
    if (coreInfo.noteType.singlePage) return;
    final currentPageIndex = this.currentPageIndex;
    insertPageAfter(currentPageIndex);
    CanvasGestureDetector.scrollToPage(
      pageIndex: coreInfo.noteType == .flashcards
          ? (currentPageIndex ~/ 2) * 2 + 2
          : currentPageIndex + 1,
      pages: coreInfo.pages,
      screenWidth: MediaQuery.sizeOf(context).width,
      transformationController: _transformationController,
    );
  }

  Widget bottomSheet(BuildContext context) {
    final invert = InnerCanvas.invertOf(context);
    final int currentPageIndex = this.currentPageIndex;

    return EditorBottomSheet(
      invert: invert,
      coreInfo: coreInfo,
      currentPageIndex: currentPageIndex,
      setBackgroundPattern: (pattern) => setState(() {
        if (coreInfo.readOnly) return;
        final previous = coreInfo.backgroundPattern;
        coreInfo.backgroundPattern = pattern;
        stows.lastBackgroundPattern.value = pattern;
        history.recordChange(
          EditorHistoryItem(
            type: .backgroundPattern,
            pageIndex: currentPageIndex,
            backgroundPatternChange: Change(
              previous: previous,
              current: pattern,
            ),
            strokes: [],
            images: [],
          ),
        );
        autosaveAfterDelay();
      }),
      setLineHeight: (lineHeight) => setState(() {
        if (coreInfo.readOnly) return;
        coreInfo.lineHeight = lineHeight;
        stows.lastLineHeight.value = lineHeight;
        autosaveUnrecordedChange();
      }),
      setLineThickness: (lineThickness) => setState(() {
        if (coreInfo.readOnly) return;
        coreInfo.lineThickness = lineThickness;
        stows.lastLineThickness.value = lineThickness;
        autosaveUnrecordedChange();
      }),
      removeBackgroundImage: () => setState(() {
        if (coreInfo.readOnly) return;

        final page = coreInfo.pages[currentPageIndex];
        if (page.backgroundImage == null) return;
        page.images.add(page.backgroundImage!);
        page.backgroundImage = null;

        autosaveUnrecordedChange();
      }),
      redrawImage: () => setState(() {}),
      clearPage: () {
        clearPage(currentPageIndex);
      },
      clearAllPages: clearAllPages,
      redrawAndSave: () => setState(() {
        if (coreInfo.readOnly) return;
        autosaveUnrecordedChange();
      }),
      pickPhotos: _pickPhotos,
      importPdf: importPdf,
      canRasterPdf: Editor.canRasterPdf,
    );
  }

  Widget pageBuilder(BuildContext context, int pageIndex) {
    final page = coreInfo.pages[pageIndex];
    final currentStroke = Pen.currentStroke?.pageIndex == pageIndex
        ? Pen.currentStroke
        : null;
    return Canvas(
      path: coreInfo.filePath,
      page: page,
      pageIndex: pageIndex,
      textEditing: currentTool == Tool.textEditing,
      textBoxCallbacks: (
        edit: _editTextBoxes,
        record: _recordTextBoxes,
        reveal: _revealGlobalRect,
      ),
      coreInfo: coreInfo,
      // The header's readout shows the page, except in full screen.
      // (It would also peek out around the floating toolbar.)
      showPageIndicator: DynamicMaterialApp.isFullscreen,
      currentStroke: currentStroke,
      currentStrokeDetectedShape:
          currentTool is ShapePen && currentStroke != null
          ? ShapePen.detectedShape
          : null,
      currentSelection: () {
        if (currentTool is! Select) return null;
        final select = currentTool as Select;
        if (select.selectResult.pageIndex != pageIndex) return null;
        // The same size on screen at any zoom
        select.handleRadius = 16 / _pixelsPerUnit(page);
        return select.selectResult;
      }(),
      setAsBackground: (EditorImage image) {
        if (page.backgroundImage != null) {
          // restore previous background image as normal image
          page.images.add(page.backgroundImage!);
        }
        page.images.remove(image);
        page.backgroundImage = image;

        CanvasImage.activeListener
            .notifyListenersPlease(); // un-select active image

        autosaveUnrecordedChange();
        setState(() {});
      },
      currentTool: currentTool,
      currentScale: _transformationController.value.approxScale,
    );
  }

  Widget pageManager(BuildContext context) {
    return EditorPageManager(
      coreInfo: coreInfo,
      currentPageIndex: currentPageIndex,
      redrawAndSave: () => setState(() {
        if (coreInfo.readOnly) return;
        autosaveUnrecordedChange();
      }),
      insertPageAfter: insertPageAfter,
      duplicatePage: (int pageIndex) => setState(() {
        if (coreInfo.readOnly || coreInfo.noteType.singlePage) return;
        // A flashcard's front and back go together
        final (first, count) = _pagesOf(pageIndex);
        for (var i = 0; i < count; i++) {
          final page = coreInfo.pages[first + i];
          final at = first + count + i;
          final newPage = page.copyWith(
            strokes: page.strokes.map((stroke) => stroke.copy()).toList(),
            images: page.images.map((image) => image.copy()).toList(),
            quill: QuillStruct(
              controller: flutter_quill.QuillController(
                document: flutter_quill.Document.fromDelta(
                  page.quill.controller.document.toDelta(),
                ),
                selection: const TextSelection.collapsed(offset: 0),
              ),
              focusNode: FocusNode(debugLabel: 'Quill Focus Node'),
            ),
            backgroundImage: page.backgroundImage?.copy(),
          );
          coreInfo.pages.insert(at, newPage);
          listenToQuillChanges(newPage.quill, at);
          history.recordChange(
            EditorHistoryItem(
              type: .insertPage,
              pageIndex: at,
              strokes: const [],
              images: const [],
              page: newPage,
            ),
          );
        }
        _updatePageIndices(first);
        autosaveAfterDelay();
      }),
      clearPage: clearPage,
      deletePage: (int pageIndex) => setState(() {
        if (coreInfo.readOnly || coreInfo.noteType.singlePage) return;
        final (first, count) = _pagesOf(pageIndex);
        // The back first, so undo brings the front back first
        for (var i = count - 1; i >= 0; i--) {
          if (first + i >= coreInfo.pages.length) continue;
          final page = coreInfo.pages.removeAt(first + i);
          history.recordChange(
            EditorHistoryItem(
              type: .deletePage,
              pageIndex: first + i,
              strokes: const [],
              images: const [],
              page: page,
            ),
          );
        }
        _updatePageIndices(first);
        createPage(first - 1);
        autosaveAfterDelay();
      }),
      transformationController: _transformationController,
    );
  }

  /// The pages that go with [pageIndex] as (first, count): its card's
  /// front and back for flashcards, or just it.
  (int, int) _pagesOf(int pageIndex) => coreInfo.noteType == .flashcards
      ? (pageIndex ~/ 2 * 2, 2)
      : (pageIndex, 1);

  /// Tells the pages from [from] on which page they are.
  void _updatePageIndices(int from) {
    for (var i = max(0, from); i < coreInfo.pages.length; i++) {
      coreInfo.pages[i].updatePageIndex(i);
    }
  }

  /// Adds a page after [pageIndex], or for flashcards, a card (a front
  /// and a back) after its card. Whiteboards and endless pages have just
  /// the one page.
  void insertPageAfter(int pageIndex) => setState(() {
    if (coreInfo.readOnly || coreInfo.noteType.singlePage) return;
    final cards = coreInfo.noteType == .flashcards;
    // After the back of the card
    final at = cards ? (pageIndex ~/ 2) * 2 + 2 : pageIndex + 1;
    for (var i = 0; i < (cards ? 2 : 1); i++) {
      final page = coreInfo.newPage();
      coreInfo.pages.insert(at + i, page);
      listenToQuillChanges(page.quill, at + i);
      history.recordChange(
        EditorHistoryItem(
          type: .insertPage,
          pageIndex: at + i,
          strokes: const [],
          images: const [],
          page: page,
        ),
      );
    }
    for (var i = at; i < coreInfo.pages.length; i++) {
      coreInfo.pages[i].updatePageIndex(i);
    }
    autosaveAfterDelay();
  });

  void clearPage(int pageIndex) {
    if (coreInfo.readOnly) return;
    final page = coreInfo.pages[pageIndex];
    setState(() {
      final removedStrokes = page.strokes.toList();
      final removedImages = page.images.toList();
      final textBoxesBefore = page.textBoxes;
      page.strokes.clear();
      page.images.clear();
      page.textBoxes = const [];
      removeExcessPages();
      history.recordChange(
        EditorHistoryItem(
          type: .erase,
          pageIndex: pageIndex,
          strokes: removedStrokes,
          images: removedImages,
          // Back with the ink in one undo
          textBoxChange: textBoxesBefore.isEmpty
              ? null
              : Change(previous: textBoxesBefore, current: const []),
        ),
      );
      autosaveAfterDelay();
    });
  }

  /// Removes [pageIndex]'s text boxes (undoably).
  void _clearTextBoxes(int pageIndex) {
    final page = coreInfo.pages[pageIndex];
    if (page.textBoxes.isEmpty) return;
    final before = page.textBoxes;
    page.textBoxes = const [];
    _recordTextBoxes(pageIndex, before);
  }

  void clearAllPages() {
    if (coreInfo.readOnly) return;
    setState(() {
      final removedStrokes = <Stroke>[];
      final removedImages = <EditorImage>[];
      for (final (i, page) in coreInfo.pages.indexed) {
        removedStrokes.addAll(page.strokes);
        removedImages.addAll(page.images);
        page.strokes.clear();
        page.images.clear();
        _clearTextBoxes(i);
      }
      removeExcessPages();
      history.recordChange(
        EditorHistoryItem(
          type: .erase,
          pageIndex: 0,
          strokes: removedStrokes,
          images: removedImages,
        ),
      );
    });
    autosaveAfterDelay();
  }

  Future<void> showVersionTooNewDialog() async {
    final disableReadOnly =
        await showDialog(
          context: context,
          builder: (context) => AdaptiveAlertDialog(
            title: Text(t.editor.versionTooNew.title),
            content: Text(t.editor.versionTooNew.subtitle),
            actions: [
              CupertinoDialogAction(
                child: Text(t.common.cancel),
                onPressed: () => Navigator.pop(context, false),
              ),
              CupertinoDialogAction(
                child: Text(t.editor.versionTooNew.allowEditing),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;
    if (!disableReadOnly) return;

    if (coreInfo.readOnlyReason == .versionTooNew) {
      coreInfo.readOnlyReason = null;
      if (mounted) setState(() {});
    }
  }

  late int _lastCurrentPageIndex = coreInfo.initialPageIndex ?? 0;

  /// The index of the page that is currently centered on screen.
  int get currentPageIndex {
    if (!mounted) return _lastCurrentPageIndex;

    final screenWidth = MediaQuery.sizeOf(context).width;

    return _lastCurrentPageIndex = getPageIndexFromScrollPosition(
      scrollY: -scrollY,
      screenWidth: screenWidth,
      pages: coreInfo.pages,
    );
  }

  @visibleForTesting
  static int getPageIndexFromScrollPosition({
    required double scrollY,
    required double screenWidth,
    required List<EditorPage> pages,
  }) {
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final bottomOfPage = CanvasGestureDetector.getTopOfPage(
        pageIndex: pageIndex + 1, // top of next page
        pages: pages,
        screenWidth: screenWidth,
      );

      if (scrollY < bottomOfPage) {
        return pageIndex;
      }
    }
    // below the last page
    return pages.length - 1;
  }

  @override
  void dispose() {
    unawaited(_cleanUpAsync());

    DynamicMaterialApp.removeFullscreenListener(_setState);
    _readoutPageIndex.dispose();
    ruler.dispose();
    _toolbarBar.dispose();
    _topBarBar.dispose();

    _delayedSaveTimer?.cancel();
    _lifecycle.dispose();
    _lastSeenPointerCountTimer?.cancel();
    _opening.cancel();

    _removeKeybindings();
    HardwareKeyboard.instance.removeHandler(_onKey);
    _mouse.dispose();

    // manually save pen properties since the listeners don't fire if a property is changed
    stows.lastFountainPenOptions.notifyListeners();
    stows.lastBallpointPenOptions.notifyListeners();
    stows.lastHighlighterOptions.notifyListeners();
    stows.lastPencilOptions.notifyListeners();
    stows.lastShapePenOptions.notifyListeners();
    stows.lastTapeOptions.notifyListeners();
    stows.lastBrushPenOptions.notifyListeners();
    stows.lastCalligraphyPenOptions.notifyListeners();

    super.dispose();
  }

  Future<void> _cleanUpAsync() async {
    try {
      if (_renameTimer?.isActive ?? false) {
        _renameTimer!.cancel();
        await _renameFileNow();
        filenameTextEditingController.dispose();
      }
      await saveToFile();
    } finally {
      coreInfo.dispose();
    }
  }
}

/// The eraser's size around the mouse, which has no cursor for it.
class _EraserOutline extends CustomPainter {
  new(this.editor, {required this.color, required this.halo})
    : super(
        // The size and zoom change it too, without the pointer moving
        repaint: Listenable.merge([
          editor._mouse,
          stows.eraserSize,
          editor._transformationController,
        ]),
      );

  final EditorState editor;

  /// The outline, and a wider line under it so it shows on any ink.
  final Color color, halo;

  @override
  void paint(ui.Canvas canvas, Size size) {
    final (mouse, tool, box) = (
      editor._mouse.value,
      editor.currentTool,
      editor._rulerBox,
    );
    if (mouse == null || tool is! Eraser || box == null) return;
    if (editor._spaceHeld) return;
    final page = editor.coreInfo.pages.elementAtOrNull(
      editor.onWhichPageIsFocalPoint(mouse.position) ?? 0,
    );
    if (page == null) return;
    final center = box.globalToLocal(mouse.position);
    final radius = tool.size * editor._pixelsPerUnit(page);
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = .stroke
          ..strokeWidth = 3
          ..color = halo.withValues(alpha: 0.6),
      )
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = .stroke
          ..color = color,
      );
  }

  @override
  bool shouldRepaint(_EraserOutline oldDelegate) => true;
}
