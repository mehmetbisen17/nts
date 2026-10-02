import 'package:flutter/material.dart';
import 'package:nts/components/canvas/_canvas_background_painter.dart';
import 'package:nts/components/canvas/canvas_image.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/components/canvas/inner_canvas.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:sbn/canvas_background_pattern.dart';

class CanvasBackgroundPreview extends StatelessWidget {
  const new({
    super.key,
    required this.selected,
    required this.invert,
    required this.backgroundColor,
    required this.backgroundPattern,
    required this.backgroundImage,
    this.overrideBoxFit,
    required this.pageSize,
    required this.lineHeight,
    required this.lineThickness,
  });

  final bool selected;
  final bool invert;
  final Color? backgroundColor;
  final CanvasBackgroundPattern backgroundPattern;
  final EditorImage? backgroundImage;
  final BoxFit? overrideBoxFit;
  final Size pageSize;
  final int lineHeight;
  final int lineThickness;

  static const double fixedWidth = 150;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final lineColors = InnerCanvas.backgroundLineColorsOf(context);

    final previewSize = Size(
      fixedWidth,
      pageSize.height / pageSize.width * fixedWidth,
    );
    final canvasSize = pageSize / 2;
    const radius = BorderRadius.all(.circular(HiganRadius.page));
    return AnimatedContainer(
      duration: HiganMotion.fast,
      width: previewSize.width,
      height: previewSize.height,
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          color: selected ? c.text : c.hairline,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            FittedBox(
              child: CustomPaint(
                size: canvasSize,
                painter: CanvasBackgroundPainter(
                  invert: invert,
                  backgroundColor: () {
                    if (backgroundImage != null) {
                      return Colors.white;
                    } else {
                      return backgroundColor ??
                          InnerCanvas.defaultBackgroundColorOf(context);
                    }
                  }(),
                  backgroundPattern: () {
                    if (backgroundImage != null) {
                      return CanvasBackgroundPattern.none;
                    } else {
                      return backgroundPattern;
                    }
                  }(),
                  lineHeight: lineHeight,
                  lineThickness: lineThickness,
                  primaryColor: lineColors.primary,
                  secondaryColor: lineColors.secondary,
                  preview: true,
                ),
              ),
            ),
            if (backgroundImage != null)
              CanvasImage(
                filePath: '',
                image: backgroundImage!,
                overrideBoxFit: overrideBoxFit,
                pageSize: previewSize,
                setAsBackground: null,
                isBackground: true,
                readOnly: true,
              ),
          ],
        ),
      ),
    );
  }
}
