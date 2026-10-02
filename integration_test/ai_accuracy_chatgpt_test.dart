// A few real ChatGPT calls on messy handwriting, inside the macOS app so it
// uses its own ChatGPT sign-in (Keychain). Not part of `flutter test`:
//   flutter build macos --debug -t integration_test/ai_accuracy_chatgpt_test.dart
//   open -W --stdout out.log --stderr out.log build/macos/Build/Products/Debug/nts.app
// The pictures come from test/ai_accuracy_eval_test.dart (NTS_EVAL=render) in
// NTS_EVAL_DIR; answers go there too, under chatgpt/. Then rebuild the app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/ai_router.dart';
import 'package:nts/data/ai/providers/chatgpt_provider.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/services/ai_actions.dart';
import 'package:nts/data/services/plot_expression.dart';
import 'package:nts/data/services/plot_spec.dart';

final _dir =
    Platform.environment['NTS_EVAL_DIR'] ??
    '/private/tmp/claude-501/-Users-mehmetbisen-Desktop-saber/'
        'e21e6fbf-1b17-49c8-84d9-1e9fe570551b/scratchpad/eval';

/// Six calls at most: (picture, action).
const _cases = [
  ('crop_owner_tight', AiAction.explainExample),
  ('crop_owner_tight', AiAction.paragraph),
  ('samples/s1_add', AiAction.explainExample),
  ('samples/s1_add', AiAction.paragraph),
  ('samples/s6_linear', AiAction.explainExample),
  ('samples/s6_linear', AiAction.graph),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Stows.markAsOnMainIsolate(); // else the sign-in isn't read from Keychain

  testWidgets('ChatGPT reads messy handwriting', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.runAsync(() async {
      final out = Directory('$_dir/chatgpt')..createSync(recursive: true);
      void log(String line) {
        debugPrint('AI_ACC $line');
        File('${out.path}/log.txt').writeAsStringSync('$line\n', mode: .append);
      }

      final chatgpt = ChatGptProvider(stows.aiChatgptTokens);
      try {
        // A Keychain prompt would wait here
        await chatgpt.refreshStatus().timeout(const Duration(seconds: 60));
      } on TimeoutException {
        log('KEYCHAIN_BLOCKED: no sign-in after 60 s');
        return;
      }
      final status = chatgpt.status.value;
      log('status ${status.state.name} ${status.label ?? ''}');
      if (!status.isSignedIn) return;

      for (final (picture, action) in _cases) {
        final route = stows.aiRoutes[action.name]!;
        await route.waitUntilRead();
        final saved = AiRouter.parse(route.value);
        final model = saved?.provider == .chatgpt
            ? AiModel(saved!.model, saved.model)
            : await AiRouter.defaultModel(chatgpt, action);
        final provider = _Recording(chatgpt);
        final input = AiInput(
          png: File('$_dir/$picture.png').readAsBytesSync(),
        );
        final name = '${picture.split('/').last}.${action.name}';
        final result = <String, Object?>{
          'case': name,
          'route': route.value,
          'model': model.id,
        };
        final watch = Stopwatch()..start();
        try {
          if (action == .graph) {
            final (spec, reading) = await AiActions.graph(
              AiActions.newId(),
              input,
              provider: provider,
              model: model,
            );
            result['reading'] = reading;
            if (spec is FunctionPlot) {
              final f = parseExpression(spec.expression);
              result['expression'] = spec.expression;
              result['f(-1,0,1,2)'] = [f(-1), f(0), f(1), f(2)];
            } else {
              result['plot'] = spec.runtimeType.toString();
            }
          } else {
            final answer = await AiActions.explain(
              AiActions.newId(),
              input,
              action: action,
              provider: provider,
              model: model,
              onPartial: (_) =>
                  result['firstPartialMs'] ??= watch.elapsedMilliseconds,
            );
            result['reading'] = answer.reading;
            result['body'] = answer.body;
          }
        } on AiError catch (e) {
          result['error'] = '${e.code}: ${e.message}';
        }
        result['ms'] = watch.elapsedMilliseconds;
        result['raw'] = provider.raw;
        File(
          '${out.path}/$name.json',
        ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
        log(
          '$name ${model.id} ${result['ms']} ms: ${result['reading']} | '
          '${result['error'] ?? result['body'] ?? result['expression']}',
        );
      }
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// [inner], keeping what the model really said.
class _Recording implements AiProvider {
  new(this.inner);
  final AiProvider inner;
  final raw = <String>[];

  @override
  AiProviderId get id => inner.id;
  @override
  String get displayName => inner.displayName;
  @override
  ValueListenable<AiAccountStatus> get status => inner.status;
  @override
  Future<void> refreshStatus() => inner.refreshStatus();
  @override
  Future<void> signIn(BuildContext context) => inner.signIn(context);
  @override
  Future<void> signOut() => inner.signOut();
  @override
  Future<List<AiModel>> models() => inner.models();
  @override
  Future<String> respond(
    String requestId,
    AiRequest req, {
    required String model,
    void Function(String partial)? onPartial,
  }) async {
    final text = await inner.respond(
      requestId,
      req,
      model: model,
      onPartial: onPartial,
    );
    raw.add(text);
    return text;
  }

  @override
  Future<Uint8List>? generateImage(
    String requestId,
    String prompt, {
    required String model,
  }) => inner.generateImage(requestId, prompt, model: model);
  @override
  Future<List<AiLink>> search(
    String requestId,
    String query, {
    required AiSearchKind kind,
    required String model,
  }) => inner.search(requestId, query, kind: kind, model: model);
  @override
  Future<void> cancel(String requestId) => inner.cancel(requestId);
}
