import 'dart:convert';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/canvas/_asset_cache.dart';
import 'package:nts/components/canvas/_calligraphy_stroke.dart';
import 'package:nts/components/canvas/_circle_stroke.dart';
import 'package:nts/components/canvas/_rectangle_stroke.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/canvas_gesture_detector.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/components/canvas/link_dialog.dart';
import 'package:nts/components/canvas/ruler.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/editor/editor_exporter.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/calligraphy_pen.dart';
import 'package:nts/data/tools/eraser.dart';
import 'package:nts/data/tools/fill.dart';
import 'package:nts/data/tools/highlighter.dart';
import 'package:nts/data/tools/insert_space.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/data/tools/tape.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:sbn/has_size.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

const _page = HasSize(Size(1000, 1400));

Stroke _stroke(
  List<Offset> points, {
  ToolId toolId = .fountainPen,
  double size = 4,
}) => Stroke(
  color: Colors.black,
  pressureEnabled: false,
  options: StrokeOptions(size: size, isComplete: true),
  pageIndex: 0,
  page: _page,
  toolId: toolId,
)..addPoints(points);

/// Goes back and forth [passes] times between x=[left] and x=[right].
List<Offset> _zigZag(
  double left,
  double right,
  double y, {
  int passes = 6,
  double height = 20,
}) => [
  for (var pass = 0; pass < passes; pass++)
    for (var i = 0; i <= 10; i++)
      Offset(
        pass.isEven
            ? left + (right - left) * i / 10
            : right - (right - left) * i / 10,
        y + height * pass / passes,
      ),
];

