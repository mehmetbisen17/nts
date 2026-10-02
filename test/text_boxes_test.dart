import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/canvas/_asset_cache.dart';
import 'package:nts/components/canvas/text_boxes.dart';
import 'package:nts/components/toolbar/top_bar.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  FlavorConfig.setup();
  FileManager.documentsDirectory = '$tmpDir/text_boxes_test/nts';

  setUp(() {
    stows.lastTool.value = .fountainPen;
    Pen.currentPen = Pen.fountainPen();
    stows.editorFingerDrawing.value = false;
    Select.currentSelect.unselect();
    TextBoxes.color = null;
  });

  testWidgets('a tap starts a box to type in; undo and redo it', (
    tester,
  ) async {
    final editor = await _pumpEditor(tester);
    final page = editor.coreInfo.pages.first;
    editor.toggleTextEditing();
    await tester.pump();

    await tester.tapAt(
      _global(editor, const Offset(300, 400)),
      kind: PointerDeviceKind.stylus, // a finger pans, unless it draws
    );
    await tester.pump();
    await tester.pump();
    expect(page.textBoxes, hasLength(1));
    final box = page.textBoxes.single;
    expect(box.position.dx, 300);
    expect(TextBoxes.focused.value, (0, box.id));

    await tester.enterText(_boxField, 'hello');
    await tester.pump();
    expect(page.textBoxes.single.text, 'hello');

    // Putting the Text tool down ends typing: one step to undo
    editor.toggleTextEditing();
    await tester.pump();
    await tester.pump();
    expect(page.textBoxes.single.text, 'hello');
    expect(find.text('hello'), findsOneWidget); // as plain text now
    editor.undo();
    expect(page.textBoxes, isEmpty);
    editor.redo();
    expect(page.textBoxes.single.text, 'hello');
  });

  testWidgets('an empty box goes away', (tester) async {
    final editor = await _pumpEditor(tester);
    final page = editor.coreInfo.pages.first;
    editor.toggleTextEditing();
    await tester.pump();
    await tester.tapAt(
      _global(editor, const Offset(300, 400)),
      kind: PointerDeviceKind.stylus, // a finger pans, unless it draws
    );
    await tester.pump();
    await tester.pump();
    expect(page.textBoxes, hasLength(1));
    editor.toggleTextEditing();
    await tester.pump();
    await tester.pump();
    expect(page.textBoxes, isEmpty);
    expect(editor.history.canUndo, isFalse);
  });

  testWidgets('the grip moves a box with a finger, while typing', (
    tester,
  ) async {
    final editor = await _pumpEditor(tester);
    final page = editor.coreInfo.pages.first;
    editor.toggleTextEditing();
    await tester.pump();
    await tester.tapAt(
      _global(editor, const Offset(300, 400)),
      kind: PointerDeviceKind.stylus, // a finger pans, unless it draws
    );
    await tester.pump();
    await tester.pump();
    await tester.enterText(_boxField, 'move me');
    await tester.pump();
    final before = page.textBoxes.single.position;

    final grip = find.byTooltip(t.nts.textBox.move);
    expect(grip, findsOneWidget);
    await tester.drag(
      grip,
      const Offset(-200, 120),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    final after = page.textBoxes.single.position;
    expect(after.dx, closeTo(before.dx - 200, 1));
    expect(after.dy, closeTo(before.dy + 120, 1));
    // Still typing
    expect(TextBoxes.focused.value, isNotNull);
    expect(page.strokes, isEmpty);

    // Off the page to the left: it stays beside it
    await tester.drag(grip, const Offset(-150, 0));
    await tester.pump();
    expect(page.textBoxes.single.position.dx, lessThan(0));
  });

  testWidgets('tapping elsewhere, without typing, moves the new box there', (
    tester,
  ) async {
    final editor = await _pumpEditor(tester);
    final page = editor.coreInfo.pages.first;
    editor.toggleTextEditing();
    await tester.pump();
    for (final at in const [Offset(300, 400), Offset(300, 700)]) {
      await tester.tapAt(_global(editor, at), kind: PointerDeviceKind.stylus);
      await tester.pump();
      await tester.pump();
      expect(page.textBoxes, hasLength(1));
      expect(page.textBoxes.single.position.dx, 300);
      expect(TextBoxes.focused.value, (0, page.textBoxes.single.id));
    }
    // A colour picked between boxes is for the next one
    editor.toggleTextEditing();
    await tester.pump();
    editor.toggleTextEditing();
    await tester.pump();
    expect(TextBoxes.focused.value, isNull);
    tester.widget<EditorTopBar>(find.byType(EditorTopBar)).setColor(Colors.red);
    await tester.pump();
    expect(TextBoxes.color, Colors.red);
  });

  testWidgets('a tap beside the page starts a box beside it', (tester) async {
    final editor = await _pumpEditor(tester);
    final page = editor.coreInfo.pages.first;
    editor.toggleTextEditing();
    await tester.pump();
    await tester.tapAt(
      _global(editor, const Offset(1050, 400)),
      kind: PointerDeviceKind.stylus, // a finger pans, unless it draws
    );
    await tester.pump();
    await tester.pump();
    expect(page.textBoxes.single.position.dx, greaterThan(1000));
  });

  test('old typed text becomes a text box, and boxes are saved', () {
    final page = EditorPage();
    page.quill.controller.document.insert(0, 'Typed the old way');
    final json = {
      'v': 20,
      'l': 40,
      'z': [page.toJson(_assets)],
    };
    final coreInfo = EditorCoreInfo.fromJson(
      json,
      filePath: '/old',
      onlyFirstPage: false,
    );
    final converted = coreInfo.pages.first;
    expect(converted.quill.controller.document.isEmpty(), isTrue);
    final box = converted.textBoxes.single;
    expect(box.text, 'Typed the old way');
    expect(box.position, const Offset(20, 48));
    expect(box.fontSize, 28);

    final (saved, _) = coreInfo.toJson();
    final loaded = EditorCoreInfo.fromJson(
      saved,
      filePath: '/old',
      onlyFirstPage: false,
    );
    expect(loaded.pages.first.textBoxes, [box]);
  });
}

final _assets = OrderedAssetCache();

final _boxField = find.descendant(
  of: find.byType(TextBoxLayer),
  matching: find.byType(TextField),
);

Future<EditorState> _pumpEditor(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1200, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Editor(path: '/text_boxes_${tester.testDescription.hashCode}'),
    ),
  );
  await tester.pump();
  final editor = tester.state<EditorState>(find.byType(Editor));
  addTearDown(editor.cancelAutosaveAndMarkSaved);
  expect(editor.currentTool, isNot(Tool.textEditing));
  return editor;
}

Offset _global(EditorState editor, Offset local) =>
    editor.coreInfo.pages.first.renderBox!.localToGlobal(local);
