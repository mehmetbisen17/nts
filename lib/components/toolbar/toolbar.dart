import 'dart:io';
import 'dart:math';

import 'package:collapsible/collapsible.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' hide EditorState;
import 'package:keybinder/keybinder.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/dynamic_material_app.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/components/toolbar/customize_toolbar_sheet.dart';
import 'package:nts/components/toolbar/export_bar.dart';
import 'package:nts/components/toolbar/floating_bar.dart';
import 'package:nts/components/toolbar/pen_modal.dart';
import 'package:nts/components/toolbar/selection_bar.dart';
import 'package:nts/components/toolbar/size_picker.dart';
import 'package:nts/components/toolbar/toolbar_button.dart';
import 'package:nts/components/toolbar/top_bar.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/data/tools/eraser.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';

class Toolbar extends StatefulWidget {
  const new({
    super.key,
    required this.bar,
    required this.readOnly,
    required this.setTool,
    required this.currentTool,
    required this.setColor,
    required this.quillFocus,
    required this.textEditing,
    required this.toggleTextEditing,
    required this.undo,
    required this.isUndoPossible,
    required this.redo,
    required this.isRedoPossible,
    required this.toggleFingerDrawing,
    required this.pickPhoto,
    required this.paste,
    required this.shortcutsApply,
    required this.duplicateSelection,
    required this.deleteSelection,
    required this.exportAsSba,
    required this.exportAsPdf,
    required this.exportAsPng,
  });

  /// Where the toolbar is, and whether it's minimized.
  final FloatingBar bar;

  final bool readOnly;

  final ValueChanged<Tool> setTool;
  final Tool currentTool;
  final ValueChanged<Color> setColor;

  final ValueNotifier<QuillStruct?> quillFocus;
  final bool textEditing;
  final VoidCallback toggleTextEditing;

  final VoidCallback undo;
  final bool isUndoPossible;
  final VoidCallback redo;
  final bool isRedoPossible;

  final VoidCallback toggleFingerDrawing;

  final VoidCallback pickPhoto;

  final VoidCallback paste;

  /// Whether the keyboard shortcuts apply, e.g. not while typing.
  final bool Function() shortcutsApply;

  final VoidCallback duplicateSelection;
  final VoidCallback deleteSelection;

  final Future Function(BuildContext)? exportAsSba;
  final Future Function(BuildContext)? exportAsPdf;
  final Future Function(BuildContext)? exportAsPng;

  @override
  State<Toolbar> createState() => ToolbarState();

  static const _buttonPaddingHorizontal = EdgeInsets.symmetric(horizontal: 2);
  static const _buttonPaddingVertical = EdgeInsets.zero;

  /// Where the minimized toolbar goes if it hasn't been moved:
  /// its usual place, but not over the top bar (see
  /// [EditorTopBar.defaultPosition]).
  static FractionalOffset defaultPosition(AxisDirection alignment) =>
      switch (alignment) {
        .down => FractionalOffset.bottomCenter,
        .up => FractionalOffset.centerRight,
        .left => FractionalOffset.centerLeft,
        .right => FractionalOffset.centerRight,
      };
}

class ToolbarState extends State<Toolbar> {
  final showExportOptions = ValueNotifier(false);
  final toolOptionsType = ValueNotifier(ToolOptions.hide);

  @override
  void initState() {
    _assignKeybindings();

    DynamicMaterialApp.addFullscreenListener(_setState);

    super.initState();
  }

  void _setState() => setState(() {});

  Keybinding? _ctrlF;
  Keybinding? _ctrlE;
  Keybinding? _ctrlShiftS;
  Keybinding? _f11;
  Keybinding? _ctrlV;
  void _assignKeybindings() {
    _ctrlF = Keybinding([
      Editor.ctrlOrCmd,
      KeyCode.from(LogicalKeyboardKey.keyF),
    ], inclusive: true);
    _ctrlE = Keybinding([
      Editor.ctrlOrCmd,
      KeyCode.from(LogicalKeyboardKey.keyE),
    ], inclusive: true);
    _ctrlShiftS = Keybinding([
      Editor.ctrlOrCmd,
      KeyCode.shift,
      KeyCode.from(LogicalKeyboardKey.keyS),
    ], inclusive: true);
    _f11 = Keybinding([KeyCode.from(LogicalKeyboardKey.f11)], inclusive: true);
    _ctrlV = Keybinding([
      Editor.ctrlOrCmd,
      KeyCode.from(LogicalKeyboardKey.keyV),
    ], inclusive: true);

    // Not while typing: e.g. ⌘F finds in the note's text, not finger drawing
    VoidCallback unlessTyping(VoidCallback callback) => () {
      if (widget.shortcutsApply()) callback();
    };
    Keybinder.bind(_ctrlF!, unlessTyping(widget.toggleFingerDrawing));
    Keybinder.bind(_ctrlE!, unlessTyping(toggleEraser));
    Keybinder.bind(_ctrlShiftS!, unlessTyping(toggleExportBar));
    Keybinder.bind(_f11!, toggleFullscreen);
    Keybinder.bind(_ctrlV!, unlessTyping(widget.paste));
  }

