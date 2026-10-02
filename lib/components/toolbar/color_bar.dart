import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/adaptive_alert_dialog.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/toolbar/color_option.dart';
import 'package:nts/data/extensions/color_extensions.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/i18n/strings.g.dart';

typedef NamedColor = ({String name, Color color});

class ColorBar extends StatefulWidget {
  const new({
    super.key,
    required this.axis,
    required this.setColor,
    required this.currentColor,
    required this.invert,
  });

  final Axis axis;
  final ValueChanged<Color> setColor;
  final Color? currentColor;
  final bool invert;

  static List<NamedColor> get colorPresets =>
      stows.preferGreyscale.value ? greyScaleColorOptions : normalColorOptions;

  /// Higan's quiet inks (as in the mockup), plus white for black pages.
  /// More colors are in the custom picker, and pinned/recent colors.
  static final List<NamedColor> normalColorOptions = [
    (name: t.editor.colors.black, color: Colors.black),
    (name: t.editor.colors.red, color: const Color(0xFFD0283A)),
    (name: t.editor.colors.yellow, color: const Color(0xFFE2B46C)),
    (name: t.editor.colors.blue, color: const Color(0xFF6C8CA8)),
    (name: t.editor.colors.green, color: const Color(0xFF7E9B7A)),
    (name: t.editor.colors.purple, color: const Color(0xFF9B7EB3)),
    (name: t.editor.colors.white, color: Colors.white),
  ];
  static final List<NamedColor> greyScaleColorOptions = [
    (name: t.editor.colors.black, color: Colors.black),
    (name: t.editor.colors.darkGrey, color: Colors.grey[800] ?? Colors.black54),
    (name: t.editor.colors.grey, color: Colors.grey),
    (
      name: t.editor.colors.lightGrey,
      color: Colors.grey[200] ?? Colors.black12,
    ),
    (name: t.editor.colors.white, color: Colors.white),
  ];
  static final List<NamedColor> _allColors = [
    ...normalColorOptions,
    ...greyScaleColorOptions,
  ];
  static String findColorName(Color searchColor) {
    for (final namedColor in _allColors) {
      if (namedColor.color == searchColor) {
        return namedColor.name;
      }
    }
    return describeColor(searchColor);
  }

  @visibleForTesting
  static String describeColor(Color color) {
    final hsl = HSLColor.fromColor(color);

    final String hueName;
    if (hsl.saturation < 0.1 || hsl.lightness < 0.05 || hsl.lightness > 0.95) {
      hueName = t.editor.colors.grey.toLowerCase();
    } else {
      hueName = switch (hsl.hue) {
        < 10 => t.editor.colors.red.toLowerCase(),
        < 35 => t.editor.colors.orange.toLowerCase(),
        < 70 => t.editor.colors.yellow.toLowerCase(),
        < 150 => t.editor.colors.green.toLowerCase(),
        < 200 => t.editor.colors.cyan.toLowerCase(),
        < 250 => t.editor.colors.blue.toLowerCase(),
        < 285 => t.editor.colors.purple.toLowerCase(),
        < 340 => t.editor.colors.pink.toLowerCase(),
        _ => t.editor.colors.red.toLowerCase(),
      };
    }

    final lightnessName = switch (hsl.lightness) {
      < 0.35 => t.editor.colors.dark,
      < 0.65 => null,
      _ => t.editor.colors.light,
    };

    if (lightnessName == null) {
      return t.editor.colors.customHue(h: hueName);
    } else {
      return t.editor.colors.customBrightnessHue(b: lightnessName, h: hueName);
    }
  }

  /// Returns whether the color is now pinned.
  static bool toggleColorPinned(String colorString) {
    if (stows.pinnedColors.value.contains(colorString)) {
      stows.pinnedColors.value.remove(colorString);
      stows.recentColorsChronological.value.remove(colorString);
      stows.recentColorsPositioned.value.remove(colorString);
      if (stows.recentColorsChronological.value.length >=
          stows.recentColorsLength.value) {
        // if full, replace oldest
        final oldestColor = stows.recentColorsChronological.value.removeAt(0);
        stows.recentColorsChronological.value.add(colorString);
        final int oldestColorPosition = stows.recentColorsPositioned.value
            .indexOf(oldestColor);
        stows.recentColorsPositioned.value[oldestColorPosition] = colorString;
      } else {
        // not full, add to end
        stows.recentColorsChronological.value.add(colorString);
        stows.recentColorsPositioned.value.insert(0, colorString);
      }
      return false;
    } else {
      // add to pinned and remove from recent colors
      stows.pinnedColors.value.add(colorString);
      stows.recentColorsChronological.value.remove(colorString);
      stows.recentColorsPositioned.value.remove(colorString);
      return true;
    }
  }

  static var _pickedColor = const Color.fromRGBO(255, 0, 0, 1);

