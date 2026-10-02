import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/canvas/side_hit_region.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/extensions/color_extensions.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:sbn/font_fallbacks.dart';

/// What text boxes need from the editor: [edit] replaces a page's boxes
/// as they're typed in or moved, and [record] makes the changes since
/// `before` one step in the undo history.
/// [reveal] scrolls a box (its global rect) into view, e.g. above the
/// keyboard.
typedef TextBoxCallbacks = ({
  void Function(int pageIndex, List<PageTextBox> boxes) edit,
  void Function(int pageIndex, List<PageTextBox> before) record,
  void Function(Rect globalRect) reveal,
});

/// The state the text boxes share with the editor.
abstract final class TextBoxes {
  /// The box being typed in, as (page index, id).
  static final focused = ValueNotifier<(int, int)?>(null);

  /// Ends typing in the focused box right away, recording it in the undo
  /// history (focus changes are only reported later). Null if none.
  static VoidCallback? commit;

  /// The colour for new boxes, from the colour bar (null for the
  /// default ink).
  static Color? color;

  /// A box just made by a tap, to type in as soon as it's built, and the
  /// page's boxes before it (for undo).
  static ({int pageIndex, int id, List<PageTextBox> before})? pending;

  /// How wide a new box is, unless that would run off its area.
  static const newWidth = 420.0;

  /// The text's style: the typed-text font, on ruled lines.
  static TextStyle styleOf(PageTextBox box, {required bool invert}) =>
      TextStyle(
        inherit: false,
        fontFamily: 'Neucha',
        fontFamilyFallback: ntsHandwritingFontFallbacks,
        fontSize: box.fontSize,
        height: PageTextBox.lineSpacing,
        color: (box.color ?? Colors.black).withInversion(invert),
        decoration: TextDecoration.none,
        textBaseline: TextBaseline.alphabetic,
      );

  static final _bounds = Expando<Rect>();

  /// Where [box]'s text is, with its lines wrapped.
  static Rect boundsOf(PageTextBox box) => _bounds[box] ??= () {
    final painter = TextPainter(
      text: TextSpan(
        text: box.text.isEmpty ? ' ' : box.text,
        style: styleOf(box, invert: false),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: box.width);
    final size = painter.size;
    painter.dispose();
    return box.position & Size(box.width, size.height);
  }();
}

/// A page's text boxes. In [editing] (the Text tool), they can be typed
/// in and moved by their grips, with a finger, the Pencil or a mouse;
/// otherwise they're plain text that ink goes over.
class TextBoxLayer extends StatelessWidget {
  const new({
    super.key,
    required this.page,
    required this.pageIndex,
    required this.editing,
    required this.invert,
    this.callbacks,
  });

  final EditorPage page;
  final int pageIndex;
  final bool editing;
  final bool invert;
  final TextBoxCallbacks? callbacks;

  @override
  Widget build(BuildContext context) {
    final callbacks = this.callbacks;
    return Stack(
      clipBehavior: .none,
      children: [
        for (final box in page.textBoxes)
          if (editing && callbacks != null)
            _EditableTextBox(
              key: ValueKey(box.id),
              box: box,
              page: page,
              pageIndex: pageIndex,
              invert: invert,
              callbacks: callbacks,
            )
          else
            Positioned(
              left: box.position.dx,
              top: box.position.dy,
              width: box.width,
              child: IgnorePointer(
                child: Text(
                  box.text,
                  style: TextBoxes.styleOf(box, invert: invert),
                ),
              ),
            ),
      ],
    );
  }
}

class _EditableTextBox extends StatefulWidget {
  const new({
    super.key,
    required this.box,
    required this.page,
    required this.pageIndex,
    required this.invert,
    required this.callbacks,
  });

  final PageTextBox box;
  final EditorPage page;
  final int pageIndex;
  final bool invert;
  final TextBoxCallbacks callbacks;

  @override
  State<_EditableTextBox> createState() => _EditableTextBoxState();
}

class _EditableTextBoxState extends State<_EditableTextBox> {
  late final controller = TextEditingController(text: widget.box.text);
  final focusNode = FocusNode(debugLabel: 'TextBox');

