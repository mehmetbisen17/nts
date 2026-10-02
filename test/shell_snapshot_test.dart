import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/sentry/sentry_init.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/home/home.dart';

import 'higan_snapshot_util.dart';
import 'utils/test_mock_channel_handlers.dart';

/// Renders the home shell and Recent page to PNGs for visual checks:
/// `HIGAN_SNAPSHOT=1 flutter test test/shell_snapshot_test.dart`
void main() {
  setupMockPrinting();
  setupMockWindowManager();
  disableSentryForTesting();

  setUpAll(() async {
    FlavorConfig.setup();
    stows.sentryConsent.value = .granted;
    await FileManager.init(
      documentsDirectory: '${Directory.systemTemp.path}/nts-shell-snapshot',
      shouldWatchRootDirectory: false,
    );
    if (higanSnapshotsEnabled) await _createLibrary();
  });

  setUp(() {
    stows.folderViewModes.value = const {};
    ICloudStorage.state.value = .connected;
  });

  const ipad = Size(1180, 820), mac = Size(1280, 800), phone = Size(390, 844);

  for (final brightness in Brightness.values) {
    final mode = brightness == .dark ? 'night' : 'paper';

    testWidgets('ipad recent $mode', skip: !higanSnapshotsEnabled, (t) async {
      await _shot(t, 'shell_ipad_recent_$mode', ipad, brightness, .iOS);
    });
    testWidgets('mac recent $mode', skip: !higanSnapshotsEnabled, (t) async {
      await _shot(t, 'shell_mac_recent_$mode', mac, brightness, .macOS);
    });
    testWidgets('phone recent $mode', skip: !higanSnapshotsEnabled, (t) async {
      await _shot(t, 'shell_phone_recent_$mode', phone, brightness, .iOS);
    });
  }

  testWidgets('ipad recent list', skip: !higanSnapshotsEnabled, (t) async {
    FolderViewMode.set(FolderViewMode.recentKey, .list);
    await _shot(t, 'shell_ipad_recent_list_night', ipad, .dark, .iOS);
  });

  testWidgets('mac folder', skip: !higanSnapshotsEnabled, (t) async {
    await _shot(
      t,
      'shell_mac_folder_night',
      mac,
      .dark,
      .macOS,
      subpage: HomePage.browseSubpage,
      path: '/Mathematics',
    );
  });

  for (final (name, size, platform) in [
    ('ipad', ipad, TargetPlatform.iOS),
    ('mac', mac, TargetPlatform.macOS),
  ]) {
    testWidgets('$name whiteboard', skip: !higanSnapshotsEnabled, (t) async {
      await _shot(
        t,
        'shell_${name}_whiteboard_night',
        size,
        .dark,
        platform,
        subpage: HomePage.whiteboardSubpage,
      );
    });
    testWidgets('$name settings', skip: !higanSnapshotsEnabled, (t) async {
      await _shot(
        t,
        'shell_${name}_settings_paper',
        size,
        .light,
        platform,
        subpage: HomePage.settingsSubpage,
      );
    });
  }

  testWidgets('empty recent', skip: !higanSnapshotsEnabled, (t) async {
    ICloudStorage.state.value = .notConnected;
    final recent = stows.recentFiles.value;
    stows.recentFiles.value = [];
    addTearDown(() => stows.recentFiles.value = recent);
    await _shot(t, 'shell_ipad_empty_night', ipad, .dark, .iOS);
    await _shot(t, 'shell_mac_empty_paper', mac, .light, .macOS);
  });
}

/// Like [higanSnapshot], but lets file IO finish and precaches the note
/// previews before capturing.
Future<void> _shot(
  WidgetTester tester,
  String name,
  Size size,
  Brightness brightness,
  TargetPlatform platform, {
  String subpage = HomePage.recentSubpage,
  String? path,
}) async {
  await tester.runAsync(loadAppFonts);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
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
            theme: brightness == .dark
                ? HiganTheme.night(platform)
                : HiganTheme.paper(platform),
            home: HomePage(key: UniqueKey(), subpage: subpage, path: path),
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
    await tester.loadAssets();
    for (var i = 0; i < 12; i++) {
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
  } finally {
    debugDisableShadows = true;
  }
}

/// Copies the demo notes into a few folders, with realistic dates.
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
    '/Computer science': [
      'Coding review 1',
      'DistSystems MapReduce',
      'Third year projects',
      'Uni Y3 course unit selection',
    ],
    '/History': ['HG Week 6', 'HG Week 7'],
    '/Kitchen': ['Oatmeal mugcake recipe'],
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
  // Most recent first, mixed across folders.
  recent.sort((a, b) => a.hashCode.compareTo(b.hashCode));
  stows.recentFiles.value = recent;
}
