import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/services/ai_actions.dart';
import 'package:nts/data/services/plot_spec.dart';
import 'package:nts/i18n/strings.g.dart';

import 'fake_ai_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAiProvider ai;
  const model = AiModel('gpt-5.4', 'GPT-5.4');
  setUp(() => ai = FakeAiProvider(.chatgpt));

  Matcher aiError(String code, [String? message]) => throwsA(
    isA<AiError>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.message, 'message', message ?? anything),
  );

  group('explain', () {
    test('sends the circle, asks for an example, cleans the answer', () async {
      ai.onRespond = (_, onPartial) async {
        onPartial!('You wr');
        onPartial('You wrote: F = ma\n\n**Force** is');
        return '**You wrote:** F = ma\n\n'
            '**Force** is mass times acceleration.\n'
            '- Pushing a cart: 2 kg × 3 m/s² = 6 N';
      };
      final partials = <String>[];
      final answer = await AiActions.explain(
        AiActions.newId(),
        testInput(),
        action: .explainExample,
        provider: ai,
        model: model,
        onPartial: partials.add,
      );
      expect(answer.reading, 'F = ma');
      expect(
        answer.body,
        'Force is mass times acceleration.\n'
        'Pushing a cart: 2 kg × 3 m/s² = 6 N',
      );
      // Never the "You wrote:" line, even while it's coming
      expect(partials, ['', 'Force is']);
      final (_, request, asked) = ai.requests.single;
      expect(asked, 'gpt-5.4');
      expect(request.imagePng, testPng);
      expect(request.prompt, 'Explain this better, then give one example.');
      expect(request.jsonSchema, isNull);
      expect(request.webSearch, isFalse);
      expect(
        request.instructions,
        contains('exactly what the student selected on their page'),
      );
      expect(request.instructions, contains('messy handwriting'));
      expect(request.instructions, contains('Never call the notes a joke'));
      expect(request.instructions, contains('Start with "You wrote: "'));
      expect(request.instructions, contains('check the arithmetic'));
      expect(request.instructions, contains('no markdown'));
      expect(
        request.instructions,
        contains('the language the notes are written in'),
      );
      expect(
        request.instructions,
        endsWith('At most 120 words after the first line.'),
      );
    });

    test('typed text in the circle goes along', () async {
      await AiActions.explain(
        AiActions.newId(),
        testInput('F = ma'),
        action: .paragraph,
        provider: ai,
        model: model,
      );
      expect(
        ai.requests.single.$2.prompt,
        'TYPED TEXT IN THE CIRCLED PART:\nF = ma\n\n'
        'What are these notes saying?',
      );
    });

    test('no made-up links', () async {
      ai.onRespond = (_, _) async =>
          'Forces move carts. See https://www.khan-academy.org/force and '
          '[this](http://x.org) or www.physics.example.';
      final answer = await AiActions.explain(
        AiActions.newId(),
        testInput(),
        action: .paragraph,
        provider: ai,
        model: model,
      );
      expect(answer.body, isNot(contains('http')));
      expect(answer.body, isNot(contains('www')));
      expect(answer.body, contains('this'));
      expect(answer.reading, '');
    });

    test('an empty answer fails; errors go through', () async {
      ai.onRespond = (_, _) async => '  ';
      await expectLater(
        AiActions.explain(
          AiActions.newId(),
          testInput(),
          action: .paragraph,
          provider: ai,
          model: model,
        ),
        aiError(AiError.failed, t.ai.failed),
      );
      ai.onRespond = (_, _) async =>
          throw const AiError(AiError.limit, 'ChatGPT plan limit reached.');
      await expectLater(
        AiActions.explain(
          AiActions.newId(),
          testInput(),
          action: .paragraph,
          provider: ai,
          model: model,
        ),
        aiError(AiError.limit, 'ChatGPT plan limit reached.'),
      );
    });
  });

  test('cancel stops running and later calls', () async {
    final id = AiActions.newId();
    ai.onRespond = (_, _) async {
      await AiActions.cancel(id);
      return 'Too late.';
    };
    final running = AiActions.explain(
      id,
      testInput(),
      action: .paragraph,
      provider: ai,
      model: model,
    );
    await expectLater(running, aiError(AiError.cancelled));
    expect(ai.cancelled, [id]);
    await expectLater(
      AiActions.searchQuery(id, testInput(), provider: ai, model: model),
      aiError(AiError.cancelled),
    );
    expect(ai.requests, hasLength(1));
  });

  test('stripMarkdown', () {
    expect(
      AiActions.stripMarkdown(
        '## Title\n**bold** and __this__\n* one\n- two\n• three\n-5 stays',
      ),
      'Title\nbold and this\none\ntwo\nthree\n-5 stays',
    );
  });

  group('graph', () {
    test('a formula, with the chart schema', () async {
      ai.onRespond = (_, _) async =>
          '```json\n{"reading":"y = 3x","kind":"function","title":"f",'
          '"expression":"3*x","xMin":-2,"xMax":2,"xLabel":"x","yLabel":"y",'
          '"points":[]}\n```';
      final (plot, reading) = await AiActions.graph(
        AiActions.newId(),
        testInput(),
        provider: ai,
        model: model,
      );
      expect(reading, 'y = 3x');
      expect((plot as FunctionPlot).expression, '3*x');
      expect(plot.xMax, 2);
      final request = ai.requests.single.$2;
      expect(request.jsonSchema, AiActions.chartSchema);
      expect(request.imagePng, testPng);
      expect(request.instructions, contains('Never make up data.'));
      expect(request.instructions, contains('messy handwriting'));
      expect(request.instructions, contains('"reading"'));
    });

    test('numbers', () {
      final plot = AiActions.plotFromJson({
        'kind': 'bar',
        'title': 'Fruit',
        'expression': '',
        'xMin': 0,
        'xMax': 0,
        'xLabel': '',
        'yLabel': '',
        'points': [
          for (var i = 0; i < 30; i++) {'label': 'n$i', 'y': i},
        ],
      });
      expect((plot as DataPlot).kind, DataPlotKind.bar);
      expect(plot.points, hasLength(AiActions.maxPoints));
    });

    test('nothing to graph, or nothing drawable', () async {
      expect(
        () => AiActions.plotFromJson({'kind': 'none'}),
        throwsA(
          isA<AiError>().having(
            (e) => e.message,
            'message',
            t.ai.nothingToGraph,
          ),
        ),
      );
      expect(
        () => AiActions.plotFromJson({
          'kind': 'line',
          'title': '',
          'points': [
            {'label': 'a', 'y': 1},
          ],
        }),
        throwsFormatException,
      );
      for (final answer in [
        'Sorry, I can only chart numbers.',
        '{"kind":"function","title":"","expression":"x +","xMin":0,'
            '"xMax":1}',
      ]) {
        ai.onRespond = (_, _) async => answer;
        await expectLater(
          AiActions.graph(
            AiActions.newId(),
            testInput(),
            provider: ai,
            model: model,
          ),
          aiError(AiError.failed, t.ai.couldNotGraph),
        );
      }
    });

    test('a failure keeps what it read, to fix', () async {
      ai.onRespond = (_, _) async =>
          '{"reading":"y = 2x + |","kind":"none","title":"","expression":"",'
          '"xMin":0,"xMax":0,"xLabel":"","yLabel":"","points":[]}';
      await expectLater(
        AiActions.graph(
          AiActions.newId(),
          testInput(),
          provider: ai,
          model: model,
        ),
        throwsA(
          isA<AiReadingError>()
              .having((e) => e.message, 'message', t.ai.nothingToGraph)
              .having((e) => e.reading, 'reading', 'y = 2x + |'),
        ),
      );
    });

    test('the schema is flat and strict', () {
      final schema = jsonDecode(AiActions.chartSchema) as Map<String, dynamic>;
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], properties.keys.toList());
      // Read before charting
      expect(properties.keys.first, 'reading');
      expect(schema.containsKey(r'$defs'), isFalse);
    });
  });

  group('illustrate', () {
    const svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">'
        '<circle cx="256" cy="256" r="120" fill="none" stroke="#2B2A28" '
        'stroke-width="3"/></svg>';

    test('a text model draws an SVG line drawing, as a PNG', () async {
      ai.onRespond = (_, _) async =>
          'You wrote: a circle\n\nHere it is:\n```svg\n$svg\n```';
      final (reading, bytes, extension) = await AiActions.illustrate(
        AiActions.newId(),
        testInput(),
        provider: ai,
        model: model,
      );
      expect(reading, 'a circle');
      expect(extension, '.png');
      final image = (await (await instantiateImageCodec(
        bytes,
      )).getNextFrame()).image;
      expect((image.width, image.height), (1024, 1024));
      expect(ai.requests.single.$2.instructions, AiActions.svgInstructions);
      expect(AiActions.svgInstructions, contains('You wrote: '));
      expect(ai.images, isEmpty);
    });

    test('an unsafe SVG is refused', () async {
      ai.onRespond = (_, _) async =>
          '<svg viewBox="0 0 10 10"><script>alert(1)</script></svg>';
      await expectLater(
        AiActions.illustrate(
          AiActions.newId(),
          testInput(),
          provider: ai,
          model: model,
        ),
        aiError(AiError.failed, t.ai.couldNotDraw),
      );
    });

    test('a drawing that breaks the renderer fails, never hangs', () async {
      // 10^9 nested <use>s: vector_graphics_compiler throws a StateError
      final nested = StringBuffer(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">'
        '<defs><path id="l0" d="M0 0L1 1" stroke="#000"/>',
      );
      for (var i = 1; i <= 9; i++) {
        nested.write('<g id="l$i">${'<use href="#l${i - 1}"/>' * 10}</g>');
      }
      nested.write('</defs><use href="#l9"/></svg>');
      ai.onRespond = (_, _) async => '$nested';
      await expectLater(
        AiActions.illustrate(
          AiActions.newId(),
          testInput(),
          provider: ai,
          model: model,
        ),
        aiError(AiError.failed, t.ai.couldNotDraw),
      );

      // An infinite size is drawn at 512 square
      final png = await AiActions.svgToPng(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1e400 1">'
        '<path d="M0 0L1 1" stroke="#000"/></svg>',
      );
      final image = (await (await instantiateImageCodec(
        png,
      )).getNextFrame()).image;
      expect((image.width, image.height), (1024, 1024));
    });

    test('a picture model draws a description', () async {
      ai.onRespond = (_, _) async =>
          'You wrote: d = |a - b|\n\nTwo dots joined by a ruler.\nMore.';
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      ai.onImage = (_) async => jpeg;
      final (reading, bytes, extension) = await AiActions.illustrate(
        AiActions.newId(),
        testInput(),
        provider: ai,
        model: const AiModel('gpt-image-2', 'GPT Image 2', isImageModel: true),
      );
      expect((reading, bytes, extension), ('d = |a - b|', jpeg, '.jpg'));
      // Described by a text model, which can see the circle
      expect(ai.requests.single.$3, 'gpt-5.4');
      expect(ai.requests.single.$2.imagePng, testPng);
      final (prompt, drawer) = ai.images.single;
      expect(drawer, 'gpt-image-2');
      expect(prompt, startsWith('Two dots joined by a ruler. '));
      expect(prompt, contains('No text.'));
    });

    test("a picture model that can't draw falls back to lines", () async {
      var asked = 0;
      ai.onRespond = (_, _) async => asked++ == 0 ? 'A leaf.' : svg;
      final (_, _, extension) = await AiActions.illustrate(
        AiActions.newId(),
        testInput(),
        provider: ai,
        model: const AiModel('gpt-image-2', 'GPT Image 2', isImageModel: true),
      );
      expect(extension, '.png');
      expect(ai.requests.last.$2.instructions, AiActions.svgInstructions);
    });
  });

  test('sanitizeSvg', () {
    const ok =
        '<svg viewBox="0 0 10 10"><defs><path id="p" d="M0 0L9 9"/></defs>'
        '<use href="#p" stroke="url(#g)"/></svg>';
    expect(AiActions.sanitizeSvg('```svg\n$ok\n```'), ok);
    expect(
      AiActions.sanitizeSvg('<SVG viewBox="0 0 1 1"><!-- a <b> --></SVG>'),
      '<SVG viewBox="0 0 1 1"></SVG>',
    );
    // What's before the drawing (e.g. entities) is dropped
    expect(
      AiActions.sanitizeSvg('<!DOCTYPE svg [<!ENTITY x "y">]><svg>&x;</svg>'),
      '<svg>&x;</svg>',
    );
    for (final bad in [
      'no drawing here',
      '<svg><script>alert(1)</script></svg>',
      '<svg><foreignObject><div/></foreignObject></svg>',
      '<svg><image href="data:image/png;base64,AAAA"/></svg>',
      '<svg><circle onload="alert(1)" r="1"/></svg>',
      '<svg><circle ONCLICK = "x" r="1"/></svg>',
      '<svg><use xlink:href="https://evil.example/x.svg#a"/></svg>',
      '<svg><use href=" http://evil.example/a"/></svg>',
      '<svg><rect fill="url(https://evil.example/p)"/></svg>',
      '<svg><a href="#x"><circle r="1"/></a></svg>',
      '<svg><!DOCTYPE x></svg>',
      '<svg><?xml-stylesheet href="x"?></svg>',
      '<svg><style>@import "x.css";</style></svg>',
      '<svg><path d="javascript:1"/></svg>',
      '<svg viewBox="0 0 1 1">${' ' * AiActions.maxSvgLength}</svg>',
    ]) {
      expect(AiActions.sanitizeSvg(bad), isNull, reason: bad);
    }
  });

  group('searchQuery', () {
    test('asks for one line and cleans the answer', () async {
      ai.onRespond = (_, _) async =>
          'QUERY: "Photosynthesis light light reactions."\nmore';
      expect(
        await AiActions.searchQuery(
          AiActions.newId(),
          testInput(),
          provider: ai,
          model: model,
        ),
        ('', 'Photosynthesis light reactions'),
      );
      final request = ai.requests.single.$2;
      expect(request.prompt, 'What would you search for?');
      expect(request.instructions, isNot(contains('photosyn')));
      expect(request.instructions, contains('QUERY: <3 to 8 words'));
      expect(request.imagePng, testPng);
      expect(request.webSearch, isFalse);
    });

    test('falls back to the typed text', () async {
      ai.onRespond = (_, _) async =>
          throw const AiError(AiError.limit, 'Limit.');
      expect(
        await AiActions.searchQuery(
          AiActions.newId(),
          testInput('\n  Treaty of Versailles.\n1919'),
          provider: ai,
          model: model,
        ),
        ('', 'Treaty of Versailles'),
      );
      // Only handwriting: nothing to fall back to
      await expectLater(
        AiActions.searchQuery(
          AiActions.newId(),
          testInput(),
          provider: ai,
          model: model,
        ),
        aiError(AiError.limit, 'Limit.'),
      );
    });
  });

  test('search keeps only web links', () async {
    ai.onSearch = (_, _) async => [
      AiLink(
        title: 'Light reactions',
        url: Uri.parse('https://www.youtube.com/watch?v=1'),
        source: 'Khan Academy',
        thumbnail: Uri.parse('https://i.ytimg.com/vi/1/mqdefault.jpg'),
      ),
      AiLink(title: '', url: Uri.parse('http://example.org/a')),
      AiLink(title: 'Mail', url: Uri.parse('mailto:a@b.c')),
      AiLink(title: 'Script', url: Uri.parse('javascript:alert(1)')),
      AiLink(
        title: 'File',
        url: Uri.parse('https://example.org/b'),
        thumbnail: Uri.parse('file:///etc/passwd'),
      ),
    ];
    final links = await AiActions.search(
      AiActions.newId(),
      'photosynthesis',
      kind: .video,
      provider: ai,
      model: model,
    );
    expect(ai.searches.single, (
      'photosynthesis',
      AiSearchKind.video,
      'gpt-5.4',
    ));
    expect(
      [for (final link in links) link.title],
      ['Light reactions', 'example.org', 'File'],
    );
    expect(links.first.thumbnail, isNotNull);
    expect(links.last.thumbnail, isNull);
  });

  test('cleanQuery', () {
    expect(
      AiActions.cleanQuery('“Newton’s second law”?'),
      'Newton’s second law',
    );
    expect(AiActions.cleanQuery("'calvin cycle'."), 'calvin cycle');
    expect(
      AiActions.cleanQuery('one two three four five six seven eight nine'),
      'one two three four five six seven eight',
    );
    expect(AiActions.cleanQuery('cell Cell cell division'), 'cell division');
    expect(AiActions.cleanQuery('query: 1 + 1 = 2'), '1 + 1 = 2');
    expect(
      AiActions.cleanQuery('addition one plus one'),
      'addition one plus one',
    );
    expect(AiActions.cleanQuery(''), '');
  });

  group('reading', () {
    test('AiReading.split', () {
      for (final (answer, reading, body) in [
        ('You wrote: 1 + 1 = 2\n\nAddition.', '1 + 1 = 2', 'Addition.'),
        ('**You wrote:** 1 + 1 = 2\n\nAddition.', '1 + 1 = 2', 'Addition.'),
        ('**You wrote: 1 + 1 = 2**\n\nAddition.', '1 + 1 = 2', 'Addition.'),
        ('you WROTE: "x = 3"\n\nSo x is 3.', 'x = 3', 'So x is 3.'),
        ('  “You wrote: y = 2x”\n\nA line.', 'y = 2x', 'A line.'),
        ('I read: f\'(x) = 2x\n\nThe slope.', "f'(x) = 2x", 'The slope.'),
        ("You wrote: '3x = 9'\n\nx is 3.", '3x = 9', 'x is 3.'),
        (
          'You drew: a right triangle\n\nIts sides.',
          'a right triangle',
          'Its sides.',
        ),
        // Notes over two lines: all of them, up to the blank line
        (
          'You wrote: |x| + 2 = 5\nx = 3, x = -3\n\nThis shows',
          '|x| + 2 = 5; x = 3, x = -3',
          'This shows',
        ),
        ('You wrote: x\nQUERY: lines', 'x', 'QUERY: lines'),
        (
          'You wrote: a circle\n```svg\n<svg/>\n```',
          'a circle',
          '```svg\n<svg/>\n```',
        ),
        // What's said before it goes
        (
          'Sure! Here is what I read.\nYou wrote: 1 + 1 = 2\n\nAddition.',
          '1 + 1 = 2',
          'Addition.',
        ),
        ('You wrote:\n\n  E = mc^2\n\nEnergy.', 'E = mc^2', 'Energy.'),
        ('You wrote: ?\nI can\'t read this.', '?', "I can't read this."),
        ('You wrote: `a² + b² = c²`', 'a² + b² = c²', ''),
        (
          'Addition means putting together.',
          '',
          'Addition means putting together.',
        ),
        ('A.\nB.\nC.\nYou wrote: 1', '', 'A.\nB.\nC.\nYou wrote: 1'),
        // A model that skips the blank line keeps its answer
        (
          'You wrote: 1 + 1 = 2\nThis is addition.\nFor example, two apples.',
          '1 + 1 = 2',
          'This is addition.\nFor example, two apples.',
        ),
        (
          'You wrote: a = b\nc = d\n\nTwo equations.',
          'a = b; c = d',
          'Two equations.',
        ),
        ('', '', ''),
      ]) {
        expect(AiReading.split(answer), (reading, body), reason: answer);
      }
    });

    test('partialBody hides the reading line while it comes', () {
      for (final (partial, body) in [
        ('Y', ''),
        ('**You wro', ''),
        ('You wrote: 1 +', ''),
        ('You wrote:\n', ''),
        ('You wrote: 1 + 1 = 2\n\nAdd', 'Add'),
        // No blank line (yet): the next line is the answer
        ('You wrote: |x| = 3\nx = 3', 'x = 3'),
        ('You wrote: ?\nToo tangled', ''),
        ('I', ''),
        ('Ice melts', 'Ice melts'),
        ('Addition', 'Addition'),
      ]) {
        expect(AiActions.partialBody(partial), body, reason: partial);
      }
    });

    test('isRefusal', () {
      for (final refusal in [
        "I can't read this.",
        'I cannot make out the handwriting.',
        'Sorry, the image is blank.',
        "I'm unable to see any text in the image.",
        'I don’t see any readable writing',
        'No readable text in the image',
        'The handwriting is illegible',
        'The image appears to be empty.',
        'There is no text here.',
        'I can read the mathematical symbols clearly, but',
        'Could you clarify the last symbol?',
        'These marks are too tangled for me to read.',
        'Nothing readable here.',
      ]) {
        expect(AiActions.isRefusal(refusal), isTrue, reason: refusal);
      }
      for (final query in [
        'photosynthesis light reactions',
        'adding one plus one',
        "Newton's second law",
        "why oil and water don't mix",
        'why nothing can exceed the speed of light',
        '1 + 1 = 2',
        'Ideal gas law',
        'I Have a Dream speech analysis',
        'I = V/R',
        'I numeri primi spiegazione',
        'i cani e i gatti',
        'I think therefore I am meaning',
      ]) {
        expect(AiActions.isRefusal(query), isFalse, reason: query);
      }
    });

    test('a confirmed reading goes along and wins', () async {
      ai.onRespond = (_, _) async => 'You wrote: 1 + 1 = II\n\nOne and one.';
      final answer = await AiActions.explain(
        AiActions.newId(),
        testInput('sum'),
        action: .paragraph,
        provider: ai,
        model: model,
        confirmedReading: '  1 + 1 = 2 ',
      );
      expect((answer.reading, answer.body), ('1 + 1 = 2', 'One and one.'));
      expect(
        ai.requests.single.$2.prompt,
        'TYPED TEXT IN THE CIRCLED PART:\nsum\n\n'
        'The student confirmed the circled part says: 1 + 1 = 2\n'
        "Use exactly this reading; don't read the image differently.\n\n"
        'What are these notes saying?',
      );
      expect(ai.requests.single.$2.imagePng, testPng);

      // Every action sends it
      ai.onRespond = (req, _) async => req.jsonSchema != null
          ? '{"reading":"x","kind":"function","title":"","expression":"x",'
                '"xMin":0,"xMax":1,"xLabel":"","yLabel":"","points":[]}'
          : 'You wrote: x\nQUERY: lines';
      final (_, graphReading) = await AiActions.graph(
        AiActions.newId(),
        testInput(),
        provider: ai,
        model: model,
        confirmedReading: 'y = x',
      );
      final (queryReading, _) = await AiActions.searchQuery(
        AiActions.newId(),
        testInput(),
        provider: ai,
        model: model,
        confirmedReading: 'y = x',
      );
      expect((graphReading, queryReading), ('y = x', 'y = x'));
      for (final (_, request, _) in ai.requests.skip(1)) {
        expect(request.prompt, contains('says: y = x'));
      }

      // Blank: as if not confirmed
      ai.onRespond = (_, _) async => 'You wrote: 7\n\nSeven.';
      final blank = await AiActions.explain(
        AiActions.newId(),
        testInput(),
        action: .paragraph,
        provider: ai,
        model: model,
        confirmedReading: ' ',
      );
      expect(blank.reading, '7');
      expect(ai.requests.last.$2.prompt, 'What are these notes saying?');
    });

    test('nothing readable', () async {
      // Words: the student can still say what it says
      ai.onRespond = (_, _) async => 'You wrote: ?\nToo tangled; a neuron?';
      await expectLater(
        AiActions.explain(
          AiActions.newId(),
          testInput(),
          action: .explainExample,
          provider: ai,
          model: model,
        ),
        aiError(AiActions.unreadable, t.ai.nothingToRead),
      );

      // Never a drawing or chart of it
      ai.onRespond = (_, _) async => "You wrote: ?\nI can't read this.";
      await expectLater(
        AiActions.illustrate(
          AiActions.newId(),
          testInput(),
          provider: ai,
          model: model,
        ),
        aiError(AiActions.unreadable, t.ai.nothingToRead),
      );
      ai.onImage = (_) async => fail('no picture of a refusal');
      // Also when the sentence after it isn't a refusal, or it draws anyway
      for (final answer in [
        'You wrote: ?\n\nThese marks are too tangled for me to read.',
        'You wrote: ?\n\nThat said, it shows a neuron.\n'
            '<svg viewBox="0 0 9 9"><circle r="4"/></svg>',
      ]) {
        ai.onRespond = (_, _) async => answer;
        for (final drawer in [
          model,
          const AiModel('gpt-image-2', 'GPT Image 2', isImageModel: true),
        ]) {
          await expectLater(
            AiActions.illustrate(
              AiActions.newId(),
              testInput(),
              provider: ai,
              model: drawer,
            ),
            aiError(AiActions.unreadable),
            reason: '$answer ${drawer.id}',
          );
        }
      }
      ai.onRespond = (_, _) async => "You wrote: ?\nI can't read this.";
      await expectLater(
        AiActions.illustrate(
          AiActions.newId(),
          testInput(),
          provider: ai,
          model: const AiModel(
            'gpt-image-2',
            'GPT Image 2',
            isImageModel: true,
          ),
        ),
        aiError(AiActions.unreadable),
      );
      ai.onRespond = (_, _) async => '{"reading":"?","kind":"none"}';
      await expectLater(
        AiActions.graph(
          AiActions.newId(),
          testInput(),
          provider: ai,
          model: model,
        ),
        aiError(AiActions.unreadable),
      );
    });

    test('a search query is never a refusal', () async {
      Future<(String, String)> query(String answer, [String typed = '']) {
        ai.onRespond = (_, _) async => answer;
        return AiActions.searchQuery(
          AiActions.newId(),
          testInput(typed),
          provider: ai,
          model: model,
        );
      }

      expect(
        await query('You wrote: 1 + 1 = 2\nQUERY: basic addition for kids'),
        ('1 + 1 = 2', 'basic addition for kids'),
      );
      // The reading instead, with its repeated digits
      expect(await query("You wrote: 1 + 1 = 2\nQUERY: Sorry, I can't help."), (
        '1 + 1 = 2',
        '1 + 1 = 2',
      ));
      expect(await query('You wrote: ?\nThe ink is too faint.', 'Mitosis'), (
        '?',
        'Mitosis',
      ));
      await expectLater(
        query("I'm sorry, I can't make out any writing in this image."),
        aiError(AiActions.unreadable, t.ai.nothingToRead),
      );
      // Queries that start with "I"
      expect(
        await query(
          'You wrote: I Have a Dream – MLK\n'
          'QUERY: I Have a Dream speech analysis',
        ),
        ('I Have a Dream – MLK', 'I Have a Dream speech analysis'),
      );
      expect(
        await query(
          'You wrote: I numeri primi: 2, 3, 5, 7\n'
          'QUERY: I numeri primi spiegazione',
        ),
        ('I numeri primi: 2, 3, 5, 7', 'I numeri primi spiegazione'),
      );
      // Only a query line, never a question or a sentence: the reading
      for (final answer in [
        'You wrote: F = ma\nQUERY: Können Sie das letzte Zeichen erklären?',
        'You wrote: F = ma\n\nI can read the symbols clearly, but',
        'You wrote: F = ma\nQUERY: The notes show Newton\'s second law, '
            'which relates force, mass and acceleration',
      ]) {
        expect(await query(answer), ('F = ma', 'F = ma'), reason: answer);
      }
    });
  });

  test('languageName', () {
    expect(AiActions.languageName(const Locale('de', 'AT')), 'German');
    expect(
      AiActions.languageName(const Locale('zh', 'TW')),
      'Traditional Chinese',
    );
    expect(
      AiActions.languageName(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      'Traditional Chinese',
    );
    expect(
      AiActions.languageName(const Locale('zh', 'CN')),
      'Simplified Chinese',
    );
    expect(AiActions.languageName(const Locale('xx')), 'English');
    expect(AiActions.languageName(), isNotEmpty);
  });
}
