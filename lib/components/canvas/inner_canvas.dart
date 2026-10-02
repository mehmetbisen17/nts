import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:nts/components/canvas/_canvas_background_painter.dart';
import 'package:nts/components/canvas/_canvas_painter.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/canvas_image.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/components/canvas/text_boxes.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/extensions/color_extensions.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/select.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/quill_styles.dart';

class InnerCanvas extends StatefulWidget {
  const new({
    super.key,
    required this.pageIndex,
    this.redrawPageListenable,
    required this.width,
    required this.height,
    this.showPageIndicator = true,
    this.textEditing = false,
    required this.coreInfo,
    required this.currentStroke,
    required this.currentStrokeDetectedShape,
    required this.currentSelection,
    this.setAsBackground,
    this.onRenderObjectChange,
    required this.currentToolIsSelect,
    required this.currentScale,
    this.textBoxCallbacks,
    this.cardLabel,
  });

  final int pageIndex;
  final Listenable? redrawPageListenable;
  final double width;
  final double height;
  final bool showPageIndicator;
  final bool textEditing;
  final EditorCoreInfo coreInfo;
  final Stroke? currentStroke;
  final RecognizedUnistroke? currentStrokeDetectedShape;
  final SelectResult? currentSelection;
  final void Function(EditorImage image)? setAsBackground;
  final ValueChanged<RenderObject>? onRenderObjectChange;

  final bool currentToolIsSelect;

  final double currentScale;

  /// Lets the text boxes be typed in and moved while [textEditing].
  final TextBoxCallbacks? textBoxCallbacks;

  /// See [CanvasPainter.cardLabel].
  final String? cardLabel;

  static const defaultBackgroundColor = Color(0xFFFCFCFC);

  /// The page color for notes that don't set one: Higan paper in the app,
  /// [defaultBackgroundColor] in exports (which use their own theme).
  static Color defaultBackgroundColorOf(BuildContext context) =>
      Theme.of(context).extension<HiganColors>()?.pagePaper ??
      defaultBackgroundColor;

  /// Whether pages are drawn black with inverted ink (Settings › Pages),
  /// in both Night and Paper. Exports keep paper: their light theme
  /// has no [HiganColors].
  static bool invertOf(BuildContext context) {
    if (!stows.editorAutoInvert.value) return false;
    final theme = Theme.of(context);
    return theme.extension<HiganColors>() != null || theme.brightness == .dark;
  }

  /// Background line colors ([primary] lines, [secondary] margins):
  /// quiet blue-grey rules and a red margin in the app,
  /// the theme's colors in exports.
  static ({Color primary, Color secondary}) backgroundLineColorsOf(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final higan = theme.extension<HiganColors>();
    if (higan == null) {
      return (
        primary: theme.colorScheme.primary,
        secondary: theme.colorScheme.secondary,
      );
    }
    return (primary: const Color(0xFF6C8CA8), secondary: higan.higan);
  }

  @override
  State<InnerCanvas> createState() => _InnerCanvasState();
}

