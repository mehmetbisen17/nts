import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:bson/bson.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/pencil_shader.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/editor/editor_exporter.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/services/selection_image.dart';
import 'package:nts/data/tools/select.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:sbn/has_size.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

/// What the AI gets for a lasso ([selectionPng]): only the selected ink.
/// With a copy of the owner's note in [_eval], this also writes its crops
/// there and times them against the old full-page render.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  FlavorConfig.setup();
  setUpAll(PencilShader.init);
  tearDown(Select.currentSelect.unselect);

  testWidgets('only the selected ink, with a margin', (tester) async {
    // A word, and a line through it that's mostly outside the lasso
    final word = _stroke([
      for (var i = 0; i <= 20; i++) Offset(100 + i * 10.0, 100 + (i % 2) * 16),
    ]);
    final line = _stroke([const Offset(200, 60), const Offset(200, 400)]);
    final coreInfo = _note([word, line]);
    final selection = _lasso(coreInfo, const Rect.fromLTRB(80, 80, 320, 150));
    expect(selection.strokes, [word]);

    final png = (await tester.runAsync(
      () => selectionPng(coreInfo, selection),
    ))!;
    final image = im.decodePng(png)!;
    final area = word.highQualityPath.getBounds().inflate(12);
    final scale = min(4, 1024 / area.longestSide);
    expect(image.width, closeTo(area.width * scale, 2));
    expect(image.height, closeTo(area.height * scale, 2));

    double brightness(Offset onPage) {
      final pixel = image.getPixel(
        ((onPage.dx - area.left) * scale).round(),
        ((onPage.dy - area.top) * scale).round(),
      );
      return (pixel.rNormalized + pixel.gNormalized + pixel.bNormalized) / 3;
    }

    expect(brightness(const Offset(100, 100)), lessThan(0.3), reason: 'ink');
    // Where the unselected line would be, under the word: paper
    expect(brightness(Offset(200, area.bottom - 4)), greaterThan(0.7));
  });

  testWidgets('tape still hides what it covers; no see-through edges', (
    tester,
  ) async {
    // An answer under a long tape that's mostly outside the lasso
    final answer = _stroke([
      for (var i = 0; i <= 13; i++)
        Offset(100.3 + i * 9.7, 100.37 + i % 2 * 17),
    ]);
    const tapeColor = Color(0xFF6C8CA8);
    final tape = _stroke(
      [const Offset(60, 108), const Offset(900, 108)],
      toolId: .tape,
      size: 50,
      color: tapeColor,
    );
    final coreInfo = _note([answer, tape]);
    final selection = _lasso(coreInfo, const Rect.fromLTRB(80, 70, 330, 150));
    expect(selection.strokes, [answer]);

    final png = (await tester.runAsync(
      () => selectionPng(coreInfo, selection),
    ))!;
    final image = im.decodePng(png)!;
    final area = answer.highQualityPath.getBounds().inflate(12);
    final scale = min(4, 1024 / area.longestSide);
    final ink = image.getPixel(
      ((100.3 - area.left) * scale).round(),
      ((108 - area.top) * scale).round(),
    );
    expect((ink.r, ink.g, ink.b), (0x6C, 0x8C, 0xA8), reason: 'tape on top');
    for (final (x, y) in [
      (image.width - 1, 0),
      (image.width - 1, image.height - 1),
      (0, image.height - 1),
    ]) {
      expect(image.getPixel(x, y).a, 255, reason: '($x, $y)');
    }
  });

  testWidgets('nothing selected: the circled area only if it can have '
      'something to read', (tester) async {
    final coreInfo = _note([
      _stroke([const Offset(500, 500), const Offset(600, 500)]),
    ]);
    final selection = _lasso(coreInfo, const Rect.fromLTRB(80, 80, 330, 180));
    expect(selection.isEmpty, isTrue);
    expect(
      await tester.runAsync(() => selectionPng(coreInfo, selection)),
      isNull,
    );

    // e.g. typed text there
    final png = (await tester.runAsync(
      () => selectionPng(coreInfo, selection, hasText: true),
    ))!;
    final image = im.decodePng(png)!;
    expect(image.width, closeTo(250 * 4, 2));
    expect(image.height, closeTo(100 * 4, 2));
  });

  testWidgets(
    "the owner's 1 + 1 = 2: crops and timings",
    skip: !File('$_eval/hw1-a.sbn2').existsSync(),
    (tester) async {
      final coreInfo = _ownerNote();
      final strokes = coreInfo.pages[1].strokes.length;
      final lines = <String>[];
      for (final (name, lasso) in const [
        ('tight', Rect.fromLTRB(255, 440, 710, 635)),
        // Also over the top of the curve drawn under the equation
        ('loose', Rect.fromLTRB(240, 430, 720, 800)),
      ]) {
        final selection = _lasso(coreInfo, lasso, pageIndex: 1);
        expect(selection.strokes, hasLength(strokes - 1), reason: 'not curve');

        final (before, beforeMs) = await _time(
          tester,
          () => _oldPng(coreInfo, 1, selectionBounds(selection)),
        );
        final (after, afterMs) = await _time(
          tester,
          () => selectionPng(coreInfo, selection),
        );
        File('$_eval/crop_owner_$name.png').writeAsBytesSync(after!);
        File('$_eval/crop_owner_${name}_before.png').writeAsBytesSync(before!);
        final a = im.decodePng(after)!, b = im.decodePng(before)!;
        lines.add(
          '$name: before ${b.width}x${b.height} ${beforeMs.toStringAsFixed(1)} '
          'ms (+200 ms fixed wait in the app), after ${a.width}x${a.height} '
          '${afterMs.toStringAsFixed(1)} ms',
        );
      }
      File('$_eval/crop_timings.txt')
          .writeAsStringSync('${lines.join('\n')}\n');
      debugPrint(lines.join('\n'));
    },
  );
}

