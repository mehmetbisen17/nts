import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/canvas/_asset_cache.dart';
import 'package:nts/components/canvas/_canvas_painter.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/canvas_image.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:sbn/has_size.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  FlavorConfig.setup();
  FileManager.documentsDirectory = '$tmpDir/side_areas_test/nts';

  setUp(() {
    stows.lastTool.value = .fountainPen;
    Pen.currentPen = Pen.fountainPen();
    stows.editorFingerDrawing.value = false;
    stows.holdToSnapShape.value = false;
    Select.currentSelect.unselect();
  });

  testWidgets('the pen writes beside the page, which gets a card', (
    tester,
  ) async {
    final editor = await _pumpEditor(tester);
    final page = editor.coreInfo.pages.first;
    await _stylus(tester, editor, const [
      Offset(-60, 200),
      Offset(-50, 250),
      Offset(-40, 300),
    ]);
    expect(page.strokes, hasLength(1));
    expect(page.strokes.single.bounds.center.dx, lessThan(0));

    final groups = SideCardsPainter.sideGroups(page);
    expect(groups, hasLength(1));
    expect(groups.single.$1.right, lessThanOrEqualTo(-2));
    expect(groups.single.$1.contains(const Offset(-50, 250)), isTrue);
  });

  testWidgets('a selection moves beside the page, out of the way, and back', (
    tester,
  ) async {
    final editor = await _pumpEditor(tester);
    final page = editor.coreInfo.pages.first;
    final stroke = _stroke(const [Offset(300, 200), Offset(500, 260)]);
    final other = _stroke(const [Offset(300, 220), Offset(400, 230)]);
    page.strokes.addAll([stroke, other]);

    void select(Stroke stroke) {
      editor.currentTool = Select.currentSelect;
      Select.currentSelect
        ..selectResult = SelectResult(
          pageIndex: 0,
          strokes: [stroke],
          images: [],
          path: Path()..addRect(stroke.bounds.inflate(10)),
        )
        ..doneSelecting = true;
    }

    select(stroke);
    editor.moveSelectionToSide(-1);
    final moved = Select.currentSelect.selectionBounds!;
    expect(moved.right, closeTo(-EditorPage.sideGap, 1e-6));
    expect(moved.top, closeTo(198, 1e-6)); // same height
    expect(EditorState.sideOf(moved, page.size), -1);

    // Something else moved there at that height goes further out
    select(other);
    editor.moveSelectionToSide(-1);
    final second = Select.currentSelect.selectionBounds!;
    expect(second.right, lessThan(moved.left));

    // And back onto the page, by the left edge
    select(stroke);
    editor.moveSelectionToSide(1);
    final back = Select.currentSelect.selectionBounds!;
    expect(back.left, closeTo(EditorPage.sideGap, 1e-6));

    // It's one undoable move each time
    editor.undo();
    expect(
      Select.currentSelect.selectionBounds!.right,
      closeTo(-EditorPage.sideGap, 1e-6),
    );
  });

  testWidgets('an image beside the page can be grabbed and moved', (
    tester,
  ) async {
    final editor = await _pumpEditor(tester);
    final page = editor.coreInfo.pages.first;
    final image = _TestImage(dstRect: const Rect.fromLTWH(-90, 300, 80, 80))
      ..newImage = false;
    page.images.add(image);
    editor.currentTool = Select.currentSelect;
    // ignore: invalid_use_of_protected_member
    editor.setState(() {});
    await tester.pump();

    final center = _global(editor, image.dstRect.center);
    await tester.tapAt(center); // activates it
    await tester.pump();
    expect((tester.state(find.byType(CanvasImage)) as dynamic).active, isTrue);
    final gesture = await tester.startGesture(center);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(center + Offset(3.0 * i, 4.0 * i));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    // It follows the finger exactly, from where it went down
    expect(image.dstRect.left, closeTo(-60, 1));
    expect(image.dstRect.top, closeTo(340, 1));

    // Without tapping it first: press and hold, then drag
    await tester.tapAt(center + const Offset(30, 40)); // deselects it
    await tester.pump();
    final press = await tester.startGesture(center + const Offset(30, 40));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    for (var i = 1; i <= 10; i++) {
      await press.moveBy(const Offset(0, -10));
      await tester.pump();
    }
    await press.up();
    await tester.pumpAndSettle();
    expect(image.dstRect.top, closeTo(240, 1));
  });

  test('cards keep ink readable', () {
    const paper = Color(0xFFF4F2ED), accent = Color(0xFFD0283A);
    // Dark ink: the page's own colour (barely tinted)
    final card = SideCardsPainter.cardColor(paper, [Colors.black], accent);
    expect(card.computeLuminance(), greaterThan(0.7));
    // Light ink that was on a dark PDF: a dark card instead
    final dark = SideCardsPainter.cardColor(paper, [Colors.white], accent);
    expect(dark.computeLuminance(), lessThan(0.1));
  });

  test('dropped images go where they land, inside that area', () async {
    final page = EditorPage();
    final photo = (bytes: _pixel, extension: '.png');
    // Beside the page on the left: kept clear of the page
    final left = await EditorState.placeImage(
      page,
      const Offset(-5, 500),
      photo,
    );
    expect(left.right, lessThanOrEqualTo(-EditorPage.sideGap));
    expect(left.center.dy, closeTo(500, 1));
    // On the page: on the page
    final onPage = await EditorState.placeImage(
      page,
      const Offset(500, 10),
      photo,
    );
    expect(onPage.top, greaterThanOrEqualTo(0));
    expect(onPage.left, greaterThanOrEqualTo(0));
    // Beside it on the right
    final right = await EditorState.placeImage(
      page,
      const Offset(1100, 500),
      photo,
    );
    expect(right.left, greaterThanOrEqualTo(1000 + EditorPage.sideGap));
  });
}

Stroke _stroke(List<Offset> points) => Stroke(
  color: Colors.black,
  pressureEnabled: false,
  options: StrokeOptions(size: 4, isComplete: true),
  pageIndex: 0,
  page: const HasSize(Size(1000, 1400)),
  toolId: .fountainPen,
)..addPoints(points);

Future<EditorState> _pumpEditor(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1200, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Editor(path: '/side_areas_${tester.testDescription.hashCode}'),
    ),
  );
  await tester.pump();
  final editor = tester.state<EditorState>(find.byType(Editor));
  addTearDown(editor.cancelAutosaveAndMarkSaved);
  return editor;
}

Offset _global(EditorState editor, Offset local) =>
    editor.coreInfo.pages.first.renderBox!.localToGlobal(local);

Future<void> _stylus(
  WidgetTester tester,
  EditorState editor,
  List<Offset> points,
) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.stylus);
  await gesture.down(_global(editor, points.first));
  for (final point in points.skip(1)) {
    await gesture.moveTo(_global(editor, point));
  }
  await gesture.up();
  await tester.pump();
}

// ignore: missing_override_of_must_be_overridden
class _TestImage extends PngEditorImage {
  static final _assetCache = AssetCache();

  new({required super.dstRect})
    : super(
        id: -1,
        extension: '.png',
        imageProvider: MemoryImage(_pixel),
        pageIndex: 0,
        pageSize: const Size(1000, 1400),
        onMoveImage: null,
        onDeleteImage: null,
        onMiscChange: null,
        assetCache: _assetCache,
      );

  @override
  Future<void> firstLoad() async {}

  @override
  // ignore: must_call_super
  Future<bool> loadOut() async => false;
}

/// A transparent 1x1 PNG.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);