Stroke _roundTrip(Stroke stroke) => Stroke.fromJson(
  stroke.toJson(),
  fileVersion: EditorCoreInfo.sbnVersion,
  pageIndex: 0,
  page: _page,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  FlavorConfig.setup();
  FileManager.documentsDirectory = '$tmpDir/canvas_tools_test/nts';

  setUp(() {
    stows.lastTool.value = .fountainPen;
    Pen.currentPen = Pen.fountainPen();
    stows.editorFingerDrawing.value = false;
    stows.scribbleToErase.value = false;
    stows.holdToSnapShape.value = true;
    stows.lassoMode.value = .freehand;
    stows.calligraphyNibAngle.value = CalligraphyStroke.defaultNibAngle;
    Select.currentSelect.unselect();
  });

  group('saving', () {
    test('the file version is new enough for older apps to notice', () {
      expect(EditorCoreInfo.sbnVersion, 21);
    });

    test('tape, brush pen and calligraphy strokes keep their pen', () {
      final tape = _stroke(const [Offset.zero, Offset(100, 0)], toolId: .tape);
      expect(_roundTrip(tape).toolId, ToolId.tape);

      final brush = Stroke(
        color: Colors.black,
        pressureEnabled: true,
        options: Pen.brushPenOptions,
        pageIndex: 0,
        page: _page,
        toolId: .brushPen,
      )..addPoints(const [Offset.zero, Offset(50, 50)]);
      final loadedBrush = _roundTrip(brush);
      expect(loadedBrush.toolId, ToolId.brushPen);
      expect(loadedBrush.options.thinning, brush.options.thinning);
      expect(loadedBrush.options.start.customTaper, 25);

      final calligraphy = CalligraphyStroke(
        color: Colors.black,
        pressureEnabled: false,
        options: Pen.calligraphyPenOptions,
        pageIndex: 0,
        page: _page,
        toolId: .calligraphyPen,
        nibAngle: 30,
      )..addPoints(const [Offset.zero, Offset(50, 50)]);
      final loadedCalligraphy = _roundTrip(calligraphy);
      expect(loadedCalligraphy, isA<CalligraphyStroke>());
      expect((loadedCalligraphy as CalligraphyStroke).nibAngle, 30);
      expect(loadedCalligraphy.copy(), isA<CalligraphyStroke>());
    });

    test('fills round-trip on every kind of stroke', () {
      const fill = Color(0xFFE2B46C);
      final loop = _stroke(const [
        Offset.zero,
        Offset(100, 0),
        Offset(100, 100),
        Offset.zero,
      ])..fillColor = fill;
      final circle = CircleStroke(
        color: Colors.black,
        pressureEnabled: false,
        options: StrokeOptions(),
        pageIndex: 0,
        page: _page,
        toolId: .fountainPen,
        center: const Offset(50, 50),
        radius: 20,
      )..fillColor = fill;
      final rect = RectangleStroke(
        color: Colors.black,
        pressureEnabled: false,
        options: StrokeOptions(),
        pageIndex: 0,
        page: _page,
        toolId: .shapePen,
        rect: const Rect.fromLTWH(0, 0, 10, 10),
      )..fillColor = fill;

      for (final stroke in [loop, circle, rect]) {
        final loaded = _roundTrip(stroke);
        expect(loaded.runtimeType, stroke.runtimeType);
        expect(loaded.fillColor, fill);
        expect(loaded.copy().fillColor, fill);
      }
      // Shapes drawn by holding a pen still keep their pen
      expect(_roundTrip(circle).toolId, ToolId.fountainPen);
    });

    test('old strokes load without the new keys', () {
      final json = _stroke(const [Offset.zero, Offset(9, 9)]).toJson()
        ..remove('fc');
      expect(_roundTrip(_stroke(const [Offset(1, 1)])).fillColor, isNull);
      expect(
        Stroke.fromJson(
          json,
          fileVersion: 19,
          pageIndex: 0,
          page: _page,
        ).fillColor,
        isNull,
      );

      final oldCircle = {
        'shape': 'circle',
        'i': 0,
        'cx': 5.0,
        'cy': 5.0,
        'r': 3.0,
        'pe': false,
        'c': Colors.black.toARGB32(),
      };
      final circle = Stroke.fromJson(
        oldCircle,
        fileVersion: 19,
        pageIndex: 0,
        page: _page,
      );
      expect(circle.toolId, ToolId.shapePen);
      expect(circle.fillColor, isNull);
    });

    test('a note with every new element saves and loads', () async {
      final page = EditorPage(size: _page.size);
      final coreInfo = EditorCoreInfo(filePath: '/canvas_tools')
        ..pages.add(page);
      page.strokes.addAll([
        _stroke(const [Offset.zero, Offset(100, 0)], toolId: .tape),
        CalligraphyStroke(
          color: Colors.black,
          pressureEnabled: false,
          options: Pen.calligraphyPenOptions,
          pageIndex: 0,
          page: page,
          toolId: .calligraphyPen,
          nibAngle: 60,
        )..addPoints(const [Offset.zero, Offset(30, 60)]),
        _stroke(const [
          Offset.zero,
          Offset(100, 0),
          Offset(0, 100),
          Offset.zero,
        ])..fillColor = const Color(0xFF7E9B7A),
      ]);
      page.revealedTapes.add(page.strokes.first);
      page.links = [
        const PageLink(Rect.fromLTWH(10, 20, 30, 40), 'https://example.com'),
        const PageLink(Rect.fromLTWH(0, 0, 5, 5), '#page=1'),
      ];

      final (bson, _) = coreInfo.saveToBinary(currentPageIndex: 0);
      final loaded = await EditorCoreInfo.loadFromFileContents(
        bsonBytes: bson,
        path: '/canvas_tools',
        onlyFirstPage: false,
      );
      expect(loaded.readOnly, isFalse);
      final loadedPage = loaded.pages.first;
      expect(loadedPage.links, page.links);
      expect(loadedPage.revealedTapes, isEmpty, reason: 'tapes cover again');
      Stroke byTool(ToolId id) =>
          loadedPage.strokes.firstWhere((stroke) => stroke.toolId == id);
      expect(byTool(.tape), isNotNull);
      expect((byTool(.calligraphyPen) as CalligraphyStroke).nibAngle, 60);
      expect(byTool(.fountainPen).fillColor, const Color(0xFF7E9B7A));
      expect(byTool(.tape).fillColor, isNull);
      coreInfo.dispose();
      loaded.dispose();
    });

    testWidgets('a note with the new strokes exports to PDF', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final page = EditorPage(size: _page.size);
      final coreInfo = EditorCoreInfo(filePath: '/canvas_tools_pdf')
        ..pages.addAll([page, EditorPage(size: _page.size)]);
      page.strokes.addAll([
        _stroke(const [Offset(10, 10), Offset(300, 10)], toolId: .tape),
        CalligraphyStroke(
          color: Colors.black,
          pressureEnabled: false,
          options: Pen.calligraphyPenOptions,
          pageIndex: 0,
          page: page,
          toolId: .calligraphyPen,
        )..addPoints(const [Offset(50, 50), Offset(80, 120), Offset(140, 60)]),
        _stroke(const [
          Offset(200, 200),
          Offset(400, 200),
          Offset(300, 400),
          Offset(200, 200),
        ])..fillColor = const Color(0xFFE2B46C),
      ]);
      final bytes = await tester.runAsync(() async {
        final pdf = await EditorExporter.generatePdf(coreInfo, context);
        return pdf.save();
      });
      expect(bytes, isNotEmpty);
    });

    test('old pages have no links', () {
      final page = EditorPage.fromJson(
        {'w': 1000.0, 'h': 1400.0},
        inlineAssets: null,
        readOnly: false,
        fileVersion: 19,
        sbnPath: '/old',
        assetCache: AssetCache(),
      );
      expect(page.links, isEmpty);
      expect(page.toJson(OrderedAssetCache()), isNot(contains('lk')));
    });

    test('links must be web, email or page links', () {
      String? parse(String url) => PageLink.parse(url, pageCount: 3);
      expect(parse('https://example.com/a?b=c'), 'https://example.com/a?b=c');
      expect(parse(' example.com '), 'https://example.com');
      expect(parse('name@example.com'), 'mailto:name@example.com');
      expect(parse('mailto:name@example.com'), 'mailto:name@example.com');
      expect(parse('#page=3'), '#page=3');
      expect(parse('#page=4'), isNull);
      expect(parse('#page=0'), isNull);
      expect(parse('javascript:alert(1)'), isNull);
      expect(parse('file:///etc/passwd'), isNull);
      expect(parse('two words'), isNull);
      expect(parse(''), isNull);
      expect(const PageLink(Rect.zero, '#page=2').pageIndex, 1);
      expect(const PageLink(Rect.zero, 'https://a.b').pageIndex, isNull);
    });
  });

  group('catalog', () {
    test('the canvas tools can be added but new users do not get them', () {
      for (final id in [
        'tape',
        'fill',
        'holdToSnapShape',
        'scribbleToErase',
        'insertSpace',
        'ruler',
      ]) {
        expect(ToolCatalog.byId(id), isNotNull, reason: id);
        expect(ToolCatalog.basics, isNot(contains(id)));
      }
    });
  });

  group('tape', () {
    test('is always opaque', () {
      final tape = Tape()..color = const Color(0x33FF0000);
      expect(tape.color, const Color(0xFFFF0000));
    });

    testWidgets('covers ink, and tapping it shows what is under it', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      final page = editor.coreInfo.pages.first;
      editor.currentTool = Tape.currentTape;
      await _stylus(tester, editor, const [
        Offset(100, 200),
        Offset(200, 200),
        Offset(300, 200),
      ]);
      expect(page.strokes, hasLength(1));
      final tape = page.strokes.single;
      expect(tape.toolId, ToolId.tape);

      await _stylus(tester, editor, const [Offset(200, 200)]);
      expect(page.strokes, [tape], reason: 'a tap on tape adds no dot');
      expect(page.revealedTapes, {tape});

      await _stylus(tester, editor, const [Offset(200, 200)]);
      expect(page.revealedTapes, isEmpty);
      expect(editor.history.canUndo, isTrue);
      editor.undo();
      expect(page.strokes, isEmpty, reason: 'toggling is not an edit');
    });
  });

  group('calligraphy pen', () {
    test('is thin along the nib and thick across it', () {
      CalligraphyStroke line(List<Offset> points) => CalligraphyStroke(
        color: Colors.black,
        pressureEnabled: false,
        options: StrokeOptions(size: 20, streamline: 0, isComplete: true),
        pageIndex: 0,
        page: _page,
        toolId: .calligraphyPen,
        nibAngle: 0, // a horizontal nib
      )..addPoints(points);
      Rect boundsOf(Stroke stroke) {
        final polygon = stroke.highQualityPolygon;
        return polygon
            .skip(1)
            .fold(
              polygon.first & Size.zero,
              (r, p) => r.expandToInclude(p & Size.zero),
            );
      }

      final horizontal = line(const [Offset(0, 50), Offset(100, 50)]);
      expect(boundsOf(horizontal).height, lessThan(3));
      final vertical = line(const [Offset(50, 0), Offset(50, 100)]);
      expect(boundsOf(vertical).width, closeTo(20, 0.01));

      // The PDF export draws the same outline
      expect(vertical.toSvgPath(), startsWith('M'));
      expect(vertical.toSvgPath(), endsWith('Z'));

      // Partly erased pieces keep the nib
      final pieces = vertical.erasePartially(
        const Offset(0, 50),
        const Offset(100, 50),
        5,
      )!;
      expect(pieces, hasLength(2));
      expect(pieces, everyElement(isA<CalligraphyStroke>()));

      // Turning it turns the nib
      final turned = vertical.transformed(Matrix4.rotationZ(-pi / 2));
      expect(turned.nibAngle, closeTo(90, 1e-9));
    });

    test('the pen uses the nib angle setting', () {
      stows.calligraphyNibAngle.value = 60;
      final pen = CalligraphyPen();
      pen.onDragStart(Offset.zero, EditorPage(), 0, null);
      final stroke = pen.onDragEnd();
      expect(stroke, isA<CalligraphyStroke>());
      expect((stroke! as CalligraphyStroke).nibAngle, 60);
    });
  });

  group('fill', () {
    test('fills the smallest closed stroke around the tap', () {
      final big = _stroke(const [
        Offset.zero,
        Offset(200, 0),
        Offset(200, 200),
        Offset(0, 200),
        Offset.zero,
      ]);
      final small = CircleStroke(
        color: Colors.black,
        pressureEnabled: false,
        options: StrokeOptions(),
        pageIndex: 0,
        page: _page,
        toolId: .shapePen,
        center: const Offset(100, 100),
        radius: 20,
      );
      final open = _stroke(const [Offset.zero, Offset(200, 200)]);
      final strokes = [big, small, open];
      expect(open.isClosed, isFalse);
      expect(Fill.strokeAt(strokes, const Offset(100, 100)), small);
      expect(Fill.strokeAt(strokes, const Offset(20, 150)), big);
      expect(Fill.strokeAt(strokes, const Offset(300, 300)), isNull);
    });

    testWidgets('tapping fills, tapping again with the color clears it, '
        'and it undoes', (tester) async {
      final editor = await _pumpEditor(tester);
      final page = editor.coreInfo.pages.first;
      final circle = CircleStroke(
        color: Colors.black,
        pressureEnabled: false,
        options: StrokeOptions(),
        pageIndex: 0,
        page: page,
        toolId: .shapePen,
        center: const Offset(300, 300),
        radius: 80,
      );
      page.strokes.add(circle);
      final fill = Fill.currentFill..color = const Color(0xFF6C8CA8);
      editor.currentTool = fill;

      await _stylus(tester, editor, const [Offset(300, 300)]);
      expect(circle.fillColor, fill.color);
      await _stylus(tester, editor, const [Offset(310, 290)]);
      expect(circle.fillColor, isNull);

      editor.undo();
      expect(circle.fillColor, fill.color);
      editor.undo();
      expect(circle.fillColor, isNull);
      editor.redo();
      expect(circle.fillColor, fill.color);
    });

    test('fills are rasterized under the text in exports', () {
      final page = EditorPage(size: _page.size);
      final filled = _stroke(const [
        Offset.zero,
        Offset(50, 0),
        Offset(0, 50),
        Offset.zero,
      ])..fillColor = Colors.red;
      page.strokes.add(filled);
      final clone = page.cloneForRasterization();
      expect(clone.strokes, hasLength(1));
      expect(clone.strokes.single.fillColor, Colors.red);
      expect(
        clone.strokes.single.color.a,
        0,
        reason: 'the outline is a vector',
      );
      clone.disposeClonedData();
      page.dispose();
    });
  });

  group('rectangle lasso', () {
    test('selects what is inside the dragged rectangle', () {
      stows.lassoMode.value = .rectangle;
      final inside = _stroke(const [Offset(20, 20), Offset(40, 40)]);
      final outside = _stroke(const [Offset(200, 200), Offset(240, 240)]);
      final select = Select.currentSelect
        ..onDragStart(const Offset(10, 10), 0)
        ..onDragUpdate(const Offset(30, 90))
        ..onDragUpdate(const Offset(100, 100))
        ..onDragEnd([inside, outside], const []);
      expect(select.selectResult.strokes, [inside]);
      expect(
        select.selectResult.path.getBounds(),
        const Rect.fromLTRB(10, 10, 100, 100),
      );
    });
  });

  group('resize and rotate', () {
    Select selectAll(
      List<Stroke> strokes, [
      List<EditorImage> images = const [],
    ]) {
      return Select.currentSelect
        ..onDragStart(const Offset(-500, -500), 0)
        ..onDragUpdate(const Offset(1500, -500))
        ..onDragUpdate(const Offset(1500, 1500))
        ..onDragUpdate(const Offset(-500, 1500))
        ..onDragEnd(strokes, images)
        ..handleRadius = 10;
    }

    test('a corner scales from the opposite corner, and undoes', () {
      final a = _stroke(const [Offset(100, 100), Offset(200, 100)]);
      final b = CircleStroke(
        color: Colors.black,
        pressureEnabled: false,
        options: StrokeOptions(size: 4),
        pageIndex: 0,
        page: _page,
        toolId: .shapePen,
        center: const Offset(150, 200),
        radius: 20,
      );
      final strokes = <Stroke>[a, b];
      final select = selectAll(strokes);
      final bounds = select.selectionBounds!;
      final corner = select.handles[SelectionHandle.bottomRight]!;
      expect(corner, bounds.bottomRight);

      expect(select.startTransform(corner, strokes), isTrue);
      select.updateTransform(
        bounds.topLeft + (corner - bounds.topLeft) * 2,
        strokes,
      );
      final item = select.finishTransform(0, strokes)!;

      expect(strokes, hasLength(2));
      final scaledB = strokes[1] as CircleStroke;
      expect(scaledB.radius, closeTo(40, 1e-6));
      expect(scaledB.options.size, closeTo(8, 1e-6));
      expect(strokes[0].bounds.width, closeTo(200, 1e-6));
      expect(select.selectResult.strokes, strokes);

      item.strokeListChange!.reverse().apply(strokes);
      expect(strokes, [a, b]);
      expect(b.radius, 20, reason: 'the originals are untouched');
    });

    test('rotating turns a rectangle into a polyline, but not by 90°', () {
      Stroke rect() => RectangleStroke(
        color: Colors.black,
        pressureEnabled: false,
        options: StrokeOptions(size: 4),
        pageIndex: 0,
        page: _page,
        toolId: .shapePen,
        rect: const Rect.fromLTWH(100, 100, 200, 100),
      );
      for (final (angle, stillARectangle) in [
        (pi / 4, false),
        (pi / 2, true),
      ]) {
        final strokes = [rect()];
        final select = selectAll(strokes);
        final center = select.selectionBounds!.center;
        final handle = select.handles[SelectionHandle.rotate]!;
        expect(select.startTransform(handle, strokes), isTrue);
        final from = handle - center;
        select.updateTransform(
          center +
              Offset(
                from.dx * cos(angle) - from.dy * sin(angle),
                from.dx * sin(angle) + from.dy * cos(angle),
              ),
          strokes,
        );
        expect(select.finishTransform(0, strokes), isNotNull);
        expect(strokes.single is RectangleStroke, stillARectangle);
        expect(strokes.single.bounds.center.dx, closeTo(center.dx, 1e-6));
      }
    });

    test('images scale but do not rotate', () {
      final image = _TestImage(dstRect: const Rect.fromLTWH(0, 0, 100, 50));
      final strokes = <Stroke>[];
      final select = selectAll(strokes, [image]);
      expect(select.handles, isNot(contains(SelectionHandle.rotate)));

      final corner = select.handles[SelectionHandle.bottomRight]!;
      expect(select.startTransform(corner, strokes), isTrue);
      select.updateTransform(corner * 1.5, strokes);
      final item = select.finishTransform(0, strokes)!;
      expect(image.dstRect, const Rect.fromLTWH(0, 0, 150, 75));
      expect(
        item.imageRectChange![image]!.previous,
        const Rect.fromLTWH(0, 0, 100, 50),
      );
    });

    testWidgets('the editor records it, so it undoes', (tester) async {
      final editor = await _pumpEditor(tester);
      final page = editor.coreInfo.pages.first;
      final stroke = _stroke(const [Offset(200, 300), Offset(400, 300)]);
      final image = _TestImage(
        dstRect: const Rect.fromLTWH(200, 400, 100, 100),
      );
      page.strokes.add(stroke);
      page.images.add(image);
      editor.currentTool = Select.currentSelect;
      selectAll(page.strokes, page.images);
      await tester.pump();

      final select = Select.currentSelect;
      final corner = select.handles[SelectionHandle.bottomRight]!;
      final pivot = select.handles[SelectionHandle.topLeft]!;
      await _stylus(tester, editor, [corner, (corner + pivot) / 2]);
      expect(page.strokes.single, isNot(stroke));
      expect(image.dstRect.width, closeTo(50, 1));

      editor.undo();
      expect(page.strokes, [stroke]);
      expect(image.dstRect, const Rect.fromLTWH(200, 400, 100, 100));
      editor.redo();
      expect(page.strokes.single.bounds.width, closeTo(100, 1));
      expect(image.dstRect.width, closeTo(50, 1));
    });
  });

  group('resize after other edits', () {
    testWidgets('undoing a move after a resize moves the ink back', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      final page = editor.coreInfo.pages.first;
      final stroke = _stroke(const [Offset(200, 300), Offset(400, 300)]);
      final left = stroke.bounds.left;
      page.strokes.add(stroke);
      editor.currentTool = Select.currentSelect;
      Select.currentSelect
        ..onDragStart(const Offset(100, 200), 0)
        ..onDragUpdate(const Offset(500, 200))
        ..onDragUpdate(const Offset(500, 400))
        ..onDragUpdate(const Offset(100, 400))
        ..onDragEnd(page.strokes, page.images)
        ..handleRadius = 10;
      await tester.pump();

      await _stylus(tester, editor, const [
        Offset(300, 300),
        Offset(325, 300),
        Offset(350, 300),
      ]);
      expect(page.strokes.single.bounds.left, closeTo(left + 50, 1));

      final select = Select.currentSelect;
      final corner = select.handles[SelectionHandle.bottomRight]!;
      final pivot = select.handles[SelectionHandle.topLeft]!;
      await _stylus(tester, editor, [corner, (corner + pivot) / 2]);

      editor.undo(); // the resize
      editor.undo(); // the move
      expect(page.strokes, [stroke]);
      expect(stroke.bounds.left, closeTo(left, 1));
    });

    test("stops if the page's strokes moved under it", () {
      final x = _stroke(const [Offset(0, 500), Offset(50, 500)]);
      final a = _stroke(const [Offset(100, 100), Offset(200, 100)]);
      final b = _stroke(const [Offset(0, 800), Offset(50, 800)]);
      final strokes = [x, a, b];
      final select = Select.currentSelect
        ..onDragStart(const Offset(50, 50), 0)
        ..onDragUpdate(const Offset(250, 50))
        ..onDragUpdate(const Offset(250, 150))
        ..onDragUpdate(const Offset(50, 150))
        ..onDragEnd(strokes, const [])
        ..handleRadius = 10;
      expect(select.selectResult.strokes, [a]);

      final corner = select.handles[SelectionHandle.bottomRight]!;
      expect(select.startTransform(corner, strokes), isTrue);
      select.updateTransform(corner + const Offset(20, 20), strokes);
      expect(strokes[1], isNot(a));
      strokes.removeAt(0); // e.g. an undo in the middle of the drag
      select.updateTransform(corner + const Offset(40, 40), strokes);
      expect(strokes[1], b);
      expect(select.isTransforming, isFalse);
      expect(select.finishTransform(0, strokes), isNull);
    });
  });

  test('a page with only links is not empty', () {
    final page = EditorPage(size: _page.size);
    expect(page.isEmpty, isTrue);
    page.links = [const PageLink(Rect.fromLTWH(0, 0, 5, 5), '#page=1')];
    expect(page.isEmpty, isFalse);
  });

  group('scribble to erase', () {
    test('a zig-zag is a scribble, handwriting is not', () {
      expect(_stroke(_zigZag(0, 100, 0)).isScribble(), isTrue);
      expect(_stroke(_zigZag(0, 100, 0, passes: 3)).isScribble(), isFalse);

      // "mmm": up and down, but only one way along
      final mmm = [
        for (var letter = 0; letter < 3; letter++)
          for (var hump = 0; hump < 2; hump++)
            for (var i = 0; i <= 8; i++)
              Offset(
                letter * 40 + hump * 20 + i * 20 / 8,
                20 - 20 * sin(pi * i / 8),
              ),
      ];
      expect(_stroke(mmm).isScribble(), isFalse);
      // A straight line isn't either
      expect(
        _stroke(const [
          Offset.zero,
          Offset(25, 0),
          Offset(50, 0),
          Offset(75, 0),
          Offset(100, 0),
        ]).isScribble(),
        isFalse,
      );
    });

    test('erases what is mostly under it', () {
      final scribble = _stroke(_zigZag(0, 100, 0));
      final under = _stroke(const [Offset(10, 10), Offset(90, 10)]);
      final partly = _stroke(const [Offset(50, 10), Offset(400, 10)]);
      final away = _stroke(const [Offset(300, 300), Offset(400, 300)]);
      expect(
        Eraser.strokesUnderScribble(scribble, [under, partly, away, scribble]),
        [under],
      );
    });

    testWidgets('only when it is on, and it undoes', (tester) async {
      final editor = await _pumpEditor(tester);
      final page = editor.coreInfo.pages.first;
      editor.currentTool = Pen.currentPen = Pen.fountainPen();
      await _stylus(tester, editor, const [
        Offset(210, 310),
        Offset(250, 310),
        Offset(290, 310),
      ]);
      final word = page.strokes.single;

      await _stylus(tester, editor, _zigZag(200, 300, 300));
      expect(page.strokes, hasLength(2), reason: 'off by default');
      editor.undo();

      stows.scribbleToErase.value = true;
      await _stylus(tester, editor, _zigZag(200, 300, 300));
      expect(page.strokes, isEmpty);
      editor.undo();
      expect(page.strokes, [word]);

      // With nothing under it, it's just ink
      await _stylus(tester, editor, _zigZag(500, 600, 600));
      expect(page.strokes, hasLength(2));
    });
  });

  group('insert space', () {
    testWidgets('pushes what is below the line down, and undoes', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      final page = editor.coreInfo.pages.first;
      final above = _stroke(const [Offset(100, 100), Offset(200, 100)]);
      final below = _stroke(const [Offset(100, 500), Offset(200, 500)]);
      final image = _TestImage(dstRect: const Rect.fromLTWH(100, 600, 50, 50));
      page.strokes.addAll([above, below]);
      page.images.add(image);
      editor.currentTool = InsertSpace.currentInsertSpace;

      await _stylus(tester, editor, const [
        Offset(300, 300),
        Offset(300, 350),
        Offset(300, 400),
      ]);
      expect(above.bounds.top, 100);
      expect(below.bounds.top, closeTo(600, 0.5));
      expect(image.dstRect.top, closeTo(700, 0.5));
      expect(InsertSpace.currentInsertSpace.preview, isNull);

      editor.undo();
      expect(below.bounds.top, closeTo(500, 0.5));
      expect(image.dstRect.top, closeTo(600, 0.5));

      // Removing space stops at the content above
      await _stylus(tester, editor, const [
        Offset(300, 300),
        Offset(300, 0),
        Offset(300, -300),
      ]);
      expect(below.bounds.top, closeTo(100 + 2 + 2, 0.5));
    });

    test('keeps what moves on the page', () {
      final page = EditorPage(size: const Size(1000, 1000));
      page.strokes.add(_stroke(const [Offset(0, 900), Offset(10, 950)]));
      expect(InsertSpace.clampDy(page, 800, 500), closeTo(48, 1e-9));
      expect(InsertSpace.clampDy(page, 800, -2000), closeTo(-898, 1e-9));
      page.dispose();
    });
  });

  group('hold to snap shape', () {
    // (The recognizer needs 64 points or more)
    List<Offset> circle(Offset center, double radius) => [
      for (var i = 0; i <= 76; i++)
        center + Offset(cos(2 * pi * i / 80), sin(2 * pi * i / 80)) * radius,
    ];

    testWidgets('holding still at the end snaps a pen stroke', (tester) async {
      final page = EditorPage();
      final pen = Pen.fountainPen();
      final points = circle(const Offset(300, 300), 100);
      pen.onDragStart(points.first, page, 0, null);
      for (final point in points.skip(1)) {
        pen.onDragUpdate(point, null);
      }
      expect(Pen.snapPreview, isNull);
      await tester.pump(Pen.holdToSnapDelay);
      expect(Pen.snapPreview, isA<CircleStroke>());

      final stroke = pen.onDragEnd();
      expect(stroke, isA<CircleStroke>());
      expect(stroke!.toolId, ToolId.fountainPen);
      expect((stroke as CircleStroke).radius, closeTo(100, 10));
      expect(Pen.snapPreview, isNull);
      page.dispose();
    });

    testWidgets('moving on, or the setting being off, keeps the stroke', (
      tester,
    ) async {
      final page = EditorPage();
      final pen = Pen.fountainPen();
      final points = circle(const Offset(300, 300), 100);

      pen.onDragStart(points.first, page, 0, null);
      for (final point in points.skip(1)) {
        pen.onDragUpdate(point, null);
      }
      await tester.pump(Pen.holdToSnapDelay);
      pen.onDragUpdate(const Offset(500, 500), null);
      expect(Pen.snapPreview, isNull);
      expect(pen.onDragEnd(), isNot(isA<CircleStroke>()));

      stows.holdToSnapShape.value = false;
      pen.onDragStart(points.first, page, 0, null);
      for (final point in points.skip(1)) {
        pen.onDragUpdate(point, null);
      }
      await tester.pump(Pen.holdToSnapDelay);
      expect(Pen.snapPreview, isNull);
      expect(pen.onDragEnd(), isNot(isA<CircleStroke>()));
      page.dispose();
    });

    testWidgets('pausing on handwriting does not snap', (tester) async {
      final page = EditorPage();
      final pen = Pen.ballpointPen();
      final squiggle = [
        for (var i = 0; i <= 90; i++) Offset(i * 3.0, 20 * sin(i / 4).abs()),
      ];
      pen.onDragStart(squiggle.first, page, 0, null);
      for (final point in squiggle.skip(1)) {
        pen.onDragUpdate(point, null);
      }
      await tester.pump(Pen.holdToSnapDelay);
      final stroke = pen.onDragEnd()!;
      expect(stroke.runtimeType, Stroke);
      expect(stroke.length, greaterThan(10));
      page.dispose();
    });

    /// The stroke [pen] makes through [points] when held still at the end.
    Future<Stroke> held(
      WidgetTester tester,
      Pen pen,
      List<Offset> points,
    ) async {
      final page = EditorPage();
      pen.onDragStart(points.first, page, 0, null);
      for (final point in points.skip(1)) {
        pen.onDragUpdate(point, null);
      }
      await tester.pump(Pen.holdToSnapDelay);
      return pen.onDragEnd()!;
    }

    // Wobbly, and with few points, like a quick stroke with the Pencil
    List<Offset> wobbly(List<Offset> corners, {int perSide = 8}) {
      final random = Random(2);
      return [
        for (var i = 0; i + 1 < corners.length; i++)
          for (var k = 0; k < perSide; k++)
            Offset.lerp(corners[i], corners[i + 1], k / perSide)! +
                Offset(
                  random.nextDouble() * 8 - 4,
                  random.nextDouble() * 8 - 4,
                ),
        corners.last,
      ];
    }

    testWidgets('a quick wobbly line snaps straight', (tester) async {
      final points = wobbly(const [Offset(100, 100), Offset(500, 130)]);
      expect(points.length, lessThan(64));
      final line = await held(tester, Pen.ballpointPen(), points);
      expect(line.length, 3); // first, last, last
    });

    testWidgets('a squarish rectangle snaps square, a long one stays', (
      tester,
    ) async {
      final square = await held(
        tester,
        Pen.fountainPen(),
        wobbly(const [
          Offset(100, 100),
          Offset(300, 110),
          Offset(305, 290),
          Offset(100, 300),
          Offset(102, 104),
        ]),
      );
      expect(square, isA<RectangleStroke>());
      final rect = (square as RectangleStroke).rect;
      expect(rect.width, closeTo(rect.height, 1e-9));

      final long = await held(
        tester,
        Pen.fountainPen(),
        wobbly(const [
          Offset(100, 100),
          Offset(500, 105),
          Offset(500, 300),
          Offset(100, 300),
          Offset(102, 104),
        ]),
      );
      final longRect = (long as RectangleStroke).rect;
      expect(longRect.width, greaterThan(longRect.height * 1.5));
    });

    testWidgets('a long loop snaps to an oval, a round one to a circle', (
      tester,
    ) async {
      List<Offset> loop(double rx, double ry) => [
        for (var i = 0; i <= 70; i++)
          Offset(
            300 + rx * cos(2 * pi * i / 72),
            300 + ry * sin(2 * pi * i / 72),
          ),
      ];
      final oval = await held(tester, Pen.fountainPen(), loop(200, 80));
      expect(oval, isNot(isA<CircleStroke>()));
      expect(oval.bounds.width, closeTo(400, 10));
      expect(oval.bounds.height, closeTo(160, 10));
      expect(oval.isClosed, isTrue);

      expect(
        await held(tester, Pen.fountainPen(), loop(100, 95)),
        isA<CircleStroke>(),
      );
    });

    testWidgets('a tilted oval stays tilted, a tilted square too', (
      tester,
    ) async {
      // An oval turned 45°: its upright box is square, but it isn't a circle
      final turned = [
        for (var i = 0; i <= 70; i++)
          () {
            final t = 2 * pi * i / 72;
            final x = 200 * cos(t), y = 80 * sin(t);
            return Offset(300 + (x - y) / sqrt2, 300 + (x + y) / sqrt2);
          }(),
      ];
      final oval = await held(tester, Pen.fountainPen(), turned);
      expect(oval, isNot(isA<CircleStroke>()));
      expect(oval.isClosed, isTrue);
      // Its far ends are about 200 from the middle, along the diagonal
      final far = oval.bounds.topLeft - const Offset(300, 300);
      expect(far.distance, closeTo(200 * sqrt2 * 0.75, 40));

      final diamond = await held(
        tester,
        Pen.fountainPen(),
        wobbly(const [
          Offset(300, 100),
          Offset(500, 300),
          Offset(300, 500),
          Offset(100, 300),
          Offset(302, 102),
        ]),
      );
      expect(diamond, isNot(isA<RectangleStroke>()));
      expect(diamond.bounds.width, closeTo(400, 30));
    });

    testWidgets("snapping a line doesn't change the pen's taper", (
      tester,
    ) async {
      final brush = Pen.brushPen();
      final taper = brush.options.start.taperEnabled;
      expect(taper, isTrue);
      await held(
        tester,
        brush,
        wobbly(const [Offset(100, 100), Offset(500, 130)]),
      );
      expect(brush.options.start.taperEnabled, taper);
      expect(brush.options.end.taperEnabled, isTrue);
    });

    test('a quick line straightens only when held, not by itself', () {
      final quick = _stroke(
        List.generate(
          20,
          (i) => Offset(100 + i * 20.0, 100 + (i.isEven ? 3 : -3)),
        ),
      );
      expect(quick.length, lessThan(64));
      expect(quick.isStraightLine(), isFalse);
      expect(quick.detectShape()?.name, isNotNull);
    });

    testWidgets('the highlighter only snaps lines', (tester) async {
      final circle = await held(tester, Highlighter(), [
        for (var i = 0; i <= 76; i++)
          const Offset(300, 300) +
              Offset(cos(2 * pi * i / 80), sin(2 * pi * i / 80)) * 100,
      ]);
      expect(circle.runtimeType, Stroke);
      expect(circle.length, greaterThan(10));
      final line = await held(
        tester,
        Highlighter(),
        wobbly(const [Offset(100, 100), Offset(600, 100)]),
      );
      expect(line.length, 3);
    });
  });

  group('ruler', () {
    test('snaps points near an edge onto it', () {
      const ruler = (center: Offset(100, 100), angle: 0.0);
      const edge = RulerOverlay.height / 2;
      expect(ruler.edgeNear(const Offset(0, 100 - edge - 10)), -1);
      expect(ruler.edgeNear(const Offset(0, 100 + edge + 20)), 1);
      expect(ruler.edgeNear(const Offset(0, 100 + edge + 30)), isNull);
      expect(
        ruler.snap(const Offset(40, 70), -1),
        const Offset(40, 100 - edge),
      );

      const turned = (center: Offset.zero, angle: pi / 2);
      final snapped = turned.snap(const Offset(20, 50), 1);
      expect(snapped.dx, closeTo(-edge, 1e-9));
      expect(snapped.dy, closeTo(50, 1e-9));
    });

    testWidgets('pen strokes that start near it follow its edge', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      final page = editor.coreInfo.pages.first;
      editor.toggleRuler();
      await tester.pump();
      final ruler = editor.ruler.value!;
      expect(ruler.angle, 0);

      final box = tester.renderObject<RenderBox>(find.byType(RulerOverlay));
      final edge = box.localToGlobal(
        ruler.center - const Offset(0, RulerOverlay.height / 2),
      );
      final gesture = await tester.createGesture(kind: .stylus);
      await gesture.down(edge + const Offset(-100, -10));
      await gesture.moveTo(edge + const Offset(-50, -18));
      await gesture.moveTo(edge + const Offset(0, 5));
      await gesture.moveTo(edge + const Offset(80, -12));
      await gesture.up();
      await tester.pump();

      final stroke = page.strokes.single;
      final edgeY = page.renderBox!.globalToLocal(edge).dy;
      expect(stroke.bounds.top, closeTo(edgeY, 0.01));
      expect(stroke.bounds.bottom, closeTo(edgeY, 0.01));

      // Hiding it stops the snapping
      editor.toggleRuler();
      expect(editor.ruler.value, isNull);
    });

    testWidgets('a stylus on it draws, along the nearest edge', (tester) async {
      final editor = await _pumpEditor(tester);
      final page = editor.coreInfo.pages.first;
      editor.toggleRuler();
      await tester.pump();
      final ruler = editor.ruler.value!;
      final box = tester.renderObject<RenderBox>(find.byType(RulerOverlay));
      // On the ruler, 16px inside its top edge
      final start = box.localToGlobal(ruler.center + const Offset(-100, -20));
      final gesture = await tester.createGesture(kind: .stylus);
      await gesture.down(start);
      await gesture.moveTo(start + const Offset(40, 0));
      await gesture.moveTo(start + const Offset(160, 2));
      await gesture.up();
      await tester.pump();

      final edgeY = page.renderBox!
          .globalToLocal(
            box.localToGlobal(
              ruler.center - const Offset(0, RulerOverlay.height / 2),
            ),
          )
          .dy;
      expect(page.strokes.single.bounds.top, closeTo(edgeY, 0.01));
      expect(editor.ruler.value, ruler, reason: "the ruler didn't move");
    });

    testWidgets('a finger moves it without drawing', (tester) async {
      stows.editorFingerDrawing.value = true;
      final editor = await _pumpEditor(tester);
      editor.toggleRuler();
      await tester.pump();
      final before = editor.ruler.value!.center;
      final box = tester.renderObject<RenderBox>(find.byType(RulerOverlay));

      await tester.dragFrom(
        box.localToGlobal(before + const Offset(60, 0)),
        const Offset(30, 80),
      );
      await tester.pump();
      // (Minus the slop before a drag starts)
      final moved = editor.ruler.value!.center - before;
      expect(moved.dx, inInclusiveRange(10, 30));
      expect(moved.dy, inInclusiveRange(40, 80));
      expect(editor.coreInfo.pages.first.strokes, isEmpty);
    });
  });

  group('links', () {
    testWidgets('are added to a selection, and tapping one opens it', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      editor.createPage(2);
      final page = editor.coreInfo.pages.first;
      final ink = _stroke(const [Offset(100, 100), Offset(200, 150)]);
      page.strokes.add(ink);
      editor.currentTool = Select.currentSelect;
      Select.currentSelect
        ..onDragStart(const Offset(50, 50), 0)
        ..onDragUpdate(const Offset(250, 50))
        ..onDragUpdate(const Offset(250, 200))
        ..onDragUpdate(const Offset(50, 200))
        ..onDragEnd(page.strokes, page.images);
      await tester.pump();

      final done = editor.editSelectionLink();
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(LinkDialog),
        matching: find.byType(EditableText),
      );
      await tester.enterText(field, 'not a link');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(page.links, isEmpty, reason: 'invalid links are refused');
      await tester.enterText(field, '#page=2');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await done;
      expect(page.links, hasLength(1));
      expect(page.links.single.url, '#page=2');
      expect(page.links.single.rect.contains(const Offset(150, 125)), isTrue);

      // Tapping it goes to page 2
      Select.currentSelect.unselect();
      expect(editor.scrollY, 0);
      await _stylus(tester, editor, const [Offset(150, 125)]);
      expect(-editor.scrollY, _scrolledTo(editor, 1));

      editor.undo();
      expect(page.links, isEmpty);
      editor.redo();
      expect(page.links, hasLength(1));
    });

    testWidgets('open in read-only notes too', (tester) async {
      final editor = await _pumpEditor(tester);
      editor.createPage(2);
      final page = editor.coreInfo.pages.first;
      page.links = [
        const PageLink(Rect.fromLTWH(100, 100, 100, 50), '#page=3'),
      ];
      editor.coreInfo.readOnlyReason = .versionTooNew;
      tester.element(find.byType(Editor)).markNeedsBuild();
      await tester.pump();

      await tester.tapAt(_global(editor, const Offset(150, 125)));
      await tester.pump();
      expect(-editor.scrollY, _scrolledTo(editor, 2));
    });
  });
}

