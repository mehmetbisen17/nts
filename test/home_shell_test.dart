import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nts/components/navbar/home_sidebar.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/data/sentry/sentry_init.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/home/browse.dart';
import 'package:nts/pages/home/home.dart';

void main() {
  testWidgets('Sidebar opens folders in the browse page', (tester) async {
    FlavorConfig.setup();
    disableSentryForTesting();
    stows.sentryConsent.value = .granted;
    final docs = '${Directory.systemTemp.path}/nts-home-shell-test';
    await tester.runAsync(() async {
      if (Directory(docs).existsSync())
        Directory(docs).deleteSync(recursive: true);
      await Directory('$docs/Alpha').create(recursive: true);
      await Directory('$docs/Beta').create(recursive: true);
    });
    await FileManager.init(
      documentsDirectory: docs,
      shouldWatchRootDirectory: false,
    );

    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp.router(
          theme: HiganTheme.night(.macOS),
          routerConfig: router,
        ),
      ),
    );

    // Lets file IO finish (the lily keeps animating, so no pumpAndSettle).
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Finder inSidebar(String text) => find.descendant(
      of: find.byType(HomeSidebar),
      matching: find.text(text),
    );
    Finder inBrowse(String text) =>
        find.descendant(of: find.byType(BrowsePage), matching: find.text(text));
    String? path() => router.state.uri.queryParameters['path'];

    await settle();
    expect(inBrowse('Beta'), findsWidgets);

    await tester.tap(inSidebar('Alpha'));
    await settle();
    expect(path(), '/Alpha');
    expect(inBrowse('Alpha'), findsWidgets); // the title
    expect(inBrowse('Beta'), findsNothing);

    await tester.tap(inSidebar('Beta'));
    await settle();
    expect(path(), '/Beta');
    expect(inBrowse('Alpha'), findsNothing);

    // Folders goes back to the root, even when it's already selected.
    await tester.tap(inSidebar(t.higan.folders));
    await settle();
    expect(path(), isNull);
    expect(inBrowse('Alpha'), findsWidgets);
    expect(inBrowse('Beta'), findsWidgets);
  });
}
