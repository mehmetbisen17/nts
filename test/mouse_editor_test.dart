// The editor with a mouse (and a Mac trackpad's click, which Flutter
// reports as a mouse): it draws with every tool whatever the finger
// drawing toggle says, pans with the wheel, middle button and Space,
// has cursors, right-click menus and keyboard shortcuts.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:keybinder/keybinder.dart';
import 'package:nts/components/canvas/_asset_cache.dart';
import 'package:nts/components/canvas/_circle_stroke.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/components/canvas/interactive_canvas.dart';
import 'package:nts/components/canvas/pencil_shader.dart';
import 'package:nts/components/canvas/ruler.dart';
import 'package:nts/components/toolbar/floating_bar.dart';
import 'package:nts/components/toolbar/toolbar.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/extensions/matrix4_extensions.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/services/selection_clipboard.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/data/tools/calligraphy_pen.dart';
import 'package:nts/data/tools/eraser.dart';
import 'package:nts/data/tools/fill.dart';
import 'package:nts/data/tools/highlighter.dart';
import 'package:nts/data/tools/insert_space.dart';
import 'package:nts/data/tools/laser_pointer.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/pencil.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/data/tools/shape_pen.dart';
import 'package:nts/data/tools/tape.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:sbn/has_size.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

const _page = HasSize(Size(1000, 1400));

Stroke _stroke(List<Offset> points) => Stroke(
  color: Colors.black,
  pressureEnabled: false,
  options: StrokeOptions(size: 4, isComplete: true),
  pageIndex: 0,
  page: _page,
  toolId: .fountainPen,
)..addPoints(points);

List<Offset> _circle(Offset c, double r, {int n = 40}) => [
  for (var i = 0; i <= n; i++)
    c + Offset(cos(2 * pi * i / n), sin(2 * pi * i / n)) * r,
];

const _line = [
  Offset(150, 300),
  Offset(200, 310),
  Offset(250, 320),
  Offset(300, 330),
  Offset(350, 340),
];

