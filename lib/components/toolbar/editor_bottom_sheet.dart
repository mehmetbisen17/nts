import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/canvas/canvas_background_preview.dart';
import 'package:nts/components/canvas/canvas_image_dialog.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/extensions/list_extensions.dart';
import 'package:nts/i18n/extensions/box_fit_localized.dart';
import 'package:nts/i18n/extensions/canvas_background_pattern_localized.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:sbn/canvas_background_pattern.dart';

class EditorBottomSheet extends StatefulWidget {
  const new({
    super.key,
    required this.invert,
    required this.coreInfo,
    required this.currentPageIndex,
    required this.setBackgroundPattern,
    required this.setLineHeight,
    required this.setLineThickness,
    required this.removeBackgroundImage,
    required this.redrawImage,
    required this.clearPage,
    required this.clearAllPages,
    required this.redrawAndSave,
    required this.pickPhotos,
    required this.importPdf,
    required this.canRasterPdf,
  });

  final bool invert;
  final EditorCoreInfo coreInfo;
  final int? currentPageIndex;
  final void Function(CanvasBackgroundPattern) setBackgroundPattern;
  final void Function(int) setLineHeight;
  final void Function(int) setLineThickness;
  final VoidCallback removeBackgroundImage;
  final VoidCallback redrawImage;
  final VoidCallback clearPage;
  final VoidCallback clearAllPages;
  final VoidCallback redrawAndSave;
  final Future<int> Function() pickPhotos;
  final Future<bool> Function() importPdf;
  final bool canRasterPdf;

  @override
  State<EditorBottomSheet> createState() => _EditorBottomSheetState();
}

class _EditorBottomSheetState extends State<EditorBottomSheet> {
  static const imageBoxFits = <BoxFit>[.fill, .cover, .contain];

