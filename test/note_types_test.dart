import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/save_indicator.dart';
import 'package:nts/components/toolbar/editor_page_manager.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:nts/pages/editor/flashcard_study.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  FlavorConfig.setup();
  FileManager.documentsDirectory = '$tmpDir/note_types_test/nts';

  setUp(() {
    stows.lastTool.value = .fountainPen;
    Pen.currentPen = Pen.fountainPen();
    stows.editorFingerDrawing.value = false;
    stows.holdToSnapShape.value = false;
    Select.currentSelect.unselect();
  });

  testWidgets('slides are landscape pages', (tester) async {
    final editor = await _pumpEditor(tester, .slides);
    final page = editor.coreInfo.pages.first;
    expect(page.size.aspectRatio, closeTo(16 / 9, 1e-9));
    editor.insertPageAfter(0);
    expect(editor.coreInfo.pages[1].size, page.size);
  });

  testWidgets('flashcards come in fronts and backs, with a blank card', (
    tester,
  ) async {
    final editor = await _pumpEditor(tester, .flashcards);
    final pages = editor.coreInfo.pages;
    expect(pages, hasLength(2)); // one blank card
    expect(pages.first.size.aspectRatio, closeTo(1 / 0.6, 1e-9));

    // Writing on the front adds a blank card after it
    await _stylus(tester, editor, 0, const [
      Offset(100, 100),
      Offset(300, 200),
    ]);
    expect(pages, hasLength(4));
    // and erasing it leaves one blank card again
    editor.undo();
    await tester.pump();
    expect(pages, hasLength(2));

    // "Add a card" adds a front and a back after the card in view
    editor.insertPageAfter(1);
    expect(pages, hasLength(4));
  });

  testWidgets('undo and redo keep cards in pairs', (tester) async {
    final editor = await _pumpEditor(tester, .flashcards);
    final pages = editor.coreInfo.pages;
    await _stylus(tester, editor, 0, const [
      Offset(100, 100),
      Offset(300, 200),
    ]);
    editor.insertPageAfter(1); // a second card
    expect(pages, hasLength(6));
    final front = pages[0], back = pages[1];

    // Deleting a card, then undoing it, brings back its front and back
    final manager = editor.pageManager(editor.context) as EditorPageManager;
    manager.deletePage(0);
    expect(pages, hasLength(4));
    editor.undo();
    expect(pages, hasLength(6));
    expect(pages.take(2), [front, back]);
    editor.redo();
    expect(pages, hasLength(4));
    expect(pages, isNot(contains(front)));
    editor.undo();

    // Adding a card, undone and redone
    editor.insertPageAfter(1);
    expect(pages, hasLength(8));
    editor.undo();
    expect(pages, hasLength(6));
    editor.redo();
    expect(pages, hasLength(8));
  });

  testWidgets('changes outside the undo history are saved too', (tester) async {
    final editor = await _pumpEditor(tester, .pages);
    expect(editor.savingState.value, SavingState.saved);
    // e.g. pages reordered in the page manager
    (editor.pageManager(editor.context) as EditorPageManager).redrawAndSave();
    expect(editor.savingState.value, SavingState.waitingToSave);
    editor.cancelAutosaveAndMarkSaved();
  });

  testWidgets('an endless page grows as you write near its bottom', (
    tester,
  ) async {
    final editor = await _pumpEditor(tester, .endless);
    final page = editor.coreInfo.pages.single;
    final height = page.size.height;
    page.strokes.add(
      Stroke(
        color: Colors.black,
        pressureEnabled: false,
        options: Pen.ballpointPenOptions..isComplete = true,
        pageIndex: 0,
        page: page,
        toolId: .ballpointPen,
      )..addPoints([Offset(100, height - 200), Offset(300, height - 150)]),
    );
    editor.createPage(0);
    expect(editor.coreInfo.pages, hasLength(1));
    expect(page.size.height, greaterThan(height + 1000));
    expect(page.size.width, EditorPage.defaultWidth);
    editor.insertPageAfter(0); // just the one page
    expect(editor.coreInfo.pages, hasLength(1));
  });

  testWidgets('a whiteboard is one big board that opens in its middle', (
    tester,
  ) async {
    final editor = await _pumpEditor(tester, .whiteboard);
    final page = editor.coreInfo.pages.single;
    expect(page.isBoard, isTrue);
    expect(page.size, NoteType.whiteboard.pageSize);
    expect(page.sideWidth, 0);
    // The middle of the board is the middle of the screen
    final middle = page.renderBox!.localToGlobal(page.size.center(Offset.zero));
    expect(middle.dx, closeTo(600, 2));
    expect(middle.dy, closeTo(800, 120));

    // It draws where it's touched, 1:1, and adds no pages
    await _stylus(tester, editor, 0, [
      page.size.center(Offset.zero),
      page.size.center(const Offset(80, 40)),
    ]);
    expect(page.strokes, hasLength(1));
    expect(editor.coreInfo.pages, hasLength(1));
    expect(page.strokes.single.bounds.width, closeTo(80, 1));
  });

  test('the kind of note is saved', () {
    final coreInfo = EditorCoreInfo(filePath: '/cards', noteType: .flashcards)
      ..pages = [];
    coreInfo.addBlankEnd();
    final (json, _) = coreInfo.toJson();
    expect(json['nt'], 'flashcards');
    final loaded = EditorCoreInfo.fromJson(
      json,
      filePath: '/cards',
      onlyFirstPage: false,
    );
    expect(loaded.noteType, NoteType.flashcards);
    expect(loaded.pages, hasLength(2));
    final (pagesJson, _) = EditorCoreInfo(filePath: '/plain').toJson();
    expect(pagesJson.containsKey('nt'), isFalse);
  });

  testWidgets('studying flips a card to its back', (tester) async {
    final coreInfo = EditorCoreInfo(filePath: '/study', noteType: .flashcards)
      ..pages = [];
    coreInfo.addBlankEnd();
    coreInfo.pages[0].textBoxes = const [
      PageTextBox(
        id: 0,
        position: Offset(100, 100),
        width: 500,
        text: 'Question',
      ),
    ];
    coreInfo.pages[1].textBoxes = const [
      PageTextBox(
        id: 0,
        position: Offset(100, 100),
        width: 500,
        text: 'Answer',
      ),
    ];
    coreInfo.addBlankEnd(); // a blank card, which isn't studied
    expect(FlashcardStudy.cardsOf(coreInfo), [0]);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(home: FlashcardStudy(coreInfo: coreInfo)),
      ),
    );
    expect(find.text('Question'), findsOneWidget);
    expect(find.text('Answer'), findsNothing);
    await tester.tap(find.text(t.nts.flashcards.showBack));
    await tester.pumpAndSettle();
    expect(find.text('Answer'), findsOneWidget);
    expect(find.text('Question'), findsNothing);
  });
}

Future<EditorState> _pumpEditor(WidgetTester tester, NoteType type) async {
  tester.view
    ..physicalSize = const Size(1200, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Editor(
        path: '/note_types_${tester.testDescription.hashCode}',
        noteType: type,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  final editor = tester.state<EditorState>(find.byType(Editor));
  addTearDown(editor.cancelAutosaveAndMarkSaved);
  expect(editor.coreInfo.noteType, type);
  return editor;
}

Future<void> _stylus(
  WidgetTester tester,
  EditorState editor,
  int pageIndex,
  List<Offset> points,
) async {
  final box = editor.coreInfo.pages[pageIndex].renderBox!;
  final gesture = await tester.createGesture(kind: PointerDeviceKind.stylus);
  await gesture.down(box.localToGlobal(points.first));
  for (final point in points.skip(1)) {
    await gesture.moveTo(box.localToGlobal(point));
  }
  await gesture.up();
  await tester.pump();
}
