import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:nts/components/canvas/_circle_stroke.dart';
import 'package:nts/components/canvas/_rectangle_stroke.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/pencil_shader.dart';
import 'package:nts/components/canvas/ruler.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/calligraphy_pen.dart';
import 'package:nts/data/tools/fill.dart';
import 'package:nts/data/tools/insert_space.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/data/tools/tape.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:sbn/tool_id.dart';

import 'higan_snapshot_util.dart';
import 'utils/test_mock_channel_handlers.dart';

/// Renders the canvas tools in use, for visual checks:
/// `HIGAN_SNAPSHOT=1 flutter test test/canvas_tools_snapshot_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  setupMockPrinting();
  setupMockWindowManager();
  FlavorConfig.setup();

  const demoNote = '/Canvas tools/Metric Spaces';

  setUpAll(() async {
    if (!higanSnapshotsEnabled) return;
    await Future.wait([
      FileManager.init(shouldWatchRootDirectory: false),
      PencilShader.init(),
      loadAppFonts(),
    ]);
  });

  setUp(() async {
    if (!higanSnapshotsEnabled) return;
    stows.lastTool.value = ToolId.fountainPen;
    Pen.currentPen = Pen.fountainPen();
    stows.editorToolbarAlignment.value = .down;
    stows.editorAutoInvert.value = false;
    stows.editorToolbarItems.value = [
      ...ToolCatalog.basics,
      'tape',
      'fill',
      'insertSpace',
      'ruler',
    ];
    stows.editorBarPositions.value = const {};
    stows.editorMinimizedBars.value = const [];
    stows.lassoMode.value = .freehand;
    Select.currentSelect.unselect();
    // (Some snapshots are taken mid-drag)
    InsertSpace.currentInsertSpace.preview = null;

    // A fresh copy, since the editor saves changes
    final bytes = await File('test/demo_notes/Metric Spaces Week 1.sbn2')
        .readAsBytes();
    final file = FileManager.getFile('$demoNote${Editor.extension}');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
  });

  const ipad = Size(1180, 820), phone = Size(390, 844);

  testWidgets('tape', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'canvas_tape_ipad_night',
      size: ipad,
      path: demoNote,
      setup: (editor) {
        final page = editor.coreInfo.pages.first;
        final tape = Tape.currentTape..color = Tape.defaultColor;
        editor.currentTool = tape;
        // Over the right-hand sides of the three properties
        for (final (from, to) in [
          (const Offset(540, 308), const Offset(660, 308)),
          (const Offset(580, 386), const Offset(980, 386)),
          (const Offset(330, 464), const Offset(890, 464)),
        ]) {
          page.insertStroke(_draw(tape, page, [from, to]));
        }
        // The middle one shows what's under it
        page.revealedTapes.add(
          page.strokes.where((stroke) => stroke.toolId == .tape).elementAt(1),
        );
      },
    );
  });

  testWidgets('pens', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'canvas_pens_ipad_night',
      size: ipad,
      setup: (editor) {
        final page = editor.coreInfo.pages.first;
        final brush = Pen.brushPen()..options.size = 14;
        page.insertStroke(_draw(brush, page, _swash(const Offset(120, 120))));
        page.insertStroke(_draw(brush, page, _swash(const Offset(520, 120))));

        stows.calligraphyNibAngle.value = 45;
        final calligraphy = CalligraphyPen()..options.size = 16;
        for (var i = 0; i < 3; i++) {
          page.insertStroke(
            _draw(calligraphy, page, _loops(Offset(120, 320 + i * 110.0))),
          );
        }
        editor.currentTool = Pen.currentPen = calligraphy;
      },
      // Show the pen types
      interact: (tester) =>
          tester.tap(find.byTooltip(t.editor.canvasTools.calligraphyPen)),
    );
  });

  testWidgets('pens phone', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'canvas_pens_phone_night',
      size: phone,
      setup: (editor) {
        final page = editor.coreInfo.pages.first;
        final calligraphy = CalligraphyPen()..options.size = 22;
        for (var i = 0; i < 4; i++) {
          page.insertStroke(
            _draw(calligraphy, page, _loops(Offset(80, 150 + i * 130.0))),
          );
        }
        editor.currentTool = Pen.currentPen = calligraphy;
      },
      interact: (tester) =>
          tester.tap(find.byTooltip(t.editor.canvasTools.calligraphyPen)),
    );
  });

  testWidgets('hold to snap', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'canvas_hold_to_snap_ipad_night',
      size: ipad,
      interact: (tester) async {
        // A rough circle, then holding still
        final editor = tester.state<EditorState>(find.byType(Editor));
        final gesture = await tester.createGesture(kind: .stylus);
        await gesture.down(_global(editor, const Offset(620, 300)));
        for (var i = 1; i <= 76; i++) {
          final a = 2 * pi * i / 80;
          await gesture.moveTo(
            _global(
              editor,
              Offset(
                500 + (120 + 8 * sin(5 * a)) * cos(a),
                300 + (110 + 6 * cos(3 * a)) * sin(a),
              ),
            ),
          );
        }
        await tester.pump(Pen.holdToSnapDelay);
      },
    );
  });

  testWidgets('fill', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'canvas_fill_ipad_night',
      size: ipad,
      setup: (editor) {
        final page = editor.coreInfo.pages.first;
        final pen = Pen.fountainPen()..options.size = 5;
        final circle = CircleStroke(
          color: Colors.black,
          pressureEnabled: false,
          options: StrokeOptions(size: 5),
          pageIndex: 0,
          page: page,
          toolId: .shapePen,
          center: const Offset(260, 260),
          radius: 130,
        )..fillColor = const Color(0xFFE2B46C);
        final rect = RectangleStroke(
          color: Colors.black,
          pressureEnabled: false,
          options: StrokeOptions(size: 5),
          pageIndex: 0,
          page: page,
          toolId: .shapePen,
          rect: const Rect.fromLTWH(500, 140, 380, 240),
        )..fillColor = const Color(0xFF6C8CA8);
        final blob = _draw(pen, page, [
          for (var i = 0; i <= 90; i++)
            const Offset(300, 620) +
                Offset(
                  cos(2 * pi * i / 90) * (180 + 25 * sin(6 * pi * i / 90)),
                  sin(2 * pi * i / 90) * (110 + 20 * cos(4 * pi * i / 90)),
                ),
        ])..fillColor = const Color(0xFF7E9B7A);
        page.strokes.addAll([circle, rect, blob]);
        // Ink on top of a fill stays visible
        page.insertStroke(
          _draw(pen, page, [
            for (var i = 0; i <= 40; i++)
              Offset(560 + i * 7.0, 260 + 30 * sin(i / 3)),
          ]),
        );
        editor.currentTool = Fill.currentFill..color = const Color(0xFF7E9B7A);
      },
    );
  });

  testWidgets('lasso', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'canvas_lasso_ipad_night',
      size: ipad,
      path: demoNote,
      setup: (editor) {
        final page = editor.coreInfo.pages.first;
        editor.currentTool = Select.currentSelect
          ..onDragStart(const Offset(20, 20), 0)
          ..onDragUpdate(const Offset(420, 10))
          ..onDragUpdate(const Offset(430, 120))
          ..onDragUpdate(const Offset(10, 110))
          ..onDragEnd(page.strokes, page.images);
      },
    );
  });

  testWidgets('rectangle lasso', skip: !higanSnapshotsEnabled, (tester) async {
    stows.lassoMode.value = .rectangle;
    await _snapshot(
      tester,
      name: 'canvas_lasso_rect_ipad_night',
      size: ipad,
      path: demoNote,
      setup: (editor) => editor.currentTool = Select.currentSelect,
      interact: (tester) async {
        // Mid-drag
        final editor = tester.state<EditorState>(find.byType(Editor));
        final gesture = await tester.createGesture(kind: .stylus);
        await gesture.down(_global(editor, const Offset(150, 270)));
        await gesture.moveTo(_global(editor, const Offset(600, 300)));
        await gesture.moveTo(_global(editor, const Offset(760, 440)));
      },
    );
  });

  testWidgets('insert space', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'canvas_insert_space_ipad_night',
      size: ipad,
      path: demoNote,
      setup: (editor) => editor.currentTool = InsertSpace.currentInsertSpace,
      interact: (tester) async {
        final editor = tester.state<EditorState>(find.byType(Editor));
        final gesture = await tester.createGesture(kind: .stylus);
        await gesture.down(_global(editor, const Offset(500, 505)));
        await gesture.moveTo(_global(editor, const Offset(500, 540)));
        await gesture.moveTo(_global(editor, const Offset(500, 590)));
      },
    );
  });

  for (final brightness in Brightness.values)
    testWidgets('ruler $brightness', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await _snapshot(
        tester,
        name: 'canvas_ruler_ipad_${brightness == .dark ? 'night' : 'paper'}',
        size: ipad,
        brightness: brightness,
        setup: (editor) {
          editor.toggleRuler();
          final ruler = editor.ruler.value!;
          editor.ruler.value = (center: ruler.center, angle: -pi / 6);
        },
        interact: (tester) async {
          // A line along the ruler's top edge
          final editor = tester.state<EditorState>(find.byType(Editor));
          final ruler = editor.ruler.value!;
          final box = tester.renderObject<RenderBox>(find.byType(RulerOverlay));
          final along = Offset(cos(ruler.angle), sin(ruler.angle));
          final up = Offset(sin(ruler.angle), -cos(ruler.angle)) * 40;
          final gesture = await tester.createGesture(kind: .stylus);
          await gesture.down(
            box.localToGlobal(ruler.center + up - along * 300),
          );
          for (var i = 1; i <= 12; i++) {
            await gesture.moveTo(
              box.localToGlobal(
                ruler.center +
                    up +
                    along * (i * 50.0 - 300) +
                    Offset(0, i.isEven ? 6 : -6),
              ),
            );
          }
          await gesture.up();
        },
      );
    });

  testWidgets('links', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'canvas_links_ipad_night',
      size: ipad,
      path: demoNote,
      setup: (editor) {
        final page = editor.coreInfo.pages.first;
        page.links = [
          const PageLink(
            Rect.fromLTWH(740, 30, 250, 70),
            'https://en.wikipedia.org/wiki/Metric_space',
          ),
        ];
        editor.currentTool = Select.currentSelect
          ..onDragStart(const Offset(30, 270), 0)
          ..onDragUpdate(const Offset(980, 260))
          ..onDragUpdate(const Offset(990, 400))
          ..onDragUpdate(const Offset(40, 410))
          ..onDragEnd(page.strokes, page.images);
      },
      interact: (tester) async {
        final editor = tester.state<EditorState>(find.byType(Editor));
        editor.editSelectionLink();
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(EditableText).last,
          'wikipedia.org/wiki/Distance',
        );
      },
    );
  });

  testWidgets('sheet', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'canvas_sheet_ipad_night',
      size: ipad,
      interact: (tester) =>
          tester.tap(find.byTooltip(t.editor.customizeToolbar.customize)),
    );
  });
}

