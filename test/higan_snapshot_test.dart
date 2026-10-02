import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/higan/higan_lily.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';

import 'higan_snapshot_util.dart';

/// Renders the Higan foundation widgets to PNGs for visual checks:
/// `HIGAN_SNAPSHOT=1 flutter test test/higan_snapshot_test.dart`
void main() {
  for (final brightness in Brightness.values) {
    final mode = brightness == .dark ? 'night' : 'paper';

    testWidgets('home $mode', skip: !higanSnapshotsEnabled, (tester) async {
      await higanSnapshot(
        tester,
        name: 'foundation_home_$mode',
        brightness: brightness,
        child: const _HomeSink(),
      );
    });

    testWidgets('widgets $mode', skip: !higanSnapshotsEnabled, (tester) async {
      await higanSnapshot(
        tester,
        name: 'foundation_widgets_$mode',
        brightness: brightness,
        size: const Size(1180, 900),
        child: const _WidgetSink(),
      );
    });

    testWidgets('lily $mode', skip: !higanSnapshotsEnabled, (tester) async {
      await higanSnapshot(
        tester,
        name: 'foundation_lily_$mode',
        brightness: brightness,
        size: const Size(420, 420),
        child: const Center(child: HiganLily(size: 330, variant: .hero)),
      );
    });
  }

  for (final ms in const [300, 800, 1400, 2800]) {
    testWidgets('loading ${ms}ms', skip: !higanSnapshotsEnabled, (
      tester,
    ) async {
      await higanSnapshot(
        tester,
        name: 'foundation_loading_$ms',
        size: const Size(200, 200),
        settle: Duration(milliseconds: ms),
        child: const HiganLoading(size: 120),
      );
    });
  }
}

class _HomeSink extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return Stack(
      children: [
        const HiganEmber(),
        Padding(
          padding: const .fromLTRB(40, 26, 40, 0),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Row(
                children: [
                  const HiganMark(size: 26),
                  const Spacer(),
                  HiganTabs(
                    labels: const ['Recent', 'Folders', 'Whiteboard'],
                    selectedIndex: 1,
                    onSelected: (_) {},
                  ),
                  const Spacer(),
                  HiganCircleButton(
                    icon: Symbols.settings,
                    tooltip: 'Settings',
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 44),
              const Row(
                crossAxisAlignment: .end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: 10,
                      children: [
                        HiganLabel('Library · 6 folders · 47 notes'),
                        HiganTitle('Folders'),
                      ],
                    ),
                  ),
                  HiganViewSwitch(path: '/'),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                spacing: 22,
                crossAxisAlignment: .start,
                children: [
                  for (var i = 0; i < 5; i++)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          HiganPaperThumb(
                            aspectRatio: HiganPaperThumb.galleryAspectRatio,
                            child: CustomPaint(painter: _FakeNote(i)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            const [
                              'Linear algebra',
                              'Eigenvalues',
                              'Series',
                              'Proofs',
                              'Probability',
                            ][i],
                            style: HiganText.body(context),
                          ),
                          const SizedBox(height: 5),
                          HiganLabel(
                            '${higanRelativeTime(DateTime.now().subtract(Duration(hours: 2 + i * 20)))} · ${i + 2} pages',
                            size: 10,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 30),
              for (var i = 0; i < 2; i++)
                HiganListRow(
                  topBorder: i == 0,
                  selected: i == 1,
                  onTap: () {},
                  leading: SizedBox(
                    width: 44,
                    height: 57,
                    child: HiganPaperThumb(
                      radius: 3,
                      shadow: false,
                      child: CustomPaint(painter: _FakeNote(i + 7)),
                    ),
                  ),
                  title: const ['Waves', 'Thermodynamics', 'Optics'][i],
                  trailing: [
                    SizedBox(width: 140, child: HiganLabel('${i + 1} pages')),
                    const SizedBox(width: 150, child: HiganLabel('Yesterday')),
                  ],
                ),
            ],
          ),
        ),
        Positioned(
          right: 30,
          bottom: 34,
          child: HiganFab(onPressed: () {}, tooltip: 'New note'),
        ),
        Positioned(
          left: 40,
          bottom: 30,
          child: Row(
            spacing: 8,
            children: [
              SizedBox.square(
                dimension: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.stamen, shape: .circle),
                ),
              ),
              const HiganLabel('iCloud · synced'),
            ],
          ),
        ),
      ],
    );
  }
}

class _WidgetSink extends StatefulWidget {
  const new();

  @override
  State<_WidgetSink> createState() => _WidgetSinkState();
}