  void _removeKeybindings() {
    if (_ctrlF != null) Keybinder.remove(_ctrlF!);
    if (_ctrlE != null) Keybinder.remove(_ctrlE!);
    if (_ctrlShiftS != null) Keybinder.remove(_ctrlShiftS!);
    if (_f11 != null) Keybinder.remove(_f11!);
    if (_ctrlV != null) Keybinder.remove(_ctrlV!);
  }

  /// Hides the pen types (etc.) and switches to [tool].
  void selectTool(Tool tool) {
    toolOptionsType.value = .hide;
    widget.setTool(tool);
  }

  void toggleEraser() {
    toolOptionsType.value = .hide;
    widget.setTool(Eraser()); // this toggles eraser
  }

  void toggleExportBar() {
    showExportOptions.value = !showExportOptions.value;
  }

  void toggleFullscreen() async {
    DynamicMaterialApp.setFullscreen(
      !DynamicMaterialApp.isFullscreen,
      updateSystem: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final alignment = stows.editorToolbarAlignment.value;
    final isToolbarVertical =
        alignment == AxisDirection.left || alignment == AxisDirection.right;
    final axis = isToolbarVertical ? Axis.vertical : Axis.horizontal;
    final buttonPadding = isToolbarVertical
        ? Toolbar._buttonPaddingVertical
        : Toolbar._buttonPaddingHorizontal;

    if (widget.currentTool == Select.currentSelect) {
      // Enable selection bar only when selection is done
      toolOptionsType.value = Select.currentSelect.doneSelecting
          ? .select
          : .hide;
    }

    return ListenableBuilder(
      listenable: widget.bar,
      builder: (context, _) {
        final bar = widget.bar;
        final pill = bar.minimized
            ? MinimizedFloatingBar(bar: bar, child: _currentToolButton(context))
            : _pill(context, axis: axis, buttonPadding: buttonPadding);
        if (bar.docked) {
          return Flex(
            direction: isToolbarVertical ? Axis.horizontal : Axis.vertical,
            mainAxisSize: .min,
            textDirection: switch (alignment) {
              AxisDirection.left => .rtl,
              AxisDirection.right => .ltr,
              _ => null,
            },
            verticalDirection: switch (alignment) {
              AxisDirection.down => VerticalDirection.down,
              AxisDirection.up => VerticalDirection.up,
              _ => VerticalDirection.down,
            },
            children: [..._subBars(context, axis), pill],
          );
        }

        // Moved or minimized: the secondary bars (e.g. the selection's
        // actions) open next to it, toward the middle of the screen
        final position = bar.position ?? Toolbar.defaultPosition(alignment);
        final barsFirst = isToolbarVertical
            ? position.dx > 0.5
            : position.dy > 0.5;
        return CustomMultiChildLayout(
          delegate: _FloatingToolbarLayout(
            position,
            vertical: isToolbarVertical,
            barsFirst: barsFirst,
          ),
          children: [
            LayoutId(
              id: _Slot.bars,
              child: Flex(
                direction: isToolbarVertical ? Axis.horizontal : Axis.vertical,
                mainAxisSize: .min,
                textDirection: barsFirst ? .ltr : .rtl,
                verticalDirection: barsFirst ? .down : .up,
                children: _subBars(context, axis),
              ),
            ),
            LayoutId(id: _Slot.pill, child: pill),
          ],
        );
      },
    );
  }

  /// The export bar, pen types or selection bar, and text formatting,
  /// ordered away from the main pill.
  List<Widget> _subBars(BuildContext context, Axis axis) {
    final c = context.higan;
    final isToolbarVertical = axis == .vertical;
    final collapsibleAxis = isToolbarVertical
        ? CollapsibleAxis.horizontal
        : CollapsibleAxis.vertical;

    /// A floating glass panel for a secondary bar,
    /// with a gap between it and the main pill.
    Widget panel(Widget child) => Padding(
      padding: isToolbarVertical
          ? const .symmetric(horizontal: 4)
          : const .symmetric(vertical: 4),
      child: HiganPill(height: null, padding: const .all(5), child: child),
    );

    return [
      ValueListenableBuilder(
        valueListenable: showExportOptions,
        builder: (context, showExportOptions, child) {
          return Collapsible(
            axis: collapsibleAxis,
            maintainState: true,
            collapsed: !showExportOptions,
            child: child!,
          );
        },
        child: panel(
          ExportBar(
            axis: axis,
            toggleExportBar: toggleExportBar,
            exportAsSba: widget.exportAsSba,
            exportAsPdf: widget.exportAsPdf,
            exportAsPng: widget.exportAsPng,
          ),
        ),
      ),
      ValueListenableBuilder(
        valueListenable: toolOptionsType,
        builder: (context, toolOptionsType, _) {
          return Collapsible(
            axis: collapsibleAxis,
            maintainState: true,
            collapsed: toolOptionsType == .hide,
            child: switch (toolOptionsType) {
              .hide => const SizedBox.square(dimension: SizePicker.smallLength),
              .pen => panel(
                PenModal(
                  getTool: () => Pen.currentPen,
                  setTool: widget.setTool,
                ),
              ),
              .select => panel(
                SelectionBar(
                  axis: axis,
                  duplicateSelection: widget.duplicateSelection,
                  deleteSelection: widget.deleteSelection,
                ),
              ),
            },
          );
        },
      ),
      ValueListenableBuilder(
        valueListenable: widget.quillFocus,
        builder: (context, quill, _) {
          final baseButtonStyle =
              IconButtonTheme.of(context).style ?? const ButtonStyle();

          final iconTheme = QuillIconTheme(
            iconButtonUnselectedData: IconButtonData(
              style: baseButtonStyle.copyWith(
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
                foregroundColor: WidgetStateProperty.all(c.textSecondary),
                iconColor: WidgetStateProperty.all(c.textSecondary),
              ),
            ),
            iconButtonSelectedData: IconButtonData(
              style: baseButtonStyle.copyWith(
                backgroundColor: WidgetStateProperty.all(
                  c.text.withValues(alpha: 0.1),
                ),
                foregroundColor: WidgetStateProperty.all(c.text),
                iconColor: WidgetStateProperty.all(c.text),
              ),
            ),
          );
          return Collapsible(
            axis: collapsibleAxis,
            maintainState: false,
            collapsed: !widget.textEditing || quill == null,
            child: quill != null
                ? panel(
                    QuillSimpleToolbar(
                      controller: quill.controller,
                      config: QuillSimpleToolbarConfig(
                        axis: axis,
                        buttonOptions: QuillSimpleToolbarButtonOptions(
                          base: QuillToolbarBaseButtonOptions(
                            iconTheme: iconTheme,
                          ),
                        ),
                        // scrollable on Android and iOS
                        multiRowsDisplay:
                            !Platform.isAndroid && !Platform.isIOS,
                        showUndo: false,
                        showRedo: false,
                        showFontSize: false,
                        showFontFamily: false,
                        showClearFormat: false,
                        showDividers: false,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
    ];
  }

  /// The main pill: a grip, the user's items (see [ToolCatalog]),
  /// then "+" and minimize.
  Widget _pill(
    BuildContext context, {
    required Axis axis,
    required EdgeInsets buttonPadding,
  }) {
    final isToolbarVertical = axis == .vertical;
    return HiganPill(
      key: widget.bar.pillKey,
      height: null,
      padding: isToolbarVertical
          ? const .fromLTRB(4, 2, 4, 6)
          : const .fromLTRB(2, 4, 10, 4),
      child: Flex(
        direction: axis,
        mainAxisSize: .min,
        children: [
          FloatingBarGrip(bar: widget.bar, axis: axis),
          Flexible(
            child: ListenableBuilder(
              // pen favorites change the toolbar's length
              listenable: Listenable.merge([
                stows.editorToolbarItems,
                stows.penPresets,
              ]),
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) => _runs(
                  _buttonGroups(context, buttonPadding: buttonPadding),
                  axis: axis,
                  buttonPadding: buttonPadding,
                  available: isToolbarVertical
                      ? constraints.maxHeight
                      : constraints.maxWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The toolbar's items, grouped by neighbouring items' category,
  /// then "+" and minimize.
  List<List<_Button>> _buttonGroups(
    BuildContext context, {
    required EdgeInsets buttonPadding,
  }) {
    // Long-press shows an item's menu (with its name) instead
    final itemTooltips = TooltipTheme.of(context)
        .copyWith(triggerMode: TooltipTriggerMode.manual);
    final groups = <List<_Button>>[];
    ToolCategory? category;
    for (final item in ToolCatalog.current) {
      if (item.category != category) groups.add([]);
      category = item.category;
      groups.last.add((
        span: item.span?.call() ?? 1,
        widget: ControlClick(
          onClick: (position) => _showItemMenu(item, position),
          child: GestureDetector(
            onLongPressStart: (details) =>
                _showItemMenu(item, details.globalPosition),
            onSecondaryTapUp: (details) =>
                _showItemMenu(item, details.globalPosition),
            child: TooltipTheme(
              data: itemTooltips,
              child: item.build(.new(context, this, item, buttonPadding)),
            ),
          ),
        ),
      ));
    }
    final c = context.higan;
    groups.add([
      for (final widget in [
        ToolbarIconButton(
          tooltip: t.editor.customizeToolbar.customize,
          onPressed: () => showCustomizeToolbarSheet(context),
          padding: buttonPadding,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: .circle,
              border: Border.all(color: c.hairlineStrong),
            ),
            child: const SizedBox.square(
              dimension: 24,
              child: Icon(Symbols.add, size: 16),
            ),
          ),
        ),
        MinimizeBarButton(bar: widget.bar, padding: buttonPadding),
      ])
        (span: 1, widget: widget),
    ]);
    return groups;
  }

  void _showItemMenu(ToolbarItem item, Offset position) => showBarMenu(
    context,
    position,
    title: item.label(),
    actions: [
      (
        t.editor.customizeToolbar.removeFromToolbar,
        () => ToolCatalog.remove(item.id),
      ),
    ],
  );

  /// One run of [groups] if they fit in [available], else as few runs as
  /// needed, about the same length (e.g. on phones). Runs break between
  /// groups, so a divider never dangles at the end of a run, and inside a
  /// group only if it's longer than a run on its own.
  Widget _runs(
    List<List<_Button>> groups, {
    required Axis axis,
    required EdgeInsets buttonPadding,
    required double available,
  }) {
    Widget run(Iterable<List<_Button>> groups) => Wrap(
      direction: axis,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, group) in groups.indexed) ...[
          if (i > 0) ToolbarDivider(axis: axis),
          for (final button in group) button.widget,
        ],
      ],
    );

    final buttonExtent =
        ToolbarIconButton.size +
        (axis == .vertical ? buttonPadding.vertical : buttonPadding.horizontal);
    double extent(Iterable<List<_Button>> groups) =>
        groups.fold(
          0.0,
          (sum, group) =>
              sum +
              group.fold(0, (n, button) => n + button.span) * buttonExtent,
        ) +
        (groups.length - 1) * ToolbarDivider.extent(axis);

    if (extent(groups) <= available) return run(groups);

    /// [pieces] in order, starting a new run before one that would make
    /// the run longer than [limit].
    List<List<List<_Button>>> pack(List<List<_Button>> pieces, double limit) {
      final runs = [<List<_Button>>[]];
      for (final piece in pieces) {
        if (runs.last.isNotEmpty && extent([...runs.last, piece]) > limit) {
          runs.add([]);
        }
        runs.last.add(piece);
      }
      return runs;
    }

    // Groups longer than a run are split into runs of whole buttons
    final pieces = <List<_Button>>[];
    for (final group in groups) {
      pieces.add([]);
      for (final button in group) {
        if (pieces.last.isNotEmpty &&
            extent([
                  [...pieces.last, button],
                ]) >
                available) {
          pieces.add([]);
        }
        pieces.last.add(button);
      }
    }

    // The shortest limit that needs no more runs than [available] does,
    // so the runs are about even
    final count = pack(pieces, available).length;
    var low = pieces.map((piece) => extent([piece])).reduce(max);
    var high = max(low, available);
    for (var i = 0; i < 20; i++) {
      final mid = (low + high) / 2;
      if (pack(pieces, mid).length <= count) {
        high = mid;
      } else {
        low = mid;
      }
    }
    return Flex(
      direction: flipAxis(axis),
      mainAxisSize: .min,
      children: [for (final runGroups in pack(pieces, high)) run(runGroups)],
    );
  }

  /// The current tool's button, for the minimized toolbar.
  Widget _currentToolButton(BuildContext context) {
    final current = widget.currentTool;
    for (final item in ToolCatalog.items) {
      if (item.isCurrentTool?.call(current) ?? false) {
        return item.build(.new(context, this, item, .zero));
      }
    }
    return const Icon(Symbols.more_horiz);
  }

  @override
  void dispose() {
    DynamicMaterialApp.removeFullscreenListener(_setState);
    DynamicMaterialApp.setFullscreen(false, updateSystem: true);

    _removeKeybindings();
    super.dispose();
  }
}

enum ToolOptions { hide, pen, select }

/// A toolbar item's widget, [span] buttons long.
typedef _Button = ({Widget widget, int span});

/// What a [ToolbarItem] builds its button with.
class ToolbarItemContext {
  const new(this.context, this.state, this.item, this.padding);

  final BuildContext context;
  final ToolbarState state;
  final ToolbarItem item;
  final EdgeInsets padding;

  Toolbar get toolbar => state.widget;
  Tool get currentTool => toolbar.currentTool;
  bool get readOnly => toolbar.readOnly;

  /// For items that need more of the editor than [Toolbar] passes along.
  EditorState? get editor => context.findAncestorStateOfType<EditorState>();

  /// [label] with [item]'s keyboard shortcut on computers,
  /// e.g. "Highlighter (H)", or "Toggle finger drawing (⌘F)" on a Mac.
  String withShortcut(String label) {
    if (HiganTap.isTouch(context)) return label;
    if (ToolCatalog.shortcuts[item.id] case final key?) {
      label =
          '${label.replaceFirst(RegExp(r' \(.*\)$'), '')} (${key.keyLabel})';
    }
    if (Theme.of(context).platform != .macOS) return label;
    return label.replaceAll('Ctrl Shift ', '⇧⌘').replaceAll('Ctrl ', '⌘');
  }

  /// A toolbar button with [item]'s tooltip and icon by default.
  Widget button({
    required VoidCallback? onPressed,
    String? tooltip,
    bool selected = false,
    bool enabled = true,
    bool showDot = true,
    Widget? child,
  }) => ToolbarIconButton(
    tooltip: withShortcut(tooltip ?? item.label()),
    selected: selected,
    enabled: enabled,
    showDot: showDot,
    onPressed: onPressed,
    padding: padding,
    child: child ?? Icon(item.icon),
  );

  /// A button that selects [tool].
  Widget toolButton(Tool tool, {bool inReadOnly = false}) => button(
    selected: currentTool == tool,
    enabled: inReadOnly || !readOnly,
    onPressed: () => state.selectTool(tool),
  );
}

enum _Slot { pill, bars }

/// Puts a moved toolbar's pill at its position, with the secondary bars
/// next to it: before it if [barsFirst] (above, or left if [vertical]).
class _FloatingToolbarLayout extends MultiChildLayoutDelegate {
  new(this.position, {required this.vertical, required this.barsFirst});

  final FractionalOffset position;
  final bool vertical, barsFirst;

  @override
  void performLayout(Size size) {
    final loose = BoxConstraints.loose(size);
    final pill = layoutChild(_Slot.pill, loose);
    final pillOffset = Offset(
      (size.width - pill.width) * position.dx,
      (size.height - pill.height) * position.dy,
    );
    positionChild(_Slot.pill, pillOffset);

    final bars = layoutChild(_Slot.bars, loose);
    final offset = vertical
        ? Offset(
            barsFirst ? pillOffset.dx - bars.width : pillOffset.dx + pill.width,
            pillOffset.dy + (pill.height - bars.height) / 2,
          )
        : Offset(
            pillOffset.dx + (pill.width - bars.width) / 2,
            barsFirst
                ? pillOffset.dy - bars.height
                : pillOffset.dy + pill.height,
          );
    positionChild(
      _Slot.bars,
      Offset(
        offset.dx.clamp(0, max(0, size.width - bars.width)),
        offset.dy.clamp(0, max(0, size.height - bars.height)),
      ),
    );
  }

  @override
  bool shouldRelayout(_FloatingToolbarLayout oldDelegate) =>
      position != oldDelegate.position ||
      vertical != oldDelegate.vertical ||
      barsFirst != oldDelegate.barsFirst;
}
