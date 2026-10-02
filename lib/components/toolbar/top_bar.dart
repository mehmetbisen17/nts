import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/canvas/_calligraphy_stroke.dart';
import 'package:nts/components/canvas/inner_canvas.dart';
import 'package:nts/components/canvas/text_boxes.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/components/toolbar/color_bar.dart';
import 'package:nts/components/toolbar/color_option.dart';
import 'package:nts/components/toolbar/floating_bar.dart';
import 'package:nts/components/toolbar/size_picker.dart';
import 'package:nts/components/toolbar/toolbar_button.dart';
import 'package:nts/data/extensions/color_extensions.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/data/tools/calligraphy_pen.dart';
import 'package:nts/data/tools/eraser.dart';
import 'package:nts/data/tools/fill.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/i18n/strings.g.dart';

/// An always-visible bar at the top of the editor
/// with the current tool's color and size options.
class EditorTopBar extends StatelessWidget {
  const new({
    super.key,
    required this.currentTool,
    required this.setTool,
    required this.setColor,
    required this.readOnly,
    this.bar,
  });

  final Tool currentTool;
  final ValueChanged<Tool> setTool;
  final ValueChanged<Color> setColor;
  final bool readOnly;

  /// Where the bar is and whether it's minimized,
  /// or null for a bar that can't move.
  final FloatingBar? bar;

  /// Fixed so the canvas doesn't jump when switching tools.
  static const double height = 50;

  /// So the colors don't stretch across big screens.
  static const double maxWidth = 640;

  /// Where the minimized top bar goes if it hasn't been moved:
  /// the top, or the bottom if the toolbar is at the top.
  static FractionalOffset get defaultPosition =>
      stows.editorToolbarAlignment.value == .up
      ? FractionalOffset.bottomCenter
      : FractionalOffset.topCenter;

  @override
  Widget build(BuildContext context) {
    if (readOnly) return const SizedBox.shrink();
    final bar = this.bar;
    if (bar == null) return _build(context, null);
    return ListenableBuilder(
      listenable: bar,
      builder: (context, _) => _build(context, bar),
    );
  }

  Widget _build(BuildContext context, FloatingBar? bar) {
    final c = context.higan;
    final invert = InnerCanvas.invertOf(context);

    final color = switch (currentTool) {
      final Pen pen => pen.color,
      final Fill fill => fill.color,
      final Select select => select.getDominantStrokeColor(),
      Tool.textEditing => TextBoxes.color ?? Colors.black,
      _ => null,
    };
    final Widget? options = switch (currentTool) {
      final Pen pen => LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: ColorBar(
                axis: .horizontal,
                setColor: setColor,
                currentColor: pen.color,
                invert: invert,
              ),
            ),
            if (pen is CalligraphyPen) ...[
              const SizedBox(width: 6),
              const _NibAngleButton(),
            ],
            const SizedBox(width: 10),
            SizePicker(
              axis: .horizontal,
              pen: pen,
              // shorter on phones (and with the nib), leaving room for colors
              length:
                  (constraints.maxWidth / 4 -
                          (pen is CalligraphyPen ? _NibAngleButton.width : 0))
                      .clamp(60, SizePicker.largeLength),
            ),
          ],
        ),
      ),
      final Select select
          when select.doneSelecting && select.selectResult.strokes.isNotEmpty =>
        ColorBar(
          axis: .horizontal,
          setColor: setColor,
          currentColor: select.getDominantStrokeColor(),
          invert: invert,
        ),
      Select() => const _LassoOptions(),
      final Fill fill => ColorBar(
        axis: .horizontal,
        setColor: setColor,
        currentColor: fill.color,
        invert: invert,
      ),
      Eraser() => const _EraserOptions(),
      // The colour of the text box being typed in, and of new ones
      Tool.textEditing => ColorBar(
        axis: .horizontal,
        setColor: setColor,
        currentColor: TextBoxes.color ?? Colors.black,
        invert: invert,
      ),
      _ => null,
    };

    if (bar != null && bar.minimized) {
      if (options == null) return const SizedBox.shrink();
      return Align(
        alignment: bar.position ?? defaultPosition,
        child: MinimizedFloatingBar(
          bar: bar,
          child: color == null
              ? Icon(
                  currentTool is Select
                      ? Symbols.lasso_select
                      : Symbols.ink_eraser,
                  size: 19,
                  weight: 300,
                  color: c.textSecondary,
                )
              : CurrentColorDot(
                  color.withInversion(invert).withValues(alpha: 1),
                ),
        ),
      );
    }

    final pill = options == null
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: HiganPill(
              key: bar?.pillKey,
              height: height,
              padding: bar == null
                  ? const .symmetric(horizontal: 10)
                  : const .only(left: 2),
              child: Row(
                mainAxisSize: .min,
                children: [
                  if (bar != null) FloatingBarGrip(bar: bar),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: HiganMotion.fast,
                      child: KeyedSubtree(
                        key: ValueKey(options.runtimeType),
                        child: options,
                      ),
                    ),
                  ),
                  if (bar != null)
                    MinimizeBarButton(bar: bar, padding: const .only(left: 4)),
                ],
              ),
            ),
          );

    final position = bar?.position;
    if (position != null) {
      return Align(alignment: position, child: pill);
    }
    return SizedBox(
      height: height,
      child: pill == null ? null : Center(child: pill),
    );
  }
}

