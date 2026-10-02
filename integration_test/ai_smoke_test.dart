// Runs the AI actions for real inside the macOS app, through the owner's
// Claude Code (signed in to their Claude plan) via the router's Automatic
// route, plus the Vision handwriting reader. Not part of `flutter test`:
//   flutter build macos --debug -t integration_test/ai_smoke_test.dart
//   open --stdout out.log --stderr out.log build/macos/Build/Products/Debug/nts.app
// Wait for `AI_SMOKE_TIMINGS` in out.log, then quit the app. Files go to
// the folder printed as `AI_SMOKE_OUT`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nts/components/ai/ai_chart.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/ai_router.dart';
import 'package:nts/data/ai/providers/claude_code_provider.dart';
import 'package:nts/data/services/ai_actions.dart';
import 'package:nts/data/services/plot_spec.dart';

final _markdown = RegExp(r'\*\*|__|^\s*(#|[-*•] )', multiLine: true);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final timings = <String, int>{};
  final out = Directory('${Directory.systemTemp.path}/nts_ai_real')
    ..createSync(recursive: true);
  void save(String name, Object data) {
    final file = File('${out.path}/aiacc_real_$name');
    data is String
        ? file.writeAsStringSync(data)
        : file.writeAsBytesSync(data as List<int>);
  }

  Future<T> timed<T>(String name, Future<T> Function() run) async {
    final watch = Stopwatch()..start();
    final result = await run();
    timings[name] = watch.elapsedMilliseconds;
    final shown = switch (result) {
      AiTextResult(:final reading, :final body) => '$reading | $body',
      (final String reading, Uint8List _, final String extension) =>
        '$reading $extension',
      _ => '$result',
    };
    debugPrint('AI_SMOKE $name ${watch.elapsedMilliseconds} ms: $shown');
    return result;
  }

  tearDownAll(() {
    save(
      'timings.txt',
      timings.entries.map((e) => '${e.key}: ${e.value} ms').join('\n'),
    );
    debugPrint('AI_SMOKE_OUT ${out.path}');
    debugPrint('AI_SMOKE_TIMINGS $timings');
  });

  testWidgets('AI actions through Claude Code on this Mac', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));

    await tester.runAsync(() async {
      // Only Claude, so Automatic picks it for every action
      final claude = ClaudeCodeProvider();
      AiRouter.debugProviders = [claude];
      await timed('status', claude.refreshStatus);
      expect(
        claude.status.value.isSignedIn,
        isTrue,
        reason: '${claude.status.value.detail}',
      );

      Future<(AiProvider, AiModel)> route(AiAction action) async {
        final (provider, model) = await AiRouter.resolve(action);
        expect(provider, same(claude));
        debugPrint('AI_SMOKE route ${action.name}: ${model.id}');
        return (provider, model);
      }

      final notes = AiInput(
        png: await _writing(
          'Photosyntesis:\nlight rxns in thylakoid\ncalvin cycle in stroma',
        ),
      );
      save('input_notes.png', notes.png);

      final (provider, model) = await route(.paragraph);
      var partials = 0;
      final paragraph = await timed(
        'paragraph',
        () => AiActions.explain(
          AiActions.newId(),
          notes,
          action: .paragraph,
          provider: provider,
          model: model,
          onPartial: (_) => partials++,
        ),
      );
      save('paragraph.txt', '${paragraph.reading}\n\n${paragraph.body}');
      // What it read comes first, apart from the answer
      expect(paragraph.reading.toLowerCase(), contains('calvin'));
      expect(paragraph.body, isNot(startsWith('You wrote')));
      final body = paragraph.body;
      expect(body.toLowerCase(), contains('calvin'), reason: body);
      expect(_markdown.hasMatch(body), isFalse, reason: body);
      debugPrint('AI_SMOKE paragraph partials: $partials');

      final formula = AiInput(png: await _writing('y = x^2 - 4'));
      save('input_formula.png', formula.png);
      final (graphProvider, graphModel) = await route(.graph);
      final (chart, formulaReading) = await timed(
        'graph formula',
        () => AiActions.graph(
          AiActions.newId(),
          formula,
          provider: graphProvider,
          model: graphModel,
        ),
      );
      expect(chart, isA<FunctionPlot>());
      expect(formulaReading, contains('x'));
      save('chart.png', await AiChart.renderPng(chart));

      final sales = AiInput(
        png: await _writing('Sales\nMon 12\nTue 18\nWed 9'),
      );
      final (data, dataReading) = await timed(
        'graph data',
        () => AiActions.graph(
          AiActions.newId(),
          sales,
          provider: graphProvider,
          model: graphModel,
        ),
      );
      expect(data, isA<DataPlot>());
      expect(dataReading, isNotEmpty);
      expect((data as DataPlot).points, hasLength(3));
      save('chart_data.png', await AiChart.renderPng(data));

      final (drawProvider, drawModel) = await route(.illustration);
      expect(drawModel.isImageModel, isFalse); // Claude draws lines
      final (drawReading, png, extension) = await timed(
        'illustration',
        () => AiActions.illustrate(
          AiActions.newId(),
          notes,
          provider: drawProvider,
          model: drawModel,
        ),
      );
      expect(extension, '.png');
      expect(drawReading, isNotEmpty);
      save('illustration.png', png);

      final (searchProvider, searchModel) = await route(.source);
      final id = AiActions.newId();
      final (queryReading, query) = await timed(
        'searchQuery',
        () => AiActions.searchQuery(
          id,
          notes,
          provider: searchProvider,
          model: searchModel,
        ),
      );
      expect(query.split(' ').length, inInclusiveRange(2, 8), reason: query);
      expect(queryReading, isNotEmpty);
      final links = await timed(
        'source search',
        () => AiActions.search(
          id,
          query,
          kind: .source,
          provider: searchProvider,
          model: searchModel,
        ),
      );
      save(
        'sources.txt',
        [
          'query: $query',
          for (final link in links)
            '${link.title} | ${link.source} | ${link.url}',
        ].join('\n'),
      );
      expect(links, isNotEmpty);

      final text = await timed('handwriting OCR', () async {
        final png = await _writing('light reactions\ncalvin cycle');
        return const MethodChannel('nts/handwriting')
            .invokeMethod<String>('recognize', {
              'png': png,
              'languages': ['en-US'],
            });
      });
      expect(text!.toLowerCase(), contains('calvin'));
      AiRouter.debugProviders = null;
    });
  }, timeout: const Timeout(Duration(minutes: 8)));
}

/// [text] in dark ink on white, as a PNG, standing in for handwriting.
Future<Uint8List> _writing(String text) async {
  final builder =
      ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 64, fontStyle: .italic))
        ..pushStyle(ui.TextStyle(color: const Color(0xFF222222)))
        ..addText(text);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 900));
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawColor(const Color(0xFFFFFFFF), .src)
    ..drawParagraph(paragraph, const Offset(40, 40));
  final image = await recorder.endRecording().toImage(
    1000,
    paragraph.height.ceil() + 80,
  );
  final bytes = await image.toByteData(format: .png);
  return bytes!.buffer.asUint8List();
}
