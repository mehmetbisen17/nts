import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/toolbar/toolbar_button.dart';
import 'package:nts/data/extensions/axis_extensions.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/data/tools/calligraphy_pen.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/shape_pen.dart';
import 'package:nts/i18n/strings.g.dart';

class PenModal extends StatefulWidget {
  const new({super.key, required this.getTool, required this.setTool});

  final Tool Function() getTool;
  final void Function(Pen) setTool;

  @override
  State<PenModal> createState() => _PenModalState();
}

class _PenModalState extends State<PenModal> {
  @override
  Widget build(BuildContext context) {
    final axis = stows.editorToolbarAlignment.value.axis.opposite;
    if (widget.getTool() is! Pen) return const SizedBox();

    const padding = EdgeInsets.all(2);
    return Flex(
      direction: axis,
      mainAxisSize: .min,
      children: [
        ToolbarIconButton(
          tooltip: t.editor.pens.fountainPen,
          selected: Pen.currentPen.icon == Pen.fountainPenIcon,
          onPressed: () => setState(() {
            widget.setTool(Pen.fountainPen());
          }),
          padding: padding,
          child: const _Scribble('assets/images/scribble_fountain.svg'),
        ),
        ToolbarIconButton(
          tooltip: t.editor.pens.ballpointPen,
          selected: Pen.currentPen.icon == Pen.ballpointPenIcon,
          onPressed: () => setState(() {
            widget.setTool(Pen.ballpointPen());
          }),
          padding: padding,
          child: const _Scribble('assets/images/scribble_ballpoint.svg'),
        ),
        ToolbarIconButton(
          tooltip: t.editor.pens.shapePen,
          selected: Pen.currentPen.icon == ShapePen.shapePenIcon,
          onPressed: () => setState(() {
            widget.setTool(ShapePen());
          }),
          padding: padding,
          child: const Icon(Symbols.shapes),
        ),
        ToolbarIconButton(
          tooltip: t.editor.canvasTools.brushPen,
          selected: Pen.currentPen.icon == Pen.brushPenIcon,
          onPressed: () => setState(() {
            widget.setTool(Pen.brushPen());
          }),
          padding: padding,
          child: const Icon(Symbols.brush),
        ),
        ToolbarIconButton(
          tooltip: t.editor.canvasTools.calligraphyPen,
          selected: Pen.currentPen.icon == CalligraphyPen.calligraphyPenIcon,
          onPressed: () => setState(() {
            widget.setTool(CalligraphyPen());
          }),
          padding: padding,
          child: const Icon(Symbols.history_edu),
        ),
      ],
    );
  }
}

/// A sample stroke of a pen, in the button's icon color.
class _Scribble extends StatelessWidget {
  const new(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: 26,
      height: 26 / 508 * 374,
      theme: SvgTheme(currentColor: IconTheme.of(context).color!),
    );
  }
}