  /// The page's boxes when this edit (typing or a move) started.
  List<PageTextBox>? _before;

  PageTextBox get box => widget.box;

  /// This box as it is on the page now: newer than [box] when several
  /// moves (or keys) come before the next frame.
  PageTextBox get _current => widget.page.textBoxes.firstWhere(
    (other) => other.id == box.id,
    orElse: () => box,
  );

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_onFocus);
    final pending = TextBoxes.pending;
    if (pending != null &&
        pending.pageIndex == widget.pageIndex &&
        pending.id == box.id) {
      TextBoxes.pending = null;
      _before = pending.before;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(_EditableTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Undo and redo change the text from outside
    if (box.text != controller.text && !focusNode.hasFocus) {
      controller.text = box.text;
    }
  }

  @override
  void dispose() {
    // Typing (or a move) ends when the Text tool is put down
    if (_before != null) _endEdit();
    focusNode.dispose();
    controller.dispose();
    super.dispose();
  }

  /// The keyboard's height when this was last laid out.
  double? _keyboard;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The keyboard came up (or changed): keep the box above it
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboard != _keyboard) {
      _keyboard = keyboard;
      if (focusNode.hasFocus) _revealSoon();
    }
  }

  /// Scrolls this box into view after the next layout.
  void _revealSoon() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final box = context.findRenderObject() as RenderBox?;
    if (!mounted || box == null || !box.attached) return;
    widget.callbacks.reveal(box.localToGlobal(Offset.zero) & box.size);
  });

  void _onFocus() {
    if (focusNode.hasFocus) {
      _before ??= widget.page.textBoxes;
      TextBoxes.focused.value = (widget.pageIndex, box.id);
      TextBoxes.commit = _commit;
      _revealSoon();
    } else {
      _endEdit();
    }
    if (mounted) setState(() {});
  }

  void _commit() {
    _endEdit();
    focusNode.unfocus();
  }

  void _endEdit() {
    final before = _before;
    // Already ended (e.g. by [_commit], then its late unfocus): the box
    // with this id may be a new one by now
    if (before == null) return;
    _before = null;
    if (TextBoxes.focused.value == (widget.pageIndex, box.id)) {
      TextBoxes.focused.value = null;
    }
    if (TextBoxes.commit == _commit) TextBoxes.commit = null;
    // An empty box goes away
    if (controller.text.trim().isEmpty) {
      _replace(null);
    }
    widget.callbacks.record(widget.pageIndex, before);
  }

  /// Replaces this box on its page with [newBox] (or removes it).
  void _replace(PageTextBox? newBox) =>
      widget.callbacks.edit(widget.pageIndex, [
        for (final other in widget.page.textBoxes)
          if (other.id != box.id) other else ?newBox,
      ]);

  void _startMove() => _before ??= widget.page.textBoxes;
  void _endMove() {
    if (focusNode.hasFocus) return; // recorded when typing ends
    final before = _before;
    _before = null;
    if (before != null) widget.callbacks.record(widget.pageIndex, before);
  }

  /// Keeps a box on its page or in the space beside it.
  Offset _clamp(Offset position) {
    final area = widget.page.areaWithSides;
    return Offset(
      position.dx.clamp(area.left, max(area.left, area.right - box.width)),
      position.dy.clamp(0, max(0, area.bottom - box.fontSize)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = HiganColors.of(context);
    final focused = focusNode.hasFocus;
    final style = TextBoxes.styleOf(box, invert: widget.invert);
    final strings = t.nts.textBox;

    final Widget grip = _Handle(
      tooltip: strings.move,
      cursor: SystemMouseCursors.grab,
      onStart: _startMove,
      onUpdate: (delta) => _replace(
        _current.copyWith(position: _clamp(_current.position + delta)),
      ),
      onEnd: _endMove,
      child: Icon(Symbols.drag_indicator, size: 18, color: c.text),
    );

    return Positioned(
      left: box.position.dx,
      top: box.position.dy,
      width: box.width,
      child: SideHittable(
        child: Stack(
          clipBehavior: .none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: focused
                      ? c.higan.withValues(alpha: 0.7)
                      : c.textTertiary.withValues(alpha: 0.5),
                  width: focused ? 1.5 : 1,
                ),
                borderRadius: const .all(.circular(4)),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                style: style,
                cursorColor: c.higan,
                keyboardAppearance: widget.invert ? .dark : .light,
                decoration: InputDecoration.collapsed(
                  hintText: strings.hint,
                  hintStyle: style.copyWith(
                    color: style.color?.withValues(alpha: 0.35),
                  ),
                ),
                onChanged: (text) {
                  _replace(_current.copyWith(text: text));
                  _revealSoon(); // e.g. a new line under the keyboard
                },
                // Panning the page, or tapping a bar, keeps typing going
                onTapOutside: (_) {},
              ),
            ),
            // The grip, outside the top left, always there to move it
            // (Each outside the box can be touched there too)
            Positioned(left: -40, top: 0, child: SideHittable(child: grip)),
            if (focused) ...[
              // Text size and delete, above the box
              Positioned(
                left: 0,
                top: -48,
                child: SideHittable(
                  child: _Bar(
                    children: [
                      _BarButton(
                        tooltip: strings.smaller,
                        icon: Symbols.text_decrease,
                        onPressed: () {
                          _before ??= widget.page.textBoxes;
                          _replace(
                            _current.copyWith(
                              fontSize: max(12, _current.fontSize / 1.15),
                            ),
                          );
                        },
                      ),
                      _BarButton(
                        tooltip: strings.bigger,
                        icon: Symbols.text_increase,
                        onPressed: () {
                          _before ??= widget.page.textBoxes;
                          _replace(
                            _current.copyWith(
                              fontSize: min(120, _current.fontSize * 1.15),
                            ),
                          );
                        },
                      ),
                      _BarButton(
                        tooltip: strings.delete,
                        icon: Symbols.delete,
                        onPressed: () {
                          controller.clear();
                          focusNode.unfocus();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // Drag the right edge to change the width
              Positioned(
                right: -22,
                top: 0,
                bottom: 0,
                child: Center(
                  child: SideHittable(
                    child: _Handle(
                      tooltip: strings.width,
                      cursor: SystemMouseCursors.resizeLeftRight,
                      onStart: _startMove,
                      onUpdate: (delta) => _replace(
                        _current.copyWith(
                          width: max(
                            PageTextBox.minWidth,
                            _current.width + delta.dx,
                          ),
                        ),
                      ),
                      onEnd: _endMove,
                      child: Container(
                        width: 6,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c.higan.withValues(alpha: 0.8),
                          borderRadius: const .all(.circular(3)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Something to drag (in page units) without taking the keyboard away,
/// with a finger, the Pencil or a mouse.
class _Handle extends StatelessWidget {
  const new({
    required this.tooltip,
    required this.cursor,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.child,
  });

  final String tooltip;
  final MouseCursor cursor;
  final VoidCallback onStart, onEnd;
  final ValueChanged<Offset> onUpdate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = HiganColors.of(context);
    return Tooltip(
      message: tooltip,
      triggerMode: .manual,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: .opaque,
          dragStartBehavior: DragStartBehavior.down,
          // A tap on it isn't a tap on the page (which starts a box)
          onTap: () {},
          onPanStart: (_) => onStart(),
          onPanUpdate: (details) => onUpdate(details.delta),
          onPanEnd: (_) => onEnd(),
          onPanCancel: onEnd,
          child: Container(
            width: 36,
            height: 36,
            alignment: .center,
            decoration: BoxDecoration(
              color: c.surface2.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(color: c.hairlineStrong),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = HiganColors.of(context);
    // A tap between its buttons isn't a tap on the page
    return GestureDetector(
      behavior: .opaque,
      onTap: () {},
      child: _decorated(c),
    );
  }

  Widget _decorated(HiganColors c) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: const .all(.circular(HiganRadius.pill)),
        border: Border.all(color: c.hairlineStrong),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 4),
        child: Row(mainAxisSize: .min, children: children),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const new({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: .compact,
    icon: Icon(icon, size: 18, color: HiganColors.of(context).text),
  );
}
