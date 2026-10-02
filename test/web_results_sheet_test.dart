import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/ai/web_results_sheet.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/ai_router.dart';
import 'package:nts/data/services/ai_actions.dart';
import 'package:nts/i18n/strings.g.dart';

import 'fake_ai_provider.dart';

/// The link sheet searches with the action's account, lists what it
/// found natively, and opens links outside the app (no web view).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<FakeAiProvider> ai;
  late List<Uri> launched;
  setUp(() {
    ai = FakeAiProvider.install();
    launched = [];
    WebResultsSheet.launch = (url) async {
      launched.add(url);
      return true;
    };
  });
  tearDown(() => AiRouter.debugProviders = null);

  final videos = [
    AiLink(
      title: 'Photosynthesis: light reactions',
      url: Uri.parse('https://www.youtube.com/watch?v=abc'),
      source: 'Khan Academy',
      thumbnail: Uri.parse('https://i.ytimg.com/vi/abc/mqdefault.jpg'),
    ),
    AiLink(
      title: 'The Calvin cycle',
      url: Uri.parse('https://www.youtube.com/watch?v=def'),
      source: 'Amoeba Sisters',
    ),
  ];

  Future<void> open(
    WidgetTester tester,
    AiSearchKind kind, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showWebResults(
                context,
                initialQuery: 'photosynthesis light reactions',
                kind: kind,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('video: Google finds them, a tap opens one outside', (
    tester,
  ) async {
    final [_, _, google] = ai;
    google.onSearch = (_, _) async => videos;
    await open(tester, .video);
    expect(google.searches.single, (
      'photosynthesis light reactions',
      AiSearchKind.video,
      'gemini-2.5-flash',
    ));
    expect(find.text('Photosynthesis: light reactions'), findsOneWidget);
    expect(find.text('KHAN ACADEMY · YOUTUBE.COM'), findsOneWidget);
    // Google's video list is YouTube's own search, not the model's
    expect(find.text(t.ai.web.foundWithYouTube.toUpperCase()), findsOneWidget);
    await tester.tap(find.text('The Calvin cycle'));
    await tester.pump();
    expect(launched, [videos[1].url]);
  });

  testWidgets('source: ChatGPT; the edited query is searched', (tester) async {
    final [chatgpt, _, _] = ai;
    chatgpt.onSearch = (query, _) async => [
      AiLink(
        title: 'Light-dependent reactions',
        url: Uri.parse(
          'https://en.wikipedia.org/wiki/Light-dependent_reactions',
        ),
      ),
    ];
    await open(tester, .source);
    expect(find.text('Light-dependent reactions'), findsOneWidget);
    expect(find.text('EN.WIKIPEDIA.ORG'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Calvin cycle');
    await tester.tap(find.text(t.ai.web.search));
    await tester.pumpAndSettle();
    expect(
      [for (final (query, _, _) in chatgpt.searches) query],
      ['photosynthesis light reactions', 'Calvin cycle'],
    );
  });

  testWidgets('nothing found', (tester) async {
    await open(tester, .source);
    expect(find.text(t.ai.web.noResults), findsOneWidget);
  });

  testWidgets('a chosen account that is signed out offers Settings', (
    tester,
  ) async {
    final [_, claude, google] = ai;
    AiRouter.routes[AiAction.video]!.value = 'claude:sonnet';
    claude.setStatus(AiAccountStatus.signedOut);
    await open(tester, .video);
    expect(find.text(t.ai.route.signedOut(provider: 'Claude')), findsOneWidget);
    expect(find.text(t.ai.openSettings), findsOneWidget);
    expect(google.searches, isEmpty, reason: 'no fallback when chosen');

    claude.setStatus(const AiAccountStatus(.signedIn)); // e.g. in Settings
    await tester.tap(find.text(t.ai.tryAgain));
    await tester.pumpAndSettle();
    expect(find.text(t.ai.web.noResults), findsOneWidget);
  });

  testWidgets('closing stops the search', (tester) async {
    final [_, _, google] = ai;
    google.onSearch = (_, _) => Completer<List<AiLink>>().future;
    await open(tester, .video, settle: false);
    expect(find.text(t.ai.searching), findsOneWidget);
    await tester.tap(find.byTooltip(t.ai.close));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(google.cancelled, hasLength(1));
  });
}
