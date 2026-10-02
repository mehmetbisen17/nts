import 'package:flutter/material.dart' hide TransformationController;
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';

class CanvasZoomIndicator extends StatelessWidget {
  const new({super.key, required this.scale, required this.resetZoom});

  final double scale;
  final VoidCallback? resetZoom;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return HiganTapTarget(
      onTap: resetZoom,
      child: Material(
        color: c.glass,
        shape: StadiumBorder(side: BorderSide(color: c.hairlineStrong)),
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: resetZoom,
          child: Container(
            height: 32,
            alignment: .center,
            padding: const .symmetric(horizontal: 12),
            child: Text(
              '${scale.toStringAsFixed(1)}x',
              style: HiganText.label(context, color: c.text),
            ),
          ),
        ),
      ),
    );
  }
}