Offset _global(EditorState editor, Offset local) =>
    editor.coreInfo.pages.first.renderBox!.localToGlobal(local);

Stroke _draw(Pen pen, EditorPage page, List<Offset> points) {
  pen.onDragStart(points.first, page, 0, null);
  for (final point in points.skip(1)) {
    pen.onDragUpdate(point, null);
  }
  return pen.onDragEnd()!;
}

/// A brush swash: fast in the middle (thin), slow at the ends.
List<Offset> _swash(Offset origin) => [
  for (var i = 0; i <= 60; i++)
    () {
      final t = i / 60;
      // Ease in and out, so points bunch up at the ends
      final s = t * t * (3 - 2 * t);
      return origin + Offset(s * 320, -70 * sin(s * 2 * pi) + 40 * s);
    }(),
];

/// Calligraphy loops, like a row of "l"s.
List<Offset> _loops(Offset origin) => [
  for (var i = 0; i <= 240; i++)
    origin +
        Offset(
          i * 2.6 - 30 * sin(i * 2 * pi / 40),
          -38 * (1 - cos(i * 2 * pi / 40)),
        ),
];

/// Pumps the editor in Night (a blank note, or the note at [path]),
/// [setup]s it and [interact]s, then writes the PNG.
Future<void> _snapshot(
  WidgetTester tester, {
  required String name,
  required Size size,
  String? path,
  void Function(EditorState editor)? setup,
  Future<void> Function(WidgetTester tester)? interact,
  Brightness brightness = .dark,
}) async {
  stows.platform.value = .iOS;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = size.width < 600
        ? const FakeViewPadding(top: 47, bottom: 34)
        : const FakeViewPadding(top: 24, bottom: 20);
  addTearDown(tester.view.reset);

  debugDisableShadows = false;
  try {
    final key = GlobalKey();
    await tester.pumpWidget(
      TranslationProvider(
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
              FlutterQuillLocalizations.delegate,
            ],
            theme: brightness == .dark
                ? HiganTheme.night(.iOS)
                : HiganTheme.paper(.iOS),
            home: Editor(path: path ?? '/Canvas tools/$name'),
          ),
        ),
      ),
    );

    final editor = tester.state<EditorState>(find.byType(Editor));
    while (editor.coreInfo.readOnlyReason == .placeholder) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pump();
    setup?.call(editor);
    tester.element(find.byType(Editor)).markNeedsBuild();
    await tester.pump();
    await interact?.call(tester);
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File('$higanSnapshotDir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });

    editor.cancelAutosaveAndMarkSaved();
    await tester.pumpWidget(const SizedBox());
  } finally {
    debugDisableShadows = true;
  }
}
