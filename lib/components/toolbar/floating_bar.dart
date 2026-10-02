import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/components/toolbar/toolbar_button.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/i18n/strings.g.dart';

/// Where one of the editor's floating bars (the toolbar or the top bar) is
/// and whether it's minimized, saved in [stows].
///
/// A bar is [docked] in its default place until it's dragged by its
/// [FloatingBarGrip] or minimized. Then the editor puts it above the page,
/// in an area of its own size inset by [insets], and the bar positions
/// itself at [position].
class FloatingBar extends ChangeNotifier {
  new(this.id, {required this.areaKey});

  /// E.g. 'toolbar'. Part of the saved keys.
  final String id;

  /// The editor's area for floating bars, used to measure drags.
  final GlobalKey areaKey;

  /// For the bar's widget, so it keeps its state (e.g. keybindings and a
  /// drag in progress) when it moves between docked and floating.
  final key = GlobalKey();

  /// For the bar's pill and its minimized circle, to measure them.
  final pillKey = GlobalKey(), circleKey = GlobalKey();

  /// Margins and system insets around the floating area. Set by the editor.
  var insets = EdgeInsets.zero;

  /// Phones (and narrow windows) remember their own positions.
  /// Set by the editor.
  var compact = false;

  String get _key => '$id.${compact ? 'compact' : 'wide'}';

  /// The top-left of the bar as a fraction of the free space around it
  /// (like [Align]), so it stays on screen when the window resizes.
  /// Null when it hasn't been moved.
  FractionalOffset? get position {
    if (_dragPosition != null) return _dragPosition;
    final saved = stows.editorBarPositions.value[_key];
    if (saved == null || saved.length != 2) return null;
    return FractionalOffset(saved[0].clamp(0, 1), saved[1].clamp(0, 1));
  }

  bool get minimized => stows.editorMinimizedBars.value.contains(id);
  set minimized(bool value) {
    if (value == minimized) return;
    stows.editorMinimizedBars.value = [
      for (final other in stows.editorMinimizedBars.value)
        if (other != id) other,
      if (value) id,
    ];
    notifyListeners();
  }

  /// In its default place in the editor's layout.
  bool get docked => position == null && !minimized;

  void resetPosition() {
    stows.editorBarPositions.value = {...stows.editorBarPositions.value}
      ..remove(_key);
    notifyListeners();
  }

  FractionalOffset? _dragPosition;
  var _dragStart = Offset.zero;
  var _dragDelta = Offset.zero;
  var _free = Size.zero;

  void onDragStart(DragStartDetails _) {
    final area = areaKey.currentContext?.findRenderObject() as RenderBox?;
    final bar =
        (minimized ? circleKey : pillKey).currentContext?.findRenderObject()
            as RenderBox?;
    if (area == null || bar == null || !bar.attached) return;

    final safe = insets.deflateRect(Offset.zero & area.size);
    _dragStart = bar.localToGlobal(.zero, ancestor: area) - safe.topLeft;
    _dragDelta = .zero;
    _free = Size(
      (safe.width - bar.size.width).clamp(0, double.infinity),
      (safe.height - bar.size.height).clamp(0, double.infinity),
    );
    _dragPosition = fractionOf(_dragStart, _free);
    notifyListeners();
  }

  void onDragUpdate(DragUpdateDetails details) {
    if (_dragPosition == null) return;
    _dragDelta += details.delta;
    _dragPosition = fractionOf(_dragStart + _dragDelta, _free);
    notifyListeners();
  }

  void onDragEnd([DragEndDetails? _]) {
    final dragged = _dragPosition;
    if (dragged == null) return;
    _dragPosition = null;
    stows.editorBarPositions.value = {
      ...stows.editorBarPositions.value,
      _key: [dragged.dx, dragged.dy],
    };
    notifyListeners();
  }

  /// [topLeft] as a fraction of [free] (the room around the bar), kept on
  /// screen and snapped to the edges and middle when within [snap] pixels.
  static FractionalOffset fractionOf(
    Offset topLeft,
    Size free, {
    double snap = 12,
  }) {
    double along(double value, double room) {
      if (room <= 0) return 0.5;
      value = value.clamp(0, room);
      if (value < snap) return 0;
      if (room - value < snap) return 1;
      if ((value - room / 2).abs() < snap) return 0.5;
      return value / room;
    }

    return FractionalOffset(
      along(topLeft.dx, free.width),
      along(topLeft.dy, free.height),
    );
  }

