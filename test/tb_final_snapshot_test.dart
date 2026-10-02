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
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/pencil_shader.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/components/toolbar/floating_bar.dart';
import 'package:nts/components/toolbar/toolbar.dart';
import 'package:nts/components/toolbar/top_bar.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/services/pen_presets.dart';
import 'package:nts/data/services/selection_clipboard.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/data/tools/tape.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:sbn/tool_id.dart';

import 'higan_snapshot_util.dart';
import 'utils/test_mock_channel_handlers.dart';

/// The integrated toolbar, tools and bars, for a final visual check:
/// `HIGAN_SNAPSHOT=1 flutter test test/tb_final_snapshot_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  setupMockPrinting();
  setupMockWindowManager();
  FlavorConfig.setup();

  const note = '/Mathematics/Metric Spaces Week 1';

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
    stows.editorToolbarItems.value = ToolCatalog.basics;
    stows.editorBarPositions.value = const {};
    stows.editorMinimizedBars.value = const [];
    stows.penPresets.value = const [];
    Select.currentSelect.unselect();
    SelectionClipboard.content.value = null;
    // A fresh copy, since the editor saves changes
    final bytes = await File('test/demo_notes/Metric Spaces Week 1.sbn2')
        .readAsBytes();
    final file = FileManager.getFile('$note${Editor.extension}');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
  });

  const ipad = Size(1180, 820), mac = Size(1280, 800), phone = Size(390, 844);

  Finder grip(Type bar) => find.descendant(
    of: find.byType(bar),
    matching: find.byType(FloatingBarGrip),
  );

  for (final brightness in Brightness.values) {
    final mode = brightness == .dark ? 'night' : 'paper';
    testWidgets('basics $mode', skip: !higanSnapshotsEnabled, (tester) async {
      await _snapshot(
        tester,
        name: 'tb_final_basics_ipad_$mode',
        size: ipad,
        brightness: brightness,
      );
    });
  }

  testWidgets('basics phone', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(tester, name: 'tb_final_basics_phone_night', size: phone);
  });

  testWidgets('sheet', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'tb_final_sheet_ipad_night',
      size: ipad,
      interact: (tester) =>
          tester.tap(find.byTooltip(t.editor.customizeToolbar.customize)),
    );
  });

  for (final (scroll, suffix) in const [(900.0, '2'), (1800.0, '3')]) {
    testWidgets('sheet scrolled $suffix', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await _snapshot(
        tester,
        name: 'tb_final_sheet_${suffix}_ipad_paper',
        size: ipad,
        brightness: .light,
        interact: (tester) async {
          await tester.tap(find.byTooltip(t.editor.customizeToolbar.customize));
          await tester.pumpAndSettle();
          await tester.drag(
            find.byType(CustomScrollView).last,
            Offset(0, -scroll),
          );
        },
      );
    });
  }

  testWidgets('minimized', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'tb_final_minimized_ipad_night',
      size: ipad,
      interact: (tester) async {
        for (final bar in [Toolbar, EditorTopBar]) {
          await tester.tap(
            find.descendant(
              of: find.byType(bar),
              matching: find.byType(MinimizeBarButton),
            ),
          );
          await tester.pump();
        }
      },
    );
  });

  testWidgets('moved', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'tb_final_moved_ipad_paper',
      size: ipad,
      brightness: .light,
      interact: (tester) async {
        await tester.drag(grip(Toolbar), Offset(ipad.width, -ipad.height));
        await tester.pump();
        await tester.drag(grip(EditorTopBar), Offset(-ipad.width, ipad.height));
        await tester.pump();
        await tester.tap(find.byTooltip(Pen.currentPen.name));
      },
    );
  });

  // Every tool, with pen favorites: splits into two rows
  for (final (device, size) in [
    ('ipad', ipad),
    ('mac', mac),
    ('phone', phone),
  ]) {
    testWidgets('all tools $device', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      stows.editorToolbarItems.value = [
        for (final item in ToolCatalog.items) item.id,
      ];
      stows.penPresets.value = [
        const PenPreset(toolId: .fountainPen, color: Colors.black, size: 5),
        const PenPreset(
          toolId: .highlighter,
          color: Color(0xFFFFEB3B),
          size: 20,
        ),
      ];
      await _snapshot(
        tester,
        name: 'tb_final_all_tools_${device}_night',
        size: size,
      );
    });
  }

  testWidgets('tools in use', skip: !higanSnapshotsEnabled, (tester) async {
    stows.editorToolbarItems.value = [
      ...ToolCatalog.basics,
      'tape',
      'brushPen',
      'ruler',
      'addPage',
    ];
    await _snapshot(
      tester,
      name: 'tb_final_tape_brush_ruler_ipad_paper',
      size: ipad,
      brightness: .light,
      setup: (editor) {
        final page = editor.coreInfo.pages.first;
        final tape = Tape.currentTape..color = Tape.defaultColor;
        page.insertStroke(
          _draw(tape, page, [const Offset(580, 386), const Offset(980, 386)]),
        );
        // A brush swash under the title
        final brush = Pen.brushPen()
          ..options.size = 12
          ..color = const Color(0xFFD0283A);
        page.insertStroke(
          _draw(brush, page, [
            for (var i = 0; i <= 60; i++)
              Offset(120 + i * 5.0, 108 - 10 * sin(i / 60 * 2 * pi)),
          ]),
        );
        editor.currentTool = Pen.currentPen = brush;
        editor.toggleRuler();
        final ruler = editor.ruler.value!;
        editor.ruler.value = (center: ruler.center, angle: -pi / 12);
      },
    );
  });

  testWidgets('some tools phone', skip: !higanSnapshotsEnabled, (tester) async {
    stows.editorToolbarItems.value = [
      ...ToolCatalog.basics,
      'tape',
      'brushPen',
      'ruler',
      'addPage',
    ];
    await _snapshot(
      tester,
      name: 'tb_final_some_tools_phone_night',
      size: phone,
    );
  });

  testWidgets('ruler night', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'tb_final_ruler_ipad_night',
      size: ipad,
      setup: (editor) {
        editor.toggleRuler();
        final ruler = editor.ruler.value!;
        editor.ruler.value = (
          center: ruler.center - const Offset(0, 240),
          angle: -pi / 12,
        );
      },
    );
  });

  void lassoTitle(EditorState editor) {
    final page = editor.coreInfo.pages.first;
    editor.currentTool = Select.currentSelect
      ..onDragStart(const Offset(20, 20), 0)
      ..onDragUpdate(const Offset(420, 10))
      ..onDragUpdate(const Offset(430, 120))
      ..onDragUpdate(const Offset(10, 110))
      ..onDragEnd(page.strokes, page.images);
  }

  testWidgets('lasso phone', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'tb_final_lasso_phone_night',
      size: phone,
      setup: lassoTitle,
    );
  });

  testWidgets('minimized lasso', skip: !higanSnapshotsEnabled, (tester) async {
    stows.editorMinimizedBars.value = const ['toolbar', 'topBar'];
    await _snapshot(
      tester,
      name: 'tb_final_minimized_lasso_ipad_paper',
      size: ipad,
      brightness: .light,
      setup: lassoTitle,
    );
  });

  testWidgets('lasso bar', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshot(
      tester,
      name: 'tb_final_lasso_bar_ipad_night',
      size: ipad,
      setup: (editor) {
        final page = editor.coreInfo.pages.first;
        // Something copied, so "Paste" shows too
        SelectionClipboard.content.value = (
          strokes: const [],
          images: const [],
          assets: const [],
          path: Path(),
        );
        editor.currentTool = Select.currentSelect
          ..onDragStart(const Offset(20, 20), 0)
          ..onDragUpdate(const Offset(420, 10))
          ..onDragUpdate(const Offset(430, 120))
          ..onDragUpdate(const Offset(10, 110))
          ..onDragEnd(page.strokes, page.images);
      },
    );
  });
}

Stroke _draw(Pen pen, EditorPage page, List<Offset> points) {
  pen.onDragStart(points.first, page, 0, null);
  for (final point in points.skip(1)) {
    pen.onDragUpdate(point, null);
  }
  return pen.onDragEnd()!;
}

/// Pumps the demo note, [setup]s and [interact]s, then writes the PNG.
Future<void> _snapshot(
  WidgetTester tester, {
  required String name,
  required Size size,
  Brightness brightness = .dark,
  void Function(EditorState editor)? setup,
  Future<void> Function(WidgetTester tester)? interact,
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
            home: Editor(path: '/Mathematics/Metric Spaces Week 1'),
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
