import 'package:flutter/material.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';

/// An 18px swatch; when selected, a thin bone ring sits 2px outside it.
/// Taps anywhere in the 30px circle around it (44px on touch screens).
class ColorOption extends StatelessWidget {
  const new({
    super.key,
    required this.isSelected,
    this.enabled = true,
    this.onTap,
    this.onLongPress,
    required this.tooltip,
    required this.child,
  });

  final bool isSelected;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final Widget child;

  static const double diameter = 24;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final onLongPress = enabled ? this.onLongPress : null;
    return Tooltip(
      message: tooltip ?? '',
      child: ControlClick(
        onClick: onLongPress == null ? null : (_) => onLongPress(),
        child: HiganTapTarget(
          onTap: enabled ? onTap : null,
          child: HiganFocusRing(
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onTap : null,
              onLongPress: onLongPress,
              onSecondaryTap: onLongPress,
              child: Padding(
                padding: const .all(3),
                child: AnimatedContainer(
                  duration: HiganMotion.fast,
                  width: diameter,
                  height: diameter,
                  padding: const .all(2),
                  decoration: BoxDecoration(
                    shape: .circle,
                    border: Border.all(
                      color: isSelected ? c.text : Colors.transparent,
                    ),
                  ),
                  child: AnimatedOpacity(
                    opacity: enabled ? 1 : 0.4,
                    duration: HiganMotion.fast,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The current [color] as an 18px dot in a bone ring, like a selected
/// [ColorOption], so it shows even when it's the glass's own color
/// (black in Night, white in Paper).
class CurrentColorDot extends StatelessWidget {
  const new(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return Container(
      width: ColorOption.diameter,
      height: ColorOption.diameter,
      padding: const .all(2),
      decoration: BoxDecoration(
        shape: .circle,
        border: Border.all(color: c.text),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: .circle,
          border: Border.all(color: c.hairlineStrong),
        ),
      ),
    );
  }
}

/// A hairline between groups of colors.
class ColorOptionSeparator extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 8),
      child: SizedBox(
        width: 1,
        height: 18,
        child: ColoredBox(color: context.higan.hairlineStrong),
      ),
    );
  }
}