  /// Shows a dialog to pick a custom color, then passes it to [setColor].
  static Future<void> openColorPicker(
    BuildContext context, {
    required ValueChanged<Color> setColor,
    required bool invert,
  }) async {
    final bool? confirmChange = await showDialog(
      context: context,
      builder: _colorPickerDialog,
    );
    if (confirmChange ?? false) {
      setColor(_pickedColor.withInversion(invert));
    }
  }

  static Widget _colorPickerDialog(BuildContext context) => AdaptiveAlertDialog(
    title: Text(t.settings.accentColorPicker.pickAColor),
    content: SingleChildScrollView(
      child: ColorPicker(
        color: _pickedColor,
        pickersEnabled: const {ColorPickerType.wheel: true},
        onColorChanged: (Color color) {
          _pickedColor = color;
        },
      ),
    ),
    actions: [
      CupertinoDialogAction(
        child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        onPressed: () {
          Navigator.of(context).pop(true);
        },
      ),
    ],
  );

  @override
  State<ColorBar> createState() => _ColorBarState();
}

class _ColorBarState extends State<ColorBar> {
  /// Whether more colors are scrolled out of view before or after the
  /// visible ones: that edge fades, so no swatch is just cut off.
  var _moreBefore = false, _moreAfter = false;

  void _updateFades(ScrollMetrics metrics) {
    final before = metrics.extentBefore > 0.5;
    final after = metrics.extentAfter > 0.5;
    if (before == _moreBefore && after == _moreAfter) return;
    setState(() {
      _moreBefore = before;
      _moreAfter = after;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;

    Widget swatch(Color color) => DecoratedBox(
      decoration: BoxDecoration(
        color: color.withInversion(widget.invert),
        shape: .circle,
        border: Border.all(color: c.hairlineStrong),
      ),
    );

    bool isCurrent(int argb) =>
        widget.currentColor?.withAlpha(255).toARGB32() == argb;

    Widget savedColor(String colorString) {
      final color = Color(int.parse(colorString));
      return ColorOption(
        isSelected: isCurrent(color.toARGB32()),
        enabled: widget.currentColor != null,
        onTap: () => widget.setColor(color),
        onLongPress: () =>
            setState(() => ColorBar.toggleColorPinned(colorString)),
        tooltip: ColorBar.findColorName(color),
        child: swatch(color),
      );
    }

    final pinnedColors = stows.pinnedColors.value;
    final recentColors = stows.recentColorsPositioned.value.reversed;

    final children = <Widget>[
      for (final colorString in pinnedColors) savedColor(colorString),
      if (pinnedColors.isNotEmpty) const ColorOptionSeparator(),
      for (final colorString in recentColors) savedColor(colorString),
      if (recentColors.isNotEmpty) const ColorOptionSeparator(),

      // custom color
      ColorOption(
        isSelected: isCurrent(ColorBar._pickedColor.toARGB32()),
        enabled: true,
        onTap: () => ColorBar.openColorPicker(
          context,
          setColor: widget.setColor,
          invert: widget.invert,
        ),
        tooltip: t.editor.colors.colorPicker,
        child: Icon(
          Symbols.colorize,
          size: 16,
          weight: 300,
          color: c.textSecondary,
        ),
      ),

      // color presets
      for (final namedColor in ColorBar.colorPresets)
        ColorOption(
          isSelected: isCurrent(namedColor.color.toARGB32()),
          enabled: widget.currentColor != null,
          onTap: () => widget.setColor(namedColor.color),
          tooltip: namedColor.name,
          child: swatch(namedColor.color),
        ),
    ];

    final horizontal = widget.axis == .horizontal;
    return Center(
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          _updateFades(notification.metrics);
          return false;
        },
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (notification) {
            _updateFades(notification.metrics);
            return false;
          },
          child: ShaderMask(
            blendMode: .dstIn,
            shaderCallback: (bounds) {
              const fade = 24.0;
              final length = horizontal ? bounds.width : bounds.height;
              final stop = length <= 2 * fade ? 0.5 : fade / length;
              return LinearGradient(
                begin: horizontal ? .centerLeft : .topCenter,
                end: horizontal ? .centerRight : .bottomCenter,
                colors: [
                  if (_moreBefore) Colors.transparent else Colors.white,
                  Colors.white,
                  Colors.white,
                  if (_moreAfter) Colors.transparent else Colors.white,
                ],
                stops: [0, stop, 1 - stop, 1],
              ).createShader(bounds);
            },
            child: ScrollConfiguration(
              // A mouse drag scrolls it too
              behavior: ScrollConfiguration.of(context)
                  .copyWith(dragDevices: PointerDeviceKind.values.toSet()),
              child: SingleChildScrollView(
                scrollDirection: widget.axis,
                padding: const .symmetric(horizontal: 4),
                child: Flex(direction: widget.axis, children: children),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