class _InnerCanvasState extends State<InnerCanvas> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lineColors = InnerCanvas.backgroundLineColorsOf(context);

    if (widget.coreInfo.pages.isEmpty) {
      return SizedBox(width: widget.width, height: widget.height);
    }

    final page = widget.coreInfo.pages[widget.pageIndex];
    // A whiteboard is the app's own background: dark ink shows light on
    // it in Night (like black pages), and as it is in Paper
    final higan = theme.extension<HiganColors>();
    final invert = page.isBoard
        ? (higan?.isNight ?? theme.brightness == .dark)
        : InnerCanvas.invertOf(context);
    final Color backgroundColor = page.isBoard
        // (Inverted again when it's drawn)
        ? (higan?.bg ?? InnerCanvas.defaultBackgroundColor).withInversion(
            invert,
          )
        : widget.coreInfo.backgroundColor ??
              InnerCanvas.defaultBackgroundColorOf(context);

    final quillEditor = widget.coreInfo.pages.isNotEmpty
        ? QuillEditor(
            controller:
                widget.coreInfo.pages[widget.pageIndex].quill.controller,
            config: QuillEditorConfig(
              customStyles: NtsQuillStyles.get(
                invert: invert,
                secondary: colorScheme.secondary,
                lineHeight: widget.coreInfo.lineHeight,
              ),
              scrollable: false,
              autoFocus: false,
              expands: true,
              // Typed text is in text boxes now (see [TextBoxLayer]):
              // this only shows text typed the old way while it's
              // converted.
              placeholder: null,
              showCursor: true,
              keyboardAppearance: invert ? .dark : .light,
              padding: .only(
                top: widget.coreInfo.lineHeight * 1.2,
                left: widget.coreInfo.lineHeight * 0.5,
                right: widget.coreInfo.lineHeight * 0.5,
                bottom: widget.coreInfo.lineHeight * 0.5,
              ),
            ),
            scrollController: ScrollController(),
            focusNode: widget.coreInfo.pages[widget.pageIndex].quill.focusNode,
          )
        : null;

    return RepaintBoundary(
      child: CustomPaint(
        painter: CanvasBackgroundPainter(
          invert: invert,
          backgroundColor: () {
            if (page.backgroundImage != null) {
              return Colors.white;
            } else {
              return backgroundColor;
            }
          }(),
          backgroundPattern: () {
            if (page.backgroundImage != null || page.isBoard) {
              return CanvasBackgroundPattern.none;
            } else {
              return widget.coreInfo.backgroundPattern;
            }
          }(),
          lineHeight: widget.coreInfo.lineHeight,
          lineThickness: widget.coreInfo.lineThickness,
          primaryColor: lineColors.primary,
          secondaryColor: lineColors.secondary,
        ),
        foregroundPainter: CanvasPainter(
          repaint: widget.redrawPageListenable,
          invert: invert,
          strokes: page.strokes,
          laserStrokes: page.laserStrokes,
          currentStroke: widget.currentStroke,
          currentSelection: widget.currentSelection,
          primaryColor: colorScheme.primary,
          page: page,
          showPageIndicator: widget.showPageIndicator && !page.isBoard,
          pageIndex: widget.pageIndex,
          totalPages: widget.coreInfo.pages.length,
          currentScale: widget.currentScale,
          defaultTextStyle: theme.textTheme.bodyMedium!,
          linkColor: theme.extension<HiganColors>()?.higan,
          cardLabel: widget.cardLabel,
        ),
        isComplex: true,
        willChange: true,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: DeferredPointerHandler(
            child: Stack(
              // Images and ink can sit beside the page
              clipBehavior: .none,
              children: [
                // Cards behind what's beside the page
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: SideCardsPainter(
                          repaint: widget.redrawPageListenable,
                          page: page,
                          invert: invert,
                          pageColor: page.backgroundImage != null
                              ? Colors.white
                              : backgroundColor,
                          accent:
                              theme.extension<HiganColors>()?.higan ??
                              colorScheme.primary,
                          backdrop:
                              theme.extension<HiganColors>()?.bg ??
                              Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                if (page.backgroundImage != null)
                  CanvasImage(
                    filePath: widget.coreInfo.filePath,
                    image: page.backgroundImage!,
                    pageSize: Size(widget.width, widget.height),
                    setAsBackground: null,
                    isBackground: true,
                    readOnly: true,
                  ),
                // Fills go under the text, images and ink
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: CanvasFillPainter(
                          repaint: widget.redrawPageListenable,
                          strokes: page.strokes,
                          invert: invert,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  width: widget.width,
                  height: widget.height,
                  child: IgnorePointer(ignoring: true, child: quillEditor),
                ),
                for (int i = 0; i < page.images.length; i++)
                  CanvasImage(
                    filePath: widget.coreInfo.filePath,
                    image: page.images[i],
                    pageSize: Size(widget.width, widget.height),
                    setAsBackground: widget.setAsBackground,
                    readOnly:
                        widget.coreInfo.readOnly || !widget.currentToolIsSelect,
                    selected:
                        widget.currentSelection?.images.contains(
                          page.images[i],
                        ) ??
                        false,
                  ),
                // Typed text goes over images, under ink
                Positioned.fill(
                  child: TextBoxLayer(
                    page: page,
                    pageIndex: widget.pageIndex,
                    editing: widget.textEditing && !widget.coreInfo.readOnly,
                    invert: invert,
                    callbacks: widget.textBoxCallbacks,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
