import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/ai/ai_menu.dart';
import 'package:nts/components/canvas/inner_canvas.dart';
import 'package:nts/components/theming/dynamic_material_app.dart';
import 'package:nts/components/toolbar/color_bar.dart';
import 'package:nts/components/toolbar/color_option.dart';
import 'package:nts/components/toolbar/pen_presets_bar.dart';
import 'package:nts/components/toolbar/selection_bar.dart';
import 'package:nts/components/toolbar/toolbar.dart';
import 'package:nts/data/editor/editor_history.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/extensions/color_extensions.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/services/camera.dart';
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
import 'package:nts/i18n/strings.g.dart';
import 'package:sbn/tool_id.dart';

/// The sections of the toolbar's "+" sheet. Neighbouring toolbar buttons
/// of the same category are grouped between dividers.
enum ToolCategory {
  write,
  eraseAndSelect,
  insert,
  view,
  actions;

  String get label => switch (this) {
    write => t.editor.customizeToolbar.categories.write,
    eraseAndSelect => t.editor.customizeToolbar.categories.eraseAndSelect,
    insert => t.editor.customizeToolbar.categories.insert,
    view => t.editor.customizeToolbar.categories.view,
    actions => t.editor.customizeToolbar.categories.actions,
  };
}

/// A button that people can add to the editor's toolbar.
///
/// To add one, add a [ToolbarItem] to [ToolCatalog.items].
/// A canvas tool is usually just [ToolbarItem.tool]; if it handles its own
/// pointer input, make it a [CanvasTool].
class ToolbarItem {
  const new({
    required this.id,
    required this.category,
    required this.icon,
    required this.label,
    required this.build,
    this.isCurrentTool,
    this.isAvailable,
    this.span,
  });

  /// A button that selects a tool, e.g. the pencil.
  ///
  /// [tool] is a getter since e.g. [Pencil.currentPencil] can change.
  /// [inReadOnly] keeps it enabled in read-only notes (e.g. the laser pointer).
  factory tool({
    required String id,
    required ToolCategory category,
    required IconData icon,
    required String Function() label,
    required Tool Function() tool,
    bool inReadOnly = false,
  }) => ToolbarItem(
    id: id,
    category: category,
    icon: icon,
    label: label,
    build: (b) => b.toolButton(tool(), inReadOnly: inReadOnly),
    isCurrentTool: (current) => current == tool(),
  );

  /// Saved in [Stows.editorToolbarItems], so never change it.
  final String id;
  final ToolCategory category;

  /// Shown in the "+" sheet and (by [ToolbarItemContext.button]) the toolbar.
  final IconData icon;

  /// The name in the "+" sheet, e.g. "Pencil". Also the default tooltip.
  final String Function() label;

  /// Builds the toolbar button, usually with [ToolbarItemContext.button]
  /// or [ToolbarItemContext.toolButton].
  final Widget Function(ToolbarItemContext b) build;

  /// Whether [tool] is this item's tool: the minimized toolbar then shows
  /// this item's button.
  final bool Function(Tool tool)? isCurrentTool;

  /// Returns false to hide the item everywhere, e.g. on some platforms.
  final bool Function()? isAvailable;

  /// How many buttons long the item is, if not one (e.g. pen favorites).
  /// Used to split the toolbar into two rows when it doesn't fit.
  final int Function()? span;

  bool get available => isAvailable?.call() ?? true;
}

abstract final class ToolCatalog {
  /// What new users' toolbars have.
  static const basics = [
    'pen',
    'highlighter',
    'eraser',
    'lasso',
    'text',
    'undo',
    'redo',
    'export',
  ];

  /// The toolbar before it could be customized, which people who used the
  /// app before keep (see [seed]).
  static const legacy = [
    'pen',
    'pencil',
    'highlighter',
    'eraser',
    'lasso',
    'image',
    'text',
    'laserPointer',
    'fingerDrawing',
    'fullscreen',
    'undo',
    'redo',
    'export',
  ];

  /// Once, on the first launch with a customizable toolbar: people who have
  /// opened notes before keep their old buttons ([legacy]), and new users
  /// start with the [basics].
  static Future<void> seed() async {
    await Future.wait([
      stows.editorToolbarSeeded.waitUntilRead(),
      stows.editorToolbarItems.waitUntilRead(),
      stows.recentFiles.waitUntilRead(),
    ]);
    if (stows.editorToolbarSeeded.value) return;
    stows.editorToolbarSeeded.value = true;
    // still the default, i.e. never customized
    if (identical(stows.editorToolbarItems.value, basics) &&
        stows.recentFiles.value.isNotEmpty) {
      stows.editorToolbarItems.value = legacy;
    }
  }

