import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/data/sentry/sentry_init.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/main.dart';
import 'package:nts/pages/home/home.dart';

void main() {
  group('Home subpage transition', () {
    for (final brightness in Brightness.values)
      testWidgets(brightness.name, (tester) async {
        FlavorConfig.setup();
        disableSentryForTesting();
        stows.sentryConsent.value = .granted;
        stows.layoutSize.value = .phone;

        final router = GoRouter(
          initialLocation: App.initialLocation,
          routes: [
            GoRoute(
              path: RoutePaths.home,
              builder: (context, state) => HomePage(
                subpage:
                    state.pathParameters['subpage'] ?? HomePage.recentSubpage,
                path: state.uri.queryParameters['path'],
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            title: 'Saber',
            routeInformationProvider: router.routeInformationProvider,
            routeInformationParser: router.routeInformationParser,
            routerDelegate: router.routerDelegate,
          ),
        );

        await tester.tap(find.byTooltip(t.higan.settings));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(
          [
            find.text(t.home.welcome),
            find.text(t.higan.appearance.toUpperCase()),
          ],
          [findsOneWidget, findsOneWidget],
        );
      });
  });
}
