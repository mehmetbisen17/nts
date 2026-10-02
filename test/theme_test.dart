import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nts/components/theming/dynamic_material_app.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/i18n/strings.g.dart';

void main() {
  group('Theme', () {
    setUpAll(() {
      FlavorConfig.setup();
    });

    for (final platform in TargetPlatform.values)
      for (final hyperlegible in const [false, true])
        for (final hasAccent in const [false, true])
          _testTheme(
            platform: platform,
            hyperlegible: hyperlegible,
            hasAccent: hasAccent,
          );
  });
}

void _testTheme({
  required TargetPlatform platform,
  required bool hyperlegible,
  required bool hasAccent,
}) {
  final repr =
      '${platform.name}_'
      '${hyperlegible ? 'hyperlegible' : 'inter'}_'
      '${hasAccent ? 'with-accent' : 'no-accent'}';
  testWidgets(repr, (tester) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const Text('hi'))],
    );

    stows.platform.value = platform;
    stows.hyperlegibleFont.value = hyperlegible;
    stows.accentColor.value = hasAccent ? const Color(0xFF00FF00) : null;
    addTearDown(() {
      stows.platform.value = stows.platform.defaultValue;
      stows.hyperlegibleFont.value = stows.hyperlegibleFont.defaultValue;
      stows.accentColor.value = stows.accentColor.defaultValue;
    });

    await tester.pumpWidget(
      TranslationProvider(
        child: DynamicMaterialApp(title: 'title', router: router),
      ),
    );

    final app = tester.widget<ExplicitlyThemedApp>(
      find.byType(ExplicitlyThemedApp),
    );
    for (final theme in [app.theme, ?app.darkTheme]) {
      expect(theme.platform, platform);

      // Higan ignores accent colors: the one red is always primary.
      expect(theme.colorScheme.primary, HiganColors.night.higan);
      expect(theme.extension<HiganColors>(), isNotNull);

      final expectedFontFamily = hyperlegible
          ? 'AtkinsonHyperlegibleNext'
          : 'Geist';
      for (final font in _extractFonts(theme.textTheme)) {
        expect(font, expectedFontFamily);
      }
    }
    expect(app.theme.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);
  });
}

List<String?> _extractFonts(TextTheme textTheme) {
  return [textTheme.displayLarge?.fontFamily, textTheme.bodyLarge?.fontFamily];
}