  /// Keys that work like these items' buttons when nothing is being typed
  /// (see `EditorState`), shown in their tooltips on computers.
  /// Goodnotes' letters, which Mac users may know.
  static const shortcuts = <String, LogicalKeyboardKey>{
    'lasso': .keyV,
    'pen': .keyP,
    'highlighter': .keyH,
    'eraser': .keyE,
    'text': .keyT,
    'shapes': .keyS,
    'laserPointer': .keyL,
    'tape': .keyA,
    'ruler': .keyR,
    'image': .keyI,
  };

  /// Every button that can be in the toolbar, in the "+" sheet's order.
  static final items = <ToolbarItem>[
    // Write
    .new(
      id: 'pen',
      category: .write,
      icon: Symbols.ink_pen,
      label: () => t.editor.customizeToolbar.tools.pen,
      isCurrentTool: (tool) => tool == Pen.currentPen,
      build: (b) => b.button(
        tooltip: Pen.currentPen.name,
        // unless the pen type's own button is in the toolbar (see _penType)
        selected:
            b.currentTool == Pen.currentPen &&
            !current.any(
              (item) =>
                  item.id != 'pen' &&
                  (item.isCurrentTool?.call(b.currentTool) ?? false),
            ),
        enabled: !b.readOnly,
        onPressed: () {
          final options = b.state.toolOptionsType;
          if (b.currentTool == Pen.currentPen) {
            // Tapping the selected pen shows the pen types
            options.value = options.value == .pen ? .hide : .pen;
          } else {
            b.state.selectTool(Pen.currentPen);
          }
        },
        child: Icon(switch (Pen.currentPen.toolId) {
          .ballpointPen => Symbols.stylus,
          .shapePen => Symbols.shapes,
          .brushPen => Symbols.brush,
          .calligraphyPen => Symbols.history_edu,
          _ => Symbols.ink_pen,
        }),
      ),
    ),
    .tool(
      id: 'pencil',
      category: .write,
      icon: Symbols.edit,
      label: () => t.editor.pens.pencil,
      tool: () => Pencil.currentPencil,
    ),
    .tool(
      id: 'highlighter',
      category: .write,
      icon: Symbols.ink_highlighter,
      label: () => t.editor.pens.highlighter,
      tool: () => Highlighter.currentHighlighter,
    ),
    // Pen types, also in the pen's popup
    _penType(
      id: 'shapes',
      icon: Symbols.shapes,
      label: () => t.editor.pens.shapePen,
      toolId: .shapePen,
      pen: ShapePen.new,
    ),
    _penType(
      id: 'brushPen',
      icon: Symbols.brush,
      label: () => t.editor.canvasTools.brushPen,
      toolId: .brushPen,
      pen: Pen.brushPen,
    ),
    _penType(
      id: 'calligraphyPen',
      icon: Symbols.history_edu,
      label: () => t.editor.canvasTools.calligraphyPen,
      toolId: .calligraphyPen,
      pen: CalligraphyPen.new,
    ),
    // The palette is always in the top bar, so this just opens the
    // custom color picker.
    .new(
      id: 'colorPicker',
      category: .write,
      icon: Symbols.palette,
      label: () => t.editor.customizeToolbar.tools.colorPicker,
      build: (b) {
        final invert = InnerCanvas.invertOf(b.context);
        final color = switch (b.currentTool) {
          final Pen pen => pen.color,
          final Select select => select.getDominantStrokeColor(),
          _ => null,
        };
        return b.button(
          tooltip: t.editor.colors.colorPicker,
          // no color applies to e.g. the eraser
          enabled: !b.readOnly && color != null,
          onPressed: () => ColorBar.openColorPicker(
            b.context,
            setColor: b.toolbar.setColor,
            invert: invert,
          ),
          child: color == null
              ? null
              : CurrentColorDot(
                  color.withInversion(invert).withValues(alpha: 1),
                ),
        );
      },
    ),

    // Erase and select
    .new(
      id: 'eraser',
      category: .eraseAndSelect,
      icon: Symbols.ink_eraser,
      label: () => t.editor.customizeToolbar.tools.eraser,
      isCurrentTool: (tool) => tool is Eraser,
      build: (b) => b.button(
        tooltip: t.editor.toolbar.toggleEraser,
        selected: b.currentTool is Eraser,
        enabled: !b.readOnly,
        onPressed: b.state.toggleEraser,
      ),
    ),
    .new(
      id: 'lasso',
      category: .eraseAndSelect,
      icon: Symbols.lasso_select,
      label: () => t.editor.toolbar.select,
      // not while it's "Ask AI"'s lasso
      isCurrentTool: (tool) =>
          tool == Select.currentSelect && !AiMenu.lassoArmed,
      build: (b) => b.button(
        selected: b.currentTool == Select.currentSelect && !AiMenu.lassoArmed,
        enabled: !b.readOnly,
        onPressed: () => b.state.selectTool(Select.currentSelect),
      ),
    ),

    // Insert
    .new(
      id: 'image',
      category: .insert,
      icon: Symbols.image,
      label: () => t.editor.toolbar.photo,
      build: (b) =>
          b.button(enabled: !b.readOnly, onPressed: b.toolbar.pickPhoto),
    ),
    .new(
      id: 'text',
      category: .insert,
      icon: Symbols.text_fields,
      label: () => t.editor.toolbar.text,
      isCurrentTool: (tool) => tool == Tool.textEditing,
      build: (b) => b.button(
        selected: b.toolbar.textEditing,
        enabled: !b.readOnly,
        onPressed: b.toolbar.toggleTextEditing,
      ),
    ),

    .new(
      id: 'addPage',
      category: .insert,
      icon: Symbols.insert_page_break,
      label: () => t.editor.menu.insertPage,
      build: (b) => b.button(
        // A whiteboard or an endless page is just the one page
        enabled:
            !b.readOnly &&
            b.editor != null &&
            !b.editor!.coreInfo.noteType.singlePage,
        onPressed: () => b.editor!.insertPageAfterCurrent(),
      ),
    ),
    // Background pattern, line height, etc., as in the header's menu
    .new(
      id: 'pageOptions',
      category: .insert,
      icon: Symbols.note_stack,
      label: () => t.editor.customizeToolbar.tools.pageOptions,
      build: (b) => b.button(
        enabled: b.editor != null,
        onPressed: () => b.editor!.showNoteOptions(),
      ),
    ),

    // View
    .tool(
      id: 'laserPointer',
      category: .view,
      icon: Symbols.stylus_laser_pointer,
      label: () => t.editor.pens.laserPointer,
      tool: () => LaserPointer.currentLaserPointer,
      inReadOnly: true,
    ),
    .new(
      id: 'fingerDrawing',
      category: .view,
      icon: Symbols.gesture,
      label: () => t.editor.customizeToolbar.tools.fingerDrawing,
      // The setting fixes finger drawing on or off
      isAvailable: () => !stows.hideFingerDrawingToggle.value,
      build: (b) => ValueListenableBuilder(
        valueListenable: stows.editorFingerDrawing,
        builder: (context, value, _) => b.button(
          tooltip: t.editor.toolbar.toggleFingerDrawing,
          selected: value,
          showDot: false,
          enabled: !b.readOnly,
          onPressed: b.toolbar.toggleFingerDrawing,
        ),
      ),
    ),
    .new(
      id: 'fullscreen',
      category: .view,
      icon: Symbols.fullscreen,
      label: () => t.editor.customizeToolbar.tools.fullscreen,
      build: (b) => b.button(
        tooltip: t.editor.toolbar.fullscreen,
        selected: DynamicMaterialApp.isFullscreen,
        showDot: false,
        enabled: !b.readOnly,
        onPressed: b.state.toggleFullscreen,
        child: Icon(
          DynamicMaterialApp.isFullscreen
              ? Symbols.fullscreen_exit
              : Symbols.fullscreen,
        ),
      ),
    ),

    // Actions
    .new(
      id: 'undo',
      category: .actions,
      icon: Symbols.undo,
      label: () => t.editor.toolbar.undo,
      build: (b) => b.button(
        enabled: !b.readOnly && b.toolbar.isUndoPossible,
        onPressed: b.toolbar.undo,
      ),
    ),
    .new(
      id: 'redo',
      category: .actions,
      icon: Symbols.redo,
      label: () => t.editor.toolbar.redo,
      build: (b) => b.button(
        enabled: !b.readOnly && b.toolbar.isRedoPossible,
        onPressed: b.toolbar.redo,
      ),
    ),
    .new(
      id: 'export',
      category: .actions,
      icon: Symbols.ios_share,
      label: () => t.editor.customizeToolbar.tools.export,
      build: (b) => ValueListenableBuilder(
        valueListenable: b.state.showExportOptions,
        builder: (context, showExportOptions, _) => b.button(
          tooltip: t.editor.toolbar.export,
          selected: showExportOptions,
          showDot: false,
          enabled: !b.readOnly,
          onPressed: b.state.toggleExportBar,
        ),
      ),
    ),

    // Canvas tools and pen options (lib/data/tools/)
    .tool(
      id: 'tape',
      category: .write,
      icon: Tape.tapeIcon,
      label: () => t.editor.canvasTools.tape,
      tool: () => Tape.currentTape,
    ),
    .tool(
      id: 'fill',
      category: .write,
      icon: Symbols.format_color_fill,
      label: () => t.editor.canvasTools.fill,
      tool: () => Fill.currentFill,
    ),
    .new(
      id: 'holdToSnapShape',
      category: .write,
      icon: Symbols.shape_recognition,
      label: () => t.editor.canvasTools.holdToSnapShape,
      build: (b) => ValueListenableBuilder(
        valueListenable: stows.holdToSnapShape,
        builder: (context, on, _) => b.button(
          selected: on,
          showDot: false,
          enabled: !b.readOnly,
          onPressed: () => stows.holdToSnapShape.value = !on,
        ),
      ),
    ),
    .new(
      id: 'scribbleToErase',
      category: .eraseAndSelect,
      icon: Symbols.ink_eraser_off,
      label: () => t.editor.canvasTools.scribbleToErase,
      build: (b) => ValueListenableBuilder(
        valueListenable: stows.scribbleToErase,
        builder: (context, on, _) => b.button(
          selected: on,
          showDot: false,
          enabled: !b.readOnly,
          onPressed: () => stows.scribbleToErase.value = !on,
        ),
      ),
    ),
    .tool(
      id: 'insertSpace',
      category: .insert,
      icon: Symbols.expand,
      label: () => t.editor.canvasTools.insertSpace,
      tool: () => InsertSpace.currentInsertSpace,
    ),
    .new(
      id: 'ruler',
      category: .view,
      icon: Symbols.straighten,
      label: () => t.editor.canvasTools.ruler,
      build: (b) => switch (b.editor) {
        null => b.button(onPressed: null),
        final editor => ValueListenableBuilder(
          valueListenable: editor.ruler,
          builder: (context, ruler, _) => b.button(
            selected: ruler != null,
            showDot: false,
            enabled: !b.readOnly,
            onPressed: editor.toggleRuler,
          ),
        ),
      },
    ),

    // Pen favorites, lasso extras and camera (lib/data/services/)
    .new(
      id: 'penPresets',
      category: .write,
      icon: Symbols.bookmark_star,
      label: () => t.editor.otherTools.penFavorites,
      // the favorites and the "save" button
      span: () => stows.penPresets.value.length + 1,
      build: (b) => PenPresetButtons(
        axis: b.axis,
        currentTool: b.currentTool,
        enabled: !b.readOnly,
        selectTool: b.state.selectTool,
        padding: b.padding,
      ),
    ),
    .new(
      id: 'lassoClipboard',
      category: .eraseAndSelect,
      icon: Symbols.content_paste,
      label: () => t.editor.otherTools.paste,
      build: (b) => ValueListenableBuilder(
        valueListenable: SelectionClipboard.content,
        builder: (context, clip, _) => b.button(
          enabled: !b.readOnly && clip != null && b.editor != null,
          onPressed: () => SelectionClipboard.paste(b.editor!),
        ),
      ),
    ),
    .new(
      id: 'lassoScreenshot',
      category: .eraseAndSelect,
      icon: Symbols.screenshot_region,
      label: () => t.editor.otherTools.screenshot,
      build: (b) => Builder(
        builder: (context) => b.button(
          enabled:
              SelectionActions.selectionOf(b.currentTool) != null &&
              b.editor != null,
          onPressed: () => SelectionActions.screenshot(context, b.editor!),
        ),
      ),
    ),
    .new(
      id: 'handwritingToText',
      category: .eraseAndSelect,
      icon: Symbols.convert_to_text,
      label: () => t.editor.otherTools.handwriting,
      isAvailable: () => Handwriting.isSupported,
      build: (b) => Builder(
        builder: (context) => b.button(
          enabled:
              Handwriting.inkOf(
                SelectionActions.selectionOf(b.currentTool)?.strokes ??
                    const [],
              ).isNotEmpty &&
              b.editor != null,
          onPressed: () => SelectionActions.handwriting(context, b.editor!),
        ),
      ),
    ),
    .new(
      id: 'askAi',
      category: .eraseAndSelect,
      icon: Symbols.auto_awesome,
      label: () => t.ai.askAi,
      // the lasso, but finishing it opens the AI menu
      isCurrentTool: (tool) =>
          tool == Select.currentSelect && AiMenu.lassoArmed,
      build: (b) => Builder(
        builder: (context) => b.button(
          selected: b.currentTool == Select.currentSelect && AiMenu.lassoArmed,
          enabled: !b.readOnly && b.editor != null,
          onPressed: () {
            b.state.selectTool(Select.currentSelect);
            AiMenu.lassoArmed = true;
            if (SelectionActions.selectionOf(Select.currentSelect) != null) {
              showAiMenu(context, b.editor!);
            }
          },
        ),
      ),
    ),
    .new(
      id: 'camera',
      category: .insert,
      icon: Symbols.photo_camera,
      label: () => t.editor.otherTools.camera,
      isAvailable: () => Camera.isSupported,
      build: (b) => b.button(
        enabled: !b.readOnly && b.editor != null,
        onPressed: () => Camera.takePhoto(b.editor!),
      ),
    ),
  ];

