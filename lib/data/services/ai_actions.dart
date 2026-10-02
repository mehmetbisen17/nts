import 'dart:convert';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logging/logging.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/services/plot_spec.dart';
import 'package:nts/i18n/strings.g.dart';

/// The six things the AI menu offers for circled notes.
enum AiAction { explainExample, paragraph, graph, illustration, video, source }

/// What the AI gets: the circled part of the page as a PNG, and the typed
/// text there (the PNG shows it too; this is exact).
class AiInput {
  const new({required this.png, this.typedText = ''});

  final Uint8List png;
  final String typedText;
}

/// An answer in words, and what the AI read in the circle.
class AiTextResult {
  const new({required this.reading, required this.body});

  /// What the student wrote, as the AI read it (or as the student
  /// confirmed it): '' if it didn't say, '?' if it couldn't read it.
  final String reading;
  final String body;
}

/// An [AiError] after the AI read the circle, with what it read there
/// ([AiTextResult.reading]), so the student can see a misreading and fix it.
class AiReadingError extends AiError {
  const new(super.code, super.message, {required this.reading});

  final String reading;
}

/// The "You wrote: …" line every action's answer starts with.
abstract final class AiReading {
  static final _label = RegExp(
    r'''^[\s*_>"'“‘`]*(?:you (?:wrote|drew|sketched)|i read)\s*:[\s*_]*(.*)$''',
    caseSensitive: false,
  );

  /// Lines that come after the reading: the query, or the SVG.
  static final _after = RegExp(
    r'^\s*(?:QUERY:|```|<svg)',
    caseSensitive: false,
  );

  /// [text] as (reading, the rest). The reading follows "You wrote:" (or
  /// "You drew:", "I read:") in one of the first three lines, dropping
  /// anything said before it, and runs to a blank line or a query line;
  /// several lines are joined with "; ". Tolerates markdown and quotes;
  /// without the label, the reading is ''.
  static (String reading, String body) split(String text) {
    final lines = text.trim().split('\n');
    final start = lines.indexed
        .where((line) => line.$2.trim().isNotEmpty)
        .take(3)
        .firstWhereOrNull((line) => _label.hasMatch(line.$2.trim()))
        ?.$1;
    if (start == null) return ('', text.trim());
    var i = start + 1;
    final parts = [_label.firstMatch(lines[start].trim())![1]!];
    if (clean(parts.single).isEmpty) {
      // "You wrote:" alone: the reading is on the next line
      parts.clear();
      while (i < lines.length && lines[i].trim().isEmpty) {
        i++;
      }
      if (i < lines.length && !_after.hasMatch(lines[i])) parts.add(lines[i++]);
    }
    // A reading over several lines ends at a blank or query line; without
    // one close by, the next lines are the answer (a model that skipped the
    // blank line), not more reading.
    final end = lines.indexed
        .skip(i)
        .firstWhereOrNull(
          (line) => line.$2.trim().isEmpty || _after.hasMatch(line.$2),
        )
        ?.$1;
    final continues = end != null && end - i <= 3;
    // "?" is all there is to it; see [AiActions.explain]
    while (continues &&
        i < lines.length &&
        lines[i].trim().isNotEmpty &&
        !_after.hasMatch(lines[i]) &&
        (parts.isEmpty || clean(parts.first) != '?')) {
      parts.add(lines[i++]);
    }
    final reading = parts.map(clean).where((part) => part.isNotEmpty);
    return (reading.join('; '), lines.skip(i).join('\n').trim());
  }

  /// [reading] without markdown or the quotes around it.
  static String clean(String reading) {
    final text = reading
        .replaceAll('**', '')
        .replaceAll('__', '')
        .trim()
        .replaceAll(RegExp(r'^["“”«»`]+|["“”«»`]+$'), '')
        .trim();
    // Only a pair: f' keeps its prime
    return RegExp(r"^['‘’](.*)['‘’]$").firstMatch(text)?[1]!.trim() ?? text;
  }
}

/// The prompts and clean-up for [AiAction]s, on the account and model
/// `AiRouter.resolve` picked. Big multimodal models read the circled
/// handwriting straight from the picture. Failures are [AiError]s with a
/// message to show as is.
abstract final class AiActions {
  static final log = Logger('AiActions');