final _eval =
    Platform.environment['NTS_EVAL_DIR'] ??
    '${Directory.systemTemp.path}/nts-eval';

const _pageSize = HasSize(Size(1000, 1400));

Stroke _stroke(
  List<Offset> points, {
  ToolId toolId = .fountainPen,
  double size = 4,
  Color color = Colors.black,
}) => Stroke(
  color: color,
  pressureEnabled: false,
  options: StrokeOptions(size: size, isComplete: true),
  pageIndex: 0,
  page: _pageSize,
  toolId: toolId,
)..addPoints(points);

EditorCoreInfo _note(List<Stroke> strokes) =>
    EditorCoreInfo(filePath: '/selection_png')
      ..pages.add(EditorPage(size: _pageSize.size, strokes: strokes));

SelectResult _lasso(EditorCoreInfo coreInfo, Rect rect, {int pageIndex = 0}) {
  final page = coreInfo.pages[pageIndex];
  return (Select.currentSelect
        ..onDragStart(rect.topLeft, pageIndex)
        ..onDragUpdate(rect.topRight)
        ..onDragUpdate(rect.bottomRight)
        ..onDragUpdate(rect.bottomLeft)
        ..onDragEnd(page.strokes, page.images))
      .selectResult;
}

/// A copy of the owner's note (never the original), without page 1's PDF,
/// which tests can't draw, and without the answer added to page 2 after.
EditorCoreInfo _ownerNote() {
  final json = BsonCodec.deserialize(
    BsonBinary.from(File('$_eval/hw1-a.sbn2').readAsBytesSync()),
  );
  final pages = json['z'] as List;
  (pages[0] as Map).remove('b');
  (pages[1] as Map).remove('q');
  return EditorCoreInfo.fromJson(
    json,
    filePath: '/owner_copy',
    onlyFirstPage: false,
  );
}

/// The median of 5 runs after a warm-up: (result, milliseconds).
Future<(T?, double)> _time<T>(
  WidgetTester tester,
  Future<T> Function() run,
) async {
  T? result;
  final times = <double>[];
  for (var i = 0; i < 6; i++) {
    final watch = Stopwatch()..start();
    result = await tester.runAsync(run);
    if (i > 0) times.add(watch.elapsedMicroseconds / 1000);
  }
  times.sort();
  return (result, times[times.length ~/ 2]);
}

/// How the AI's picture was made before: the whole page at 2x, cropped
/// to the lasso's bounds and all it selected.
Future<Uint8List?> _oldPng(
  EditorCoreInfo coreInfo,
  int pageIndex,
  Rect area,
) async {
  final pageSize = coreInfo.pages[pageIndex].size;
  area = area.intersect(Offset.zero & pageSize);
  final page = await EditorExporter.screenshotPage(
    coreInfo: coreInfo,
    pageIndex: pageIndex,
    rasterizeAllStrokes: true,
    pixelRatio: min(2.0, 4000 / pageSize.longestSide),
  );
  try {
    final scale = page.width / pageSize.width;
    final src = Rect.fromLTRB(
      area.left * scale,
      area.top * scale,
      area.right * scale,
      area.bottom * scale,
    );
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(page, src, Offset.zero & src.size, Paint());
    final image = await recorder.endRecording().toImage(
      src.width.ceil(),
      src.height.ceil(),
    );
    try {
      final bytes = await image.toByteData(format: .png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    page.dispose();
  }
}
