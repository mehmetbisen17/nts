import 'package:flutter_test/flutter_test.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/ai_router.dart';
import 'package:nts/data/services/ai_actions.dart';
import 'package:nts/i18n/strings.g.dart';

import 'fake_ai_provider.dart';

void main() {
  tearDown(() => AiRouter.debugProviders = null);

  Matcher aiError(String code, [String? message]) => throwsA(
    isA<AiError>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.message, 'message', message ?? isNotEmpty),
  );

  test('Automatic tries the accounts in each action\'s order', () async {
    FakeAiProvider.install();
    Future<AiProviderId> who(AiAction action) async =>
        (await AiRouter.resolve(action)).$1.id;
    expect(await who(.explainExample), AiProviderId.chatgpt);
    expect(await who(.paragraph), AiProviderId.chatgpt);
    expect(await who(.graph), AiProviderId.chatgpt);
    expect(await who(.illustration), AiProviderId.claude);
    expect(await who(.video), AiProviderId.google);
    expect(await who(.source), AiProviderId.chatgpt);
  });

  test('Automatic skips signed-out accounts', () async {
    final [chatgpt, claude, google] = FakeAiProvider.install(chatgpt: false);
    expect((await AiRouter.resolve(.paragraph)).$1, claude);
    expect((await AiRouter.resolve(.source)).$1, claude);
    claude.setStatus(
      const AiAccountStatus(.unavailable, detail: 'Mac only'),
    ); // e.g. on iPad
    expect((await AiRouter.resolve(.paragraph)).$1, google);
    expect((await AiRouter.resolve(.illustration)).$1, google);
    google.setStatus(AiAccountStatus.signedOut);
    expect(AiRouter.anySignedIn, isFalse);
    await expectLater(
      AiRouter.resolve(.video),
      aiError(AiError.signedOut, t.ai.signInToUse),
    );
    expect(AiRouter.unavailableReason(.video), t.ai.signInToUse);
    chatgpt.setStatus(const AiAccountStatus(.signedIn));
    expect(AiRouter.anySignedIn, isTrue);
    expect((await AiRouter.resolve(.video)).$1, chatgpt);
  });

  test('Automatic picks an included text model', () async {
    final [chatgpt, claude, _] = FakeAiProvider.install();
    claude.modelList = const [
      AiModel('fable', 'Fable', mayCostExtra: true),
      AiModel('sonnet', 'Sonnet'),
    ];
    expect((await AiRouter.resolve(.paragraph)).$2.id, 'gpt-5.4');
    expect((await AiRouter.resolve(.illustration)).$2.id, 'sonnet');

    // Pictures: a picture model when the account has one (paid ChatGPT)
    claude.setStatus(AiAccountStatus.signedOut);
    expect((await AiRouter.resolve(.illustration)).$2.id, 'gpt-image-2');
    expect((await AiRouter.resolve(.source)).$2.id, 'gpt-5.4');
    chatgpt.modelList = const [AiModel('gpt-5.4', 'GPT-5.4')]; // Free
    expect((await AiRouter.resolve(.illustration)).$2.id, 'gpt-5.4');

    chatgpt.modelList = const [];
    await expectLater(
      AiRouter.resolve(.paragraph),
      aiError(AiError.modelUnavailable),
    );
  });

  test('a chosen account is used, and never swapped for another', () async {
    final [chatgpt, claude, _] = FakeAiProvider.install();
    AiRouter.routes[AiAction.paragraph]!.value = AiRouter.encode(
      .claude,
      'opus',
    );
    final (provider, model) = await AiRouter.resolve(.paragraph);
    expect(provider, claude);
    expect((model.id, model.label), ('opus', 'Opus'));
    expect(AiRouter.unavailableReason(.paragraph), isNull);
    expect(AiRouter.providerFor(.paragraph), claude);

    claude.setStatus(AiAccountStatus.signedOut);
    final signedOut = t.ai.route.signedOut(provider: 'Claude');
    expect(AiRouter.unavailableReason(.paragraph), signedOut);
    await expectLater(
      AiRouter.resolve(.paragraph),
      aiError(AiError.signedOut, signedOut),
    );
    // Only Automatic falls back
    expect((await AiRouter.resolve(.explainExample)).$1, chatgpt);

    claude.setStatus(
      const AiAccountStatus(.unavailable, detail: 'Not on iPad.'),
    );
    await expectLater(
      AiRouter.resolve(.paragraph),
      aiError(AiError.notAvailable, 'Not on iPad.'),
    );

    // What's wrong, not "signed out": signing in again won't help
    const update = 'Couldn\'t read Claude Code\'s sign-in. Update Claude Code.';
    claude.setStatus(const AiAccountStatus(.error, detail: update));
    expect(AiRouter.unavailableReason(.paragraph), update);
    await expectLater(
      AiRouter.resolve(.paragraph),
      aiError(AiError.signedOut, update),
    );
  });

  test('a chosen model that has gone is still asked for', () async {
    FakeAiProvider.install();
    AiRouter.routes[AiAction.graph]!.value = 'chatgpt:gpt-4o';
    final (_, model) = await AiRouter.resolve(.graph);
    expect((model.id, model.label), ('gpt-4o', 'gpt-4o'));
  });

  test('routes', () {
    expect(AiRouter.parse('auto'), isNull);
    expect(AiRouter.parse('chatgpt:gpt-5.4'), (
      provider: AiProviderId.chatgpt,
      model: 'gpt-5.4',
    ));
    expect(AiRouter.parse('google:models/gemini:x')?.model, 'models/gemini:x');
    expect(AiRouter.parse('nobody:x'), isNull);
    expect(AiRouter.parse('claude:'), isNull);
    expect(AiRouter.encode(.claude, 'sonnet'), 'claude:sonnet');
    expect(AiRouter.routes.values.map((route) => route.key).toSet(), {
      for (final action in AiAction.values) 'ai.route.${action.name}',
    });
  });

  test('short names', () {
    final [chatgpt, _, google] = FakeAiProvider.install();
    expect(AiRouter.shortName(chatgpt), 'ChatGPT');
    expect(AiRouter.shortName(google), 'Google');
  });
}
