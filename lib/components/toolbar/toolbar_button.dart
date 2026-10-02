import 'package:flutter/material.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';

/// A thin outline icon button for the editor's floating toolbars:
/// ash normally, bone when [selected], with a small red dot below
/// if it's the selected tool ([showDot]).
class ToolbarIconButton extends StatelessWidget {
  const new({
    super.key,
    this.tooltip,
    this.selected = false,
    this.enabled = true,
    this.showDot = true,
    required this.onPressed,
    required this.padding,
    required this.child,
  });

  final String? tooltip;
  final bool selected;
  final bool enabled;

  /// False for on/off toggles (e.g. finger drawing): the red dot only
  /// marks the one selected tool.
  final bool showDot;
  final VoidCallback? onPressed;

  final EdgeInsets padding;
  final Widget child;

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final active = enabled && onPressed != null;
    final color = !active
        ? c.textTertiary
        : selected
        ? c.text
        : c.textSecondary;

    return Padding(
      padding: padding,
      child: Stack(
        alignment: .bottomCenter,
        children: [
          IconButton(
            style: ButtonStyle(
              fixedSize: const WidgetStatePropertyAll(Size.square(size)),
              visualDensity: VisualDensity.standard,
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              iconSize: const WidgetStatePropertyAll(19),
              foregroundColor: WidgetStatePropertyAll(color),
              iconColor: WidgetStatePropertyAll(color),
              backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
              tapTargetSize: .shrinkWrap,
              mouseCursor: WidgetStateMouseCursor.clickable,
            ),
            onPressed: active ? onPressed : null,
            tooltip: tooltip,
            isSelected: selected,
            icon: IconTheme.merge(
              data: const IconThemeData(weight: 300, opticalSize: 20),
              child: child,
            ),
          ),
          Positioned(
            bottom: 3,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: selected && active && showDot ? 1 : 0,
                duration: HiganMotion.fast,
                child: SizedBox.square(
                  dimension: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: c.higan, shape: .circle),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A hairline between groups of toolbar buttons.
class ToolbarDivider extends StatelessWidget {
  const new({super.key, required this.axis});

  /// The toolbar's axis: a horizontal toolbar gets a vertical line.
  final Axis axis;

  static const _gapHorizontal = 6.0, _gapVertical = 4.0;

  /// Its length along the toolbar's [axis], gaps included.
  static double extent(Axis axis) =>
      1 + 2 * (axis == .horizontal ? _gapHorizontal : _gapVertical);

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == .horizontal;
    return Padding(
      padding: horizontal
          ? const .symmetric(horizontal: _gapHorizontal)
          : const .symmetric(vertical: _gapVertical),
      child: SizedBox(
        width: horizontal ? 1 : 18,
        height: horizontal ? 18 : 1,
        child: ColoredBox(color: context.higan.hairlineStrong),
      ),
    );
  }
}
