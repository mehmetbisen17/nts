import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/canvas/inner_canvas.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/components/toolbar/floating_bar.dart';
import 'package:nts/components/toolbar/toolbar_button.dart';
import 'package:nts/data/extensions/color_extensions.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/services/pen_presets.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/i18n/strings.g.dart';

/// The pen favorites in the toolbar: tap one to use it, long-press or
/// right-click one to remove it. The last button saves the current pen.
class PenPresetButtons extends StatelessWidget {
  const new({
    super.key,
    required this.axis,
    required this.currentTool,
    required this.enabled,
    required this.selectTool,
    required this.padding,
  });

  /// The toolbar's direction.
  final Axis axis;
  final Tool currentTool;
  final bool enabled;
  final ValueChanged<Tool> selectTool;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final invert = InnerCanvas.invertOf(context);
    return ValueListenableBuilder(
      valueListenable: stows.penPresets,
      builder: (context, presets, _) {
        final current = PenPreset.of(currentTool);
        void showMenu(PenPreset preset, Offset position) => showBarMenu(
          context,
          position,
          title: preset.name,
          actions: [
            (
              t.editor.otherTools.removeFavorite,
              () => PenPreset.remove(preset),
            ),
          ],
        );
        return Flex(
          direction: axis,
          mainAxisSize: .min,
          children: [
            for (final preset in presets)
              ControlClick(
                onClick: (position) => showMenu(preset, position),
                child: GestureDetector(
                  onLongPressStart: (details) =>
                      showMenu(preset, details.globalPosition),
                  onSecondaryTapUp: (details) =>
                      showMenu(preset, details.globalPosition),
                  child: ToolbarIconButton(
                    tooltip: '${preset.name} · ${preset.size.round()}',
                    selected: preset == current,
                    enabled: enabled,
                    onPressed: () => selectTool(preset.toPen()),
                    padding: padding,
                    child: _PresetSwatch(preset, invert: invert),
                  ),
                ),
              ),
            ToolbarIconButton(
              tooltip: t.editor.otherTools.saveFavorite,
              enabled:
                  enabled &&
                  current != null &&
                  !presets.contains(current) &&
                  presets.length < PenPreset.max,
              onPressed: () => PenPreset.add(current!),
              padding: padding,
              child: const Icon(Symbols.bookmark_add),
            ),
          ],
        );
      },
    );
  }
}

/// The preset's color above its size: a bar for highlighters,
/// a dot for pens.
class _PresetSwatch extends StatelessWidget {
  const new(this.preset, {required this.invert});

  final PenPreset preset;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final highlighter = preset.toolId == .highlighter;
    return Column(
      mainAxisSize: .min,
      children: [
        Container(
          width: highlighter ? 16 : 12,
          height: highlighter ? 8 : 12,
          decoration: BoxDecoration(
            color: preset.color.withInversion(invert).withValues(alpha: 1),
            shape: highlighter ? .rectangle : .circle,
            borderRadius: highlighter ? BorderRadius.circular(2) : null,
            // so black shows on the dark pill
            border: Border.all(color: context.higan.textTertiary),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${preset.size.round()}',
          style: HiganText.label(
            context,
            size: 9,
            color: IconTheme.of(context).color,
          ),
        ),
      ],
    );
  }
}
