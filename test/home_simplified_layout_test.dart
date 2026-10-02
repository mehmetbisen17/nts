import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/sentry/_sentry_init_foss.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/home/home.dart';

import 'utils/demo_files.dart';
import 'utils/test_mock_channel_handlers.dart';

void main() {
  group('simplifiedHomeLayout', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupMockPathProvider();
    disableSentryForTesting();

    FlavorConfig.setup();

    stows.sentryConsent.value = .granted;
    stows.homeLayout.value = .simpleGrid;

    setUpAll(() async {
      await FileManager.init(shouldWatchRootDirectory: false);
      await setupDemoFiles();
    });

    testGoldens('golden', (tester) async {
      final device = GoldenSmallDevices.androidPhone.device;

      final widget = ScreenshotApp.withConditionalTitlebar(
        device: device,
        title: 'nts',
        home: TranslationProvider(
          child: const HomePage(subpage: HomePage.recentSubpage, path: ''),
        ),
      );
      await tester.pumpWidget(widget);
      await tester.pump();

      await tester.loadAssets();
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_simplified_layout.png'),
      );
    });
  });
}