  @override
  Widget build(BuildContext context) {
    final page = widget.coreInfo.pages.getOrNull(widget.currentPageIndex ?? -1);
    final pageSize = page?.size ?? EditorPage.defaultSize;
    final backgroundImage = page?.backgroundImage;

    final previewSize = Size(
      CanvasBackgroundPreview.fixedWidth,
      pageSize.height / pageSize.width * CanvasBackgroundPreview.fixedWidth,
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        // Enable drag scrolling on all devices (including mouse)
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 16),
        child: ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: widget.coreInfo.isNotEmpty
                      ? () {
                          widget.clearPage();
                          Navigator.pop(context);
                        }
                      : null,
                  child: Wrap(
                    children: [
                      const Icon(
                        Symbols.cleaning_services,
                        size: 18,
                        weight: 300,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.editor.menu.clearPage(
                          page: widget.currentPageIndex == null
                              ? '?'
                              : widget.currentPageIndex! + 1,
                          totalPages: widget.coreInfo.pages.length,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: widget.coreInfo.isNotEmpty
                      ? () {
                          widget.clearAllPages();
                          Navigator.pop(context);
                        }
                      : null,
                  child: Wrap(
                    children: [
                      const Icon(
                        Symbols.cleaning_services,
                        size: 18,
                        weight: 300,
                      ),
                      const SizedBox(width: 8),
                      Text(t.editor.menu.clearAllPages),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (backgroundImage != null) ...[
              _SectionLabel(t.editor.menu.backgroundImageFit),
              SizedBox(
                height: previewSize.height,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageBoxFits.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final boxFit = imageBoxFits[index];
                    return InkWell(
                      borderRadius: const .all(.circular(8)),
                      onTap: () => setState(() {
                        backgroundImage.backgroundFit = boxFit;
                        widget.redrawAndSave();
                      }),
                      child: Stack(
                        children: [
                          CanvasBackgroundPreview(
                            selected: backgroundImage.backgroundFit == boxFit,
                            invert: widget.invert,
                            backgroundColor: widget.coreInfo.backgroundColor,
                            backgroundPattern:
                                widget.coreInfo.backgroundPattern,
                            backgroundImage: backgroundImage,
                            overrideBoxFit: boxFit,
                            pageSize: pageSize,
                            lineHeight: widget.coreInfo.lineHeight,
                            lineThickness: widget.coreInfo.lineThickness,
                          ),
                          Positioned(
                            bottom: previewSize.height * 0.1,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _PermanentTooltip(
                                text: boxFit.localizedName,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              CanvasImageDialog(
                filePath: widget.coreInfo.filePath,
                image: backgroundImage,
                redrawImage: () => setState(() {
                  widget.redrawImage();
                }),
                isBackground: true,
                toggleAsBackground: widget.removeBackgroundImage,
                singleRow: true,
              ),
              const SizedBox(height: 16),
            ],
            _SectionLabel(t.editor.menu.backgroundPattern),
            SizedBox(
              height: previewSize.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: CanvasBackgroundPattern.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final backgroundPattern =
                      CanvasBackgroundPattern.values[index];
                  return InkWell(
                    borderRadius: const .all(.circular(8)),
                    onTap: () => setState(() {
                      widget.setBackgroundPattern(backgroundPattern);
                    }),
                    child: Stack(
                      children: [
                        CanvasBackgroundPreview(
                          selected:
                              widget.coreInfo.backgroundPattern ==
                              backgroundPattern,
                          invert: widget.invert,
                          backgroundColor: widget.coreInfo.backgroundColor,
                          backgroundPattern: backgroundPattern,
                          backgroundImage: null, // focus on background pattern
                          pageSize: pageSize,
                          lineHeight: widget.coreInfo.lineHeight,
                          lineThickness: widget.coreInfo.lineThickness,
                        ),
                        Positioned(
                          bottom: previewSize.height * 0.1,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _PermanentTooltip(
                              text: backgroundPattern.localizedName,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel(t.editor.menu.lineHeight),
            _Description(t.editor.menu.lineHeightDescription),
            Row(
              children: [
                _Value(widget.coreInfo.lineHeight),
                Expanded(
                  child: Slider(
                    value: widget.coreInfo.lineHeight.toDouble(),
                    min: 20,
                    max: 100,
                    divisions: 8,
                    onChanged: (double value) => setState(() {
                      widget.setLineHeight(value.toInt());
                    }),
                  ),
                ),
              ],
            ),
            _SectionLabel(t.editor.menu.lineThickness),
            _Description(t.editor.menu.lineThicknessDescription),
            Row(
              children: [
                _Value(widget.coreInfo.lineThickness),
                Expanded(
                  child: Slider(
                    value: widget.coreInfo.lineThickness.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    onChanged: (double value) => setState(() {
                      widget.setLineThickness(value.toInt());
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionLabel(t.editor.menu.import),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final photosPicked = await widget.pickPhotos();
                    if (photosPicked > 0) {
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    }
                  },
                  child: Text(t.editor.toolbar.photo),
                ),
                if (widget.canRasterPdf)
                  ElevatedButton(
                    onPressed: () async {
                      final pdfImported = await widget.importPdf();
                      if (pdfImported) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('PDF'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PermanentTooltip extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const .all(.circular(HiganRadius.pill)),
        color: c.surface2.withValues(alpha: 0.9),
        border: Border.all(color: c.hairline),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 8, vertical: 3),
        child: HiganLabel(
          text,
          size: 9.5,
          color: c.text,
          maxLines: 2,
          textAlign: .center,
        ),
      ),
    );
  }
}

/// A mono section label, e.g. BACKGROUND PATTERN.
class _SectionLabel extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .only(top: 8, bottom: 10),
    child: HiganLabel(text, maxLines: null),
  );
}

class _Description extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: HiganText.body(
      context,
      size: 13,
      color: context.higan.textSecondary,
    ),
  );
}

class _Value extends StatelessWidget {
  const new(this.value);

  final int value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    child: Text(
      '$value',
      style: HiganText.label(context, color: context.higan.text),
    ),
  );
}
