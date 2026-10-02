import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/components/toolbar/customize_toolbar_sheet.dart';
import 'package:nts/components/toolbar/floating_bar.dart';
import 'package:nts/components/toolbar/selection_bar.dart';
import 'package:nts/components/toolbar/toolbar.dart';
import 'package:nts/components/toolbar/toolbar_button.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  setUpAll(FlavorConfig.setup);

  setUp(() {
    stows.editorToolbarItems.value = ToolCatalog.basics;
    stows.editorBarPositions.value = const {};
    stows.editorMinimizedBars.value = const [];
    stows.hideFingerDrawingToggle.value = false;
    stows.editorToolbarAlignment.value = .down;
  });

  List<String> ids() => [for (final item in ToolCatalog.current) item.id];

  group('ToolCatalog', () {
    test('ids are unique and the basics exist', () {
      final all = [for (final item in ToolCatalog.items) item.id];
      expect(all.toSet(), hasLength(all.length));
      expect(all, containsAll(ToolCatalog.basics));
    });

    test('new users get only the basics', () {
      expect(stows.editorToolbarItems.defaultValue, ToolCatalog.basics);
      expect(ids(), [
        'pen',
        'highlighter',
        'eraser',
        'lasso',
        'text',
        'undo',
        'redo',
        'export',
      ]);
    });

    test('ignores unknown and repeated ids', () {
      stows.editorToolbarItems.value = ['fromTheFuture', 'undo', 'pen', 'undo'];
      expect(ids(), ['undo', 'pen']);
    });

    test('add, remove and reorder keep unknown ids', () {
      stows.editorToolbarItems.value = ['pen', 'fromTheFuture', 'undo'];
      ToolCatalog.add('pencil');
      expect(stows.editorToolbarItems.value, [
        'pen',
        'fromTheFuture',
        'undo',
        'pencil',
      ]);
      ToolCatalog.remove('pen');
      expect(ids(), ['undo', 'pencil']);
      ToolCatalog.reorder(1, 0);
      expect(ids(), ['pencil', 'undo']);
      expect(stows.editorToolbarItems.value, contains('fromTheFuture'));
      ToolCatalog.resetToBasics();
      expect(ids(), ToolCatalog.basics);
    });

    test('hides unavailable items', () {
      stows.editorToolbarItems.value = ['pen', 'fingerDrawing'];
      expect(ids(), ['pen', 'fingerDrawing']);
      stows.hideFingerDrawingToggle.value = true;
      expect(ids(), ['pen']);
    });
  });

  test('FloatingBar keeps bars on screen and snaps', () {
    const free = Size(1000, 500);
    FractionalOffset at(double x, double y) =>
        FloatingBar.fractionOf(Offset(x, y), free);
    expect(at(-50, 600), FractionalOffset.bottomLeft);
    expect(at(5, 495), FractionalOffset.bottomLeft); // edges
    expect(at(495, 255), FractionalOffset.center); // middle
    expect(at(250, 100), const FractionalOffset(0.25, 0.2));
    expect(
      FloatingBar.fractionOf(const Offset(10, 10), Size.zero),
      FractionalOffset.center,
    );
  });

  group('editor', () {
    Future<EditorState> pumpEditor(WidgetTester tester) async {
      FileManager.documentsDirectory =
          '$tmpDir/toolbarCustomize/${FileManager.appRootDirectoryPrefix}';
      Pen.currentPen = Pen.fountainPen();
      await tester.pumpWidget(
        TranslationProvider(child: MaterialApp(home: Editor())),
      );
      final state = tester.state<EditorState>(find.byType(Editor));
      addTearDown(state.cancelAutosaveAndMarkSaved);
      await tester.pumpAndSettle();
      return state;
    }

    Finder inToolbar(Finder finder) =>
        find.descendant(of: find.byType(Toolbar), matching: finder);
    final grip = inToolbar(find.byType(FloatingBarGrip));

    testWidgets('shows only the basics', (tester) async {
      await pumpEditor(tester);
      for (final tooltip in [
        t.editor.pens.highlighter,
        t.editor.toolbar.toggleEraser,
        t.editor.toolbar.select,
        t.editor.toolbar.text,
        t.editor.toolbar.undo,
        t.editor.toolbar.redo,
        t.editor.toolbar.export,
      ]) {
        expect(inToolbar(find.byTooltip(tooltip)), findsOneWidget);
      }
      for (final tooltip in [
        t.editor.pens.pencil,
        t.editor.pens.laserPointer,
        t.editor.toolbar.photo,
        t.editor.toolbar.fullscreen,
      ]) {
        expect(inToolbar(find.byTooltip(tooltip)), findsNothing);
      }
    });

    testWidgets('"+" adds a tool', (tester) async {
      await pumpEditor(tester);
      await tester.tap(find.byTooltip(t.editor.customizeToolbar.customize));
      await tester.pumpAndSettle();

      final pencil = find.text(t.editor.pens.pencil);
      await tester.scrollUntilVisible(
        pencil.hitTestable(),
        100,
        scrollable: find
            .descendant(
              of: find.byType(CustomizeToolbarSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(pencil);
      await tester.pumpAndSettle();
      expect(ids().last, 'pencil');
      expect(inToolbar(find.byTooltip(t.editor.pens.pencil)), findsOneWidget);
    });

    testWidgets('long-press removes a tool', (tester) async {
      await pumpEditor(tester);
      await tester.longPress(
        inToolbar(find.byTooltip(t.editor.pens.highlighter)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.editor.customizeToolbar.removeFromToolbar));
      await tester.pumpAndSettle();
      expect(ids(), isNot(contains('highlighter')));
      expect(
        inToolbar(find.byTooltip(t.editor.pens.highlighter)),
        findsNothing,
      );
    });

    testWidgets('minimizes and restores', (tester) async {
      await pumpEditor(tester);
      await tester.tap(inToolbar(find.byType(MinimizeBarButton)));
      await tester.pumpAndSettle();
      expect(stows.editorMinimizedBars.value, ['toolbar']);
      expect(inToolbar(find.byType(MinimizedFloatingBar)), findsOneWidget);
      expect(grip, findsNothing);

      await tester.tap(inToolbar(find.byType(MinimizedFloatingBar)));
      await tester.pumpAndSettle();
      expect(stows.editorMinimizedBars.value, isEmpty);
      expect(grip, findsOneWidget);
    });

    testWidgets('dragging moves the toolbar without drawing', (tester) async {
      final editor = await pumpEditor(tester);
      final strokes = editor.coreInfo.pages.first.strokes;

      await tester.drag(grip, const Offset(-200, -300));
      await tester.pumpAndSettle();
      expect(strokes, isEmpty);
      expect(stows.editorBarPositions.value, contains('toolbar.wide'));
      final pill = tester.getRect(
        inToolbar(find.byType(FloatingBarGrip)).first,
      );
      expect(pill.top, lessThan(300));

      // Drawing still works where the toolbar was
      await tester.timedDragFrom(
        const Offset(300, 560),
        const Offset(50, 0),
        const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();
      expect(strokes, hasLength(1));

      // Double-tap the grip to put it back
      await tester.tap(grip);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(grip);
      await tester.pumpAndSettle();
      expect(stows.editorBarPositions.value, isEmpty);
    });

    testWidgets('on a phone, it wraps between groups into even runs', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      stows.editorToolbarItems.value = [
        ...ToolCatalog.basics,
        'tape',
        'brushPen',
        'ruler',
        'addPage',
      ];
      await pumpEditor(tester);
      final pill = find.ancestor(of: grip, matching: find.byType(HiganPill));
      final runs = find.descendant(of: pill, matching: find.byType(Wrap));
      expect(runs.evaluate().length, inInclusiveRange(2, 3));
      for (final run in runs.evaluate()) {
        expect(
          (run.renderObject! as RenderBox).size.height,
          ToolbarIconButton.size,
          reason: 'each run is one line',
        );
      }
      double top(String tooltip) =>
          tester.getRect(inToolbar(find.byTooltip(tooltip))).top;
      expect(top(t.editor.toolbar.undo), top(t.editor.toolbar.redo));
    });

    testWidgets('minimized, the selection bar still shows', (tester) async {
      await pumpEditor(tester);
      await tester.tap(inToolbar(find.byTooltip(t.editor.toolbar.select)));
      await tester.tap(inToolbar(find.byType(MinimizeBarButton)));
      await tester.pumpAndSettle();
      Select.currentSelect
        ..selectResult = SelectResult(
          pageIndex: 0,
          strokes: [],
          images: [],
          path: Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10)),
        )
        ..doneSelecting = true;
      tester.element(find.byType(Editor)).markNeedsBuild();
      await tester.pumpAndSettle();
      expect(inToolbar(find.byType(MinimizedFloatingBar)), findsOneWidget);
      expect(inToolbar(find.byType(SelectionBar)), findsOneWidget);
      Select.currentSelect.unselect();
    });

    testWidgets('every tool builds; pen types and add page work', (
      tester,
    ) async {
      stows.editorToolbarItems.value = [
        for (final item in ToolCatalog.items) item.id,
      ];
      final editor = await pumpEditor(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(
        inToolbar(find.byTooltip(t.editor.canvasTools.brushPen)),
      );
      await tester.pumpAndSettle();
      expect(Pen.currentPen.toolId, ToolId.brushPen);
      expect(editor.currentTool, Pen.currentPen);

      final pages = editor.coreInfo.pages.length;
      await tester.tap(inToolbar(find.byTooltip(t.editor.menu.insertPage)));
      await tester.pumpAndSettle();
      expect(editor.coreInfo.pages, hasLength(pages + 1));
    });
  });
}
