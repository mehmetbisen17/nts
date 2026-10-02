import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nts/components/theming/dynamic_material_app.dart';
import 'package:nts/components/theming/nts_theme.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/home/browse.dart';
import 'package:nts/pages/home/home.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  group('Browse page folder navigation', () {
    setUp(() {
      FlavorConfig.setup();
      setupMockPathProvider();
      stows.sentryConsent.value = .granted;
      FileManager.init(shouldWatchRootDirectory: false);
      BrowsePage.overrideChildren = DirectoryChildren(
        const ['subfolder1', 'subfolder2'],
        const ['file1', 'file2', 'file3'],
      );
    });
    testWidgets('No back folder at root', (tester) async {
      await tester.pumpWidget(const _BrowseApp());
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
    testWidgets('Back folder present in subfolder', (tester) async {
      await tester.pumpWidget(const _BrowseApp(path: '/helloworld'));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
    testWidgets('Navigate back to root', (tester) async {
      await tester.pumpWidget(const _BrowseApp(path: '/helloworld'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
    testWidgets('Navigate back twice to root', (tester) async {
      // Tall enough for the folder tiles to sit below the header on screen.
      tester.view.physicalSize = Size(tester.view.physicalSize.width, 3000);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const _BrowseApp(path: '/helloworld'));
      await tester.pump();
      await tester.tap(find.text('subfolder1'));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });
}

class _BrowseApp extends StatelessWidget {
  const new({this.path});
  final String? path;
  @override
  Widget build(BuildContext context) {
    final theme = NtsTheme.createThemeFromSeed(Colors.yellow, .light, .android);
    final router = GoRouter(
      initialLocation: HomeRoutes.browseFilePath(path ?? ''),
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
    return TranslationProvider(
      child: ExplicitlyThemedApp(
        title: 'nts',
        router: router,
        themeMode: ThemeMode.light,
        theme: theme,
        darkTheme: theme,
      ),
    );
  }
}
