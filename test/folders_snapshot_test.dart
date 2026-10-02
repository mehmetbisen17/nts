import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/home/home.dart';

import 'higan_snapshot_util.dart';
import 'utils/test_mock_channel_handlers.dart';

/// Renders the Folders screen (in the real home shell) with sample notes to PNGs for visual checks:
/// `HIGAN_SNAPSHOT=1 flutter test test/folders_snapshot_test.dart`
void main() {
  setUpAll(() async {
    if (!higanSnapshotsEnabled) return;
    FlavorConfig.setup();
    setupMockPathProvider();
    final docs = Directory('${Directory.systemTemp.path}/higan-folders-docs');
    if (docs.existsSync()) docs.deleteSync(recursive: true);
    await FileManager.init(
      documentsDirectory: docs.path,
      shouldWatchRootDirectory: false,
    );
    await _writeLibrary();
    ICloudStorage.state.value = .connected;
    stows.sentryConsent.value = .granted;
  });
  tearDown(() => stows.folderViewModes.value = const {});

  const ipad = Size(1180, 820), mac = Size(1280, 800), phone = Size(390, 844);

  for (final brightness in Brightness.values) {
    final mode = brightness == .dark ? 'night' : 'paper';

    Future<void> shoot(
      WidgetTester tester,
      String name, {
      required Size size,
      TargetPlatform platform = .iOS,
      String? path,
      Future<void> Function()? act,
    }) => _shoot(
      tester,
      name: 'folders_${name}_$mode',
      size: size,
      brightness: brightness,
      platform: platform,
      path: path,
      act: act,
    );

    testWidgets('ipad root $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await shoot(tester, 'ipad_root', size: ipad);
    });
    testWidgets('ipad folder $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await shoot(tester, 'ipad_folder', size: ipad, path: '/Mathematics');
    });
    testWidgets('ipad list $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      FolderViewMode.set('/Mathematics', .list);
      await shoot(tester, 'ipad_list', size: ipad, path: '/Mathematics');
    });
    testWidgets('ipad root list $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      FolderViewMode.set('/', .list);
      await shoot(tester, 'ipad_root_list', size: ipad);
    });
    testWidgets('ipad empty $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await shoot(tester, 'ipad_empty', size: ipad, path: '/Empty');
    });
    testWidgets('ipad select $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await shoot(
        tester,
        'ipad_select',
        size: ipad,
        path: '/Physics',
        act: () async {
          await tester.longPress(find.text('Waves'));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Optics'));
        },
      );
    });
    testWidgets('mac root $mode', skip: !higanSnapshotsEnabled, (tester) async {
      await shoot(tester, 'mac_root', size: mac, platform: .macOS);
    });
    testWidgets('mac folder $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await shoot(
        tester,
        'mac_folder',
        size: mac,
        platform: .macOS,
        path: '/Physics',
      );
    });
    testWidgets('phone root $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await shoot(tester, 'phone_root', size: phone);
    });
    testWidgets('phone list $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      FolderViewMode.set('/Mathematics', .list);
      await shoot(tester, 'phone_list', size: phone, path: '/Mathematics');
    });
    testWidgets('folder actions $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await shoot(
        tester,
        'folder_actions',
        size: ipad,
        act: () => tester.longPress(find.text('Chemistry')),
      );
    });
    testWidgets('hover $mode', skip: !higanSnapshotsEnabled, (tester) async {
      await shoot(
        tester,
        'hover',
        size: ipad,
        act: () async {
          final mouse = await tester.createGesture(kind: .mouse);
          await mouse.addPointer(location: .zero);
          addTearDown(mouse.removePointer);
          await mouse.moveTo(
            tester.getCenter(find.text('Chemistry')) - const Offset(0, 120),
          );
        },
      );
    });
    testWidgets('new folder dialog $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await shoot(
        tester,
        'dialog_new_folder',
        size: mac,
        platform: .macOS,
        act: () => tester.tap(find.byTooltip(t.home.newFolder.newFolder).first),
      );
    });
    testWidgets('move dialog $mode', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await shoot(
        tester,
        'dialog_move',
        size: ipad,
        platform: .android,
        path: '/Physics',
        act: () async {
          await tester.longPress(find.text('Optics'));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.byTooltip(t.home.moveNote.moveNote));
        },
      );
    });
  }
}

Future<void> _shoot(
  WidgetTester tester, {
  required String name,
  required Size size,
  required Brightness brightness,
  required TargetPlatform platform,
  String? path,
  Future<void> Function()? act,
}) async {
  await tester.runAsync(loadAppFonts);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  debugDisableShadows = false;
  try {
    final key = GlobalKey();
    final theme = brightness == .dark
        ? HiganTheme.night(platform)
        : HiganTheme.paper(platform);
    await tester.pumpWidget(
      TranslationProvider(
        child: RepaintBoundary(
          key: key,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: theme,
            routerConfig: GoRouter(
              initialLocation: HomeRoutes.browseFilePath(path ?? '/'),
              routes: [
                GoRoute(
                  path: RoutePaths.home,
                  builder: (context, state) => HomePage(
                    subpage:
                        state.pathParameters['subpage'] ??
                        HomePage.recentSubpage,
                    path: state.uri.queryParameters['path'],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Future<void> settle() async {
      // Each step of real file IO needs a real event loop turn and a pump.
      for (var i = 0; i < 150; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 2)),
        );
        await tester.pump(const Duration(milliseconds: 4));
      }
    }

    await settle();
    if (act != null) {
      await act();
      await settle();
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
  } finally {
    debugDisableShadows = true;
  }
}

/// Folder -> note names. Notes reuse the demo notes (and their previews).
const _library = {
  'Mathematics': [
    'Linear algebra',
    'Eigenvalues',
    'Series and sequences',
    'Proofs by induction',
    'Probability',
    'Vectors',
    'Integrals',
    'Limits',
  ],
  'Mathematics/Exams': ['Midterm review', 'Final review'],
  'Physics': ['Waves', 'Thermodynamics', 'Optics', 'Circuits'],
  'Journal': ['26 Sep', '25 Sep', '23 Sep'],
  'Reading': ['Dune', 'Meditations'],
  'Sketches': ['Spider lily', 'Hands', 'Perspective'],
  'Chemistry': ['Bonding', 'Kinetics'],
};

Future<void> _writeLibrary() async {
  final demos = [
    for (final file in Directory('test/demo_notes').listSync())
      if (file.path.endsWith('.sbn2')) file.path,
  ]..sort();
  final now = DateTime.now();
  var n = 0;
  var f = 0;
  for (final MapEntry(key: folder, value: notes) in _library.entries) {
    for (final (i, note) in notes.indexed) {
      final demo = demos[(n++ * 5) % demos.length];
      final path = '/$folder/$note.sbn2';
      final modified = now.subtract(Duration(hours: 2 + f * 22 + i * 30));
      for (final suffix in const ['', '.p']) {
        final file = FileManager.getFile('$path$suffix');
        await file.create(recursive: true);
        await file.writeAsBytes(await File('$demo$suffix').readAsBytes());
        await file.setLastModified(modified);
      }
    }
    f++;
  }
  await FileManager.createFolder('/Empty');
}
