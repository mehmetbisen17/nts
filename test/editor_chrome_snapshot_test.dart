import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:nts/components/canvas/pencil_shader.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:sbn/tool_id.dart';

import 'higan_snapshot_util.dart';
import 'utils/test_mock_channel_handlers.dart';

/// Renders the restyled editor to PNGs for visual checks:
/// `HIGAN_SNAPSHOT=1 flutter test test/editor_chrome_snapshot_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  setupMockPrinting();
  setupMockWindowManager();
  FlavorConfig.setup();

  const notePath = '/Mathematics/Metric Spaces Week 1';

  setUpAll(() async {
    if (!higanSnapshotsEnabled) return;
    await Future.wait([
      FileManager.init(shouldWatchRootDirectory: false),
      PencilShader.init(),
      loadAppFonts(),
    ]);
    final bytes = await File('test/demo_notes/Metric Spaces Week 1.sbn2')
        .readAsBytes();
    final file = FileManager.getFile('$notePath${Editor.extension}');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
  });

  setUp(() {
    stows.lastTool.value = ToolId.fountainPen;
    Pen.currentPen = Pen.fountainPen();
    stows.editorToolbarAlignment.value = .down;
    stows.editorAutoInvert.value = false;
  });

  const ipad = Size(1180, 820), mac = Size(1280, 800), phone = Size(390, 844);

  for (final brightness in Brightness.values) {
    final mode = brightness == .dark ? 'night' : 'paper';

    for (final (device, size, platform) in const [
      ('ipad', ipad, TargetPlatform.iOS),
      ('mac', mac, TargetPlatform.macOS),
      ('phone', phone, TargetPlatform.iOS),
    ]) {
      testWidgets('$device $mode', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        await _snapshotEditor(
          tester,
          name: 'editor_${device}_$mode',
          size: size,
          brightness: brightness,
          platform: platform,
          notePath: notePath,
        );
      });
    }

    testWidgets('eraser $mode', skip: !higanSnapshotsEnabled, (tester) async {
      stows.lastTool.value = ToolId.eraser;
      await _snapshotEditor(
        tester,
        name: 'editor_eraser_$mode',
        size: ipad,
        brightness: brightness,
        notePath: notePath,
      );
    });

    testWidgets('pen types $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await _snapshotEditor(
        tester,
        name: 'editor_pen_types_$mode',
        size: ipad,
        brightness: brightness,
        notePath: notePath,
        interact: (tester) async {
          await tester.tap(find.byTooltip(Pen.currentPen.name));
          await tester.pump();
          await tester.tap(find.byTooltip(t.editor.toolbar.export));
        },
      );
    });

    testWidgets('left toolbar $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      stows.editorToolbarAlignment.value = .left;
      await _snapshotEditor(
        tester,
        name: 'editor_left_$mode',
        size: mac,
        brightness: brightness,
        platform: .macOS,
        notePath: notePath,
      );
    });
  }

  for (final (name, tooltip) in [
    ('options', 'More'),
    ('pages', t.editor.pages),
  ]) {
    testWidgets(name, skip: !higanSnapshotsEnabled, (tester) async {
      await _snapshotEditor(
        tester,
        name: 'editor_${name}_night',
        size: ipad,
        brightness: .dark,
        notePath: notePath,
        interact: (tester) => tester.tap(find.byTooltip(tooltip)),
      );
    });
  }

  for (final (device, size, platform) in const [
    ('ipad', ipad, TargetPlatform.iOS),
    ('mac', mac, TargetPlatform.macOS),
  ]) {
    testWidgets('text $device', skip: !higanSnapshotsEnabled, (tester) async {
      await _snapshotEditor(
        tester,
        name: 'editor_text_${device}_paper',
        size: size,
        brightness: .light,
        platform: platform,
        notePath: notePath,
        interact: (tester) => tester.tap(find.byTooltip(t.editor.toolbar.text)),
      );
    });
  }

  testWidgets('black pages', skip: !higanSnapshotsEnabled, (tester) async {
    stows.editorAutoInvert.value = true;
    await _snapshotEditor(
      tester,
      name: 'editor_black_pages_night',
      size: ipad,
      brightness: .dark,
      notePath: notePath,
    );
  });

  testWidgets('loading', skip: !higanSnapshotsEnabled, (tester) async {
    await _snapshotEditor(
      tester,
      name: 'editor_loading_night',
      size: ipad,
      brightness: .dark,
      notePath: notePath,
      waitForLoad: false,
    );
  });
}

/// Like [higanSnapshot], but waits for the note to load (real IO)
/// and can [interact] before capturing.
Future<void> _snapshotEditor(
  WidgetTester tester, {
  required String name,
  required Size size,
  required Brightness brightness,
  TargetPlatform platform = .iOS,
  required String notePath,
  bool waitForLoad = true,
  Future<void> Function(WidgetTester tester)? interact,
}) async {
  stows.platform.value = platform;
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
                ? HiganTheme.night(platform)
                : HiganTheme.paper(platform),
            home: Editor(path: notePath),
          ),
        ),
      ),
    );

    if (waitForLoad) {
      final editor = tester.state<EditorState>(find.byType(Editor));
      while (editor.coreInfo.isEmpty) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }
    await interact?.call(tester);
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 30; i++) {
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

    // Dispose the editor while shadows are still allowed.
    await tester.pumpWidget(const SizedBox());
  } finally {
    debugDisableShadows = true;
  }
}
