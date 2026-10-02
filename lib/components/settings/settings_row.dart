import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';

/// One settings row: title (italic when changed from its default) and
/// subtitle on the left, [trailing] on the right, a hairline below.
class SettingsRow extends StatelessWidget {
  const new({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.wide = false,
    this.modified = false,
    this.showChevron = false,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// A wide [trailing] (e.g. a segmented control) moves below the text
  /// when the row is narrow.
  final bool wide;
  final bool modified;
  final bool showChevron;
  final VoidCallback? onTap, onLongPress;

  static const _narrow = 520.0;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final text = Column(
      crossAxisAlignment: .start,
      spacing: 3,
      children: [
        Text(title, style: HiganText.body(context)),
        if (subtitle case final subtitle? when subtitle.isNotEmpty)
          Text(
            subtitle,
            style: HiganText.body(context, size: 13, color: c.textSecondary),
          ),
      ],
    );
    final trailing =
        this.trailing ??
        (showChevron
            ? Icon(
                Symbols.chevron_right,
                size: 16,
                weight: 300,
                color: c.textTertiary,
              )
            : null);

    return HiganFocusRing(
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(6))),
      child: Material(
        color: Colors.transparent,
        shape: Border(bottom: BorderSide(color: c.hairline)),
        child: ControlClick(
          onClick: switch (onLongPress) {
            final onLongPress? => (_) => onLongPress(),
            null => null,
          },
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            // Right-click resets a changed setting, like a long-press.
            onSecondaryTap: onLongPress,
            mouseCursor: onTap == null ? null : SystemMouseCursors.click,
            child: Padding(
              padding: const .symmetric(vertical: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (trailing == null) return text;
                  if (wide && constraints.maxWidth < _narrow) {
                    return Column(
                      crossAxisAlignment: .start,
                      spacing: HiganSpace.m,
                      children: [text, trailing],
                    );
                  }
                  return Row(
                    spacing: HiganSpace.l,
                    children: [
                      Expanded(child: text),
                      trailing,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
