import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/i18n/strings.g.dart';

/// Where [higanSnapshot] writes PNGs (outside the repo).
final higanSnapshotDir = '${Directory.systemTemp.path}/nts-snapshots';

/// True when run with `HIGAN_SNAPSHOT=1`. Use as `skip: !higanSnapshotsEnabled`
/// so the normal test suite doesn't write files.
final higanSnapshotsEnabled = Platform.environment['HIGAN_SNAPSHOT'] == '1';

var _fontsLoaded = false;

/// Pumps [child] in the Higan theme at [size] (devicePixelRatio 1) and
/// writes `<higanSnapshotDir>/<name>.png`.
///
/// Real fonts are loaded from FontManifest.json (Geist, GeistMono,
/// MaterialIcons, Material Symbols, ...). Animations keep running, so this
/// pumps [settle] instead of `pumpAndSettle`.
Future<File> higanSnapshot(
  WidgetTester tester, {
  required String name,
  required Widget child,
  Size size = const Size(1180, 800),
  Brightness brightness = .dark,
  TargetPlatform platform = .iOS,
  Duration settle = const Duration(milliseconds: 600),
}) async {
  if (!_fontsLoaded) {
    FlavorConfig.setup();
    await tester.runAsync(loadAppFonts);
    _fontsLoaded = true;
  }

  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final file = File('$higanSnapshotDir/$name.png');

  // flutter_test disables shadows and checks they're disabled again
  // before tear-downs run, so restore it here.
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
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
    // Let images and fonts settle, and animations move a little.
    for (var elapsed = Duration.zero; elapsed < settle; elapsed += _frame) {
      await tester.pump(_frame);
    }

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
  } finally {
    debugDisableShadows = true;
  }
  return file;
}

const _frame = Duration(milliseconds: 50);
