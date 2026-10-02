import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/ai/ai_chart.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/services/plot_spec.dart';

import 'higan_snapshot_util.dart';

/// Visual check: `HIGAN_SNAPSHOT=1 flutter test test/ai_chart_test.dart`
/// writes ai_chart_*.png to [higanSnapshotDir].
void main() {
  final specs = <String, PlotSpec>{
    'function': FunctionPlot(
      title: 'Roots of a parabola',
      expression: 'x^2 - 4x + 3',
      xMin: -2,
      xMax: 6,
      xLabel: 'x',
      yLabel: 'y',
    ),
    'bar': const DataPlot(
      title: 'Rainfall by month',
      kind: .bar,
      xLabel: 'Month',
      yLabel: 'mm',
      points: [
        ('Jan', 78),
        ('Feb', 52),
        ('Mar', 61),
        ('Apr', 44),
        ('May', 39),
        ('Jun', 22),
      ],
    ),
    'line': const DataPlot(
      title: 'Population of Lyon',
      kind: .line,
      xLabel: 'Year',
      yLabel: 'Thousands',
      points: [
        ('1990', 415),
        ('2000', 445),
        ('2010', 484),
        ('2015', 513),
        ('2020', 522),
      ],
    ),
    'damped': FunctionPlot(
      title: 'Damped oscillation',
      expression: 'e^{-0.2t} * cos(2t)',
      xMin: 0,
      xMax: 10,
      xLabel: 't (s)',
      yLabel: 'Displacement',
    ),
    'reciprocal': FunctionPlot(
      title: 'y = 1/x',
      expression: '1/x',
      xMin: -5,
      xMax: 5,
    ),
    'negative_bars': const DataPlot(
      title: 'Profit per quarter',
      kind: .bar,
      points: [('Q1', 1200), ('Q2', -350), ('Q3', 800), ('Q4', 2150.5)],
    ),
  };

  testWidgets('AiChart paints every kind in both themes', (tester) async {
    for (final brightness in Brightness.values) {
      for (final spec in specs.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Center(child: SizedBox(width: 360, child: AiChart(spec))),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(AiChart)), const Size(360, 240));
      }
    }
  });

  testWidgets('renderPng makes a PNG of the requested size', (tester) async {
    final png = (await tester.runAsync(
      () => AiChart.renderPng(specs['bar']!, size: const Size(300, 200)),
    ))!;
    // Signature, then IHDR width and height.
    expect(png.sublist(1, 4), 'PNG'.codeUnits);
    final header = ByteData.sublistView(png, 16, 24);
    expect(header.getUint32(0), 300);
    expect(header.getUint32(4), 200);
  });

  group('snapshots', skip: !higanSnapshotsEnabled, () {
    for (final brightness in Brightness.values) {
      final mode = brightness == .dark ? 'night' : 'paper';
      testWidgets('widget $mode', (tester) async {
        await higanSnapshot(
          tester,
          name: 'ai_chart_$mode',
          brightness: brightness,
          size: const Size(1500, 760),
          child: _Sheet(specs.values.toList()),
        );
      });
    }

    testWidgets('renderPng', (tester) async {
      // Loads the fonts.
      await higanSnapshot(
        tester,
        name: 'ai_chart_fonts',
        size: const Size(10, 10),
        child: const SizedBox(),
      );
      for (final name in ['function', 'bar', 'line', 'damped', 'reciprocal']) {
        await tester.runAsync(() async {
          final png = await AiChart.renderPng(specs[name]!);
          await File('$higanSnapshotDir/ai_chart_png_$name.png')
              .writeAsBytes(png);
        });
      }
    });
  });
}

/// The charts on sheet-colored cards, three to a row.
class _Sheet extends StatelessWidget {
  const new(this.specs);

  final List<PlotSpec> specs;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return ColoredBox(
      color: c.bg,
      child: Padding(
        padding: const .all(20),
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            for (final spec in specs)
              Container(
                width: 466,
                padding: const .all(8),
                decoration: BoxDecoration(
                  color: c.surface1,
                  borderRadius: const .all(.circular(HiganRadius.card)),
                  border: Border.all(color: c.hairline),
                ),
                child: AiChart(spec),
              ),
          ],
        ),
      ),
    );
  }
}