class _WidgetSinkState extends State<_WidgetSink> {
  var theme = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    const tools = [
      Symbols.stylus,
      Symbols.ink_highlighter,
      Symbols.ink_eraser,
      Symbols.select,
      Symbols.image,
      Symbols.undo,
      Symbols.redo,
    ];
    return Stack(
      children: [
        const HiganEmber(),
        Padding(
          padding: const .all(32),
          child: Row(
            crossAxisAlignment: .start,
            spacing: 40,
            children: [
              const SizedBox(
                width: 400,
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 20,
                  children: [
                    HiganLabel('Symbol · higanbana'),
                    Center(child: HiganLily(size: 300, variant: .hero)),
                    SizedBox(
                      height: 330,
                      child: HiganEmptyState(
                        title: 'This folder is empty',
                        body: 'Add a note or a folder to begin.',
                        action: FilledButton(
                          onPressed: null,
                          child: Text('New note'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 18,
                  children: [
                    Center(
                      child: HiganPill(
                        child: Row(
                          mainAxisSize: .min,
                          spacing: 12,
                          children: [
                            for (final color in const [
                              Color(0xFF23211F),
                              Color(0xFFD0283A),
                              Color(0xFFE2B46C),
                              Color(0xFF6C8CA8),
                              Color(0xFF7E9B7A),
                            ])
                              SizedBox.square(
                                dimension: 18,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: .circle,
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: 170,
                              child: Slider(value: 0.38, onChanged: (_) {}),
                            ),
                            HiganLabel('3.0', size: 10, color: c.text),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: HiganPill(
                        padding: const .symmetric(horizontal: 10),
                        child: Row(
                          mainAxisSize: .min,
                          spacing: 4,
                          children: [
                            for (var i = 0; i < tools.length; i++)
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: Stack(
                                  alignment: .center,
                                  children: [
                                    Icon(
                                      tools[i],
                                      size: 18,
                                      weight: 300,
                                      color: i == 0 ? c.text : c.textSecondary,
                                    ),
                                    if (i == 0)
                                      Positioned(
                                        bottom: 2,
                                        child: SizedBox.square(
                                          dimension: 4,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: c.higan,
                                              shape: .circle,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const HiganLabel('Appearance'),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: .dark, label: Text('NIGHT')),
                        ButtonSegment(value: .light, label: Text('PAPER')),
                        ButtonSegment(value: .system, label: Text('SYSTEM')),
                      ],
                      selected: {theme},
                      onSelectionChanged: (s) =>
                          setState(() => theme = s.first),
                    ),
                    HiganSegmented<bool>(
                      value: false,
                      onChanged: (_) {},
                      segments: const [
                        HiganSegment(value: false, label: 'Paper'),
                        HiganSegment(value: true, label: 'Black'),
                      ],
                    ),
                    const Divider(),
                    SwitchListTile(
                      value: true,
                      onChanged: (_) {},
                      title: const Text('Finger drawing'),
                      subtitle: const Text('Draw with your finger'),
                    ),
                    SwitchListTile(
                      value: false,
                      onChanged: (_) {},
                      title: const Text('Auto straighten lines'),
                    ),
                    Switch.adaptive(value: true, onChanged: (_) {}),
                    const Divider(),
                    const SizedBox(
                      width: 320,
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Folder name',
                          hintText: 'Mathematics',
                        ),
                      ),
                    ),
                    Row(
                      spacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Symbols.add, size: 16),
                          label: const Text('New note'),
                        ),
                        OutlinedButton(
                          onPressed: () {},
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Rename'),
                        ),
                        Checkbox(value: true, onChanged: (_) {}),
                        Checkbox(value: false, onChanged: (_) {}),
                        RadioGroup<int>(
                          groupValue: 0,
                          onChanged: (_) {},
                          child: const Row(
                            children: [Radio(value: 0), Radio(value: 1)],
                          ),
                        ),
                      ],
                    ),
                    const LinearProgressIndicator(value: 0.4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A rough imitation of the mockup's `thumb(seed)` handwriting.
class _FakeNote extends CustomPainter {
  new(this.seed);

  final int seed;

  double _r(int i) {
    final x = math.sin((seed * 17 + i) * 999.13) * 10000;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120);
    Paint ink(Color color, double width) => Paint()
      ..style = .stroke
      ..strokeCap = .round
      ..strokeWidth = width
      ..color = color;
    Path scribble(double y, double w) {
      final path = Path()..moveTo(14, y);
      for (var x = 0.0; x < w; x += w / 4) {
        path.relativeQuadraticBezierTo(
          w / 16,
          -2 + _r(x.toInt()) * 4,
          w / 8,
          0,
        );
        path.relativeQuadraticBezierTo(
          w / 16,
          2 - _r(x.toInt() + 1) * 4,
          w / 8,
          0,
        );
      }
      return path;
    }

    canvas.drawPath(scribble(22, 30), ink(const Color(0xFF23211F), 1.6));
    var y = 38.0;
    final n = 3 + (_r(2) * 4).floor();
    for (var i = 0; i < n; i++, y += 11) {
      canvas.drawPath(
        scribble(y, 50 + _r(i + 3) * 44),
        ink(const Color(0xFF3A3734), 1),
      );
    }
    if (seed.isEven) {
      canvas.drawCircle(
        Offset(40 + _r(21) * 40, y + 30),
        12 + _r(22) * 8,
        ink(const Color(0xFFD0283A), 1.3),
      );
    }
    for (var i = 0; i < 3; i++) {
      canvas.drawPath(
        scribble(y + 66 + i * 11, 40 + _r(i + 30) * 50),
        ink(const Color(0xFF3A3734), 1),
      );
    }
  }

  @override
  bool shouldRepaint(_FakeNote old) => old.seed != seed;
}