  static var _nextId = 0;

  /// A new id for these calls and [cancel]. One id can be used for several
  /// calls in a row.
  static String newId() => 'ai${_nextId++}';

  /// Ids cancelled before or while their calls ran.
  /// ponytail: never shrinks; a few bytes per request.
  static final _cancelled = <String>{};
  static final _running = <String, AiProvider>{};

  static const _cancelledError = AiError(AiError.cancelled, '');

  /// The code of an [AiError] for a circle with nothing the AI can read.
  static const unreadable = 'UNREADABLE';

  static AiError get _unreadableError =>
      AiError(unreadable, t.ai.nothingToRead);

  /// [reading] the student typed over the AI's, or null if they didn't.
  static String? _confirmed(String? reading) =>
      reading == null || reading.trim().isEmpty ? null : reading.trim();

  /// Stops the calls with [id]: running ones and later ones throw
  /// CANCELLED.
  static Future<void> cancel(String id) async {
    _cancelled.add(id);
    await _running.remove(id)?.cancel(id);
  }

  static Future<T> _call<T>(
    String id,
    AiProvider provider,
    Future<T> Function() call,
  ) async {
    if (_cancelled.contains(id)) throw _cancelledError;
    _running[id] = provider;
    try {
      final result = await call();
      if (_cancelled.contains(id)) throw _cancelledError;
      return result;
    } finally {
      if (_running[id] == provider) _running.remove(id);
    }
  }

  /// [AiAction.explainExample] or [AiAction.paragraph]. [onPartial] gets
  /// the answer so far, without the "You wrote: …" line.
  /// With [confirmedReading] (the student's fix of [AiTextResult.reading]),
  /// the AI takes that as what the circle says.
  static Future<AiTextResult> explain(
    String id,
    AiInput input, {
    required AiAction action,
    required AiProvider provider,
    required AiModel model,
    String? confirmedReading,
    void Function(String)? onPartial,
  }) async {
    final confirmed = _confirmed(confirmedReading);
    final (task, ask) = switch (action) {
      .explainExample => (
        // Without "starting with For example," it mostly skips the example
        'Task: explain the idea in the notes more clearly in two or three '
            'sentences. Then give one short, concrete example from everyday '
            'life, starting with "For example," (or the same words in the '
            'language of the answer). For math or science, the '
            'example may be a small worked calculation; double-check every '
            'number. At most 120 words after the first line.',
        'Explain this better, then give one example.',
      ),
      .paragraph => (
        'Task: in one paragraph of at most 90 words, say what the notes are '
            'saying, as if explaining them to a classmate.',
        'What are these notes saying?',
      ),
      _ => throw ArgumentError.value(action, 'action'),
    };
    final answer = await _call(
      id,
      provider,
      () => provider.respond(
        id,
        AiRequest(
          instructions: explainInstructions(task),
          prompt: prompt(input, ask, confirmed),
          imagePng: input.png,
        ),
        model: model.id,
        onPartial: onPartial == null
            ? null
            : (partial) => onPartial(partialBody(partial)),
      ),
    );
    final (read, body) = AiReading.split(stripMarkdown(answer));
    final reading = confirmed ?? read;
    // "You wrote: ?": not an answer to add to the page, but the student can
    // still say what it says. Not what the model guesses after it (a
    // scribble "is a neuron")
    if (reading == '?') throw _unreadableError;
    if (body.isNotEmpty) return AiTextResult(reading: reading, body: body);
    throw AiReadingError(AiError.failed, t.ai.failed, reading: reading);
  }

  /// The answer so far without the "You wrote: …" line, also while that
  /// line is still coming.
  @visibleForTesting
  static String partialBody(String partial) {
    final text = stripMarkdown(partial);
    final (reading, body) = AiReading.split(text);
    if (reading == '?') return ''; // see explain
    if (reading.isNotEmpty || text.contains('\n')) return body;
    final start = text.toLowerCase().replaceFirst(
      RegExp(r'''^[*_>"'“‘`]+'''),
      '',
    );
    final maybeLabel = const [
      'you wrote:',
      'i read:',
    ].any((label) => label.startsWith(start) || start.startsWith(label));
    return maybeLabel ? '' : body;
  }