  /// Minimize and reset, for a long-press or right-click on the grip.
  void openMenu(BuildContext context, Offset globalPosition) => showBarMenu(
    context,
    globalPosition,
    actions: [
      (t.editor.floatingBar.minimize, () => minimized = true),
      if (position != null) (t.editor.floatingBar.resetPosition, resetPosition),
    ],
  );
}

/// A small popup menu at [globalPosition], e.g. for a long-pressed button.
Future<void> showBarMenu(
  BuildContext context,
  Offset globalPosition, {
  String? title,
  required List<(String label, VoidCallback onSelected)> actions,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final selected = await showMenu<VoidCallback>(
    context: context,
    position: RelativeRect.fromRect(
      globalPosition & Size.zero,
      Offset.zero & overlay.size,
    ),
    items: [
      if (title != null)
        PopupMenuItem(enabled: false, height: 32, child: HiganLabel(title)),
      for (final (label, onSelected) in actions)
        PopupMenuItem(value: onSelected, child: Text(label)),
    ],
  );
  selected?.call();
}

/// Six dots at the start of a floating bar: drag to move the bar,
/// double-tap to put it back, long-press or right-click for a menu.
class FloatingBarGrip extends StatelessWidget {
  const new({super.key, required this.bar, this.axis = .horizontal});

  final FloatingBar bar;

  /// The bar's axis.
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == .horizontal;
    // Wide enough for a finger on touch screens
    final thickness = HiganTap.isTouch(context) ? HiganTap.min : 20.0;
    return Tooltip(
      message: t.editor.floatingBar.move,
      // long-press opens the menu instead (mouse hover still works)
      triggerMode: .manual,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: ControlClick(
          onClick: (position) => bar.openMenu(context, position),
          child: GestureDetector(
            behavior: .opaque,
            onPanStart: bar.onDragStart,
            onPanUpdate: bar.onDragUpdate,
            onPanEnd: bar.onDragEnd,
            onDoubleTap: bar.resetPosition,
            onLongPressStart: (details) =>
                bar.openMenu(context, details.globalPosition),
            onSecondaryTapUp: (details) =>
                bar.openMenu(context, details.globalPosition),
            child: SizedBox(
              width: horizontal ? thickness : 40,
              height: horizontal ? 40 : thickness,
              child: RotatedBox(
                quarterTurns: horizontal ? 0 : 1,
                child: Icon(
                  Symbols.drag_indicator,
                  size: 16,
                  weight: 300,
                  color: context.higan.textTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A minimized floating bar: a small glass circle showing [child].
/// Tap to restore, drag to move, long-press or right-click for a menu.
class MinimizedFloatingBar extends StatelessWidget {
  const new({super.key, required this.bar, required this.child});

  final FloatingBar bar;
  final Widget child;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    void showMenu(Offset position) => showBarMenu(
      context,
      position,
      actions: [
        (t.editor.floatingBar.restore, () => bar.minimized = false),
        if (bar.position != null)
          (t.editor.floatingBar.resetPosition, bar.resetPosition),
      ],
    );

    return Semantics(
      button: true,
      label: t.editor.floatingBar.restore,
      child: Tooltip(
        message: t.editor.floatingBar.restore,
        triggerMode: .manual,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ControlClick(
            onClick: showMenu,
            child: GestureDetector(
              key: bar.circleKey,
              behavior: .opaque,
              onTap: () => bar.minimized = false,
              onPanStart: bar.onDragStart,
              onPanUpdate: bar.onDragUpdate,
              onPanEnd: bar.onDragEnd,
              onLongPressStart: (details) => showMenu(details.globalPosition),
              onSecondaryTapUp: (details) => showMenu(details.globalPosition),
              child: HiganPill(
                height: size,
                padding: .zero,
                child: SizedBox(
                  width: size - 2, // minus the border
                  child: Center(child: IgnorePointer(child: child)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small button to minimize a floating bar.
class MinimizeBarButton extends StatelessWidget {
  const new({super.key, required this.bar, required this.padding});

  final FloatingBar bar;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ToolbarIconButton(
    tooltip: t.editor.floatingBar.minimize,
    onPressed: () => bar.minimized = true,
    padding: padding,
    child: const Icon(Symbols.collapse_content),
  );
}
