import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/i18n/strings.g.dart';

/// Breadcrumb above a folder's title: "← FOLDERS / MATHEMATICS · 12 NOTES".
/// Every crumb but the current folder is tappable; the arrow goes up one.
class PathComponents extends StatelessWidget {
  new(
    String? path, {
    super.key,
    required this.onPathComponentTap,
    this.trailing,
  }) : components = _splitPath(path);

  final List<String> components;

  /// Called with the tapped folder's path, or null for the root.
  final void Function(String? path) onPathComponentTap;

  /// Shown dimmed after the crumbs, e.g. "12 notes".
  final String? trailing;

  /// The crumbs' tap padding above (and below) their text: enough for
  /// 44px tap targets on touch screens. Pages pull the header up by this so
  /// its heading lines up with Recent's.
  static double textInset(BuildContext context) {
    const inset = 6.0;
    if (!HiganTap.isTouch(context)) return inset;
    final text = MediaQuery.textScalerOf(context).scale(11) * 1.2;
    return math.max(inset, (HiganTap.min - text) / 2);
  }

  String? _pathOf(int count) =>
      count == 0 ? null : '/${components.take(count).join('/')}';

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final slash = HiganLabel('/', color: c.textTertiary);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 2,
      children: [
        if (components.isNotEmpty)
          _Crumb(
            tooltip: t.home.backFolder,
            isArrow: true,
            onTap: () => onPathComponentTap(_pathOf(components.length - 1)),
            child: Icon(Icons.arrow_back, size: 14, color: c.textSecondary),
          ),
        _Crumb(
          onTap: components.isEmpty ? null : () => onPathComponentTap(null),
          child: HiganLabel(
            t.higan.folders,
            color: components.isEmpty ? c.text : null,
          ),
        ),
        for (var i = 0; i < components.length; i++) ...[
          slash,
          _Crumb(
            onTap: i == components.length - 1
                ? null
                : () => onPathComponentTap(_pathOf(i + 1)),
            child: HiganLabel(
              components[i],
              color: i == components.length - 1 ? c.text : null,
            ),
          ),
        ],
        if (trailing != null) HiganLabel('· $trailing'),
      ],
    );
  }

  static List<String> _splitPath(String? path) {
    return (path ?? '')
        .split(RegExp(r'[\\/]'))
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}

class _Crumb extends StatelessWidget {
  const new({
    required this.child,
    this.onTap,
    this.tooltip,
    this.isArrow = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  /// The narrow back arrow: wider to the end on touch screens.
  final bool isArrow;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    final touch = HiganTap.isTouch(context);
    final crumb = HiganFocusRing(
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(4))),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: const .all(.circular(4)),
        child: Padding(
          padding: .fromSTEB(
            2,
            PathComponents.textInset(context),
            isArrow && touch ? 14 : 2,
            PathComponents.textInset(context),
          ),
          child: child,
        ),
      ),
    );
    return tooltip == null ? crumb : Tooltip(message: tooltip, child: crumb);
  }
}
