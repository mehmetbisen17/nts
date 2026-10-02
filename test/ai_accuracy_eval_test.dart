// Accuracy eval of the AI actions on messy handwriting, through the real
// Claude Code on this Mac (the owner's plan). Not part of the normal run:
//   NTS_EVAL=render flutter test test/ai_accuracy_eval_test.dart
//   NTS_EVAL=run [NTS_EVAL_CASES=s1.explain,…] [NTS_EVAL_TAG=r1] flutter test …
// Samples are app strokes drawn in a sloppy hand (bar-shaped 1s, looped
// 2s), cropped by the app's own selectionPng. Files go to NTS_EVAL_DIR.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/pencil_shader.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/providers/claude_code_provider.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/services/ai_actions.dart';
import 'package:nts/data/services/plot_expression.dart';
import 'package:nts/data/services/plot_spec.dart';
import 'package:nts/data/services/selection_image.dart';
import 'package:nts/data/tools/select.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/has_size.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

final _mode = Platform.environment['NTS_EVAL'];
final _dir =
    Platform.environment['NTS_EVAL_DIR'] ??
    '${Directory.systemTemp.path}/nts-eval';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  FlavorConfig.setup();
  setUpAll(PencilShader.init);

  testWidgets('render samples', skip: _mode == null, (tester) async {
    Directory('$_dir/samples').createSync(recursive: true);
    for (final sample in _samples) {
      final png = (await tester.runAsync(() => _render(sample)))!;
      File('$_dir/samples/${sample.id}.png').writeAsBytesSync(png);
    }
  });

  testWidgets(
    'real Claude Code',
    skip: _mode != 'run',
    timeout: const Timeout(Duration(minutes: 40)),
    (tester) async {
      final tag = Platform.environment['NTS_EVAL_TAG'] ?? 'r1';
      final only = Platform.environment['NTS_EVAL_CASES']?.split(',').toSet();
      final out = Directory('$_dir/results/$tag')..createSync(recursive: true);
      await tester.runAsync(() async {
        final claude = ClaudeCodeProvider();
        await claude.refreshStatus();
        expect(claude.status.value.isSignedIn, isTrue);
        final model = (await claude.models()).first; // Automatic's: Haiku
        final cases = [
          for (final c in _cases)
            if (only == null || only.contains(c.id)) c,
        ];
        // Three at a time, like a student asking a few things in a row
        for (var i = 0; i < cases.length; i += 3) {
          await Future.wait([
            for (final c in cases.skip(i).take(3))
              _run(c, claude, model).then(
                (result) => File('${out.path}/${c.id}.json').writeAsStringSync(
                  const JsonEncoder.withIndent('  ').convert(result),
                ),
              ),
          ]);
        }
      });
    },
  );
}

/// One AI call on one sample.
class _Case {
  const new(this.sample, this.action, {this.confirmed, this.suffix = ''});
  final String sample;
  final String action; // explain, paragraph, graph, query, illustration
  final String? confirmed;
  final String suffix;
  String get id => '$sample.$action$suffix';
}

final _cases = [
  for (final sample in [
    'owner_tight',
    'owner_loose',
    ..._samples.map((s) => s.id),
  ])
    for (final action in const ['explain', 'paragraph']) _Case(sample, action),
  const _Case('s6_linear', 'graph'),
  const _Case('owner_tight', 'query'),
  const _Case('s2_quadratic', 'query'),
  const _Case('s4_mito', 'query'),
  const _Case('s4_mito', 'illustration'),
  // The student corrects the reading: the answer must follow it
  const _Case('s7_scribble', 'explain', confirmed: 'E = mc^2', suffix: '.fix'),
  const _Case('s3_times', 'explain', confirmed: '7 x 6 = 42', suffix: '.fix'),
  // From the review, in samples/ too: notes over two lines, German notes,
  // a labelled sketch, and a scribble to draw or chart
  const _Case('t2_abs_two_lines', 'explain'),
  const _Case('t3_german', 'explain'),
  const _Case('t4_triangle', 'explain'),
  const _Case('s7_scribble', 'illustration'),
  const _Case('s7_scribble', 'graph'),
];

