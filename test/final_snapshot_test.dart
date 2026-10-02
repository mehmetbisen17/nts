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
import 'package:nts/components/navbar/responsive_navbar.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/sentry/sentry_init.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:nts/pages/home/home.dart';
import 'package:sbn/tool_id.dart';

import 'higan_snapshot_util.dart';
import 'utils/test_mock_channel_handlers.dart';

/// The integrated redesign, every main screen in Night and Paper:
/// `HIGAN_SNAPSHOT=1 flutter test test/final_snapshot_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  setupMockPrinting();
  setupMockWindowManager();
  disableSentryForTesting();

  setUpAll(() async {
    if (!higanSnapshotsEnabled) return;
    FlavorConfig.setup();
    stows.sentryConsent.value = .granted;
    await FileManager.init(
      documentsDirectory: '${Directory.systemTemp.path}/nts-final-snapshot',
      shouldWatchRootDirectory: false,
    );
    await Future.wait([PencilShader.init(), loadAppFonts()]);
    await _createLibrary();
  });

  setUp(() {
    stows.folderViewModes.value = const {};
    stows.editorAutoInvert.value = false;
    stows.editorToolbarAlignment.value = .down;
    stows.lastTool.value = ToolId.fountainPen;
    Pen.currentPen = Pen.fountainPen();
    ICloudStorage.state.value = .connected;
  });

  const devices = [
    ('ipad', Size(1180, 820), TargetPlatform.iOS),
    ('mac', Size(1280, 800), TargetPlatform.macOS),
  ];

  for (final brightness in Brightness.values) {
    final mode = brightness == .dark ? 'night' : 'paper';
    for (final (device, size, platform) in devices) {
      Future<void> home(
        WidgetTester tester,
        String name, {
        String subpage = HomePage.recentSubpage,
        String? path,
      }) => _shot(
        tester,
        'final_${device}_${name}_$mode',
        size,
        brightness,
        platform,
        HomePage(key: UniqueKey(), subpage: subpage, path: path),
      );

      testWidgets('$device recent $mode', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        await home(tester, 'recent');
      });
      testWidgets('$device folders $mode', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        await home(tester, 'folders', subpage: HomePage.browseSubpage);
      });
      testWidgets('$device folders list $mode', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        FolderViewMode.set('/', .list);
        await home(tester, 'folders_list', subpage: HomePage.browseSubpage);
      });
      testWidgets('$device folder $mode', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        await home(
          tester,
          'folder',
          subpage: HomePage.browseSubpage,
          path: '/Mathematics',
        );
      });
      testWidgets('$device folder list $mode', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        FolderViewMode.set('/Mathematics', .list);
        await home(
          tester,
          'folder_list',
          subpage: HomePage.browseSubpage,
          path: '/Mathematics',
        );
      });
      testWidgets('$device settings $mode', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        await home(tester, 'settings', subpage: HomePage.settingsSubpage);
      });
      testWidgets('$device whiteboard $mode', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        await home(tester, 'whiteboard', subpage: HomePage.whiteboardSubpage);
      });
      testWidgets('$device editor $mode', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        await _shot(
          tester,
          'final_${device}_editor_$mode',
          size,
          brightness,
          platform,
          Editor(path: '/Mathematics/Metric Spaces Week 1'),
        );
      });
    }
  }

  testWidgets('ipad editor black pages paper', skip: !higanSnapshotsEnabled, (
    tester,
  ) async {
    stows.editorAutoInvert.value = true;
    await _shot(
      tester,
      'final_ipad_editor_black_paper',
      const Size(1180, 820),
      .light,
      .iOS,
      Editor(path: '/Mathematics/Metric Spaces Week 1'),
    );
  });

  const phone = Size(390, 844);
  testWidgets('phone recent night', skip: !higanSnapshotsEnabled, (
    tester,
  ) async {
    await _shot(
      tester,
      'final_phone_recent_night',
      phone,
      .dark,
      .iOS,
      HomePage(key: UniqueKey(), subpage: HomePage.recentSubpage, path: null),
    );
  });
  for (final brightness in Brightness.values) {
    final mode = brightness == .dark ? 'night' : 'paper';
    testWidgets('phone editor $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await _shot(
        tester,
        'final_phone_editor_$mode',
        phone,
        brightness,
        .iOS,
        Editor(path: '/Mathematics/Metric Spaces Week 1'),
      );
    });
  }
  testWidgets('phone folders night', skip: !higanSnapshotsEnabled, (
    tester,
  ) async {
    await _shot(
      tester,
      'final_phone_folders_night',
      phone,
      .dark,
      .iOS,
      HomePage(key: UniqueKey(), subpage: HomePage.browseSubpage, path: null),
    );
  });
}

/// Pumps [home] in the Higan theme, lets real file IO (and, for the
/// editor, note loading) finish, then writes the PNG.
Future<void> _shot(
  WidgetTester tester,
  String name,
  Size size,
  Brightness brightness,
  TargetPlatform platform,
  Widget home,
) async {
  stows.platform.value = platform;
  stows.appTheme.value = brightness == .dark ? .dark : .light;
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
            builder: (context, child) => MacTitlebar(child: child!),
            home: home,
          ),
        ),
      ),
    );

    if (home is Editor) {
      final editor = tester.state<EditorState>(find.byType(Editor));
      while (editor.coreInfo.isEmpty) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }
    // Each step of real file IO needs a real event loop turn and a pump.
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.loadAssets();
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

    // Dispose while shadows are still allowed.
    await tester.pumpWidget(const SizedBox());
  } finally {
    debugDisableShadows = true;
  }
}

/// Demo notes in a few folders plus some loose notes, with realistic dates.
Future<void> _createLibrary() async {
  final root = Directory(FileManager.documentsDirectory);
  if (root.existsSync()) root.deleteSync(recursive: true);

  const library = {
    '/Mathematics': [
      'Golden ratio',
      'Metric Spaces Week 1',
      'Topology week 1',
      'Courses Year 3 Sem 2 Revision',
    ],
    '/Mathematics/Exams': ['HG Week 7'],
    '/Computer science': [
      'Coding review 1',
      'DistSystems MapReduce',
      'Third year projects',
      'Uni Y3 course unit selection',
    ],
    '/History': ['HG Week 6', 'HG Week 7'],
    '/Kitchen': ['Oatmeal mugcake recipe'],
    '/Journal': ['CM Welcome Back', 'You can type notes too!'],
    '': [
      'Annotate images and diagrams',
      'Import PDFs',
      'You can type notes too!',
      'CM Welcome Back',
    ],
  };
  final now = DateTime.now();
  final recent = <String>[];
  var age = 0;
  for (final MapEntry(key: folder, value: notes) in library.entries) {
    await Directory('${root.path}$folder').create(recursive: true);
    for (final note in notes) {
      for (final src in Directory('test/demo_notes').listSync()) {
        final name = src.uri.pathSegments.last;
        if (!name.startsWith('$note.sbn2')) continue;
        final dst = File('${root.path}$folder/$name');
        await (src as File).copy(dst.path);
        dst.setLastModifiedSync(now.subtract(Duration(hours: 2 + age * 19)));
      }
      recent.add('$folder/$note.sbn2');
      age++;
    }
  }
  recent.sort((a, b) => a.hashCode.compareTo(b.hashCode));
  stows.recentFiles.value = recent;
}
