import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/higan/higan_lily.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/i18n/strings.g.dart';

/// Tiny mono uppercase label, e.g. "2H AGO · 4 PAGES".
class HiganLabel extends StatelessWidget {
  const new(
    this.text, {
    super.key,
    this.size = 11,
    this.color,
    this.maxLines = 1,
    this.textAlign,
  });

  /// Uppercased for you.
  final String text;
  final double size;

  /// Defaults to textSecondary ("ash").
  final Color? color;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: HiganText.label(context, size: size, color: color),
      maxLines: maxLines,
      overflow: maxLines == null ? null : .ellipsis,
      textAlign: textAlign,
    );
  }
}

/// Big light title, e.g. "Folders" or a folder's name.
class HiganTitle extends StatelessWidget {
  const new(this.text, {super.key, this.size = 40});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: HiganText.title(context, size: size),
      maxLines: 2,
      overflow: .ellipsis,
    );
  }
}

class HiganSegment<T> {
  const new({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Pill segmented control with mono labels, e.g. GALLERY | LIST.
class HiganSegmented<T> extends StatelessWidget {
  const new({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<HiganSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: c.hairlineStrong)),
      ),
      child: Padding(
        padding: const .all(3),
        child: Row(
          mainAxisSize: .min,
          children: [
            for (final segment in segments)
              _HiganSegmentButton(
                segment: segment,
                selected: segment.value == value,
                onTap: () => onChanged(segment.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _HiganSegmentButton extends StatelessWidget {
  const new({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final HiganSegment segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final color = selected ? c.text : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: HiganFocusRing(
        child: AnimatedContainer(
          duration: HiganMotion.fast,
          decoration: ShapeDecoration(
            color: selected ? c.surface2 : Colors.transparent,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? c.hairlineStrong : Colors.transparent,
              ),
            ),
          ),
          child: Material(
            type: .transparency,
            child: InkWell(
              onTap: onTap,
              customBorder: const StadiumBorder(),
              child: Padding(
                // 44 tall on touch screens (with the control's padding)
                padding: .symmetric(
                  horizontal: 13,
                  vertical: HiganTap.isTouch(context) ? 13 : 7,
                ),
                child: Row(
                  mainAxisSize: .min,
                  spacing: 7,
                  children: [
                    if (segment.icon != null)
                      Icon(segment.icon, size: 13, color: color, weight: 400),
                    Text(
                      segment.label.toUpperCase(),
                      style: HiganText.label(
                        context,
                        size: 10.5,
                        color: color,
                        tracking: 0.12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// GALLERY | LIST switch that reads and saves the view mode of [path]
/// (a folder path, or [FolderViewMode.recentKey]).
class HiganViewSwitch extends HookWidget {
  const new({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    useValueListenable(stows.folderViewModes);
    return HiganSegmented<FolderViewMode>(
      value: FolderViewMode.of(path),
      onChanged: (mode) => FolderViewMode.set(path, mode),
      segments: [
        HiganSegment(
          value: .gallery,
          label: t.higan.gallery,
          icon: Symbols.grid_view,
        ),
        HiganSegment(value: .list, label: t.higan.list, icon: Symbols.list),
      ],
    );
  }
}

/// Floating glass container, e.g. the editor's color bar and toolbar.
class HiganPill extends StatelessWidget {
  const new({
    super.key,
    required this.child,
    this.height = 50,
    this.padding = const .symmetric(horizontal: 16),
  });

  final Widget child;

  /// Null to size to the child (e.g. a vertical toolbar).
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    const radius = BorderRadius.all(.circular(HiganRadius.bar));
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: c.glass,
            borderRadius: radius,
            border: Border.all(color: c.hairlineStrong),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 36px circle icon button with a hairline border.
class HiganCircleButton extends StatelessWidget {
  const new({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 36,
    this.bordered = true,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool bordered;

  /// Filled, like an active nav row (e.g. settings while it's open).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final button = HiganTapTarget(
      onTap: onPressed,
      child: HiganFocusRing(
        shape: const CircleBorder(),
        child: Material(
          color: selected ? c.surface2 : Colors.transparent,
          shape: CircleBorder(
            side: bordered ? BorderSide(color: c.hairlineStrong) : .none,
          ),
          clipBehavior: .antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                icon,
                size: 16,
                weight: 300,
                color: onPressed == null ? c.textTertiary : c.text,
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// Soft red glow in the top-left corner of home screens.
/// Put it first in a [Stack] (it's a [Positioned]).
class HiganEmber extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final ember = context.higan.ember;
    Color a(double k) => ember.withValues(alpha: ember.a * k);
    return Positioned(
      top: -360,
      left: -260,
      width: 640,
      height: 640,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [a(1), a(0.36), a(0.11), a(0)],
              stops: const [0, 0.42, 0.68, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mono text tabs; the selected one is bright with a red dot below.
class HiganTabs extends StatelessWidget {
  const new({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return Row(
      mainAxisSize: .min,
      children: [
        for (var i = 0; i < labels.length; i++)
          Semantics(
            button: true,
            selected: i == selectedIndex,
            child: HiganFocusRing(
              shape: const RoundedRectangleBorder(
                borderRadius: .all(.circular(8)),
              ),
              child: InkWell(
                onTap: () => onSelected(i),
                borderRadius: const .all(.circular(8)),
                child: Padding(
                  padding: const .symmetric(horizontal: 13, vertical: 12),
                  child: Column(
                    mainAxisSize: .min,
                    spacing: 7,
                    children: [
                      Text(
                        labels[i].toUpperCase(),
                        style: HiganText.label(
                          context,
                          color: i == selectedIndex ? c.text : c.textSecondary,
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: i == selectedIndex ? 1 : 0,
                        duration: HiganMotion.fast,
                        child: _Dot(color: c.higan),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const new({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 4,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: .circle),
    ),
  );
}

/// Red circular new-note button with a soft halo.
class HiganFab extends StatelessWidget {
  const new({
    super.key,
    required this.onPressed,
    this.icon = Symbols.add,
    this.tooltip,
    this.size = 58,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final red = context.higan.higan;
    final button = DecoratedBox(
      decoration: BoxDecoration(
        shape: .circle,
        boxShadow: [
          BoxShadow(color: red.withValues(alpha: 0.10), spreadRadius: 7),
          BoxShadow(
            color: red.withValues(alpha: 0.35),
            offset: const Offset(0, 12),
            blurRadius: 34,
          ),
        ],
      ),
      child: Material(
        color: red,
        shape: const CircleBorder(),
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: 22, weight: 500, color: Colors.white),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// Lily, a light title, one line of text and an optional action.
class HiganEmptyState extends StatelessWidget {
  const new({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.lilySize = 110,
    this.animate = true,
  });

  final String title;
  final String body;
  final Widget? action;
  final double lilySize;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const .all(HiganSpace.xl),
        child: Column(
          mainAxisSize: .min,
          children: [
            HiganLily(size: lilySize, variant: .thin, animate: animate),
            const SizedBox(height: HiganSpace.xl),
            Text(
              title,
              textAlign: .center,
              style: HiganText.title(context, size: 24),
            ),
            const SizedBox(height: HiganSpace.s),
            Text(
              body,
              textAlign: .center,
              style: HiganText.body(
                context,
                size: 14,
                color: context.higan.textSecondary,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: HiganSpace.l),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Paper frame for a note preview: paper color, rounded, shadow in Night,
/// hairline in Paper. Pass [aspectRatio] 3 / 3.9 for gallery cards.
class HiganPaperThumb extends StatelessWidget {
  const new({
    super.key,
    this.child,
    this.aspectRatio,
    this.radius = HiganRadius.page,
    this.shadow = true,
  });

  final Widget? child;
  final double? aspectRatio;
  final double radius;

  /// Off for small list thumbnails.
  final bool shadow;

  static const galleryAspectRatio = 3 / 3.9;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final borderRadius = BorderRadius.circular(radius);
    Widget frame = DecoratedBox(
      decoration: BoxDecoration(
        color: c.thumbPaper,
        borderRadius: borderRadius,
        border: c.isNight ? null : Border.all(color: c.hairlineStrong),
        boxShadow: shadow ? c.paperShadow : null,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
    if (aspectRatio != null) {
      frame = AspectRatio(aspectRatio: aspectRatio!, child: frame);
    }
    return frame;
  }
}

/// A list row with a hairline below: leading, title, trailing labels,
/// chevron. Give the list's first row [topBorder].
class HiganListRow extends StatelessWidget {
  const new({
    super.key,
    required this.title,
    this.leading,
    this.trailing = const [],
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.selected = false,
    this.showChevron = true,
    this.topBorder = false,
  });

  final String title;
  final Widget? leading;

  /// E.g. `[SizedBox(width: 140, child: HiganLabel('4 pages')), ...]`.
  final List<Widget> trailing;
  final VoidCallback? onTap, onLongPress, onSecondaryTap;
  final bool selected, showChevron, topBorder;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final line = BorderSide(color: c.hairline);
    return HiganFocusRing(
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(6))),
      child: Material(
        color: selected ? c.text.withValues(alpha: 0.05) : Colors.transparent,
        shape: Border(top: topBorder ? line : .none, bottom: line),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onSecondaryTap,
          child: Padding(
            padding: const .symmetric(horizontal: 6, vertical: 13),
            child: Row(
              spacing: HiganSpace.l,
              children: [
                ?leading,
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: HiganText.body(context, size: 15.5),
                  ),
                ),
                ...trailing,
                if (showChevron)
                  Icon(
                    Symbols.chevron_right,
                    size: 16,
                    weight: 300,
                    color: c.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws a ring around [child] while a control inside it has keyboard
/// focus (not after touch, like Material's focus highlight).
class HiganFocusRing extends StatefulWidget {
  const new({
    super.key,
    required this.child,
    this.shape = const StadiumBorder(),
  });

  final Widget child;
  final OutlinedBorder shape;

  @override
  State<HiganFocusRing> createState() => _HiganFocusRingState();
}

class _HiganFocusRingState extends State<HiganFocusRing> {
  var _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChange);
    super.dispose();
  }

  void _onHighlightModeChange(FocusHighlightMode _) {
    if (_focused) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final show =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: DecoratedBox(
        position: .foreground,
        decoration: show
            ? ShapeDecoration(
                shape: widget.shape.copyWith(side: higanFocusSide(context)),
              )
            : const BoxDecoration(),
        child: widget.child,
      ),
    );
  }
}

/// The keyboard focus ring: 1.5px of bone/ink.
BorderSide higanFocusSide(BuildContext context) =>
    BorderSide(color: context.higan.text, width: 1.5);

/// On touch screens, grows [child]'s tap area to [HiganTap.min] square
/// without changing how it looks: taps around [child] call [onTap], taps on
/// it reach it as usual. Elsewhere it's just [child].
class HiganTapTarget extends StatelessWidget {
  const new({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!HiganTap.isTouch(context)) return child;
    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      excludeFromSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: HiganTap.min,
          minHeight: HiganTap.min,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      ),
    );
  }
}

/// On a Mac, a Control-click is a right-click: it calls [onClick] with where
/// it was, and [child] doesn't get the click. Elsewhere it's just [child].
class ControlClick extends StatelessWidget {
  const new({super.key, required this.onClick, required this.child});

  final ValueChanged<Offset>? onClick;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onClick == null || defaultTargetPlatform != .macOS) return child;
    return RawGestureDetector(
      gestures: {
        _ControlClickRecognizer:
            GestureRecognizerFactoryWithHandlers<_ControlClickRecognizer>(
              _ControlClickRecognizer.new,
              (recognizer) => recognizer.onClick = onClick,
            ),
      },
      child: child,
    );
  }
}

/// Claims a mouse click with Control held, before [ControlClick.child]'s
/// own tap can, and calls [onClick] when it's released.
class _ControlClickRecognizer extends OneSequenceGestureRecognizer {
  new()
    : super(
        supportedDevices: const {.mouse},
        allowedButtonsFilter: (buttons) => buttons == kPrimaryMouseButton,
      );

  ValueChanged<Offset>? onClick;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      super.isPointerAllowed(event) &&
      HardwareKeyboard.instance.isControlPressed;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent) onClick?.call(event.position);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'control click';
}

/// "Just now", "5m ago", "2h ago", "Yesterday", "Thu", "12 Sep",
/// "12 Sep 2024". Uppercase it for labels (HiganLabel does).
String higanRelativeTime(DateTime when, {DateTime? now}) {
  now ??= DateTime.now();
  final diff = now.difference(when);
  if (diff.inMinutes < 1) return t.higan.time.justNow;
  if (diff.inHours < 1) return t.higan.time.minutesAgo(n: diff.inMinutes);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  final days = today.difference(day).inDays;
  if (days == 0) return t.higan.time.hoursAgo(n: diff.inHours);
  if (days == 1) return t.higan.time.yesterday;
  if (days < 7) return DateFormat.E().format(when);
  if (when.year == now.year) return DateFormat('d MMM').format(when);
  return DateFormat('d MMM y').format(when);
}
