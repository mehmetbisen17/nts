import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:nts/components/home/masonry_files.dart';
import 'package:nts/components/navbar/responsive_navbar.dart';
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

/// [galleryColumns], plus small vs large galleries rendered to PNGs:
/// `HIGAN_SNAPSHOT=1 flutter test test/gallery_size_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  setupMockPrinting();
  setupMockWindowManager();
  disableSentryForTesting();

  tearDown(() => stows.galleryScale.value = 1);

  test('galleryColumns', () {
    // Default: unchanged, at least 2.
    expect(galleryColumns(956, 190), 5);
    expect(galleryColumns(350, 190), 2);
    expect(galleryColumns(956, 300), 3);

    stows.galleryScale.value = 0.6;
    expect(galleryColumns(956, 190), 8);
    expect(galleryColumns(350, 190), 3);

    stows.galleryScale.value = 1.6;
    expect(galleryColumns(956, 190), 3);
    expect(galleryColumns(956, 300), 2, reason: 'at least 2 when wide');
    expect(galleryColumns(350, 190), 1, reason: 'phones go down to 1');

    stows.galleryScale.value = 0; // never divides by zero
    expect(galleryColumns(956, 190), greaterThan(0));
  });

  group('snapshots', () {
    setUpAll(() async {
      if (!higanSnapshotsEnabled) return;
      FlavorConfig.setup();
      stows.sentryConsent.value = .granted;
      await FileManager.init(
        documentsDirectory: '${Directory.systemTemp.path}/nts-gallery-size',
        shouldWatchRootDirectory: false,
      );
      await loadAppFonts();
      await _createLibrary();
    });

    setUp(() {
      stows.folderViewModes.value = const {};
      ICloudStorage.state.value = .connected;
    });

    const devices = [
      ('mac', Size(1280, 800), TargetPlatform.macOS),
      ('ipad', Size(1180, 820), TargetPlatform.iOS),
    ];
    const pages = {
      'recent': (HomePage.recentSubpage, null),
      'folders': (HomePage.browseSubpage, null),
      'folder': (HomePage.browseSubpage, '/Mathematics'),
    };
    for (final (device, size, platform) in devices) {
      for (final (label, scale) in const [('small', 0.6), ('large', 1.6)]) {
        for (final MapEntry(key: page, value: (subpage, path))
            in pages.entries) {
          testWidgets('$device $page $label', skip: !higanSnapshotsEnabled, (
            tester,
          ) async {
            stows.galleryScale.value = scale;
            await _shot(
              tester,
              'gallery_${device}_${page}_${label}_night',
              size,
              platform,
              HomePage(key: UniqueKey(), subpage: subpage, path: path),
            );
          });
        }
      }
      testWidgets('$device settings', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        stows.galleryScale.value = 1.25;
        await _shot(
          tester,
          'gallery_${device}_settings_night',
          size,
          platform,
          HomePage(
            key: UniqueKey(),
            subpage: HomePage.settingsSubpage,
            path: null,
          ),
        );
      });
    }
  });
}

/// Pumps [home] in Night, lets real file IO finish, then writes the PNG.
Future<void> _shot(
  WidgetTester tester,
  String name,
  Size size,
  TargetPlatform platform,
  Widget home,
) async {
  stows.platform.value = platform;
  stows.appTheme.value = .dark;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 24, bottom: 20);
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
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: HiganTheme.night(platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: MacTitlebar(child: child!),
            ),
            home: home,
          ),
        ),
      ),
    );
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

/// Demo notes in a few folders plus some loose notes.
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
    '/Computer science': ['Coding review 1', 'DistSystems MapReduce'],
    '/History': ['HG Week 6', 'HG Week 7'],
    '/Kitchen': ['Oatmeal mugcake recipe'],
    '/Journal': ['CM Welcome Back'],
    '': ['Annotate images and diagrams', 'Import PDFs'],
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
  stows.recentFiles.value = recent;
}