Future<EditorState> _pumpEditor(WidgetTester tester) async {
  // Big enough that pages aren't scaled down, and the bars are out of the way
  tester.view
    ..physicalSize = const Size(1200, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Editor(path: '/canvas_tools_${tester.testDescription.hashCode}'),
    ),
  );
  await tester.pump();
  final editor = tester.state<EditorState>(find.byType(Editor));
  addTearDown(editor.cancelAutosaveAndMarkSaved);
  return editor;
}

/// The scroll position after [CanvasGestureDetector.scrollToPage].
Matcher _scrolledTo(EditorState editor, int pageIndex) => closeTo(
  CanvasGestureDetector.getTopOfPage(
        pageIndex: pageIndex,
        pages: editor.coreInfo.pages,
        screenWidth: 1200,
      ) -
      50,
  1,
);

Offset _global(EditorState editor, Offset local) =>
    editor.coreInfo.pages.first.renderBox!.localToGlobal(local);

/// Draws through [points] on the first page with a stylus
/// (a tap if there's one point).
Future<void> _stylus(
  WidgetTester tester,
  EditorState editor,
  List<Offset> points,
) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.stylus);
  await gesture.down(_global(editor, points.first));
  for (final point in points.skip(1)) {
    await gesture.moveTo(_global(editor, point));
  }
  await gesture.up();
  await tester.pump();
}

// ignore: missing_override_of_must_be_overridden
class _TestImage extends PngEditorImage {
  static final _assetCache = AssetCache();

  new({required super.dstRect})
    : super(
        id: -1,
        extension: '.png',
        imageProvider: MemoryImage(_pixel),
        pageIndex: 0,
        pageSize: const Size(1000, 1400),
        onMoveImage: null,
        onDeleteImage: null,
        onMiscChange: null,
        assetCache: _assetCache,
      );

  @override
  Future<void> firstLoad() async {}

  /// Not unloaded, so no timer is left when the test ends.
  @override
  // ignore: must_call_super
  Future<bool> loadOut() async => false;
}

/// A transparent 1x1 PNG.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);