  /// How to read the circle, for every action.
  static const _readFirst = '''
The image is exactly what the student selected on their page: almost always their handwriting (letters, digits, math symbols), sometimes with a sketch or typed text. The selection line isn't in the image, so every mark in it is theirs; an oval after "=" is the digit 0.
Read it first, like a teacher reading a student's messy handwriting: read each unclear mark as the letter, digit or symbol that makes the whole line make sense, up to the last mark. For example, in math a plain vertical stroke beside + or = is the digit 1, and in "1 + 1 =" a looped squiggle at the end is the digit 2. Read marks as writing, not as pictures of things, and once you've read a mark, don't also describe it as a drawing. Treat a mark as a drawing only if it clearly isn't writing.
If the marks aren't letters, digits or a sketch of a clear thing (a scribble or a tangle of lines isn't), you can't read them: never guess what they might mean. Never call the notes a joke, pun or visual trick, and write about what the notes say, not how the handwriting looks.
If the student confirmed what they wrote, that is what it says.''';

  /// The first line of every answer in words, for [AiReading.split].
  static const _youWrote =
      'Start with "You wrote: " (in English, also for a sketch) and exactly '
      'what is written, on one line (join several lines with "; "), e.g. '
      "You wrote: 3x + 2 = 11. Copy it even if it's wrong or unfinished; "
      "don't add steps, results or "
      "fixes to that line. If you can't read it, write only You wrote: ? "
      'and one short sentence saying so, and nothing after that.';

  /// The note's language, or the device's if the model can't tell.
  static String get _language =>
      'the language the notes are written in (${languageName()} if you '
      "can't tell)";

  @visibleForTesting
  static String explainInstructions(String task) =>
      '''
You help a student understand their own notes.
$_readFirst
$_youWrote
For math, check the arithmetic and logic before you explain; if something is wrong, say so kindly.
Then, after a blank line, write your answer in plain text: no markdown, no headings, no bullet points, no links or web addresses.
Write the answer in $_language.
$task''';

  /// [ask], after the typed text in the circle and what the student
  /// [confirmed] it says, if there are.
  @visibleForTesting
  static String prompt(AiInput input, String ask, [String? confirmed]) => [
    if (input.typedText.isNotEmpty)
      'TYPED TEXT IN THE CIRCLED PART:\n${input.typedText}',
    if (confirmed != null)
      'The student confirmed the circled part says: $confirmed\n'
          "Use exactly this reading; don't read the image differently.",
    ask,
  ].join('\n\n');

  /// A chart of the formula or numbers in the circle, and what the AI read
  /// there (see [explain] for [confirmedReading]).
  static Future<(PlotSpec spec, String reading)> graph(
    String id,
    AiInput input, {
    required AiProvider provider,
    required AiModel model,
    String? confirmedReading,
  }) async {
    final confirmed = _confirmed(confirmedReading);
    final json = await _call(
      id,
      provider,
      () => provider.respond(
        id,
        AiRequest(
          instructions: graphInstructions,
          prompt: prompt(input, 'Chart it.', confirmed),
          imagePng: input.png,
          jsonSchema: chartSchema,
        ),
        model: model.id,
      ),
    );
    var reading = confirmed ?? '';
    try {
      final chart = jsonDecode(_jsonObject(json)) as Map<String, dynamic>;
      reading = confirmed ?? AiReading.clean('${chart['reading'] ?? ''}');
      if (reading == '?') throw _unreadableError; // never a made-up chart
      return (plotFromJson(chart), reading);
    } on AiError catch (e) {
      throw AiReadingError(e.code, e.message, reading: reading);
    } on FormatException {
      throw AiReadingError(
        AiError.failed,
        t.ai.couldNotGraph,
        reading: reading,
      );
    } on TypeError {
      throw AiReadingError(
        AiError.failed,
        t.ai.couldNotGraph,
        reading: reading,
      );
    }
  }

  @visibleForTesting
  static String get graphInstructions =>
      '''
You turn a student's notes into a chart.
$_readFirst
Put exactly what you read in "reading", e.g. y = 2x + 1, or ? if you truly can't read it.
Use only the formulas and numbers written in the notes. Never make up data. Write the title and labels in $_language.''';