class _EraserOptions extends StatelessWidget {
  const new();

  static const double minSize = 2, maxSize = 60;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return Row(
      mainAxisSize: .min,
      children: [
        // Shrinks on narrow screens so the slider keeps its width.
        Flexible(
          child: FittedBox(
            fit: .scaleDown,
            child: ValueListenableBuilder(
              valueListenable: stows.eraserMode,
              builder: (context, mode, _) => SegmentedButton<EraserMode>(
                segments: [
                  ButtonSegment(
                    value: .stroke,
                    label: Text(t.editor.eraserOptions.wholeLine),
                  ),
                  ButtonSegment(
                    value: .partial,
                    label: Text(t.editor.eraserOptions.partial),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) =>
                    stows.eraserMode.value = selection.first,
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: .compact,
                  tapTargetSize: .shrinkWrap,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ValueListenableBuilder(
          valueListenable: stows.eraserSize,
          builder: (context, size, _) {
            size = size.clamp(minSize, maxSize);
            return Row(
              mainAxisSize: .min,
              children: [
                SizedBox(
                  width: 120,
                  child: Semantics(
                    label: t.editor.eraserOptions.size,
                    // Continuous (no divisions) so the thumb follows the
                    // finger at once: a discrete slider animates each step
                    child: Slider(
                      value: size,
                      min: minSize,
                      max: maxSize,
                      onChanged: (value) =>
                          stows.eraserSize.value = value.roundToDouble(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 22,
                  child: Text(
                    size.round().toString(),
                    style: HiganText.label(context, size: 10, color: c.text),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Freehand or rectangle lasso, see [Stows.lassoMode].
class _LassoOptions extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: .scaleDown,
      child: ValueListenableBuilder(
        valueListenable: stows.lassoMode,
        builder: (context, mode, _) => SegmentedButton<LassoMode>(
          segments: [
            ButtonSegment(
              value: .freehand,
              label: Text(t.editor.canvasTools.lassoFreehand),
            ),
            ButtonSegment(
              value: .rectangle,
              label: Text(t.editor.canvasTools.lassoRectangle),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) =>
              stows.lassoMode.value = selection.first,
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: .compact,
            tapTargetSize: .shrinkWrap,
          ),
        ),
      ),
    );
  }
}

/// The calligraphy pen's nib angle: the nib, turned, which opens
/// the angles (see [CalligraphyStroke.nibAnglePresets]).
class _NibAngleButton extends StatelessWidget {
  const new();

  /// With the gap before it.
  static const width = ToolbarIconButton.size + 6;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: stows.calligraphyNibAngle,
      builder: (context, angle, _) => ToolbarIconButton(
        tooltip: t.editor.canvasTools.nibAngle(angle: angle.round()),
        padding: .zero,
        showDot: false,
        onPressed: () {
          final box = context.findRenderObject()! as RenderBox;
          showBarMenu(
            context,
            box.localToGlobal(box.size.bottomCenter(Offset.zero)),
            title: t.editor.canvasTools.nibAngle(angle: angle.round()),
            actions: [
              for (final preset in CalligraphyStroke.nibAnglePresets)
                (
                  '${preset.round()}°',
                  () => stows.calligraphyNibAngle.value = preset,
                ),
            ],
          );
        },
        child: _Nib(angle: angle),
      ),
    );
  }
}

class _Nib extends StatelessWidget {
  const new({required this.angle});

  /// In degrees, anticlockwise.
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -angle * pi / 180,
      child: SizedBox(
        width: 18,
        height: 3,
        child: ColoredBox(color: IconTheme.of(context).color!),
      ),
    );
  }
}
