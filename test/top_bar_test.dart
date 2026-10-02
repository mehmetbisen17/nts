import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/toolbar/color_bar.dart';
import 'package:nts/components/toolbar/size_picker.dart';
import 'package:nts/components/toolbar/top_bar.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/data/tools/eraser.dart';
import 'package:nts/data/tools/laser_pointer.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/i18n/strings.g.dart';

void main() {
  setUpAll(FlavorConfig.setup);

  Color? pickedColor;

  Future<void> pumpTopBar(WidgetTester tester, Tool tool) async {
    pickedColor = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: .topLeft,
            child: SizedBox(
              width: 320, // narrow iPad split view
              child: EditorTopBar(
                currentTool: tool,
                setTool: (_) {},
                setColor: (color) => pickedColor = color,
                readOnly: false,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull); // e.g. overflow
    expect(
      tester.getSize(find.byType(EditorTopBar)).height,
      EditorTopBar.height,
    );
  }

  testWidgets('pen shows colors and size', (tester) async {
    await pumpTopBar(tester, Pen.fountainPen());
    expect(find.byType(ColorBar), findsOneWidget);
    expect(find.byType(SizePicker), findsOneWidget);

    // A color is visible without scrolling, even this narrow
    final black = tester.getRect(find.byTooltip(t.editor.colors.black));
    expect(
      black.right,
      lessThan(tester.getTopLeft(find.byType(SizePicker)).dx),
    );

    final red = find.byTooltip(t.editor.colors.red);
    await tester.ensureVisible(red);
    await tester.tap(red);
    expect(pickedColor, const Color(0xFFD0283A));
  });

  testWidgets('eraser shows mode toggle and size slider', (tester) async {
    stows.eraserMode.value = .stroke;
    await pumpTopBar(tester, Eraser());
    expect(find.byType(ColorBar), findsNothing);
    expect(find.text(t.editor.eraserOptions.wholeLine), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    await tester.tap(find.text(t.editor.eraserOptions.partial));
    await tester.pump();
    expect(stows.eraserMode.value, EraserMode.partial);
    stows.eraserMode.value = .stroke;
  });

  testWidgets('select without selection is empty', (tester) async {
    Select.currentSelect.unselect();
    await pumpTopBar(tester, Select.currentSelect);
    expect(find.byType(ColorBar), findsNothing);
  });

  testWidgets('select with only images has no colors', (tester) async {
    final select = Select.currentSelect
      ..doneSelecting = true
      ..selectResult = SelectResult(
        pageIndex: 0,
        strokes: const [],
        images: const [],
        path: Path(),
      );
    addTearDown(select.unselect);
    await pumpTopBar(tester, select);
    expect(find.byType(ColorBar), findsNothing);
  });

  testWidgets('laser pointer is empty', (tester) async {
    await pumpTopBar(tester, LaserPointer.currentLaserPointer);
    expect(find.byType(ColorBar), findsNothing);
    expect(find.byType(SizePicker), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });
}
