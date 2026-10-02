import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/canvas/_circle_stroke.dart';
import 'package:nts/components/canvas/_rectangle_stroke.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/editor/editor_history.dart';
import 'package:nts/data/extensions/point_extensions.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/eraser.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:sbn/has_size.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

const _page = HasSize(Size(1000, 1000));

Stroke _line(
  List<PointVector> points, {
  double size = 1,
  ToolId toolId = .fountainPen,
  StrokeOptions? options,
}) => Stroke(
  color: Colors.red,
  pressureEnabled: true,
  options: (options ?? StrokeOptions())
    ..size = size
    ..simulatePressure = false
    ..isComplete = true,
  pageIndex: 0,
  page: _page,
  toolId: toolId,
)..points.addAll(points);

List<List<PointVector>>? _split(
  List<PointVector> points,
  Offset center,
  double radius, {
  Offset? from,
}) => Stroke.splitPolyline(points, from ?? center, center, (_) => radius);

void main() {
  setUpAll(FlavorConfig.setup);

  group('splitPolyline', () {
    test('cuts a hole in the middle of one long segment', () {
      final runs = _split(
        const [PointVector(0, 50, 0), PointVector(100, 50, 1)],
        const Offset(50, 50),
        10,
      )!;
      expect(runs, hasLength(2));
      expect(runs[0].first, const PointVector(0, 50, 0));
      expect(runs[0].last.dx, closeTo(40, 1e-9));
      expect(runs[0].last.pressure, closeTo(0.4, 1e-9));
      expect(runs[1].first.dx, closeTo(60, 1e-9));
      expect(runs[1].first.pressure, closeTo(0.6, 1e-9));
      expect(runs[1].last, const PointVector(100, 50, 1));
    });

    test('cuts a segment passing between far-apart vertices, on the '
        'circle boundary', () {
      const center = Offset(50, 50);
      final runs = _split(
        const [PointVector(0, 56), PointVector(100, 56)],
        center,
        10,
      )!;
      expect(runs, hasLength(2));
      for (final cut in [runs[0].last, runs[1].first]) {
        expect((cut - center).distance, closeTo(10, 1e-9));
      }
    });

    test('removes a stroke fully inside the eraser', () {
      expect(
        _split(
          const [PointVector(48, 50), PointVector(52, 50), PointVector(50, 53)],
          const Offset(50, 50),
          10,
        ),
        isEmpty,
      );
    });

    test('leaves tangent and outside strokes untouched', () {
      const center = Offset(50, 50);
      expect(
        _split(const [PointVector(0, 60), PointVector(100, 60)], center, 10),
        isNull,
        reason: 'tangent',
      );
      expect(
        _split(const [PointVector(0, 80), PointVector(100, 80)], center, 10),
        isNull,
        reason: 'outside',
      );
    });

    test('handles dots', () {
      expect(
        _split(const [PointVector(52, 50)], const Offset(50, 50), 10),
        isEmpty,
      );
      expect(
        _split(const [PointVector(70, 50)], const Offset(50, 50), 10),
        isNull,
      );
    });

    test('sweeps the eraser between positions', () {
      // Neither eraser position is near the stroke, but the path between is
      final runs = _split(
        const [PointVector(50, 0), PointVector(50, 100)],
        const Offset(100, 50),
        10,
        from: const Offset(0, 50),
      )!;
      expect(runs, hasLength(2));
      expect(runs[0].last.dy, closeTo(40, 1e-9));
      expect(runs[1].first.dy, closeTo(60, 1e-9));
    });

    test('keeps a closed loop joined around its start', () {
      const first = PointVector.zero;
      final runs = _split(
        const [
          first,
          PointVector(100, 0),
          PointVector(100, 100),
          PointVector(0, 100),
          first,
        ],
        const Offset(100, 50),
        10,
      )!;
      expect(runs, hasLength(1));
      expect(runs.single.first.dy, closeTo(60, 1e-9));
      expect(runs.single.last.dy, closeTo(40, 1e-9));
      expect(runs.single.where((p) => p == first), hasLength(1));
    });
  });

  group('erasePartially', () {
    test('accounts for stroke thickness', () {
      Stroke stroke() =>
          _line(const [PointVector(0, 50), PointVector(100, 50)], size: 10);
      // 10 (eraser) + 5 (half the stroke) = 15
      const touching = Offset(50, 64), missing = Offset(50, 66);
      expect(stroke().erasePartially(touching, touching, 10), hasLength(2));
      expect(stroke().erasePartially(missing, missing, 10), isNull);
    });

    test('fragments keep the stroke properties, and cut ends lose taper', () {
      final original = _line(
        const [PointVector(0, 50, 0.2), PointVector(100, 50, 0.8)],
        toolId: .pencil,
        options: Pen.pencilOptions,
      )..pageIndex = 3;
      final fragments = original.erasePartially(
        const Offset(50, 50),
        const Offset(50, 50),
        10,
      )!;
      expect(fragments, hasLength(2));
      for (final fragment in fragments) {
        expect(fragment.color, original.color);
        expect(fragment.toolId, ToolId.pencil);
        expect(fragment.pressureEnabled, original.pressureEnabled);
        expect(fragment.pageIndex, 3);
        expect(fragment.options.size, original.options.size);
        expect(fragment.options.thinning, original.options.thinning);
      }
      expect(fragments[0].options.start.taperEnabled, isTrue);
      expect(fragments[0].options.end.taperEnabled, isFalse);
      expect(fragments[1].options.start.taperEnabled, isFalse);
      expect(fragments[1].options.end.taperEnabled, isTrue);

      // The missing taper survives saving and loading
      final loaded = Stroke.fromJson(
        fragments[0].toJson(),
        fileVersion: 20,
        pageIndex: 3,
        page: _page,
      );
      expect(loaded.options.start.taperEnabled, isTrue);
      expect(loaded.options.end.taperEnabled, isFalse);
      expect(loaded.length, fragments[0].length);
    });

    test('drops tiny fragments', () {
      final stroke = _line(const [PointVector.zero, PointVector(10.02, 0)]);
      // 9.5 + 0.5 = 10: leaves 0.02 which is too small to keep
      expect(stroke.erasePartially(Offset.zero, Offset.zero, 9.5), isEmpty);
    });

    test('saves simulated pressure into the fragments', () {
      final stroke = Stroke(
        color: Colors.black,
        pressureEnabled: true,
        options: StrokeOptions(size: 5, isComplete: true),
        pageIndex: 0,
        page: _page,
        toolId: .fountainPen,
      )..addPoints([for (double x = 0; x <= 100; x += 2) Offset(x, x / 3)]);
      expect(stroke.options.simulatePressure, isTrue);
      final fragments = stroke.erasePartially(
        const Offset(50, 17),
        const Offset(50, 17),
        5,
      )!;
      expect(fragments, hasLength(2));
      for (final fragment in fragments) {
        expect(fragment.options.simulatePressure, isFalse);
        expect(
          fragment.toJson()['p'],
          everyElement(predicate((p) => (p as dynamic).byteList.length == 12)),
          reason: 'every point should have a pressure',
        );
      }
    });

    test('turns an erased circle into an arc', () {
      final circle = CircleStroke(
        color: Colors.blue,
        pressureEnabled: false,
        options: Pen.shapePenOptions,
        pageIndex: 0,
        page: _page,
        toolId: .shapePen,
        center: const Offset(100, 100),
        radius: 50,
      );
      final fragments = circle.erasePartially(
        const Offset(150, 100),
        const Offset(150, 100),
        10,
      )!;
      expect(fragments, hasLength(1));
      final arc = fragments.single;
      expect(arc, isNot(isA<CircleStroke>()));
      expect(arc.toolId, ToolId.shapePen);
      expect(arc.toJson()['shape'], isNull);
      expect(arc.bounds.left, closeTo(50, 0.1));
      expect(arc.bounds.right, lessThan(150));
    });

    test('turns an erased rectangle into a polyline', () {
      final rect = RectangleStroke(
        color: Colors.blue,
        pressureEnabled: false,
        options: Pen.shapePenOptions,
        pageIndex: 0,
        page: _page,
        toolId: .shapePen,
        rect: const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(
        rect.erasePartially(const Offset(50, 50), const Offset(50, 50), 10),
        isNull,
        reason: 'the inside of the rectangle is empty',
      );
      final fragments = rect.erasePartially(
        const Offset(50, 0),
        const Offset(50, 0),
        10,
      )!;
      expect(fragments, hasLength(1));
      expect(fragments.single.bounds, const Rect.fromLTWH(0, 0, 100, 100));
    });

    test('keeps the corners of an old shape with streamline', () {
      // Old shapes and shape pen options can load with streamline 0.5
      final rect = RectangleStroke(
        color: Colors.blue,
        pressureEnabled: false,
        options: StrokeOptions(size: 5),
        pageIndex: 0,
        page: _page,
        toolId: .shapePen,
        rect: const Rect.fromLTWH(0, 0, 200, 100),
      );
      final fragment = rect
          .erasePartially(const Offset(100, 0), const Offset(100, 0), 10)!
          .single;
      expect(fragment.options.streamline, 0);
      expect(fragment.options.smoothing, 0);
      final outline = fragment.highQualityPolygon;
      for (final corner in const [
        Offset.zero,
        Offset(200, 0),
        Offset(200, 100),
        Offset(0, 100),
      ]) {
        expect(
          outline.map((p) => (p - corner).distance).reduce(min),
          lessThanOrEqualTo(5),
          reason: 'corner $corner',
        );
      }
    });

    test('uses the drawn width at each point', () {
      // size 25, thinning 0.5: half-width 18.75 at pressure 1, 8.75 at 0.2
      Stroke stroke(double pressure) => _line([
        PointVector(0, 50, pressure),
        PointVector(100, 50, pressure),
      ], size: 25);
      const eraser = Offset(50, 50 + 10 + 15.0);
      expect(stroke(1).erasePartially(eraser, eraser, 10), hasLength(2));
      expect(stroke(0.2).erasePartially(eraser, eraser, 10), isNull);
    });

    test('uncut length-based tapers keep the original length', () {
      final stroke = Stroke.fromJson(
        {
          'ty': 'Pencil',
          's': 10.0,
          'ts': -1.0,
          'te': -1.0,
          'sp': false,
          'p': [
            for (double x = 0; x <= 200; x += 10)
              PointVector(x, 50, 0.5).toBsonBinary(),
          ],
        },
        fileVersion: 20,
        pageIndex: 0,
        page: _page,
      );
      expect(stroke.options.start.customTaper, isNull);
      final fragments = stroke.erasePartially(
        const Offset(100, 50),
        const Offset(100, 50),
        5,
      )!;
      expect(fragments, hasLength(2));
      expect(fragments[0].options.start.customTaper, closeTo(200, 1e-9));
      expect(fragments[0].options.end.taperEnabled, isFalse);
      expect(fragments[1].options.start.taperEnabled, isFalse);
      expect(fragments[1].options.end.customTaper, closeTo(200, 1e-9));
    });
  });

  group('Eraser in partial mode', () {
    setUp(() => stows.eraserMode.value = .partial);
    tearDown(() => stows.eraserMode.value = .stroke);

    test('replaces strokes in place and records one net change', () {
      final a = _line(const [PointVector.zero, PointVector(10, 0)]);
      final b = _line(const [PointVector(0, 50), PointVector(100, 50)]);
      final c = _line(const [PointVector(0, 90), PointVector(10, 90)]);
      final strokes = [a, b, c];

      final eraser = Eraser(size: 5);
      eraser.erase(const Offset(30, 50), strokes);
      expect(strokes, hasLength(4));
      expect(strokes.first, same(a));
      expect(strokes.last, same(c));

      // Cut the second fragment again in the same drag
      eraser.erase(const Offset(70, 50), strokes, from: const Offset(69, 50));
      expect(strokes, hasLength(5));
      final after = List.of(strokes);

      final item = eraser.finishDrag(0)!;
      expect(item.type, EditorHistoryItemType.partialErase);
      final change = item.strokeListChange!;
      expect(change.removed, [(1, b)], reason: 'only the original is removed');
      expect(change.added.map((e) => e.$2), after.sublist(1, 4));

      change.reverse().apply(strokes);
      expect(strokes, orderedEquals([a, b, c]));
      change.apply(strokes);
      expect(strokes, orderedEquals(after));

      expect(eraser.finishDrag(0), isNull, reason: 'state is reset');
    });

    test('a new drag forgets one that never finished', () {
      final a = _line(const [PointVector(0, 50), PointVector(100, 50)]);
      final b1 = _line(const [PointVector(0, 50), PointVector(100, 50)]);
      final b2 = _line(const [PointVector(0, 90), PointVector(100, 90)]);
      final eraser = Eraser(size: 5);
      eraser.erase(const Offset(50, 50), [a]); // no finishDrag

      final strokes = [b1, b2];
      eraser.erase(const Offset(50, 50), strokes);
      final change = eraser.finishDrag(1)!.strokeListChange!;
      expect(change.removed, [(0, b1)]);

      change.reverse().apply(strokes);
      expect(strokes, orderedEquals([b1, b2]));
    });

    test('ignores other changes made mid-drag', () {
      final s = _line(const [PointVector(0, 50), PointVector(100, 50)]);
      final x = _line(const [PointVector(0, 90), PointVector(100, 90)]);
      final strokes = [s];
      final eraser = Eraser(size: 5);
      eraser.erase(const Offset(50, 50), strokes);
      final fragments = List.of(strokes);
      strokes.add(x); // e.g. undo mid-drag

      final change = eraser.finishDrag(0)!.strokeListChange!;
      expect(change.removed, [(0, s)]);
      expect(change.added.map((e) => e.$2), fragments);

      change.reverse().apply(strokes);
      expect(strokes, unorderedEquals([s, x]));
    });
  });

  testWidgets('Editor undoes and redoes a partial erase', (tester) async {
    FileManager.documentsDirectory =
        '$tmpDir/eraserPartial/'
        '${FileManager.appRootDirectoryPrefix}';
    stows.eraserMode.value = .partial;
    addTearDown(() => stows.eraserMode.value = .stroke);

    await tester.pumpWidget(MaterialApp(home: Editor()));
    final state = tester.state<EditorState>(find.byType(Editor));
    addTearDown(state.cancelAutosaveAndMarkSaved);

    final strokes = state.coreInfo.pages[0].strokes;
    final original = [
      _line(const [PointVector(0, 10), PointVector(100, 10)]),
      _line(const [PointVector(0, 50), PointVector(100, 50)]),
      _line(const [PointVector(0, 90), PointVector(100, 90)]),
    ];
    strokes.addAll(original);

    final eraser = Eraser(size: 5);
    eraser.erase(const Offset(50, 0), strokes);
    eraser.erase(const Offset(50, 100), strokes, from: const Offset(50, 0));
    final erased = List.of(strokes);
    expect(erased, hasLength(6));
    state.history.recordChange(eraser.finishDrag(0)!);

    state.undo();
    await tester.pump();
    expect(state.coreInfo.pages[0].strokes, orderedEquals(original));

    state.redo();
    await tester.pump();
    expect(state.coreInfo.pages[0].strokes, orderedEquals(erased));
  });
}