/// Which pans the page down when it pans.
const _upwards = [Offset(500, 900), Offset(500, 700), Offset(500, 500)];

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  setupMockWindowManager();
  FlavorConfig.setup();
  FileManager.documentsDirectory =
      '$tmpDir/mouse_editor_test/'
      '${FileManager.appRootDirectoryPrefix}';

  setUpAll(PencilShader.init);

  setUp(() {
    stows.lastTool.value = .fountainPen;
    Pen.currentPen = Pen.fountainPen();
    stows.editorFingerDrawing.value = false;
    stows.scribbleToErase.value = false;
    stows.holdToSnapShape.value = false;
    stows.autoStraightenLines.value = false;
    stows.lassoMode.value = .freehand;
    stows.eraserMode.value = .stroke;
    stows.lastSingleFingerPanLock.value = false;
    stows.lastZoomLock.value = false;
    stows.lastAxisAlignedPanLock.value = false;
    stows.editorToolbarItems.value = ToolCatalog.basics;
    stows.editorBarPositions.value = const {};
    stows.editorMinimizedBars.value = const [];
    stows.editorToolbarAlignment.value = .down;
    stows.hideFingerDrawingToggle.value = false;
    SelectionClipboard.content.value = null;
    Select.currentSelect.unselect();
    Keybinder.dispose();
  });

  // Whatever "Draw with finger" says: that's for touch screens
  for (final fingerDrawing in [false, true]) {
    group('finger drawing ${fingerDrawing ? 'on' : 'off'}:', () {
      setUp(() => stows.editorFingerDrawing.value = fingerDrawing);

      for (final (name, make) in <(String, Tool Function())>[
        ('fountain pen', Pen.fountainPen),
        ('ballpoint pen', Pen.ballpointPen),
        ('brush pen', Pen.brushPen),
        ('calligraphy pen', CalligraphyPen.new),
        ('shape pen', ShapePen.new),
        ('pencil', Pencil.new),
        ('highlighter', Highlighter.new),
        ('tape', Tape.new),
      ]) {
        testWidgets('$name: a mouse drag draws, not pans', (tester) async {
          final editor = await _pumpEditor(tester);
          editor.currentTool = make();
          final scroll = editor.scrollY;
          await _mouse(tester, editor, _circle(const Offset(400, 400), 100));
          expect(editor.coreInfo.pages.first.strokes, hasLength(1));
          expect(editor.scrollY, scroll);
        }, variant: _mac);
      }

      testWidgets('eraser (whole strokes)', (tester) async {
        final editor = await _pumpEditor(tester);
        final page = editor.coreInfo.pages.first;
        page.strokes.add(_stroke(const [Offset(200, 300), Offset(400, 300)]));
        editor.currentTool = Eraser();
        await _mouse(tester, editor, const [
          Offset(300, 250),
          Offset(300, 300),
          Offset(300, 350),
        ]);
        expect(page.strokes, isEmpty);
      }, variant: _mac);

      testWidgets('eraser (partial)', (tester) async {
        stows.eraserMode.value = .partial;
        final editor = await _pumpEditor(tester);
        final page = editor.coreInfo.pages.first;
        page.strokes.add(
          _stroke([for (var x = 200.0; x <= 400; x += 5) Offset(x, 300)]),
        );
        editor.currentTool = Eraser();
        await _mouse(tester, editor, const [
          Offset(300, 250),
          Offset(300, 300),
          Offset(300, 350),
        ]);
        expect(page.strokes, hasLength(2));
      }, variant: _mac);

      for (final mode in LassoMode.values) {
        testWidgets('lasso (${mode.name}) selects', (tester) async {
          stows.lassoMode.value = mode;
          final editor = await _pumpEditor(tester);
          final ink = _stroke(const [Offset(200, 300), Offset(400, 300)]);
          editor.coreInfo.pages.first.strokes.add(ink);
          editor.currentTool = Select.currentSelect;
          await _mouse(tester, editor, switch (mode) {
            .freehand => const [
              Offset(100, 200),
              Offset(500, 200),
              Offset(500, 400),
              Offset(100, 400),
              Offset(100, 210),
            ],
            .rectangle => const [Offset(100, 200), Offset(500, 400)],
          });
          expect(Select.currentSelect.selectResult.strokes, [ink]);
        }, variant: _mac);
      }

      testWidgets('lasso: a loop back to where it began selects', (
        tester,
      ) async {
        final editor = await _pumpEditor(tester);
        final ink = _stroke(const [Offset(200, 300), Offset(400, 300)]);
        editor.coreInfo.pages.first.strokes.add(ink);
        editor.currentTool = Select.currentSelect;
        // Its moves add up to zero
        await _mouse(tester, editor, const [
          Offset(100, 200),
          Offset(500, 200),
          Offset(500, 400),
          Offset(100, 400),
          Offset(100, 200),
        ]);
        expect(Select.currentSelect.selectResult.strokes, [ink]);
      }, variant: _mac);

      testWidgets('lasso: dragging the selection moves it', (tester) async {
        final editor = await _withSelection(tester);
        final ink = editor.coreInfo.pages.first.strokes.single;
        await _mouse(tester, editor, const [
          Offset(300, 300),
          Offset(325, 300),
          Offset(350, 300),
        ]);
        expect(ink.bounds.left, closeTo(200 - 2 + 50, 3));
      }, variant: _mac);

      testWidgets('lasso: a corner handle resizes', (tester) async {
        final editor = await _withSelection(tester);
        final select = Select.currentSelect;
        final corner = select.handles[SelectionHandle.bottomRight]!;
        final pivot = select.handles[SelectionHandle.topLeft]!;
        await _mouse(tester, editor, [corner, (corner + pivot) / 2]);
        expect(
          editor.coreInfo.pages.first.strokes.single.bounds.width,
          lessThan(150),
        );
      }, variant: _mac);

      testWidgets('lasso: the rotate handle rotates', (tester) async {
        final editor = await _withSelection(tester);
        final select = Select.currentSelect;
        final rotate = select.handles[SelectionHandle.rotate]!;
        final center = select.selectionBounds!.center;
        await _mouse(tester, editor, [
          rotate,
          rotate + const Offset(40, 10),
          center + Offset(center.dy - rotate.dy, 0),
        ]);
        expect(
          editor.coreInfo.pages.first.strokes.single.bounds.height,
          greaterThan(100),
        );
      }, variant: _mac);

      testWidgets('tape: a click reveals it', (tester) async {
        final editor = await _pumpEditor(tester);
        final page = editor.coreInfo.pages.first;
        editor.currentTool = Tape.currentTape;
        await _mouse(tester, editor, const [
          Offset(100, 200),
          Offset(200, 200),
          Offset(300, 200),
        ]);
        await _mouse(tester, editor, const [Offset(200, 200)]);
        expect(page.revealedTapes, hasLength(1));
      }, variant: _mac);

      testWidgets('fill: a click fills', (tester) async {
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
        editor.currentTool = Fill.currentFill..color = const Color(0xFF6C8CA8);
        await _mouse(tester, editor, const [Offset(300, 300)]);
        expect(circle.fillColor, isNotNull);
      }, variant: _mac);

      testWidgets('insert space: a drag pushes ink down', (tester) async {
        final editor = await _pumpEditor(tester);
        final below = _stroke(const [Offset(100, 500), Offset(200, 500)]);
        editor.coreInfo.pages.first.strokes.add(below);
        editor.currentTool = InsertSpace.currentInsertSpace;
        await _mouse(tester, editor, const [
          Offset(300, 300),
          Offset(300, 350),
          Offset(300, 400),
        ]);
        expect(below.bounds.top, greaterThan(550));
      }, variant: _mac);

      testWidgets('laser pointer draws', (tester) async {
        final editor = await _pumpEditor(tester);
        editor.currentTool = LaserPointer.currentLaserPointer;
        final gesture = await _mouseDown(tester, _global(editor, _line.first));
        for (final point in _line.skip(1)) {
          await gesture.moveTo(_global(editor, point));
        }
        final drawing =
            editor.coreInfo.pages.first.laserStrokes.isNotEmpty ||
            LaserPointer.isDrawing;
        await gesture.up();
        await gesture.removePointer();
        await tester.pump(const Duration(seconds: 10));
        expect(drawing, isTrue);
      }, variant: _mac);

      testWidgets('a click on a link with the lasso follows it', (
        tester,
      ) async {
        final editor = await _pumpEditor(tester);
        editor.coreInfo.pages.first.links = [
          const PageLink(Rect.fromLTWH(100, 100, 100, 50), '#page=2'),
        ];
        editor.currentTool = Select.currentSelect;
        await tester.pump();
        await _mouse(tester, editor, const [Offset(150, 125)]);
        expect(-editor.scrollY, greaterThan(500));
      }, variant: _mac);

      testWidgets('pen strokes near the ruler follow its edge', (tester) async {
        final editor = await _pumpEditor(tester);
        final page = editor.coreInfo.pages.first;
        editor.toggleRuler();
        await tester.pump();
        final box = tester.renderObject<RenderBox>(find.byType(RulerOverlay));
        final edge = box.localToGlobal(
          editor.ruler.value!.center - const Offset(0, RulerOverlay.height / 2),
        );
        final gesture = await _mouseDown(
          tester,
          edge + const Offset(-100, -10),
        );
        await gesture.moveTo(edge + const Offset(-50, -18));
        await gesture.moveTo(edge + const Offset(80, -12));
        await gesture.up();
        await gesture.removePointer();
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          page.strokes.single.bounds.top,
          closeTo(page.renderBox!.globalToLocal(edge).dy, 0.5),
        );
      }, variant: _mac);

      testWidgets('the ruler moves with a drag, and leaves no ink', (
        tester,
      ) async {
        final editor = await _pumpEditor(tester);
        editor.toggleRuler();
        await tester.pump();
        final before = editor.ruler.value!.center;
        final box = tester.renderObject<RenderBox>(find.byType(RulerOverlay));
        final start = box.localToGlobal(before + const Offset(60, 0));
        final gesture = await _mouseDown(tester, start);
        await gesture.moveTo(start + const Offset(20, 40));
        await gesture.moveTo(start + const Offset(30, 80));
        await gesture.up();
        await gesture.removePointer();
        await tester.pump();
        expect((editor.ruler.value!.center - before).dy, greaterThan(40));
        expect(editor.coreInfo.pages.first.strokes, isEmpty);
      }, variant: _mac);

      testWidgets('images: a click selects one, a drag moves it', (
        tester,
      ) async {
        final editor = await _pumpEditor(tester);
        final image = await _addImage(tester, editor);
        await _mouse(tester, editor, const [Offset(300, 500)]);
        await tester.pump(kDoubleTapTimeout);
        await _mouse(tester, editor, const [
          Offset(300, 500),
          Offset(320, 520),
          Offset(350, 540),
        ]);
        expect(image.dstRect.topLeft, isNot(const Offset(200, 400)));
        expect(editor.coreInfo.pages.first.strokes, isEmpty);
      }, variant: _mac);

      testWidgets('images: dragging a corner resizes it', (tester) async {
        final editor = await _pumpEditor(tester);
        final image = await _addImage(tester, editor);
        await _mouse(tester, editor, const [Offset(300, 500)]);
        await tester.pump(kDoubleTapTimeout);
        await _mouse(tester, editor, const [
          Offset(398, 598),
          Offset(420, 620),
          Offset(448, 648),
        ]);
        expect(image.dstRect.width, greaterThan(220));
      }, variant: _mac);

      testWidgets('middle-drag pans and does not draw', (tester) async {
        final editor = await _pumpEditor(tester);
        final before = editor.scrollY;
        await _mouse(tester, editor, const [
          Offset(500, 700),
          Offset(500, 600),
          Offset(500, 400),
        ], buttons: kMiddleMouseButton);
        expect(editor.coreInfo.pages.first.strokes, isEmpty);
        expect(editor.scrollY, isNot(before));
      }, variant: _mac);

      testWidgets('right-drag pans and does not draw', (tester) async {
        final editor = await _pumpEditor(tester);
        final before = editor.scrollY;
        await _mouse(tester, editor, const [
          Offset(500, 700),
          Offset(500, 600),
          Offset(500, 400),
        ], buttons: kSecondaryMouseButton);
        expect(editor.coreInfo.pages.first.strokes, isEmpty);
        expect(editor.scrollY, isNot(before));
        expect(find.byType(PopupMenuItem<VoidCallback>), findsNothing);
      }, variant: _mac);
    });
  }

  group('touch and stylus are as they were:', () {
    testWidgets('a finger pans with finger drawing off', (tester) async {
      final editor = await _pumpEditor(tester);
      final before = editor.scrollY;
      await _drag(tester, editor, _upwards, kind: .touch);
      expect(editor.coreInfo.pages.first.strokes, isEmpty);
      expect(editor.scrollY, isNot(before));
    }, variant: _mac);

    testWidgets('a finger draws with finger drawing on', (tester) async {
      stows.editorFingerDrawing.value = true;
      final editor = await _pumpEditor(tester);
      await _drag(tester, editor, _upwards, kind: .touch);
      expect(editor.coreInfo.pages.first.strokes, hasLength(1));
    }, variant: _mac);

    testWidgets('a stylus draws without finger drawing', (tester) async {
      final editor = await _pumpEditor(tester);
      await _drag(tester, editor, _line, kind: .stylus);
      expect(editor.coreInfo.pages.first.strokes, hasLength(1));
    }, variant: _mac);

    testWidgets('the pan lock still stops a finger from panning', (
      tester,
    ) async {
      stows.lastSingleFingerPanLock.value = true;
      final editor = await _pumpEditor(tester);
      final before = editor.scrollY;
      await _drag(tester, editor, _upwards, kind: .touch);
      expect(editor.scrollY, before);
    }, variant: _mac);
  });

  group('panning and zooming:', () {
    testWidgets('the wheel scrolls without ink', (tester) async {
      final editor = await _pumpEditor(tester);
      final before = editor.scrollY;
      await _wheel(tester, _global(editor, const Offset(500, 500)), 300);
      expect(editor.scrollY, before - 300);
      expect(editor.coreInfo.pages.first.strokes, isEmpty);
    }, variant: _mac);

    testWidgets('Shift+wheel scrolls sideways', (tester) async {
      final editor = await _pumpEditor(tester);
      _controller(tester).value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();
      final before = _controller(tester).value.getTranslation().x;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _wheel(tester, _global(editor, const Offset(300, 300)), 100);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(_controller(tester).value.getTranslation().x, before - 100);
    }, variant: _mac);

    for (final (name, key) in [
      ('Cmd', LogicalKeyboardKey.metaLeft),
      ('Ctrl', LogicalKeyboardKey.controlLeft),
    ]) {
      testWidgets('$name+wheel zooms', (tester) async {
        final editor = await _pumpEditor(tester);
        await tester.sendKeyDownEvent(key);
        await _wheel(tester, _global(editor, const Offset(500, 500)), -200);
        await tester.sendKeyUpEvent(key);
        expect(_scale(tester), greaterThan(1.05));
        await tester.pump(const Duration(seconds: 6)); // the HUD's timer
      }, variant: _mac);
    }

    testWidgets('trackpad: two fingers scroll, a pinch zooms', (tester) async {
      final editor = await _pumpEditor(tester);
      final at = _global(editor, const Offset(500, 500));
      final before = editor.scrollY;
      await _panZoom(tester, at, pan: const Offset(0, -300));
      expect(editor.scrollY, isNot(before));
      await _panZoom(tester, at, scale: 1.6);
      expect(_scale(tester), greaterThan(1.2));
      expect(editor.coreInfo.pages.first.strokes, isEmpty);
    }, variant: _mac);

    testWidgets('the pan lock is for fingers: the mouse and trackpad pan', (
      tester,
    ) async {
      stows.lastSingleFingerPanLock.value = true;
      final editor = await _pumpEditor(tester);
      final at = _global(editor, const Offset(500, 500));

      var before = editor.scrollY;
      await _wheel(tester, at, 300);
      expect(editor.scrollY, isNot(before), reason: 'wheel');

      before = editor.scrollY;
      await _panZoom(tester, at, pan: const Offset(0, -300));
      expect(editor.scrollY, isNot(before), reason: 'trackpad');

      before = editor.scrollY;
      await _mouse(tester, editor, const [
        Offset(500, 700),
        Offset(500, 600),
        Offset(500, 400),
      ], buttons: kMiddleMouseButton);
      expect(editor.scrollY, isNot(before), reason: 'middle button');
    }, variant: _mac);

    testWidgets('Space+drag pans with a hand cursor', (tester) async {
      final editor = await _pumpEditor(tester);
      final before = editor.scrollY;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(
        await _hoverCursor(tester, _global(editor, const Offset(400, 400))),
        SystemMouseCursors.grab,
      );
      await _mouse(tester, editor, const [
        Offset(500, 700),
        Offset(500, 600),
        Offset(500, 400),
      ]);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(editor.coreInfo.pages.first.strokes, isEmpty);
      expect(editor.scrollY, isNot(before));
    }, variant: _mac);

    for (final (name, key) in [
      ('Cmd', LogicalKeyboardKey.metaLeft),
      ('Ctrl', LogicalKeyboardKey.controlLeft),
    ]) {
      testWidgets('$name+=, $name+- and $name+0 zoom', (tester) async {
        await _pumpEditor(tester);
        await _keys(tester, [key], LogicalKeyboardKey.equal);
        expect(_scale(tester), closeTo(1.1, 0.01));
        await _keys(tester, [key], LogicalKeyboardKey.minus);
        await _keys(tester, [key], LogicalKeyboardKey.minus);
        expect(_scale(tester), closeTo(0.9, 0.01));
        await _keys(tester, [key], LogicalKeyboardKey.digit0);
        expect(_scale(tester), 1);
      }, variant: _mac);
    }

    testWidgets('scrolling over the ruler turns it, not the page', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      editor.toggleRuler();
      await tester.pump();
      final box = tester.renderObject<RenderBox>(find.byType(RulerOverlay));
      final before = editor.scrollY;
      await _wheel(tester, box.localToGlobal(editor.ruler.value!.center), 20);
      expect(editor.ruler.value!.angle, closeTo(5 * pi / 180, 1e-9));
      expect(editor.scrollY, before);
    }, variant: _mac);

    testWidgets('hovering the HUD shows its locks', (tester) async {
      await _pumpEditor(tester);
      final lock = find.byTooltip(t.editor.hud.lockZoom);
      await _hoverCursor(tester, tester.getCenter(lock), keep: true);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(lock, kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(stows.lastZoomLock.value, isTrue);
      await tester.pump(const Duration(seconds: 6));
    }, variant: _mac);
  });

  group('cursors:', () {
    for (final (name, make, cursor) in <(String, Tool Function(), MouseCursor)>[
      ('pen', Pen.fountainPen, SystemMouseCursors.precise),
      ('highlighter', Highlighter.new, SystemMouseCursors.precise),
      ('lasso', () => Select.currentSelect, SystemMouseCursors.precise),
      ('eraser', Eraser.new, SystemMouseCursors.none),
      ('text', () => Tool.textEditing, SystemMouseCursors.text),
      (
        'insert space',
        () => InsertSpace.currentInsertSpace,
        SystemMouseCursors.resizeUpDown,
      ),
      ('fill', () => Fill.currentFill, SystemMouseCursors.precise),
    ]) {
      testWidgets(name, (tester) async {
        final editor = await _pumpEditor(tester);
        editor.currentTool = make();
        _rebuild(tester);
        await tester.pump();
        expect(
          await _hoverCursor(tester, _global(editor, const Offset(600, 900))),
          cursor,
        );
      }, variant: _mac);
    }

    testWidgets('the eraser shows its size, at any zoom', (tester) async {
      stows.eraserSize.value = 20;
      final editor = await _pumpEditor(tester);
      editor.currentTool = Eraser();
      _rebuild(tester);
      await tester.pump();
      final at = _global(editor, const Offset(400, 400));
      final outline = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() == '_EraserOutline',
      );
      await _hoverCursor(tester, at, keep: true);
      expect(
        tester.renderObject(outline),
        paints
          ..circle(radius: 20)
          ..circle(radius: 20),
      );
      _controller(tester).value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();
      expect(
        tester.renderObject(outline),
        paints
          ..circle(radius: 40)
          ..circle(radius: 40),
      );
    }, variant: _mac);

    testWidgets('the selection: grab it, resize it from a corner', (
      tester,
    ) async {
      final editor = await _withSelection(tester);
      final select = Select.currentSelect;
      final corner = select.handles[SelectionHandle.bottomRight]!;
      // A Mac has no diagonal resize cursor
      expect(
        await _hoverCursor(tester, _global(editor, corner)),
        SystemMouseCursors.grab,
      );
      expect(
        await _hoverCursor(tester, _global(editor, const Offset(300, 300))),
        SystemMouseCursors.grab,
      );
      expect(
        await _hoverCursor(tester, _global(editor, const Offset(700, 900))),
        SystemMouseCursors.precise,
      );
    }, variant: _mac);

    testWidgets('the selection: resize cursors where there are some', (
      tester,
    ) async {
      // Tall enough that the corners are apart
      final editor = await _withSelection(
        tester,
        ink: const [Offset(200, 300), Offset(400, 400)],
      );
      final corner = Select.currentSelect.handles[SelectionHandle.bottomRight]!;
      expect(
        await _hoverCursor(tester, _global(editor, corner)),
        SystemMouseCursors.resizeUpLeftDownRight,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('the ruler: grab', (tester) async {
      final editor = await _pumpEditor(tester);
      editor.toggleRuler();
      await tester.pump();
      final box = tester.renderObject<RenderBox>(find.byType(RulerOverlay));
      expect(
        await _hoverCursor(
          tester,
          box.localToGlobal(editor.ruler.value!.center),
        ),
        SystemMouseCursors.grab,
      );
    }, variant: _mac);
  });

  group('right-click menus:', () {
    testWidgets('over an image with the pen: the canvas menu', (tester) async {
      final editor = await _pumpEditor(tester);
      await _addImage(tester, editor);
      editor.currentTool = Pen.currentPen;
      _rebuild(tester);
      await tester.pump();
      await _mouse(tester, editor, _line);
      await _mouse(tester, editor, const [
        Offset(300, 500),
      ], buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text(t.editor.toolbar.undo), findsOneWidget);
      expect(find.text(t.editor.imageOptions.title), findsNothing);
    }, variant: _mac);

    testWidgets('on the canvas: select all, undo', (tester) async {
      stows.editorFingerDrawing.value = true; // must not draw either
      final editor = await _pumpEditor(tester);
      final page = editor.coreInfo.pages.first;
      await _mouse(tester, editor, _line);
      await _mouse(tester, editor, const [
        Offset(600, 900),
      ], buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(page.strokes, hasLength(1));
      expect(find.text(t.editor.toolbar.undo), findsOneWidget);
      await tester.tap(
        find.text(t.editor.mouse.selectAll),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(editor.currentTool, Select.currentSelect);
      expect(Select.currentSelect.selectResult.strokes, page.strokes);
    }, variant: _mac);

    testWidgets('Control-click is a right-click on a Mac', (tester) async {
      final editor = await _pumpEditor(tester);
      editor.coreInfo.pages.first.strokes.add(_stroke(_line));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await _mouse(tester, editor, const [Offset(600, 900)]);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(editor.coreInfo.pages.first.strokes, hasLength(1));
      expect(find.text(t.editor.mouse.selectAll), findsOneWidget);
    }, variant: _mac);

    testWidgets('on the selection: its actions', (tester) async {
      final editor = await _withSelection(tester);
      await _mouse(tester, editor, const [
        Offset(300, 300),
      ], buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      for (final action in [
        t.editor.otherTools.copy,
        t.editor.otherTools.cut,
        t.editor.selectionBar.duplicate,
        t.editor.canvasTools.addLink,
      ]) {
        expect(find.text(action), findsOneWidget, reason: action);
      }
      await tester.tap(
        find.text(t.editor.selectionBar.delete),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(editor.coreInfo.pages.first.strokes, isEmpty);
    }, variant: _mac);

    testWidgets('on an image: its own options', (tester) async {
      final editor = await _pumpEditor(tester);
      await _addImage(tester, editor);
      await _mouse(tester, editor, const [
        Offset(300, 500),
      ], buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text(t.editor.imageOptions.title), findsOneWidget);
      expect(find.text(t.editor.mouse.selectAll), findsNothing);
    }, variant: _mac);
  });

  group('keyboard:', () {
    const cmd = LogicalKeyboardKey.metaLeft;
    const ctrl = LogicalKeyboardKey.controlLeft;
    const shift = LogicalKeyboardKey.shiftLeft;

    for (final (name, mod) in [('Cmd', cmd), ('Ctrl', ctrl)]) {
      testWidgets('$name+Z undoes, $name+Shift+Z and $name+Y redo', (
        tester,
      ) async {
        final editor = await _pumpEditor(tester);
        final strokes = editor.coreInfo.pages.first.strokes;
        await _mouse(tester, editor, _line);
        await _mouse(tester, editor, _circle(const Offset(500, 600), 50));
        await _keys(tester, [mod], LogicalKeyboardKey.keyZ);
        expect(strokes, hasLength(1));
        // with something left to undo
        await _keys(tester, [mod, shift], LogicalKeyboardKey.keyZ);
        expect(strokes, hasLength(2));
        await _keys(tester, [mod], LogicalKeyboardKey.keyZ);
        await _keys(tester, [mod], LogicalKeyboardKey.keyY);
        expect(strokes, hasLength(2));
      }, variant: _mac);

      testWidgets('$name+C and $name+V copy and paste the selection', (
        tester,
      ) async {
        final editor = await _withSelection(tester);
        await _keys(tester, [mod], LogicalKeyboardKey.keyC);
        await _untilCopied(tester);
        await _keys(tester, [mod], LogicalKeyboardKey.keyV);
        expect(editor.coreInfo.pages.first.strokes, hasLength(2));
      }, variant: _mac);

      testWidgets('$name+X cuts the selection', (tester) async {
        final editor = await _withSelection(tester);
        await _keys(tester, [mod], LogicalKeyboardKey.keyX);
        await _untilCopied(tester);
        await tester.pump();
        expect(editor.coreInfo.pages.first.strokes, isEmpty);
      }, variant: _mac);
    }

    testWidgets("Cmd+Z in the note's name leaves the ink alone", (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      await _mouse(tester, editor, _line);
      await tester.enterText(find.byType(TextFormField).first, 'abc');
      await _keys(tester, [cmd], LogicalKeyboardKey.keyZ);
      expect(editor.coreInfo.pages.first.strokes, hasLength(1));
      await tester.pump(const Duration(seconds: 6)); // the rename's timer
    }, variant: _mac);

    testWidgets('Cmd+D duplicates the selection', (tester) async {
      final editor = await _withSelection(tester);
      await _keys(tester, [cmd], LogicalKeyboardKey.keyD);
      expect(editor.coreInfo.pages.first.strokes, hasLength(2));
    }, variant: _mac);

    testWidgets('Cmd+A selects everything on the page', (tester) async {
      final editor = await _pumpEditor(tester);
      final page = editor.coreInfo.pages.first;
      page.strokes
        ..add(_stroke(const [Offset(200, 300), Offset(400, 300)]))
        ..add(_stroke(const [Offset(600, 1000), Offset(700, 1100)]));
      await _keys(tester, [cmd], LogicalKeyboardKey.keyA);
      expect(editor.currentTool, Select.currentSelect);
      expect(Select.currentSelect.selectResult.strokes, page.strokes);
      expect(find.byTooltip(t.editor.selectionBar.delete), findsOneWidget);
    }, variant: _mac);

    for (final key in [
      LogicalKeyboardKey.delete,
      LogicalKeyboardKey.backspace,
    ]) {
      testWidgets('${key.keyLabel} deletes the selection', (tester) async {
        final editor = await _withSelection(tester);
        await _keys(tester, [], key);
        expect(editor.coreInfo.pages.first.strokes, isEmpty);
      }, variant: _mac);
    }

    testWidgets('Escape deselects', (tester) async {
      await _withSelection(tester);
      await _keys(tester, [], LogicalKeyboardKey.escape);
      expect(Select.currentSelect.doneSelecting, isFalse);
    }, variant: _mac);

    testWidgets('arrows nudge the selection (Shift: 10), not pan', (
      tester,
    ) async {
      final editor = await _withSelection(tester);
      final ink = editor.coreInfo.pages.first.strokes.single;
      final left = ink.bounds.left, top = ink.bounds.top;
      final scroll = editor.scrollY;
      await _keys(tester, [], LogicalKeyboardKey.arrowRight);
      await _keys(tester, [shift], LogicalKeyboardKey.arrowDown);
      expect(ink.bounds.left, closeTo(left + 1, 1e-6));
      expect(ink.bounds.top, closeTo(top + 10, 1e-6));
      expect(editor.scrollY, scroll);
      editor.undo();
      expect(ink.bounds.top, closeTo(top, 1e-6));
    }, variant: _mac);

    testWidgets('arrows pan without a selection', (tester) async {
      final editor = await _pumpEditor(tester);
      final before = editor.scrollY;
      await _keys(tester, [], LogicalKeyboardKey.arrowDown);
      expect(editor.scrollY, isNot(before));
    }, variant: _mac);

    testWidgets('single keys pick tools', (tester) async {
      final editor = await _pumpEditor(tester);
      for (final (key, check) in <(LogicalKeyboardKey, bool Function(Tool))>[
        (.keyE, (tool) => tool is Eraser),
        (.keyE, (tool) => tool is Pen), // toggles back
        (.keyV, (tool) => tool == Select.currentSelect),
        (.keyH, (tool) => tool is Highlighter),
        (.keyA, (tool) => tool is Tape),
        (.keyL, (tool) => tool is LaserPointer),
        (.keyS, (tool) => tool is ShapePen),
        (.keyP, (tool) => tool == Pen.currentPen),
        (.keyT, (tool) => tool == Tool.textEditing),
      ]) {
        await _keys(tester, [], key);
        expect(check(editor.currentTool), isTrue, reason: key.keyLabel);
      }
      // Escape leaves the text, then T types again
      await _keys(tester, [], LogicalKeyboardKey.escape);
      expect(editor.currentTool, isA<ShapePen>());
      await _keys(tester, [], LogicalKeyboardKey.keyR);
      expect(editor.ruler.value, isNotNull);
    }, variant: _mac);

    testWidgets('single keys type in text fields instead', (tester) async {
      final editor = await _pumpEditor(tester);
      await tester.tap(find.byType(TextFormField).first);
      await tester.pump();
      await _keys(tester, [], LogicalKeyboardKey.keyE);
      expect(editor.currentTool, isA<Pen>());
    }, variant: _mac);

    testWidgets('tooltips show the shortcuts on a Mac', (tester) async {
      stows.editorToolbarItems.value = [...ToolCatalog.basics, 'fingerDrawing'];
      await _pumpEditor(tester);
      Finder inToolbar(String tooltip) => find.descendant(
        of: find.byType(Toolbar),
        matching: find.byTooltip(tooltip),
      );
      expect(inToolbar('${t.editor.pens.highlighter} (H)'), findsOneWidget);
      expect(inToolbar('${t.editor.pens.fountainPen} (P)'), findsOneWidget);
      expect(inToolbar('${t.editor.toolbar.select} (V)'), findsOneWidget);
      expect(inToolbar('Toggle eraser (E)'), findsOneWidget);
      expect(inToolbar('Toggle finger drawing (⌘F)'), findsOneWidget);
      expect(inToolbar('Export (⇧⌘S)'), findsOneWidget);
    }, variant: _mac);
  });

  group('modifiers:', () {
    testWidgets('Shift draws a straight line', (tester) async {
      final editor = await _pumpEditor(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _mouse(tester, editor, const [
        Offset(100, 300),
        Offset(200, 380),
        Offset(300, 250),
        Offset(400, 305),
      ]);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      // From the first point to the last, then made level
      final bounds = editor.coreInfo.pages.first.strokes.single.bounds;
      expect(bounds.left, closeTo(100, 1));
      expect(bounds.right, closeTo(400, 1));
      expect(bounds.height, lessThan(1));
    }, variant: _mac);

    testWidgets('Shift turns the selection in steps of 15°', (tester) async {
      final editor = await _withSelection(tester);
      final select = Select.currentSelect;
      final rotate = select.handles[SelectionHandle.rotate]!;
      final center = select.selectionBounds!.center;
      // 52° clockwise from the handle
      final to =
          center +
          Offset.fromDirection(
            (rotate - center).direction + 52 * pi / 180,
            (rotate - center).distance,
          );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _mouse(tester, editor, [rotate, (rotate + to) / 2, to]);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      final bounds = editor.coreInfo.pages.first.strokes.single.bounds;
      // turned 45°, so as tall as it's wide
      expect(bounds.width, closeTo(bounds.height, 1));
    }, variant: _mac);
  });

  group('opening a note:', () {
    for (final saved in [ToolId.eraser, ToolId.select, ToolId.laserPointer]) {
      testWidgets('with ${saved.name} saved as the last tool starts with '
          'the pen', (tester) async {
        stows.lastTool.value = saved;
        final editor = await _pumpEditor(tester);
        expect(editor.currentTool, isA<Pen>());
      }, variant: _mac);
    }

    testWidgets('the eraser, lasso and laser are not saved', (tester) async {
      final editor = await _pumpEditor(tester);
      editor.currentTool = Highlighter.currentHighlighter;
      for (final tool in [
        Eraser(),
        Select.currentSelect,
        LaserPointer.currentLaserPointer,
      ]) {
        editor.currentTool = tool;
      }
      expect(stows.lastTool.value, ToolId.highlighter);
    }, variant: _mac);

    testWidgets('a double-click that opened it leaves no dot', (tester) async {
      final editor = await _pumpEditor(tester, settle: false);
      await _mouse(tester, editor, const [Offset(300, 300)]);
      expect(editor.coreInfo.pages.first.strokes, isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      await _mouse(tester, editor, const [Offset(300, 300)]);
      expect(editor.coreInfo.pages.first.strokes, hasLength(1));
    }, variant: _mac);
  });

  group('text and bars by mouse:', () {
    testWidgets('the text tool: a click places the cursor', (tester) async {
      final editor = await _pumpEditor(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Toolbar),
          matching: find.byTooltip('${t.editor.toolbar.text} (T)'),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(editor.currentTool, Tool.textEditing);
      await tester.tapAt(
        _global(editor, const Offset(300, 300)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(editor.coreInfo.pages.first.quill.focusNode.hasFocus, isTrue);
      expect(editor.coreInfo.pages.first.strokes, isEmpty);
    }, variant: _mac);

    testWidgets('dragging the toolbar grip moves it, without ink', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      await tester.drag(
        find.descendant(
          of: find.byType(Toolbar),
          matching: find.byType(FloatingBarGrip),
        ),
        const Offset(-200, -300),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(stows.editorBarPositions.value, contains('toolbar.wide'));
      expect(editor.coreInfo.pages.first.strokes, isEmpty);
    }, variant: _mac);
  });

  group('typing keeps its own shortcuts:', () {
    const cmd = LogicalKeyboardKey.metaLeft;
    const shift = LogicalKeyboardKey.shiftLeft;

    testWidgets("Cmd+Z in the note's text leaves the ink alone", (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      final strokes = editor.coreInfo.pages.first.strokes;
      await _mouse(tester, editor, _line);
      await _keys(tester, [], LogicalKeyboardKey.keyT);
      expect(editor.currentTool, Tool.textEditing);
      for (var i = 0; i < 3; i++) {
        await _keys(tester, [cmd], LogicalKeyboardKey.keyZ);
      }
      await _keys(tester, [cmd, shift], LogicalKeyboardKey.keyZ);
      await _keys(tester, [cmd], LogicalKeyboardKey.keyY);
      expect(strokes, hasLength(1));
    }, variant: _mac);

    testWidgets("Cmd+F and Cmd+E in the note's name are the text's", (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      await tester.tap(find.byType(TextFormField).first);
      await tester.pump();
      await _keys(tester, [cmd], LogicalKeyboardKey.keyF);
      await _keys(tester, [cmd], LogicalKeyboardKey.keyE);
      expect(stows.editorFingerDrawing.value, isFalse);
      expect(editor.currentTool, isA<Pen>());
    }, variant: _mac);

    testWidgets("Cmd+E, Cmd+= and Cmd+F in the note's text are the text's", (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      await _keys(tester, [], LogicalKeyboardKey.keyT);
      await _keys(tester, [cmd], LogicalKeyboardKey.keyE);
      await _keys(tester, [cmd], LogicalKeyboardKey.equal);
      await _keys(tester, [cmd], LogicalKeyboardKey.keyF);
      expect(editor.currentTool, Tool.textEditing);
      expect(_scale(tester), 1);
      expect(stows.editorFingerDrawing.value, isFalse);
    }, variant: _mac);

    testWidgets('Cmd+F and Cmd+E still work on the canvas', (tester) async {
      final editor = await _pumpEditor(tester);
      await _keys(tester, [cmd], LogicalKeyboardKey.keyF);
      expect(stows.editorFingerDrawing.value, isTrue);
      await _keys(tester, [cmd], LogicalKeyboardKey.keyE);
      expect(editor.currentTool, isA<Eraser>());
    }, variant: _mac);

    testWidgets('Cmd+= does nothing while zoom is locked', (tester) async {
      stows.lastZoomLock.value = true;
      await _pumpEditor(tester);
      await _keys(tester, [cmd], LogicalKeyboardKey.equal);
      await _keys(tester, [cmd], LogicalKeyboardKey.minus);
      expect(_scale(tester), 1);
    }, variant: _mac);
  });

  group('menus and paste:', () {
    testWidgets("right-click in the note's text: the text's menu", (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      final page = editor.coreInfo.pages.first;
      page.strokes.add(_stroke(_line));
      await _keys(tester, [], LogicalKeyboardKey.keyT);
      page.quill.controller.replaceText(0, 0, 'hello world', null);
      await tester.pump();
      await _mouse(tester, editor, const [
        Offset(300, 300),
      ], buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text(t.editor.mouse.selectAll), findsNothing);
      expect(find.text(t.editor.toolbar.undo), findsNothing);
      expect(editor.currentTool, Tool.textEditing);
      // but the text's own: cut, copy, paste
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
    }, variant: _mac);

    testWidgets('Paste goes where the right-click was, on that page', (
      tester,
    ) async {
      final editor = await _withSelection(tester);
      await _keys(tester, [LogicalKeyboardKey.metaLeft], .keyC);
      await _untilCopied(tester);
      // Page 2 in view, below page 1
      await _wheel(tester, _global(editor, const Offset(500, 800)), 1000);
      final page2 = editor.coreInfo.pages[1];
      const at = Offset(500, 300);
      final gesture = await _mouseDown(
        tester,
        page2.renderBox!.localToGlobal(at),
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await gesture.removePointer();
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(t.editor.otherTools.paste),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(editor.coreInfo.pages.first.strokes, hasLength(1));
      // The lasso's middle is at the click
      expect(
        page2.strokes.single.bounds.center,
        offsetMoreOrLessEquals(const Offset(500, 290), epsilon: 5),
      );
    }, variant: _mac);
  });

  group('trackpad and Magic Mouse:', () {
    const cmd = LogicalKeyboardKey.metaLeft;

    testWidgets('Cmd+scroll zooms, like Cmd+wheel', (tester) async {
      final editor = await _pumpEditor(tester);
      final at = _global(editor, const Offset(500, 500));
      await tester.sendKeyDownEvent(cmd);
      // Fingers down: like a wheel scrolled up, which zooms in
      await _panZoom(tester, at, pan: const Offset(0, 100));
      expect(_scale(tester), greaterThan(1.2));
      final zoomed = _scale(tester);
      await _panZoom(tester, at, pan: const Offset(0, -60));
      await tester.sendKeyUpEvent(cmd);
      expect(_scale(tester), lessThan(zoomed));
      expect(editor.coreInfo.pages.first.strokes, isEmpty);
      await tester.pump(const Duration(seconds: 6)); // the HUD's timer
    }, variant: _mac);

    testWidgets('scrolling over the ruler turns it; Cmd+scroll zooms', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      editor.toggleRuler();
      await tester.pump();
      final box = tester.renderObject<RenderBox>(find.byType(RulerOverlay));
      final center = editor.ruler.value!.center;
      final on = box.localToGlobal(center);
      final before = editor.scrollY;
      // Like a wheel's notch down
      await _panZoom(tester, on, pan: const Offset(0, -20));
      expect(editor.ruler.value!.angle, closeTo(5 * pi / 180, 1e-6));
      expect(editor.ruler.value!.center, center);
      expect(editor.scrollY, before);

      await tester.sendKeyDownEvent(cmd);
      await _wheel(tester, on, -100);
      expect(_scale(tester), greaterThan(1.2), reason: 'wheel');
      final zoomed = _scale(tester);
      await _panZoom(tester, on, pan: const Offset(0, 60));
      expect(_scale(tester), greaterThan(zoomed), reason: 'trackpad');
      await tester.sendKeyUpEvent(cmd);
      expect(editor.ruler.value!.angle, closeTo(5 * pi / 180, 1e-6));
      await tester.pump(const Duration(seconds: 6)); // the HUD's timer
    }, variant: _mac);
  });

  group('an iPad stays as it was:', () {
    final iPad = TargetPlatformVariant.only(TargetPlatform.iOS);

    testWidgets('its mouse and trackpad follow finger drawing', (tester) async {
      final editor = await _pumpEditor(tester);
      final strokes = editor.coreInfo.pages.first.strokes;
      final scroll = editor.scrollY;
      await _mouse(tester, editor, _upwards);
      expect(strokes, isEmpty);
      expect(editor.scrollY, isNot(scroll));
      stows.editorFingerDrawing.value = true;
      await _mouse(tester, editor, _circle(const Offset(400, 400), 100));
      expect(strokes, hasLength(1));
    }, variant: iPad);

    testWidgets('notes open with the eraser or lasso if that was last', (
      tester,
    ) async {
      stows.lastTool.value = .eraser;
      final editor = await _pumpEditor(tester);
      expect(editor.currentTool, isA<Eraser>());
      editor.currentTool = Select.currentSelect;
      expect(stows.lastTool.value, ToolId.select);
    }, variant: iPad);
  });

  group('images:', () {
    testWidgets('Control-click on one with the lasso: its options', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      await _addImage(tester, editor);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await _mouse(tester, editor, const [Offset(300, 500)]);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text(t.editor.imageOptions.title), findsOneWidget);
    }, variant: _mac);

    for (final key in [
      LogicalKeyboardKey.delete,
      LogicalKeyboardKey.backspace,
    ]) {
      testWidgets('${key.keyLabel} deletes the clicked one', (tester) async {
        final editor = await _pumpEditor(tester);
        final image = await _addImage(tester, editor);
        image.onDeleteImage = editor.onDeleteImage;
        await _mouse(tester, editor, const [Offset(300, 500)]);
        await tester.pump();
        await _keys(tester, [], key);
        expect(editor.coreInfo.pages.first.images, isEmpty);
        editor.undo();
        expect(editor.coreInfo.pages.first.images, hasLength(1));
      }, variant: _mac);
    }

    testWidgets('Escape deselects it; a corner has the grab cursor', (
      tester,
    ) async {
      final editor = await _pumpEditor(tester);
      await _addImage(tester, editor);
      await _mouse(tester, editor, const [Offset(300, 500)]);
      await tester.pump();
      // A Mac has no diagonal resize cursors
      expect(
        await _hoverCursor(tester, _global(editor, const Offset(400, 600))),
        SystemMouseCursors.grab,
      );
      expect(
        await _hoverCursor(tester, _global(editor, const Offset(300, 600))),
        SystemMouseCursors.resizeUpDown,
      );
      await _keys(tester, [], LogicalKeyboardKey.escape);
      expect(
        await _hoverCursor(tester, _global(editor, const Offset(300, 600))),
        isNot(SystemMouseCursors.resizeUpDown),
      );
    }, variant: _mac);
  });

  group('Control-click is a right-click on a Mac:', () {
    testWidgets('a toolbar button: its menu, not the tool', (tester) async {
      final editor = await _pumpEditor(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(
        find.descendant(
          of: find.byType(Toolbar),
          matching: find.byTooltip('${t.editor.pens.highlighter} (H)'),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        find.text(t.editor.customizeToolbar.removeFromToolbar),
        findsOneWidget,
      );
      expect(editor.currentTool, isNot(isA<Highlighter>()));
    }, variant: _mac);

    testWidgets('the grip: its menu', (tester) async {
      await _pumpEditor(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(
        find.descendant(
          of: find.byType(Toolbar),
          matching: find.byType(FloatingBarGrip),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text(t.editor.floatingBar.minimize), findsOneWidget);
    }, variant: _mac);

    testWidgets('a minimized bar: its menu, and a click cursor', (
      tester,
    ) async {
      stows.editorMinimizedBars.value = const ['toolbar'];
      await _pumpEditor(tester);
      final pill = find.byType(MinimizedFloatingBar).first;
      expect(
        await _hoverCursor(tester, tester.getCenter(pill)),
        SystemMouseCursors.click,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(pill, kind: PointerDeviceKind.mouse);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text(t.editor.floatingBar.restore), findsWidgets);
      expect(stows.editorMinimizedBars.value, contains('toolbar'));
    }, variant: _mac);

    testWidgets('elsewhere a Control-click is still a click', (tester) async {
      final editor = await _pumpEditor(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(
        find.descendant(
          of: find.byType(Toolbar),
          matching: find.byTooltip('${t.editor.pens.highlighter} (H)'),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(editor.currentTool, isA<Highlighter>());
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });

  testWidgets('a middle-drag pans with the grabbing cursor', (tester) async {
    final editor = await _pumpEditor(tester);
    final gesture = await _mouseDown(
      tester,
      _global(editor, const Offset(500, 700)),
      buttons: kMiddleMouseButton,
    );
    await gesture.moveTo(_global(editor, const Offset(500, 500)));
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.grabbing,
    );
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
  }, variant: _mac);
}

// ------------------------------------------------------------------ helpers

void _rebuild(WidgetTester tester) =>
    tester.element(find.byType(Editor)).markNeedsBuild();

/// The editor on a big screen, with room to scroll. Unless [settle] is
/// false, it waits until the mouse can draw (just after opening, a
/// double-click's second click mustn't).
Future<EditorState> _pumpEditor(
  WidgetTester tester, {
  bool settle = true,
}) async {
  tester.view
    ..physicalSize = const Size(1200, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        localizationsDelegates: const [
          ...GlobalMaterialLocalizations.delegates,
          FlutterQuillLocalizations.delegate,
        ],
        home: Editor(path: '/mouse_${tester.testDescription.hashCode}'),
      ),
    ),
  );
  await tester.pump();
  final editor = tester.state<EditorState>(find.byType(Editor));
  addTearDown(editor.cancelAutosaveAndMarkSaved);
  editor.createPage(3);
  _rebuild(tester);
  await tester.pump();
  if (settle) await tester.pump(const Duration(milliseconds: 500));
  return editor;
}

/// The editor with a stroke through [ink], lassoed.
Future<EditorState> _withSelection(
  WidgetTester tester, {
  List<Offset> ink = const [Offset(200, 300), Offset(400, 300)],
}) async {
  final editor = await _pumpEditor(tester);
  final page = editor.coreInfo.pages.first;
  page.strokes.add(_stroke(ink));
  editor.currentTool = Select.currentSelect;
  Select.currentSelect
    ..onDragStart(const Offset(100, 200), 0)
    ..onDragUpdate(const Offset(500, 200))
    ..onDragUpdate(const Offset(500, 420))
    ..onDragUpdate(const Offset(100, 420))
    ..onDragEnd(page.strokes, page.images);
  _rebuild(tester);
  await tester.pump();
  return editor;
}

/// A 200×200 image at (200, 400), not yet selected, with the lasso.
Future<EditorImage> _addImage(WidgetTester tester, EditorState editor) async {
  final image = _TestImage(dstRect: const Rect.fromLTWH(200, 400, 200, 200))
    ..newImage = false;
  editor.coreInfo.pages.first.images.add(image);
  editor.currentTool = Select.currentSelect;
  _rebuild(tester);
  await tester.pump();
  return image;
}

TransformationController _controller(WidgetTester tester) => tester
    .widget<InteractiveCanvasViewer>(find.byType(InteractiveCanvasViewer))
    .transformationController!;

double _scale(WidgetTester tester) => _controller(tester).value.approxScale;

Offset _global(EditorState editor, Offset local) =>
    editor.coreInfo.pages.first.renderBox!.localToGlobal(local);

Future<TestGesture> _mouseDown(
  WidgetTester tester,
  Offset at, {
  int buttons = kPrimaryMouseButton,
}) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: buttons,
  );
  await gesture.addPointer(location: at);
  await gesture.down(at);
  return gesture;
}

/// Drags through [points] on the first page with a mouse
/// (a click if there's one point).
Future<void> _mouse(
  WidgetTester tester,
  EditorState editor,
  List<Offset> points, {
  int buttons = kPrimaryMouseButton,
}) async {
  final gesture = await _mouseDown(
    tester,
    _global(editor, points.first),
    buttons: buttons,
  );
  for (final point in points.skip(1)) {
    await gesture.moveTo(_global(editor, point));
  }
  await gesture.up();
  await gesture.removePointer();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _drag(
  WidgetTester tester,
  EditorState editor,
  List<Offset> points, {
  required PointerDeviceKind kind,
}) async {
  final gesture = await tester.startGesture(
    _global(editor, points.first),
    kind: kind,
  );
  for (final point in points.skip(1)) {
    await gesture.moveTo(_global(editor, point));
  }
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 50));
}

/// The mouse cursor over [at]. With [keep], the mouse stays there.
Future<MouseCursor?> _hoverCursor(
  WidgetTester tester,
  Offset at, {
  bool keep = false,
}) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: at - const Offset(2, 2));
  await gesture.moveTo(at);
  await tester.pump();
  final cursor = RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(
    1,
  );
  if (keep) {
    addTearDown(gesture.removePointer);
  } else {
    await gesture.removePointer();
    await tester.pump();
  }
  return cursor;
}

Future<void> _wheel(WidgetTester tester, Offset at, double dy) async {
  final pointer = TestPointer(99, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(at));
  await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
  await tester.sendEventToBinding(pointer.removePointer());
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _panZoom(
  WidgetTester tester,
  Offset at, {
  Offset pan = Offset.zero,
  double scale = 1,
}) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.trackpad);
  await gesture.panZoomStart(at);
  for (var i = 1; i <= 5; i++) {
    await gesture.panZoomUpdate(
      at,
      pan: pan * (i / 5),
      scale: 1 + (scale - 1) * i / 5,
    );
  }
  await gesture.panZoomEnd();
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _keys(
  WidgetTester tester,
  List<LogicalKeyboardKey> modifiers,
  LogicalKeyboardKey key,
) async {
  for (final modifier in modifiers) {
    await tester.sendKeyDownEvent(modifier);
  }
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  for (final modifier in modifiers.reversed) {
    await tester.sendKeyUpEvent(modifier);
  }
  await tester.pump();
}

/// Copying reads the images' bytes asynchronously.
Future<void> _untilCopied(WidgetTester tester) async {
  for (var i = 0; i < 20 && SelectionClipboard.content.value == null; i++) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(SelectionClipboard.content.value, isNotNull);
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

  @override
  // ignore: must_call_super
  Future<bool> loadOut() async => false;
}

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);