Future<Map<String, Object?>> _run(
  _Case c,
  AiProvider claude,
  AiModel model,
) async {
  final png = File(
    '$_dir/${c.sample.startsWith('owner') ? 'crop_${c.sample}' : 'samples/${c.sample}'}.png',
  ).readAsBytesSync();
  final provider = _Recording(claude);
  final input = AiInput(png: png);
  final id = AiActions.newId();
  final result = <String, Object?>{
    'case': c.id,
    'sample': c.sample,
    'action': c.action,
    'model': model.id,
    'confirmed': c.confirmed,
  };
  final watch = Stopwatch()..start();
  try {
    switch (c.action) {
      case 'explain' || 'paragraph':
        final answer = await AiActions.explain(
          id,
          input,
          action: c.action == 'explain' ? .explainExample : .paragraph,
          provider: provider,
          model: model,
          confirmedReading: c.confirmed,
        );
        result['reading'] = answer.reading;
        result['body'] = answer.body;
      case 'graph':
        final (spec, reading) = await AiActions.graph(
          id,
          input,
          provider: provider,
          model: model,
          confirmedReading: c.confirmed,
        );
        result['reading'] = reading;
        result['title'] = spec.title;
        if (spec is FunctionPlot) {
          final f = parseExpression(spec.expression);
          result['expression'] = spec.expression;
          result['range'] = [spec.xMin, spec.xMax];
          result['f(-1,0,1,2)'] = [f(-1), f(0), f(1), f(2)];
        } else {
          result['kind'] = spec.runtimeType.toString();
        }
      case 'query':
        final (reading, query) = await AiActions.searchQuery(
          id,
          input,
          provider: provider,
          model: model,
          confirmedReading: c.confirmed,
        );
        result['reading'] = reading;
        result['query'] = query;
      case 'illustration':
        final (reading, bytes, extension) = await AiActions.illustrate(
          id,
          input,
          provider: provider,
          model: model,
          confirmedReading: c.confirmed,
        );
        result['reading'] = reading;
        final file = '$_dir/results/${c.id}$extension';
        File(file).writeAsBytesSync(bytes);
        result['picture'] = file;
    }
  } on AiError catch (e) {
    result['error'] = '${e.code}: ${e.message}';
    if (e is AiReadingError) result['reading'] = e.reading;
    if (e.code == AiActions.unreadable) result['reading'] ??= '?';
  }
  result['ms'] = watch.elapsedMilliseconds;
  result['raw'] = provider.raw;
  return result;
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
    final text = await inner.respond(requestId, req, model: model);
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

// ---------------------------------------------------------------- samples

/// A line of handwriting: [text] in [hand], [height] page units tall.
class _Sample {
  const new(
    this.id,
    this.text, {
    required this.seed,
    this.height = 120,
    this.size = 6,
    this.tool = ToolId.fountainPen,
    this.slant = 0.12,
    this.mess = 1,
    this.pattern = CanvasBackgroundPattern.dots,
  });
  final String id;

  /// Characters in [_glyphs]; `^2` is a raised 2, `[1/2]` a stacked
  /// fraction, `~` a scribble, `2` the owner's hooked, looped 2 and `z`
  /// a looped 2 of the usual shape.
  final String text;
  final int seed;
  final double height, size, slant, mess;
  final ToolId tool;
  final CanvasBackgroundPattern pattern;
}

const _samples = [
  _Sample(
    's1_add',
    '2 + 1 = 3',
    seed: 1,
    height: 150,
    size: 14,
    tool: .brushPen,
    slant: 0.05,
  ),
  _Sample(
    's2_quadratic',
    'x^z - 4 = 0',
    seed: 2,
    height: 110,
    size: 6,
    pattern: .lined,
  ),
  _Sample(
    's3_times',
    '7 * 8 = 56',
    seed: 3,
    height: 120,
    size: 7,
    mess: 1.3,
    slant: 0.18,
  ),
  _Sample(
    's4_mito',
    'mitochondria = powerhouse',
    seed: 4,
    height: 62,
    size: 4,
    slant: 0.2,
    pattern: .none,
  ),
  _Sample(
    's5_fractions',
    '[1/z] + [1/4] = [3/4]',
    seed: 5,
    height: 130,
    size: 10,
    tool: .brushPen,
    pattern: .grid,
  ),
  _Sample(
    's6_linear',
    'y = 2x + 1',
    seed: 16,
    height: 130,
    size: 12,
    tool: .brushPen,
    mess: 1.2,
  ),
  _Sample('s7_scribble', '~', seed: 7, height: 140, size: 6, mess: 1),
];

const _pageSize = HasSize(Size(1800, 1400));

Future<Uint8List?> _render(_Sample sample) async {
  final strokes = [
    for (final points in _write(sample))
      Stroke(
        color: const Color(0xFF111111),
        pressureEnabled: sample.tool == .fountainPen,
        options: sample.tool == .brushPen
            ? StrokeOptions(size: sample.size, thinning: 0.5, isComplete: true)
            : StrokeOptions(size: sample.size, isComplete: true),
        pageIndex: 0,
        page: _pageSize,
        toolId: sample.tool,
      )..addPoints(points),
  ];
  final coreInfo = EditorCoreInfo(filePath: '/eval_${sample.id}')
    ..backgroundPattern = sample.pattern
    ..pages.add(EditorPage(size: _pageSize.size, strokes: strokes));
  final bounds = strokes
      .map((s) => s.highQualityPath.getBounds())
      .reduce((a, b) => a.expandToInclude(b))
      .inflate(30);
  final page = coreInfo.pages.first;
  final selection =
      (Select.currentSelect
            ..onDragStart(bounds.topLeft, 0)
            ..onDragUpdate(bounds.topRight)
            ..onDragUpdate(bounds.bottomRight)
            ..onDragUpdate(bounds.bottomLeft)
            ..onDragEnd(page.strokes, page.images))
          .selectResult;
  expect(selection.strokes, hasLength(strokes.length), reason: sample.id);
  try {
    return await selectionPng(coreInfo, selection);
  } finally {
    Select.currentSelect.unselect();
  }
}

/// Glyphs as strokes of control points: x across, y down, 0 the top of a
/// digit and 1 the baseline (small letters from 0.45), and the advance.
const _glyphs = <String, (double, List<List<(double, double)>>)>{
  // A bare bar, like the owner's
  '1': (
    0.35,
    [
      [(0.14, 0.02), (0.11, 0.5), (0.13, 0.98)],
    ],
  ),
  // The owner's: a hook, down to the right, a loop at the bottom
  '2': (
    0.95,
    [
      [
        (0.0, 0.06),
        (0.2, 0.0),
        (0.36, 0.1),
        (0.56, 0.42),
        (0.62, 0.72),
        (0.5, 0.96),
        (0.28, 1.0),
        (0.12, 0.9),
        (0.22, 0.78),
        (0.52, 0.78),
        (0.88, 0.93),
      ],
    ],
  ),
  'z': (
    0.8,
    [
      [
        (0.08, 0.2),
        (0.3, 0.0),
        (0.58, 0.08),
        (0.6, 0.3),
        (0.4, 0.6),
        (0.15, 0.9),
        (0.05, 1.0),
        (0.0, 0.88),
        (0.12, 0.8),
        (0.35, 0.9),
        (0.72, 0.98),
      ],
    ],
  ),
  '3': (
    0.8,
    [
      [
        (0.08, 0.12),
        (0.35, 0.0),
        (0.62, 0.1),
        (0.6, 0.3),
        (0.32, 0.45),
        (0.62, 0.58),
        (0.68, 0.82),
        (0.42, 1.0),
        (0.1, 0.92),
      ],
    ],
  ),
  '4': (
    0.85,
    [
      [(0.5, 0.0), (0.25, 0.4), (0.02, 0.68), (0.4, 0.66), (0.78, 0.64)],
      [(0.55, 0.3), (0.56, 0.7), (0.57, 1.02)],
    ],
  ),
  '0': (
    0.8,
    [
      [
        (0.4, 0.02),
        (0.12, 0.2),
        (0.05, 0.55),
        (0.18, 0.92),
        (0.42, 1.0),
        (0.65, 0.8),
        (0.7, 0.4),
        (0.55, 0.08),
        (0.35, 0.04),
        (0.25, 0.12),
      ],
    ],
  ),
  '5': (
    0.8,
    [
      [
        (0.25, 0.02),
        (0.2, 0.25),
        (0.15, 0.46),
        (0.4, 0.38),
        (0.68, 0.52),
        (0.72, 0.78),
        (0.5, 0.98),
        (0.25, 1.0),
        (0.05, 0.88),
      ],
      [(0.22, 0.03), (0.45, 0.0), (0.66, 0.02)],
    ],
  ),
  '6': (
    0.8,
    [
      [
        (0.62, 0.02),
        (0.35, 0.2),
        (0.12, 0.55),
        (0.12, 0.88),
        (0.35, 1.0),
        (0.62, 0.9),
        (0.66, 0.65),
        (0.45, 0.5),
        (0.22, 0.58),
        (0.14, 0.72),
      ],
    ],
  ),
  '7': (
    0.8,
    [
      [(0.02, 0.08), (0.3, 0.02), (0.72, 0.0), (0.5, 0.45), (0.3, 1.0)],
    ],
  ),
  '8': (
    0.8,
    [
      [
        (0.62, 0.12),
        (0.4, 0.0),
        (0.15, 0.12),
        (0.2, 0.35),
        (0.45, 0.5),
        (0.7, 0.68),
        (0.65, 0.92),
        (0.4, 1.0),
        (0.12, 0.9),
        (0.15, 0.68),
        (0.42, 0.5),
        (0.62, 0.32),
        (0.64, 0.14),
      ],
    ],
  ),
  '+': (
    0.8,
    [
      [(0.05, 0.55), (0.4, 0.53), (0.7, 0.5)],
      [(0.38, 0.25), (0.37, 0.55), (0.39, 0.85)],
    ],
  ),
  '-': (
    0.7,
    [
      [(0.05, 0.58), (0.35, 0.56), (0.62, 0.55)],
    ],
  ),
  '=': (
    0.9,
    [
      [(0.05, 0.42), (0.4, 0.4), (0.7, 0.36)],
      [(0.02, 0.7), (0.4, 0.66), (0.75, 0.6)],
    ],
  ),
  '*': (
    0.75,
    [
      [(0.08, 0.35), (0.35, 0.65), (0.62, 0.95)],
      [(0.6, 0.35), (0.35, 0.65), (0.1, 0.95)],
    ],
  ),
  'x': (
    0.6,
    [
      [(0.05, 0.45), (0.28, 0.72), (0.52, 1.0)],
      [(0.5, 0.45), (0.28, 0.72), (0.03, 1.0)],
    ],
  ),
  'y': (
    0.62,
    [
      [(0.05, 0.45), (0.15, 0.75), (0.3, 0.95)],
      [(0.55, 0.45), (0.38, 0.9), (0.22, 1.3), (0.08, 1.35)],
    ],
  ),
  'm': (
    0.76,
    [
      [
        (0.04, 0.47),
        (0.05, 0.75),
        (0.05, 1.0),
        (0.06, 0.65),
        (0.2, 0.47),
        (0.33, 0.55),
        (0.35, 1.0),
        (0.37, 0.64),
        (0.5, 0.47),
        (0.64, 0.55),
        (0.66, 1.0),
      ],
    ],
  ),
  'i': (
    0.25,
    [
      [(0.08, 0.5), (0.07, 0.75), (0.09, 1.0)],
      [(0.08, 0.28), (0.1, 0.3)],
    ],
  ),
  't': (
    0.48,
    [
      [(0.18, 0.12), (0.17, 0.6), (0.2, 0.92), (0.3, 1.0), (0.42, 0.94)],
      [(0.0, 0.48), (0.2, 0.47), (0.4, 0.45)],
    ],
  ),
  'o': (
    0.6,
    [
      [
        (0.3, 0.45),
        (0.08, 0.55),
        (0.05, 0.82),
        (0.25, 1.0),
        (0.48, 0.9),
        (0.52, 0.62),
        (0.38, 0.46),
        (0.22, 0.48),
      ],
    ],
  ),
  'c': (
    0.55,
    [
      [
        (0.48, 0.52),
        (0.3, 0.45),
        (0.08, 0.58),
        (0.06, 0.85),
        (0.25, 1.0),
        (0.5, 0.94),
      ],
    ],
  ),
  'h': (
    0.56,
    [
      [
        (0.07, 0.0),
        (0.06, 0.5),
        (0.07, 1.0),
        (0.08, 0.68),
        (0.22, 0.48),
        (0.38, 0.52),
        (0.43, 0.72),
        (0.45, 1.0),
      ],
    ],
  ),
  'n': (
    0.52,
    [
      [
        (0.05, 0.47),
        (0.05, 1.0),
        (0.06, 0.66),
        (0.2, 0.47),
        (0.36, 0.52),
        (0.4, 0.72),
        (0.42, 1.0),
      ],
    ],
  ),
  'd': (
    0.6,
    [
      [
        (0.45, 0.55),
        (0.28, 0.45),
        (0.07, 0.6),
        (0.06, 0.86),
        (0.25, 1.0),
        (0.44, 0.88),
        (0.49, 0.5),
        (0.5, 0.0),
        (0.5, 0.5),
        (0.52, 1.0),
      ],
    ],
  ),
  'r': (
    0.42,
    [
      [(0.06, 0.47), (0.06, 1.0), (0.07, 0.7), (0.18, 0.5), (0.36, 0.47)],
    ],
  ),
  'a': (
    0.62,
    [
      [
        (0.46, 0.55),
        (0.28, 0.45),
        (0.07, 0.6),
        (0.07, 0.88),
        (0.26, 1.0),
        (0.44, 0.86),
        (0.48, 0.46),
        (0.48, 0.85),
        (0.56, 1.0),
      ],
    ],
  ),
  'p': (
    0.56,
    [
      [(0.07, 0.47), (0.07, 0.9), (0.07, 1.38)],
      [
        (0.07, 0.58),
        (0.28, 0.45),
        (0.48, 0.58),
        (0.48, 0.86),
        (0.28, 1.0),
        (0.08, 0.9),
      ],
    ],
  ),
  'w': (
    0.66,
    [
      [
        (0.02, 0.47),
        (0.12, 0.8),
        (0.18, 1.0),
        (0.3, 0.62),
        (0.42, 1.0),
        (0.5, 0.72),
        (0.6, 0.46),
      ],
    ],
  ),
  'e': (
    0.56,
    [
      [
        (0.07, 0.74),
        (0.3, 0.72),
        (0.48, 0.68),
        (0.44, 0.5),
        (0.25, 0.45),
        (0.06, 0.6),
        (0.07, 0.88),
        (0.28, 1.0),
        (0.5, 0.92),
      ],
    ],
  ),
  'u': (
    0.56,
    [
      [
        (0.05, 0.47),
        (0.06, 0.85),
        (0.2, 1.0),
        (0.38, 0.92),
        (0.44, 0.47),
        (0.45, 0.8),
        (0.5, 1.0),
      ],
    ],
  ),
  's': (
    0.5,
    [
      [
        (0.44, 0.5),
        (0.25, 0.45),
        (0.06, 0.54),
        (0.12, 0.7),
        (0.36, 0.77),
        (0.44, 0.92),
        (0.22, 1.0),
        (0.02, 0.93),
      ],
    ],
  ),
  ' ': (0.45, []),
};

/// [sample]'s strokes as page points, messily: jittered control points,
/// each glyph a little rotated, scaled and off the baseline, a slant, and
/// a shaky hand.
List<List<Offset>> _write(_Sample sample) {
  final random = Random(sample.seed);
  double gauss() =>
      sqrt(-2 * log(1 - random.nextDouble())) *
      cos(2 * pi * random.nextDouble());
  final h = sample.height;
  final strokes = <List<Offset>>[];
  var penX = 60.0;
  var baseline = 300.0;

  void glyph(String char, {double scale = 1, double raise = 0}) {
    final (advance, glyphStrokes) = _glyphs[char]!;
    final s = scale * (1 + 0.07 * sample.mess * gauss());
    final angle = 0.06 * sample.mess * gauss();
    final dy = 0.05 * sample.mess * gauss() * h - raise * h;
    final origin = Offset(penX, baseline - h * s + dy);
    for (final control in glyphStrokes) {
      final jittered = [
        for (final (x, y) in control)
          Offset(
            x + 0.035 * sample.mess * gauss(),
            y + 0.035 * sample.mess * gauss(),
          ),
      ];
      strokes.add([
        for (final p in _catmullRom(jittered))
          () {
            // Rotate about the glyph's middle, then slant
            final c = p - Offset(advance / 2, 0.5);
            final r =
                Offset(
                  c.dx * cos(angle) - c.dy * sin(angle),
                  c.dx * sin(angle) + c.dy * cos(angle),
                ) +
                Offset(advance / 2, 0.5);
            return origin +
                Offset(r.dx - sample.slant * (r.dy - 1), r.dy) * h * s +
                Offset(gauss(), gauss()) * 0.6;
          }(),
      ]);
    }
    penX += (advance + 0.1 + 0.05 * sample.mess * gauss()) * h * s;
    baseline += 0.02 * sample.mess * gauss() * h;
  }

  final text = sample.text;
  for (var i = 0; i < text.length; i++) {
    if (text.startsWith('^', i)) {
      glyph(text[i + 1], scale: 0.55, raise: 0.55);
      i++;
    } else if (text.startsWith('[', i)) {
      // [a/b]: a over a bar over b
      final top = text[i + 1], bottom = text[i + 3];
      final start = penX + 0.1 * h;
      final saved = baseline;
      final middle = saved - 0.5 * h;
      penX = start;
      baseline = middle - 0.12 * h;
      glyph(top, scale: 0.55);
      final width1 = penX - start;
      penX = start;
      baseline = middle + 0.7 * h;
      glyph(bottom, scale: 0.55);
      final width = max(width1, penX - start);
      baseline = saved;
      strokes.add(
        _catmullRom([
          Offset(-0.15, 0.02 * gauss()),
          Offset(width / h * 0.5, 0.03 * gauss()),
          Offset(width / h + 0.05, 0.02 * gauss() - 0.03),
        ]).map((p) => Offset(start + p.dx * h, middle + p.dy * h)).toList(),
      );
      penX = start + width + 0.2 * h;
      i += 4;
    } else if (text[i] == '~') {
      // Tangled loops that aren't letters, kept in a box by turning back
      final centre = Offset(penX + 1.3 * h, baseline - 0.5 * h);
      for (var k = 0; k < 3; k++) {
        var p = centre + Offset(gauss(), gauss()) * 0.3 * h;
        var heading = random.nextDouble() * 2 * pi;
        final points = <Offset>[p];
        for (var j = 0; j < 16; j++) {
          final away = p - centre;
          if (away.dx.abs() > 1.3 * h || away.dy.abs() > 0.6 * h) {
            heading = atan2(-away.dy, -away.dx) + 0.5 * gauss();
          } else {
            heading += 1.2 * gauss();
          }
          p += Offset(cos(heading), sin(heading)) * h * 0.3;
          points.add(p);
        }
        strokes.add(_catmullRom(points));
      }
      penX += 2.8 * h;
    } else {
      glyph(text[i]);
    }
  }
  return strokes;
}

/// A smooth curve through [points], 10 points per span.
List<Offset> _catmullRom(List<Offset> points) {
  if (points.length < 3) {
    return [
      for (var i = 0; i < points.length - 1; i++)
        for (var t = 0; t < 10; t++)
          Offset.lerp(points[i], points[i + 1], t / 10)!,
      points.last,
    ];
  }
  final result = <Offset>[];
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = points[max(0, i - 1)], p1 = points[i];
    final p2 = points[i + 1], p3 = points[min(points.length - 1, i + 2)];
    for (var t = 0; t < 10; t++) {
      final u = t / 10, u2 = u * u, u3 = u2 * u;
      result.add(
        (p1 * 2 +
                (p2 - p0) * u +
                (p0 * 2 - p1 * 5 + p2 * 4 - p3) * u2 +
                (p1 * 3 - p0 - p2 * 3 + p3) * u3) *
            0.5,
      );
    }
  }
  return result..add(points.last);
}
