import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/editor/editor_exporter.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/tools/select.dart';

/// The part of its page that [selection] covers: the lasso, plus all of
/// anything it selected.
Rect selectionBounds(SelectResult selection) => [
  selection.path.getBounds(),
  for (final stroke in selection.strokes) stroke.highQualityPath.getBounds(),
  for (final image in selection.images) image.dstRect,
].reduce((a, b) => a.expandToInclude(b)).inflate(8);

/// [area] of a page as a PNG, looking like an exported page
/// (background, strokes, images and text). Only [area] is drawn, at
/// [pixelRatio] pixels per page unit (by default sharp, but small enough
/// to not run out of memory, like exportAsPng).
Future<Uint8List?> pageAreaPng(
  EditorCoreInfo coreInfo,
  int pageIndex,
  Rect area, {
  double? pixelRatio,
}) async {
  final pageSize = coreInfo.pages[pageIndex].size;
  area = area.intersect(Offset.zero & pageSize);
  if (area.isEmpty) return null;
  final ratio = pixelRatio ?? min(2.0, 4000 / pageSize.longestSide);
  // Whole pixels: a part of one would be a see-through edge, which some
  // viewers show black (to the AI, an underline)
  double whole(double length) => max(1, (length * ratio).floor()) / ratio;
  area = area.topLeft & Size(whole(area.width), whole(area.height));

  final image = await EditorExporter.screenshotPage(
    coreInfo: coreInfo,
    pageIndex: pageIndex,
    rasterizeAllStrokes: true,
    pixelRatio: ratio,
    area: area,
  );
  try {
    final bytes = await image.toByteData(format: .png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// What the lasso circled, as the AI sees it: only the selected strokes
/// and images (not ink beside them), on the page's paper, with a little
/// margin. What's printed under them goes too (an imported PDF or
/// picture), and tape still hides what's under it, like in an export.
/// With nothing selected, the circled part of the page if it can have
/// something to read there: an imported PDF or picture as the background,
/// or typed text ([hasText]). Null if there's nothing.
Future<Uint8List?> selectionPng(
  EditorCoreInfo coreInfo,
  SelectResult selection, {
  bool hasText = false,
}) async {
  final pageIndex = selection.pageIndex;
  final page = coreInfo.pages[pageIndex];
  if (selection.isEmpty) {
    if (page.backgroundImage == null && !hasText) return null;
    final area = selection.path.getBounds();
    return pageAreaPng(coreInfo, pageIndex, area, pixelRatio: _aiScale(area));
  }

  final area = [
    for (final stroke in selection.strokes) stroke.highQualityPath.getBounds(),
    for (final image in selection.images) image.dstRect,
  ].reduce((a, b) => a.expandToInclude(b)).inflate(12);
  final selected = Set<Stroke>.identity()..addAll(selection.strokes);
  final only = EditorPage(
    size: page.size,
    strokes: [
      for (final stroke in page.strokes)
        if (selected.contains(stroke) ||
            (stroke.toolId == .tape &&
                stroke.highQualityPath.getBounds().overlaps(area)))
          stroke,
    ],
    images: [
      for (final image in page.images)
        if (image.dstRect.overlaps(area)) image,
    ],
    backgroundImage: page.backgroundImage,
  );
  try {
    return await pageAreaPng(
      coreInfo.copyWith(pages: List.of(coreInfo.pages)..[pageIndex] = only),
      pageIndex,
      area,
      pixelRatio: _aiScale(area),
    );
  } finally {
    only.disposeClonedData(); // its own empty text; the rest is the page's
  }
}

/// About 1024 pixels on the longest side, which models read well,
/// but at most 4x for a word or two.
double _aiScale(Rect area) => min(4, 1024 / area.longestSide);

/// [strokes] in black on white, for text recognition.
Future<Uint8List?> inkPng(List<Stroke> strokes) async {
  if (strokes.isEmpty) return null;
  final bounds = strokes
      .map((stroke) => stroke.highQualityPath.getBounds())
      .reduce((a, b) => a.expandToInclude(b))
      .inflate(16);
  final scale = min(2.0, 4000 / bounds.longestSide);
  return _png(bounds.size * scale, (canvas) {
    canvas
      ..drawColor(Colors.white, .src)
      ..scale(scale)
      ..translate(-bounds.left, -bounds.top);
    final paint = Paint()..color = Colors.black;
    for (final stroke in strokes) {
      canvas.drawPath(stroke.highQualityPath, paint);
    }
  });
}

Future<Uint8List> _png(Size size, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(
    max(1, size.width.ceil()),
    max(1, size.height.ceil()),
  );
  try {
    final bytes = await image.toByteData(format: .png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