  /// A button that switches the pen to one type, like the pen's popup.
  static ToolbarItem _penType({
    required String id,
    required IconData icon,
    required String Function() label,
    required ToolId toolId,
    required Pen Function() pen,
  }) => .new(
    id: id,
    category: .write,
    icon: icon,
    label: label,
    isCurrentTool: (tool) => tool is Pen && tool.toolId == toolId,
    build: (b) {
      final current = b.currentTool;
      final selected = current is Pen && current.toolId == toolId;
      return b.button(
        selected: selected,
        enabled: !b.readOnly,
        onPressed: () {
          if (!selected) b.state.selectTool(pen());
        },
      );
    },
  );

  static final _byId = {for (final item in items) item.id: item};

  static ToolbarItem? byId(String id) => _byId[id];

  /// The available items for [ids], skipping unknown ids and repeats.
  static List<ToolbarItem> resolve(Iterable<String> ids) => [
    for (final id in ids.toSet())
      if (_byId[id] case final item? when item.available) item,
  ];

  /// The toolbar's items (see [Stows.editorToolbarItems]).
  static List<ToolbarItem> get current =>
      resolve(stows.editorToolbarItems.value);

  static bool contains(String id) => current.any((item) => item.id == id);

  /// Adds [id] to the end of the toolbar.
  static void add(String id) => stows.editorToolbarItems.value = [
    for (final saved in stows.editorToolbarItems.value)
      if (saved != id) saved,
    id,
  ];

