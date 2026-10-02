import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:nts/components/canvas/pencil_shader.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/data/sentry/sentry_init.dart';
import 'package:nts/data/tools/eraser.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:nts/pages/home/browse.dart';
import 'package:nts/pages/home/home.dart';

import 'higan_snapshot_util.dart';
import 'utils/test_mock_channel_handlers.dart';

/// Renders the mouse's right-click menus and the eraser's outline to PNGs:
/// `HIGAN_SNAPSHOT=1 flutter test test/mouse_snapshot_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  setupMockPrinting();
  setupMockWindowManager();
  FlavorConfig.setup();
  disableSentryForTesting();

  const notePath = '/Mathematics/Metric Spaces Week 1';
  const mac = Size(1280, 800);
  late List<int> demo;

  setUpAll(() async {
    if (!higanSnapshotsEnabled) return;
    await Future.wait([
      FileManager.init(shouldWatchRootDirectory: false),
      PencilShader.init(),
      loadAppFonts(),
    ]);
    demo = await File('test/demo_notes/Metric Spaces Week 1.sbn2')
        .readAsBytes();
    final file = FileManager.getFile('$notePath${Editor.extension}');
    await file.create(recursive: true);
    await file.writeAsBytes(demo);
  });

  setUp(() {
    stows.lastTool.value = .fountainPen;
    Pen.currentPen = Pen.fountainPen();
    stows.editorToolbarAlignment.value = .down;
    stows.editorAutoInvert.value = false;
    stows.platform.value = .macOS;
    stows.sentryConsent.value = .granted;
    Select.currentSelect.unselect();
  });

  /// The editor on a Mac with the demo note loaded.
  Future<EditorState> pumpEditor(WidgetTester tester, GlobalKey key) async {
    await tester.pumpWidget(
      _Frame(
        boundary: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            FlutterQuillLocalizations.delegate,
          ],
          theme: HiganTheme.night(.macOS),
          home: Editor(path: notePath),
        ),
      ),
    );
    final editor = tester.state<EditorState>(find.byType(Editor));
    while (editor.coreInfo.isEmpty) {
      await _wait(tester);
    }
    await _frames(tester, 20); // past the double-click guard
    return editor;
  }

  Offset onPage(EditorState editor, Offset local) =>
      editor.coreInfo.pages.first.renderBox!.localToGlobal(local);

  testWidgets('editor canvas menu', skip: !higanSnapshotsEnabled, (
    tester,
  ) async {
    await _capture(tester, 'mouse_editor_canvas_menu', mac, (key) async {
      final editor = await pumpEditor(tester, key);
      await _rightClick(tester, onPage(editor, const Offset(700, 250)));
    });
  }, variant: TargetPlatformVariant.only(.macOS));

  testWidgets('editor selection menu', skip: !higanSnapshotsEnabled, (
    tester,
  ) async {
    await _capture(tester, 'mouse_editor_selection_menu', mac, (key) async {
      final editor = await pumpEditor(tester, key);
      editor.selectAll(0);
      await _frames(tester, 4);
      expect(Select.currentSelect.selectionBounds, isNotNull);
      // Above the toolbars, which have menus of their own
      await _rightClick(tester, onPage(editor, const Offset(700, 250)));
    });
  }, variant: TargetPlatformVariant.only(.macOS));

  testWidgets('eraser outline', skip: !higanSnapshotsEnabled, (tester) async {
    stows.eraserSize.value = 20;
    await _capture(tester, 'mouse_eraser_cursor', mac, (key) async {
      final editor = await pumpEditor(tester, key);
      editor.currentTool = Eraser();
      tester.element(find.byType(Editor)).markNeedsBuild();
      await tester.pump();
      final at = onPage(editor, const Offset(400, 300));
      final gesture = await tester.createGesture(kind: .mouse);
      await gesture.addPointer(location: at - const Offset(4, 4));
      await gesture.moveTo(at);
      addTearDown(gesture.removePointer);
    });
  }, variant: TargetPlatformVariant.only(.macOS));

  testWidgets('home card menu', skip: !higanSnapshotsEnabled, (tester) async {
    final docs = '${Directory.systemTemp.path}/nts-mouse-snapshot-test';
    await tester.runAsync(() async {
      if (Directory(docs).existsSync()) {
        Directory(docs).deleteSync(recursive: true);
      }
      await Directory('$docs/Mathematics').create(recursive: true);
      await File('$docs/Mathematics/Week 1.sbn2').writeAsBytes(demo);
      for (final name in ['Metric Spaces', 'Lecture notes', 'Ideas']) {
        await File('$docs/$name.sbn2').writeAsBytes(demo);
      }
    });
    await FileManager.init(
      documentsDirectory: docs,
      shouldWatchRootDirectory: false,
    );
    final router = GoRouter(
      initialLocation: HomeRoutes.browseFilePath(null),
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => HomePage(
            subpage: state.pathParameters['subpage'] ?? HomePage.recentSubpage,
            path: state.uri.queryParameters['path'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _capture(tester, 'mouse_home_card_menu', const Size(1280, 1000), (
      key,
    ) async {
      await tester.pumpWidget(
        _Frame(
          boundary: key,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: HiganTheme.night(.macOS),
            routerConfig: router,
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await _wait(tester);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _rightClick(
        tester,
        tester.getCenter(
          find.descendant(
            of: find.byType(BrowsePage),
            matching: find.text('Metric Spaces'),
          ),
        ),
      );
    });
  }, variant: TargetPlatformVariant.only(.macOS));
}

class _Frame extends StatelessWidget {
  const new({required this.boundary, required this.child});

  final GlobalKey boundary;
  final Widget child;

  @override
  Widget build(BuildContext context) => TranslationProvider(
    child: RepaintBoundary(key: boundary, child: child),
  );
}

/// Runs [build] (which pumps the app into the boundary it's given),
/// then writes the boundary to `<higanSnapshotDir>/<name>.png`.
Future<void> _capture(
  WidgetTester tester,
  String name,
  Size size,
  Future<void> Function(GlobalKey key) build,
) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 24, bottom: 20);
  addTearDown(tester.view.reset);
  debugDisableShadows = false;
  try {
    final key = GlobalKey();
    await build(key);
    await _wait(tester);
    await _frames(tester, 20);
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
    // Dispose while shadows are still allowed.
    await tester.pumpWidget(const SizedBox());
  } finally {
    debugDisableShadows = true;
  }
}

Future<void> _rightClick(WidgetTester tester, Offset at) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await gesture.addPointer(location: at);
  await gesture.down(at);
  await gesture.up();
  await gesture.removePointer();
  await _frames(tester, 10);
}

Future<void> _wait(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
}

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