  /// The model's [chartSchema] JSON as a chart. Throws [FormatException]
  /// if it can't be drawn, or [AiError] if there's nothing to chart.
  @visibleForTesting
  static PlotSpec plotFromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'function':
        // Throws if it can't draw it
        return FunctionPlot.fromJson(json);
      case 'line' || 'bar':
        final plot = DataPlot.fromJson(json);
        if (plot.points.length < 2) throw const FormatException('Too few');
        return DataPlot(
          title: plot.title,
          kind: plot.kind,
          xLabel: plot.xLabel,
          yLabel: plot.yLabel,
          points: plot.points.take(maxPoints).toList(),
        );
      default:
        throw AiError(AiError.failed, t.ai.nothingToGraph);
    }
  }

  static const maxPoints = 24;

  /// A [FunctionPlot] or a [DataPlot] in one flat object, as ChatGPT's
  /// strict mode needs (no anyOf at the top, every field required).
  /// "reading" comes first: the model reads before it charts.
  @visibleForTesting
  static const chartSchema =
      '{"title":"Chart","type":"object","additionalProperties":false,'
      '"properties":{'
      '"reading":{"type":"string","description":"Exactly what the student '
      'wrote in the circled part, as plain text; ? if unreadable"},'
      '"kind":{"type":"string","enum":["function","line","bar","none"],'
      '"description":"function for a formula of x; bar if the numbers '
      'belong to named categories; line if they change over time or '
      'another number; none if there is nothing to chart"},'
      '"title":{"type":"string","description":"Short chart title"},'
      '"expression":{"type":"string","description":"For function: the '
      "formula's right-hand side as a function of x, with * for every "
      'multiplication and ^ for powers, e.g. 3*x^2 - 2*x + 1. Else empty."},'
      '"xMin":{"type":"number","description":"For function: left end of '
      'the x axis. Else 0."},'
      '"xMax":{"type":"number","description":"For function: right end of '
      'the x axis. Else 0."},'
      '"xLabel":{"type":"string"},"yLabel":{"type":"string"},'
      '"points":{"type":"array","description":"For line or bar: each '
      'category or x value written in the notes, in order, with its '
      'number. Else empty.","items":{"type":"object",'
      '"additionalProperties":false,"properties":{'
      '"label":{"type":"string","description":"Category name or x value '
      'as written"},"y":{"type":"number"}},"required":["label","y"]}}},'
      '"required":["reading","kind","title","expression","xMin","xMax",'
      '"xLabel","yLabel","points"]}';

  /// [text] from its first { to its last }: some models wrap JSON in
  /// a code block.
  static String _jsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    return start < 0 || end < start ? text : text.substring(start, end + 1);
  }

  /// A picture of the main idea in the circle, and what the AI read there
  /// (see [explain] for [confirmedReading]). A picture model
  /// ([AiModel.isImageModel]) draws a description written by the
  /// account's text model; any other model draws an SVG line drawing,
  /// returned as a transparent PNG.
  static Future<(String reading, Uint8List bytes, String extension)> illustrate(
    String id,
    AiInput input, {
    required AiProvider provider,
    required AiModel model,
    String? confirmedReading,
  }) async {
    final confirmed = _confirmed(confirmedReading);
    var drawer = model;
    if (model.isImageModel) {
      final models = await _call(id, provider, provider.models);
      final writer =
          models.firstWhereOrNull((m) => !m.isImageModel && !m.mayCostExtra) ??
          models.firstWhereOrNull((m) => !m.isImageModel);
      if (writer == null) {
        throw AiError(
          AiError.modelUnavailable,
          t.ai.route.noModel(provider: provider.displayName.split(' (').first),
        );
      }
      final (read, rest) = AiReading.split(
        stripMarkdown(
          await _call(
            id,
            provider,
            () => provider.respond(
              id,
              AiRequest(
                instructions: pictureInstructions,
                prompt: prompt(input, 'Describe the picture.', confirmed),
                imagePng: input.png,
              ),
              model: writer.id,
            ),
          ),
        ),
      );
      // Never a picture of "I can't read this" or of a guess
      if (confirmed == null && read == '?') throw _unreadableError;
      final description = _firstLine(rest); // after the reading's lines
      if (description.isEmpty || isRefusal(description)) {
        throw confirmed == null && read.isEmpty
            ? _unreadableError
            : AiReadingError(
                AiError.failed,
                t.ai.couldNotDraw,
                reading: confirmed ?? read,
              );
      }
      final picture = provider.generateImage(
        id,
        '$description Clean, simple illustration with thin lines and a '
        'few soft colours on a plain light background. No text.',
        model: model.id,
      );
      if (picture != null) {
        final bytes = await _call(id, provider, () => picture);
        return (confirmed ?? read, bytes, _isJpeg(bytes) ? '.jpg' : '.png');
      }
      drawer = writer; // can't make pictures after all: draw lines
    }
    final answer = await _call(
      id,
      provider,
      () => provider.respond(
        id,
        AiRequest(
          instructions: svgInstructions,
          prompt: prompt(input, 'Draw it.', confirmed),
          imagePng: input.png,
        ),
        model: drawer.id,
      ),
    );
    final (read, rest) = AiReading.split(answer);
    // Not what the model draws after it (a scribble "is a neuron")
    if (confirmed == null && read == '?') throw _unreadableError;
    final reading = confirmed ?? read;
    final svg = sanitizeSvg(answer);
    if (svg == null) {
      log.info('Unusable SVG (${answer.length} chars)');
      throw confirmed == null && read.isEmpty && isRefusal(rest)
          ? _unreadableError
          : AiReadingError(AiError.failed, t.ai.couldNotDraw, reading: reading);
    }
    try {
      return (reading, await svgToPng(svg), '.png');
    } on Object catch (e) {
      // The renderer throws Errors too, e.g. for too deeply nested <use>s
      log.info('SVG failed to render', e);
      throw AiReadingError(AiError.failed, t.ai.couldNotDraw, reading: reading);
    }
  }

  /// For a text model that describes what a picture model draws.
  @visibleForTesting
  static const pictureInstructions =
      '''
You help a student understand their own notes.
$_readFirst
$_youWrote
Then, after a blank line, describe one simple picture that shows the main idea of the notes, in one English sentence of at most 40 words. No text, labels or formulas in the picture.''';

  @visibleForTesting
  static const svgInstructions =
      '''
You draw simple line drawings that help a student understand their own notes.
$_readFirst
$_youWrote
Then, after a blank line, draw one picture of the main idea of the notes as a single self-contained SVG.
Style: viewBox="0 0 512 512" with no width or height; thin strokes (stroke-width 2 to 4) with round caps and joins; fill="none" except for a few small flat areas; at most three colours: #2B2A28 for lines, #D0283A as the one accent, #A87A2E if needed.
Never use text, letters, numbers or labels, and never <script>, <image>, <foreignObject>, <style>, filters, gradients, links or anything loaded from outside.
After the "You wrote" line and the blank line, reply with only the SVG, from <svg to </svg>.''';

  /// The most SVG accepted from a model.
  static const maxSvgLength = 200000;

  /// The `<svg>…</svg>` in a model's [answer], or null if there's none or
  /// it could reach outside the drawing: scripts, embedded pages or
  /// pictures, event handlers, links or `url()`s other than to `#ids`,
  /// DOCTYPEs (entities) or processing instructions.
  @visibleForTesting
  static String? sanitizeSvg(String answer) {
    final start = answer.indexOf(RegExp(r'<svg[\s>]', caseSensitive: false));
    final end = answer.toLowerCase().lastIndexOf('</svg>');
    if (start < 0 || end < start) return null;
    final svg = answer
        .substring(start, end + '</svg>'.length)
        .replaceAll(RegExp('<!--.*?-->', dotAll: true), '');
    if (svg.length > maxSvgLength) return null;
    final lower = svg.toLowerCase();
    const banned = [
      '<script',
      '<foreignobject',
      '<image',
      '<iframe',
      '<embed',
      '<object',
      '<a ',
      '<a>',
      '<!',
      '<?',
      'javascript:',
      '@import',
    ];
    if (banned.any(lower.contains)) return null;
    final outside = [
      RegExp(r'\son[a-z]+\s*=', caseSensitive: false), // onload=
      RegExp(r'''href\s*=\s*["']?\s*(?![\s"'#])''', caseSensitive: false),
      RegExp(r'''url\(\s*["']?\s*(?![\s"'#])''', caseSensitive: false),
    ];
    if (outside.any((pattern) => pattern.hasMatch(svg))) return null;
    return svg;
  }

  /// [svg] drawn at [size] pixels on its longest side, transparent
  /// around the lines. A size the SVG doesn't say (or that's infinite, e.g.
  /// `viewBox="0 0 1e400 1"`) is taken as 512 square.
  static Future<Uint8List> svgToPng(String svg, {double size = 1024}) async {
    final info = await vg.loadPicture(SvgStringLoader(svg), null);
    try {
      final box = info.size.isEmpty || !info.size.isFinite
          ? const Size.square(512)
          : info.size;
      final scale = size / box.longestSide;
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..scale(scale)
        ..drawPicture(info.picture);
      int pixels(double length) => (length * scale).ceil().clamp(1, 4096);
      final image = await recorder.endRecording().toImage(
        pixels(box.width),
        pixels(box.height),
      );
      try {
        final bytes = await image.toByteData(format: .png);
        return bytes!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      info.picture.dispose();
    }
  }

  static bool _isJpeg(Uint8List bytes) =>
      bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  /// A short web search query for the circle, for the user to check
  /// before searching, and what the AI read there (see [explain] for
  /// [confirmedReading]). Never an "I can't read this": then the reading,
  /// else the typed text's first line, else an [unreadable] error.
  static Future<(String reading, String query)> searchQuery(
    String id,
    AiInput input, {
    required AiProvider provider,
    required AiModel model,
    String? confirmedReading,
  }) async {
    final confirmed = _confirmed(confirmedReading);
    var reading = confirmed ?? '';
    try {
      final answer = await _call(
        id,
        provider,
        () => provider.respond(
          id,
          AiRequest(
            instructions: queryInstructions,
            prompt: prompt(input, 'What would you search for?', confirmed),
            imagePng: input.png,
          ),
          model: model.id,
        ),
      );
      final (read, rest) = AiReading.split(stripMarkdown(answer));
      reading = confirmed ?? read;
      // Only from the query line: anything else is the model talking
      final line = _queryLine.firstMatch(rest)?[1]!.trim() ?? '';
      // Nor a question or a sentence, in any language
      final query =
          reading == '?' ||
              line.endsWith('?') ||
              line.split(RegExp(r'\s+')).length > 10
          ? ''
          : cleanQuery(line);
      if (query.isNotEmpty && !isRefusal(query)) return (reading, query);
      log.info('No query from ${provider.displayName}');
    } on AiError catch (e) {
      if (e.code == AiError.cancelled) rethrow;
      if (input.typedText.isEmpty && confirmed == null) rethrow;
      log.info('No query from ${provider.displayName}: $e');
    }
    // What the student wrote or typed: never a refusal, even "I …"
    for (final fallback in [reading, _firstLine(input.typedText)]) {
      final query = cleanQuery(fallback);
      if (query.isNotEmpty) return (reading, query);
    }
    throw _unreadableError;
  }

  static final _queryLine = RegExp(
    r'^\s*QUERY:(.*)$',
    caseSensitive: false,
    multiLine: true,
  );

  @visibleForTesting
  static String get queryInstructions =>
      '''
You turn a student's notes into one short web search query.
$_readFirst
Reply with exactly two lines:
You wrote: <exactly what you read>
QUERY: <3 to 8 words in $_language that would find good explanations of the topic, spelled correctly, no quotes>
Never ask a question: if a mark is unclear, use the reading that makes the most sense. If you can't read it at all, reply only: You wrote: ?''';

  /// Whether [text] is the model saying it can't read or help, or talking
  /// about the notes, not an answer, e.g. "I'm sorry, I can't make out the
  /// handwriting." or "I can read the symbols, but".
  static bool isRefusal(String text) =>
      _refusal.hasMatch(text) || _meta.hasMatch(text);

  /// Not any "I …": "I Have a Dream", "I = V/R", Italian "I numeri primi".
  static final _meta = RegExp(
    r"^\W*I(?:[’'][md]|\s+(?:am|can|cannot|could|couldn[’']t|don[’']t|"
    r'do not|see|think the|need|would))\b|'
    r'\b(?:could you|clarify|not (?:sure|certain))\b',
    caseSensitive: false,
  );

  static final _refusal = RegExp(
    r'\b(?:sorry|apologi[sz]e|unable|illegible|unreadable|as an ai|'
    r"(?:can[’']?t|cannot|can not|couldn[’']?t|could not|don[’']?t|do not|"
    r'not able to)\s+(?:see|read|make out|tell|identify|determine|decipher|'
    r'find|view|access|process|help)|'
    r'(?:no|not)\s+(?:readable|legible|visible|clear)|'
    r'no\s+(?:text|writing|handwriting|content)|'
    r'nothing\s+(?:readable|legible)|'
    r'too\s+(?:tangled|messy|faint|unclear)\b.{0,20}\bread|'
    r'(?:image|picture|photo|circle)\s+(?:is|appears|seems)\s+(?:to be\s+)?'
    r'(?:blank|empty))\b',
    caseSensitive: false,
  );

  /// Videos or web pages for [query], only http(s) ones.
  static Future<List<AiLink>> search(
    String id,
    String query, {
    required AiSearchKind kind,
    required AiProvider provider,
    required AiModel model,
  }) async {
    final links = await _call(
      id,
      provider,
      () => provider.search(id, query, kind: kind, model: model.id),
    );
    return [
      for (final link in links)
        if (isWebLink(link.url))
          AiLink(
            title: link.title.trim().isEmpty ? link.url.host : link.title,
            url: link.url,
            source: link.source,
            thumbnail: link.thumbnail != null && isWebLink(link.thumbnail!)
                ? link.thumbnail
                : null,
          ),
    ];
  }

  static bool isWebLink(Uri url) =>
      (url.isScheme('https') || url.isScheme('http')) && url.host.isNotEmpty;

  /// The English name of the device's language, e.g. "German".
  static String languageName([Locale? locale]) {
    locale ??= PlatformDispatcher.instance.locale;
    if (locale.languageCode == 'zh') {
      return locale.scriptCode == 'Hant' ||
              const {'TW', 'HK', 'MO'}.contains(locale.countryCode)
          ? 'Traditional Chinese'
          : 'Simplified Chinese';
    }
    // ponytail: the app's languages and a few more; others get English
    return _languageNames[locale.languageCode] ?? 'English';
  }

  static const _languageNames = {
    'ar': 'Arabic',
    'ca': 'Catalan',
    'cs': 'Czech',
    'da': 'Danish',
    'de': 'German',
    'en': 'English',
    'eo': 'Esperanto',
    'es': 'Spanish',
    'fa': 'Persian',
    'fr': 'French',
    'he': 'Hebrew',
    'hu': 'Hungarian',
    'it': 'Italian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'nb': 'Norwegian',
    'nl': 'Dutch',
    'no': 'Norwegian',
    'pl': 'Polish',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'sl': 'Slovenian',
    'sv': 'Swedish',
    'th': 'Thai',
    'tr': 'Turkish',
    'uk': 'Ukrainian',
    'vi': 'Vietnamese',
  };

  /// [text] without the markdown models write anyway: bold, headings and
  /// bullets. Also without web addresses: models make them up, and the
  /// page's text would turn them into links.
  @visibleForTesting
  static String stripMarkdown(String text) => text
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll(RegExp(r'^[ \t]*(#+|[-*•])[ \t]+', multiLine: true), '')
      .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
      .replaceAll(RegExp(r'(https?://|www\.)\S+', caseSensitive: false), '')
      .trim();

  /// The model's query as one clean line of at most 8 words.
  @visibleForTesting
  static String cleanQuery(String text) {
    final line =
        _firstLine(
              text.replaceFirst(
                RegExp(r'^\s*QUERY:', caseSensitive: false),
                '',
              ),
            )
            .replaceAll(RegExp('["“”«»`]'), '')
            .replaceAll(RegExp(r'''^['‘’]+|[\s.!?,;:…'‘’]+$'''), '');
    final words = line.split(RegExp(r'\s+'));
    return [
      for (final (i, word) in words.indexed)
        // A stutter ("cell cell"), but not "one plus one"
        if (word.isNotEmpty &&
            (i == 0 || word.toLowerCase() != words[i - 1].toLowerCase()))
          word,
    ].take(8).join(' ');
  }

  static String _firstLine(String text) => text
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
}