  static void remove(String id) => stows.editorToolbarItems.value = [
    for (final saved in stows.editorToolbarItems.value)
      if (saved != id) saved,
  ];

  /// Moves the item at [oldIndex] of [current] to [newIndex] (its index
  /// after the move). Unknown ids are kept, at the end.
  static void reorder(int oldIndex, int newIndex) {
    final ids = [for (final item in current) item.id];
    ids.insert(newIndex, ids.removeAt(oldIndex));
    stows.editorToolbarItems.value = [
      ...ids,
      for (final saved in stows.editorToolbarItems.value)
        if (!ids.contains(saved)) saved,
    ];
  }

  static void resetToBasics() => stows.editorToolbarItems.value = basics;
}

/// A tool that handles its own pointer input on the canvas,
/// e.g. `class Tape extends CanvasTool`.
///
/// The editor calls these for draw gestures (stylus, mouse, or finger when
/// finger drawing is on) while it's the current tool, then redraws the page.
/// Positions are in the page's coordinates.
abstract class CanvasTool extends Tool {
  const new();

  void onDrawStart(CanvasToolInput input) {}

  void onDrawUpdate(CanvasToolInput input) {}

  /// Returns what to add to the undo history (the editor records it and
  /// autosaves), or null if the note didn't change.
  /// [CanvasToolInput.position] is the last position of the gesture.
  EditorHistoryItem? onDrawEnd(CanvasToolInput input) => null;
}

typedef CanvasToolInput = ({
  EditorPage page,
  int pageIndex,
  Offset position,
  // From 0 to 1, or null if the pointer has no pressure (e.g. a finger).
  double? pressure,
});
