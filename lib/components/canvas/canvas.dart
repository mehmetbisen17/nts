import 'package:flutter/material.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/components/canvas/inner_canvas.dart';
import 'package:nts/components/canvas/text_boxes.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:onyxsdk_pen/onyxsdk_pen.dart';
import 'package:sbn/tool_id.dart';

class Canvas extends StatelessWidget {
  const new({
    super.key,
    required this.path,
    required this.page,
    required this.pageIndex,
    required this.textEditing,
    required this.coreInfo,
    required this.currentStroke,
    required this.currentStrokeDetectedShape,
    required this.currentSelection,
    required this.setAsBackground,
    required this.currentTool,
    required this.currentScale,
    this.placeholder = false,
    this.showPageIndicator = true,
    this.textBoxCallbacks,
  });

  final String path;
  final EditorPage page;
  final int pageIndex;

  final bool textEditing;
  final EditorCoreInfo coreInfo;
  final Stroke? currentStroke;
  final RecognizedUnistroke? currentStrokeDetectedShape;
  final SelectResult? currentSelection;

  final void Function(EditorImage image)? setAsBackground;

  final Tool currentTool;
  final double currentScale;
  final bool placeholder;

  /// The "1 / 2" at the bottom of the page.
  final bool showPageIndicator;

  final TextBoxCallbacks? textBoxCallbacks;

  OnyxStrokeStyle _getOnyxTool(Tool currentTool) {
    if (placeholder) return OnyxStrokeStyle.pen;
    switch (currentTool.toolId) {
      case ToolId.fountainPen:
        return OnyxStrokeStyle.brush;
      case ToolId.ballpointPen:
        return OnyxStrokeStyle.pen;
      case ToolId.highlighter:
        return OnyxStrokeStyle.marker;
      case ToolId.pencil:
        return OnyxStrokeStyle.pencil;
      case ToolId.shapePen:
        return OnyxStrokeStyle.disabled;
      case ToolId.eraser:
        return OnyxStrokeStyle.disabled;
      case ToolId.select:
        return OnyxStrokeStyle.pen;
      case ToolId.laserPointer:
        return OnyxStrokeStyle.pen;
      default:
        return OnyxStrokeStyle.disabled;
    }
  }

  Color _getOnyxColor() {
    if (currentTool is Pen) {
      return (currentTool as Pen).color;
    } else {
      return Colors.black;
    }
  }

  double _getOnyxWidth() {
    if (currentTool is Pen) {
      final baseSize = (currentTool as Pen).options.size * currentScale;
      if ((currentTool as Pen).pressureEnabled) {
        return baseSize;
      } else {
        return baseSize * 2;
      }
    } else {
      return 3;
    }
  }

  /// The page floats over the editor's backdrop: a deep shadow in Night,
  /// a hairline and a faint shadow in Paper. Black pages get a hairline
  /// too, so they don't vanish into the Night backdrop.
  static List<BoxShadow> _pageShadow(BuildContext context) {
    final c = Theme.of(context).extension<HiganColors>();
    if (c == null) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ];
    }
    final invert = InnerCanvas.invertOf(context);
    return [
      if (invert || !c.isNight)
        BoxShadow(color: c.hairlineStrong, spreadRadius: 1),
      if (c.isNight)
        const BoxShadow(
          color: Color(0x8C000000), // 0.55
          offset: Offset(0, 40),
          blurRadius: 80,
        )
      else
        const BoxShadow(
          color: Color(0x14141210), // 0.08
          offset: Offset(0, 18),
          blurRadius: 40,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // A whiteboard isn't shrunk to fit the screen's width: it runs off
    // both sides (the canvas pans to it) and has no paper or shadow
    if (page.isBoard) {
      return Center(
        child: SizedBox(
          width: 0,
          height: page.size.height,
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: _page(context),
          ),
        ),
      );
    }
    return Center(
      child: FittedBox(
        child: DecoratedBox(
          decoration: BoxDecoration(boxShadow: _pageShadow(context)),
          child: _page(context),
        ),
      ),
    );
  }

  /// E.g. "3 · FRONT" for the front of the third card.
  static String _cardLabel(int pageIndex) {
    final side = pageIndex.isEven
        ? t.nts.flashcards.front
        : t.nts.flashcards.back;
    return '${pageIndex ~/ 2 + 1} · ${side.toUpperCase()}';
  }

  Widget _page(BuildContext context) {
    return !placeholder
        ? SizedBox(
            width: page.size.width,
            height: page.size.height,
            child: OnyxSdkPenArea(
              refreshDelay: const Duration(seconds: 1),
              strokeStyle: _getOnyxTool(currentTool),
              strokeColor: _getOnyxColor(),
              strokeWidth: _getOnyxWidth(),
              child: InnerCanvas(
                key: page.innerCanvasKey,
                pageIndex: pageIndex,
                redrawPageListenable: page,
                width: page.size.width,
                height: page.size.height,
                textEditing: textEditing,
                coreInfo: coreInfo,
                currentStroke: currentStroke,
                currentStrokeDetectedShape: currentStrokeDetectedShape,
                currentSelection: currentSelection,
                setAsBackground: setAsBackground,
                currentToolIsSelect: currentTool.toolId == ToolId.select,
                currentScale: currentScale,
                showPageIndicator: showPageIndicator,
                textBoxCallbacks: textBoxCallbacks,
                cardLabel: coreInfo.noteType == .flashcards
                    ? _cardLabel(pageIndex)
                    : null,
              ),
            ),
          )
        : SizedBox(width: page.size.width, height: page.size.height);
  }
}
