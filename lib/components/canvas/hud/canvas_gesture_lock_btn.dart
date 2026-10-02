import 'package:flutter/material.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';

class CanvasGestureLockBtn extends StatelessWidget {
  /// Either [icon] or [child] must be provided.
  /// If both are provided, [child] will be used.
  /// If [child] is provided, you are required to handle the animation.
  const new({
    super.key,
    required this.lock,
    required this.setLock,
    required this.tooltip,
    this.icon,
    this.child,
  }) : assert(icon != null || child != null);

  final bool lock;
  final ValueChanged<bool> setLock;
  final String tooltip;
  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return Tooltip(
      message: tooltip,
      child: HiganTapTarget(
        onTap: () => setLock(!lock),
        child: Material(
          color: c.glass,
          shape: CircleBorder(side: BorderSide(color: c.hairlineStrong)),
          clipBehavior: .antiAlias,
          child: InkWell(
            onTap: () => setLock(!lock),
            child: SizedBox.square(
              dimension: 32,
              child: IconTheme.merge(
                // Locked reads as "on": bone/ink, otherwise quiet.
                data: IconThemeData(
                  size: 16,
                  weight: 300,
                  color: lock ? c.text : c.textSecondary,
                ),
                child:
                    child ??
                    AnimatedSwitcher(
                      duration: HiganMotion.fast,
                      child: Icon(icon, key: ValueKey(icon)),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
