import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:keybinder/keybinder.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/components/canvas/pencil_shader.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/components/toolbar/selection_bar.dart';
import 'package:nts/components/toolbar/toolbar.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/services/camera.dart';
import 'package:nts/data/services/handwriting.dart';
import 'package:nts/data/services/pen_presets.dart';
import 'package:nts/data/services/selection_clipboard.dart';
import 'package:nts/data/services/selection_image.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/data/tools/highlighter.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:sbn/tool_id.dart';

import 'higan_snapshot_util.dart';
import 'utils/test_mock_channel_handlers.dart';

/// Cut/copy/paste, selection screenshots, handwriting to text,
/// pen favorites and the camera. With `HIGAN_SNAPSHOT=1` this also writes
/// PNGs of them in use.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  setupMockPrinting();
  setupMockWindowManager();
  FlavorConfig.setup();

  // New folders for each test (see resetNotes), so a note one test saves
  // late can't leak into the next test.
  var run = 0;
  var metricPath = '', annotatePath = '';

  /// The "Metric Spaces" title in [metricPath], in page coordinates.
  const title = Rect.fromLTRB(10, 20, 345, 105);

  /// "This doesn't satisfy 2 and 3 so isn't a metric space."
  const sentence = Rect.fromLTRB(245, 950, 870, 1065);

  setUpAll(() async {
    await Future.wait([
      FileManager.init(shouldWatchRootDirectory: false),
      PencilShader.init(),
    ]);
    EditorImage.shouldLoadOutImmediately = true;
    if (higanSnapshotsEnabled) await loadAppFonts();
  });

  /// Fresh copies of the demo notes (old notes, from before these tools).
  /// Sync, since async IO doesn't finish in `testWidgets`' fake time.
  void resetNotes() {
    run++;
    metricPath = '/lasso$run/Metric Spaces Week 1';
    annotatePath = '/lasso$run/Annotate images and diagrams';
    for (final (path, demo) in [
      (metricPath, 'Metric Spaces Week 1'),
      (annotatePath, 'Annotate images and diagrams'),
    ]) {
      for (final suffix in ['', '.0']) {
        final source = File('test/demo_notes/$demo.sbn2$suffix');
        if (!source.existsSync()) continue;
        FileManager.getFile('$path${Editor.extension}$suffix')
          ..createSync(recursive: true)
          ..writeAsBytesSync(source.readAsBytesSync());
      }
    }
  }

  setUp(() {
    stows.lastTool.value = ToolId.fountainPen;
    Pen.currentPen = Pen.fountainPen();
    stows.editorToolbarAlignment.value = .down;
    stows.editorToolbarItems.value = ToolCatalog.basics;
    stows.editorBarPositions.value = const {};
    stows.editorMinimizedBars.value = const [];
    stows.editorAutoInvert.value = false;
    stows.penPresets.value = const [];
    SelectionClipboard.content.value = null;
    Select.currentSelect.unselect();
  });

  group('PenPreset', () {
    test('round-trips through json, skipping unknown pens', () {
      final presets = [
        const PenPreset(toolId: .pencil, color: Colors.red, size: 3),
        PenPreset(
          toolId: .highlighter,
          color: Colors.yellow.withAlpha(Highlighter.alpha),
          size: 50,
        ),
      ];
      final json = jsonDecode(jsonEncode(presets)) as List;
      expect(PenPreset.listFromJson(json), presets);
      expect(
        PenPreset.listFromJson([
          {'toolId': 'SomeFuturePen', 'color': 0, 'size': 1},
          ...json,
        ]),
        presets,
      );
    });

    test('makes the pen it was saved from', () {
      final pen = Pen.ballpointPen()
        ..color = Colors.blue
        ..options.size = 7;
      final preset = PenPreset.of(pen)!;
      final restored = preset.toPen();
      expect(restored.toolId, ToolId.ballpointPen);
      expect(restored.color, Colors.blue);
      expect(restored.options.size, 7);
      expect(PenPreset.of(restored), preset);
      expect(PenPreset.of(Select.currentSelect), isNull);
    });

    test('adds up to the max, without repeats', () {
      for (var size = 1.0; size <= 7; size++) {
        PenPreset.add(
          PenPreset(toolId: .fountainPen, color: Colors.black, size: size),
        );
      }
      final presets = stows.penPresets.value;
      expect(presets, hasLength(PenPreset.max));
      PenPreset.add(presets.first);
      PenPreset.remove(presets.first);
      expect(stows.penPresets.value, presets.skip(1));
    });
  });

  test('tool catalog has the tools, but not in the basics', () {
    const ids = [
      'penPresets',
      'lassoClipboard',
      'lassoScreenshot',
      'handwritingToText',
      'camera',
    ];
    for (final id in ids) {
      expect(ToolCatalog.byId(id), isNotNull, reason: id);
      expect(ToolCatalog.basics, isNot(contains(id)));
    }
    expect(ToolCatalog.byId('camera')!.available, Camera.isSupported);
    expect(
      ToolCatalog.byId('handwritingToText')!.available,
      Handwriting.isSupported,
    );
  });

  group('editor', () {
    testWidgets('copy and paste strokes and images, undo, save and load', (
      tester,
    ) async {
      resetNotes();
      await addSavedPhoto(tester, metricPath);
      final editor = await openNote(tester, metricPath);
      final page = editor.coreInfo.pages.first;
      final strokes = List.of(page.strokes);
      final images = List.of(page.images);
      expect(strokes, isNotEmpty);
      expect(images, hasLength(1));

      await lasso(tester, editor, Offset.zero & page.size);
      expect(find.byTooltip(t.editor.otherTools.paste), findsNothing);
      await tester.runAsync(
        () => tester.tap(find.byTooltip(t.editor.otherTools.copy)),
      );
      while (SelectionClipboard.content.value == null) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byTooltip(t.editor.otherTools.paste));
      await tester.pump();
      expect(page.strokes, hasLength(strokes.length * 2));
      expect(page.images, hasLength(2));
      final pasted = Select.currentSelect.selectResult;
      expect(editor.currentTool, Select.currentSelect);
      expect(Select.currentSelect.doneSelecting, isTrue);
      expect(pasted.strokes, hasLength(strokes.length));
      expect(
        pasted.strokes.first.bounds.topLeft,
        strokes.first.bounds.topLeft + SelectionClipboard.pasteOffset,
      );
      final pastedImage = pasted.images.single;
      expect(
        pastedImage.dstRect,
        images.single.dstRect.shift(SelectionClipboard.pasteOffset),
      );
      expect(pastedImage.id, isNot(images.single.id));

      editor.undo();
      await tester.pump();
      expect(page.strokes, hasLength(strokes.length));
      expect(page.images, images);
      editor.redo();
      await tester.pump();
      expect(page.strokes, hasLength(strokes.length * 2));

      final loaded = await saveAndReload(tester, editor);
      final loadedPage = loaded.pages.first;
      expect(loadedPage.strokes, hasLength(strokes.length * 2));
      expect(loadedPage.images, hasLength(2));
      expect(
        loadedPage.images.map((image) => image.dstRect),
        contains(pastedImage.dstRect),
      );
      expect(loadedPage.images.map((image) => image.id).toSet(), hasLength(2));
    });

    testWidgets('pastes into another note', (tester) async {
      resetNotes();
      await addSavedPhoto(tester, metricPath);
      var editor = await openNote(tester, metricPath);
      final image = editor.coreInfo.pages.first.images.single;
      await lasso(tester, editor, image.dstRect.inflate(5), imagesOnly: true);
      await tester.runAsync(() => SelectionActions.copy(editor));
      final photo = await tester.runAsync(
        () =>
            FileManager.getFile('$metricPath${Editor.extension}.0')
                .readAsBytes(),
      );
      await tester.pumpWidget(const SizedBox());

      // The other note has a background image and strokes, but no images
      editor = await openNote(tester, annotatePath);
      final page = editor.coreInfo.pages.first;
      final strokes = page.strokes.length;
      expect(page.images, isEmpty);
      SelectionClipboard.paste(editor);
      await tester.pump();
      expect(page.strokes, hasLength(strokes));
      expect(page.images, hasLength(1));

      final loaded = await saveAndReload(tester, editor);
      expect(loaded.pages.first.backgroundImage, isNotNull);
      final pasted = loaded.pages.first.images.single as PngEditorImage;
      final bytes = await tester.runAsync(
        () async => switch (pasted.imageProvider) {
          final MemoryImage image => image.bytes,
          final FileImage image => await image.file.readAsBytes(),
          _ => null,
        },
      );
      expect(bytes, photo);
    });

    testWidgets('cut, even with only an image selected', (tester) async {
      resetNotes();
      await addSavedPhoto(tester, metricPath);
      final editor = await openNote(tester, metricPath);
      final page = editor.coreInfo.pages.first;
      final image = page.images.single;
      await lasso(tester, editor, image.dstRect.inflate(5), imagesOnly: true);
      expect(Select.currentSelect.selectResult.strokes, isEmpty);

      await tester.runAsync(() => SelectionActions.cut(editor));
      await tester.pump();
      expect(page.images, isEmpty);
      expect(SelectionClipboard.content.value!.images, hasLength(1));
      expect(Select.currentSelect.doneSelecting, isFalse);

      editor.undo();
      await tester.pump();
      expect(page.images, [image]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('convert handwriting to text, undo, save and load', (
      tester,
    ) async {
      resetNotes();
      final recognized = <Uint8List>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('nts/handwriting'),
        (call) async {
          recognized.add(call.arguments['png'] as Uint8List);
          return 'Metric Spaces';
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('nts/handwriting'),
          null,
        ),
      );

      final editor = await openNote(tester, metricPath);
      final page = editor.coreInfo.pages.first;
      final strokes = List.of(page.strokes);
      await lasso(tester, editor, title);
      final ink = Select.currentSelect.selectResult.strokes;
      expect(ink, isNotEmpty);

      await tester.tap(find.byTooltip(t.editor.otherTools.handwriting));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.editor.otherTools.convertToText));
      await tester.pump();
      while (page.quill.controller.document.isEmpty()) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(recognized, hasLength(1));
      expect(page.quill.controller.document.toPlainText(), 'Metric Spaces\n');
      expect(page.strokes, hasLength(strokes.length - ink.length));

      // Two steps: the text, then the ink
      editor.undo();
      await tester.pump();
      expect(page.quill.controller.document.isEmpty(), isTrue);
      editor.undo();
      await tester.pump();
      expect(page.strokes, hasLength(strokes.length));
      editor.redo();
      editor.redo();
      await tester.pumpAndSettle();
      expect(page.quill.controller.document.toPlainText(), 'Metric Spaces\n');

      final loaded = await saveAndReload(tester, editor);
      expect(
        loaded.pages.first.quill.controller.document.toPlainText(),
        'Metric Spaces\n',
      );
      expect(
        loaded.pages.first.strokes,
        hasLength(strokes.length - ink.length),
      );
    });

    testWidgets('copy handwriting as text', (tester) async {
      resetNotes();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('nts/handwriting'),
        (call) async => 'Metric Spaces',
      );
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() {
        for (final channel in [
          const MethodChannel('nts/handwriting'),
          SystemChannels.platform,
        ]) {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        }
      });

      final editor = await openNote(tester, metricPath);
      final strokes = editor.coreInfo.pages.first.strokes.length;
      await lasso(tester, editor, title);
      await tester.tap(find.byTooltip(t.editor.otherTools.handwriting));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.editor.otherTools.copyAsText));
      while (copied == null) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(copied, 'Metric Spaces');
      expect(editor.coreInfo.pages.first.strokes, hasLength(strokes));
      await tester.pumpAndSettle();
      expect(
        find.text(t.editor.otherTools.textCopied(text: 'Metric Spaces')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ink image for handwriting skips highlighters', (tester) async {
      resetNotes();
      final editor = await openNote(tester, metricPath);
      final page = editor.coreInfo.pages.first;
      expect(
        page.strokes.where((stroke) => stroke.toolId == .highlighter),
        isNotEmpty,
      );
      expect(
        Handwriting.inkOf(page.strokes).map((stroke) => stroke.toolId),
        isNot(contains(ToolId.highlighter)),
      );

      for (final (name, area) in [('title', title), ('sentence', sentence)]) {
        await lasso(tester, editor, area);
        final ink = Handwriting.inkOf(
          Select.currentSelect.selectResult.strokes,
        );
        final png = (await tester.runAsync(() => inkPng(ink)))!;
        final size = _pngSize(png);
        expect(size.width, greaterThan(area.width));
        expect(size.height, greaterThan(40));
        if (higanSnapshotsEnabled) {
          File('$higanSnapshotDir/handwriting_$name.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(png);
        }
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('screenshot of the selected area', (tester) async {
      resetNotes();
      final editor = await openNote(tester, metricPath);
      await lasso(tester, editor, title);
      final bounds = selectionBounds(Select.currentSelect.selectResult);
      expect(bounds.contains(title.center), isTrue);

      final png = (await tester.runAsync(
        () => pageAreaPng(editor.coreInfo, 0, bounds),
      ))!;
      final size = _pngSize(png);
      final page = editor.coreInfo.pages.first.size;
      final area = bounds.intersect(Offset.zero & page);
      expect(size.width, closeTo(area.width * 2, 2));
      expect(size.height, closeTo(area.height * 2, 2));
      if (higanSnapshotsEnabled) {
        File('$higanSnapshotDir/lasso_screenshot.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png);
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('camera photo is undoable, saved and loaded', (tester) async {
      resetNotes();
      final editor = await openNote(tester, metricPath);
      final page = editor.coreInfo.pages.first;
      final photo = File('test/demo_notes/Annotate images and diagrams.sbn2.0')
          .readAsBytesSync();

      Camera.addPhoto(editor, photo, extension: '.png');
      await tester.pump();
      expect(page.images, hasLength(1));
      expect(editor.currentTool, Select.currentSelect);
      editor.undo();
      await tester.pump();
      expect(page.images, isEmpty);
      editor.redo();
      await tester.pump();
      // its size, which it gets when it's first shown
      await tester.runAsync(page.images.single.firstLoad);

      final loaded = await saveAndReload(tester, editor);
      final image = loaded.pages.first.images.single as PngEditorImage;
      expect(image.extension, '.png');
      expect(image.dstRect.shortestSide, greaterThan(0));
    });

    testWidgets('pen favorites in the toolbar', (tester) async {
      resetNotes();
      stows.editorToolbarItems.value = [...ToolCatalog.basics, 'penPresets'];
      final editor = await openNote(tester, metricPath);
      final pen = editor.currentTool as Pen;
      final preset = PenPreset.of(pen)!;

      await tester.tap(find.byTooltip(t.editor.otherTools.saveFavorite));
      await tester.pump();
      expect(stows.penPresets.value, [preset]);
      final tooltip = '${preset.name} · ${preset.size.round()}';
      expect(inToolbar(find.byTooltip(tooltip)), findsOneWidget);

      // Switch away, then back with one tap
      await tester.tap(inToolbar(find.byTooltip(t.editor.pens.highlighter)));
      await tester.pump();
      expect(editor.currentTool, isA<Highlighter>());
      await tester.tap(inToolbar(find.byTooltip(tooltip)));
      await tester.pump();
      expect(PenPreset.of(editor.currentTool), preset);
      expect(editor.currentTool, Pen.currentPen);

      await tester.longPress(inToolbar(find.byTooltip(tooltip)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.editor.otherTools.removeFavorite));
      await tester.pumpAndSettle();
      expect(stows.penPresets.value, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('paste button in the toolbar', (tester) async {
      resetNotes();
      stows.editorToolbarItems.value = [
        ...ToolCatalog.basics,
        'lassoClipboard',
        'lassoScreenshot',
      ];
      final editor = await openNote(tester, metricPath);
      final page = editor.coreInfo.pages.first;
      IconButton button(String tooltip) => tester.widget<IconButton>(
        inToolbar(
          find.ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          ),
        ).first,
      );
      expect(button(t.editor.otherTools.paste).onPressed, isNull);
      expect(button(t.editor.otherTools.screenshot).onPressed, isNull);

      await lasso(tester, editor, title);
      expect(button(t.editor.otherTools.screenshot).onPressed, isNotNull);
      final strokes = page.strokes.length;
      final selected = Select.currentSelect.selectResult.strokes.length;
      await tester.runAsync(() => SelectionActions.copy(editor));
      await tester.pump();
      await tester.tap(
        // the toolbar's, after the selection bar's
        find.byTooltip(t.editor.otherTools.paste).last,
      );
      await tester.pump();
      expect(page.strokes, hasLength(strokes + selected));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Ctrl+V', () {
    Future<void> ctrlV(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    testWidgets('pastes the lasso copy, but not while typing', (tester) async {
      // The test binding drops keyboard handlers after each test,
      // so Keybinder has to listen again
      Keybinder.dispose();
      resetNotes();
      final editor = await openNote(tester, metricPath);
      final page = editor.coreInfo.pages.first;
      await lasso(tester, editor, title);
      final selected = Select.currentSelect.selectResult.strokes.length;
      await tester.runAsync(() => SelectionActions.copy(editor));
      await tester.pump();
      final strokes = page.strokes.length;

      await ctrlV(tester);
      expect(page.strokes, hasLength(strokes + selected));

      // (without focusing the text, whose own paste needs the platform)
      editor.currentTool = Tool.textEditing;
      tester.element(find.byType(Editor)).markNeedsBuild();
      await tester.pump();
      await ctrlV(tester);
      expect(page.strokes, hasLength(strokes + selected));
      expect(editor.currentTool, Tool.textEditing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('snapshots', skip: !higanSnapshotsEnabled, () {
    setUp(() {
      // what Vision reads from the title
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('nts/handwriting'),
            (call) async => 'Metric Spaces',
          );
      stows.penPresets.value = [
        const PenPreset(toolId: .fountainPen, color: Colors.black, size: 5),
        const PenPreset(
          toolId: .fountainPen,
          color: Color(0xFFD0283A),
          size: 3,
        ),
        PenPreset(
          toolId: .highlighter,
          color: Colors.yellow.withAlpha(Highlighter.alpha),
          size: 50,
        ),
      ];
      stows.editorToolbarItems.value = [
        ...ToolCatalog.basics,
        'penPresets',
        'lassoClipboard',
        'lassoScreenshot',
        'handwritingToText',
      ];
    });

    Future<void> copyTitle(WidgetTester tester, EditorState editor) async {
      await lasso(tester, editor, title);
      await tester.runAsync(() => SelectionActions.copy(editor));
      await tester.pump();
    }

    for (final (device, size) in const [
      ('ipad', Size(1180, 820)),
      ('phone', Size(390, 844)),
    ]) {
      testWidgets('selection bar $device', (tester) async {
        resetNotes();
        await snapshot(
          tester,
          name: 'lasso_selection_bar_${device}_night',
          path: metricPath,
          size: size,
          interact: (editor) => copyTitle(tester, editor),
        );
      });
    }

    testWidgets('toolbar extras, no selection', (tester) async {
      resetNotes();
      await snapshot(
        tester,
        name: 'lasso_toolbar_extras_ipad_night',
        path: metricPath,
        interact: (editor) async {
          // the second favorite (red, 3) is the current pen
          await tester.tap(find.byTooltip('${t.editor.pens.fountainPen} · 3'));
          await tester.pump();
        },
      );
    });

    testWidgets('screenshot menu', (tester) async {
      resetNotes();
      await snapshot(
        tester,
        name: 'lasso_screenshot_menu_ipad_night',
        path: metricPath,
        interact: (editor) async {
          await lasso(tester, editor, title);
          await tester.tap(
            find
                .descendant(
                  of: find.byType(SelectionBar),
                  matching: find.byTooltip(t.editor.otherTools.screenshot),
                )
                .first,
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('handwriting menu', (tester) async {
      resetNotes();
      await snapshot(
        tester,
        name: 'lasso_handwriting_menu_ipad_night',
        path: metricPath,
        interact: (editor) async {
          await lasso(tester, editor, title);
          await tester.tap(
            find
                .descendant(
                  of: find.byType(SelectionBar),
                  matching: find.byTooltip(t.editor.otherTools.handwriting),
                )
                .first,
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('converted to text', (tester) async {
      resetNotes();
      await snapshot(
        tester,
        name: 'lasso_handwriting_converted_ipad_night',
        path: metricPath,
        interact: (editor) async {
          await lasso(tester, editor, title);
          final ink = Handwriting.inkOf(
            Select.currentSelect.selectResult.strokes,
          );
          final text = (await tester.runAsync(
            () => Handwriting.recognize(ink),
          ))!;
          SelectionActions.convertToText(editor, 0, ink, text);
          await tester.pump();
        },
      );
    });

    testWidgets('pasted', (tester) async {
      resetNotes();
      await snapshot(
        tester,
        name: 'lasso_pasted_ipad_night',
        path: metricPath,
        interact: (editor) async {
          // "1. d(x, y) = 0 <=> x = y"
          await lasso(tester, editor, const Rect.fromLTRB(60, 270, 800, 350));
          await tester.runAsync(() => SelectionActions.copy(editor));
          SelectionClipboard.paste(editor);
          await tester.pump();
        },
      );
    });
  });
}

/// The width and height in a PNG's header.
Size _pngSize(Uint8List png) {
  final data = ByteData.sublistView(png);
  return Size(data.getUint32(16).toDouble(), data.getUint32(20).toDouble());
}

/// For [snapshot].
final _boundaryKey = GlobalKey();

Future<EditorState> openNote(
  WidgetTester tester,
  String path, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: RepaintBoundary(
        key: _boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            FlutterQuillLocalizations.delegate,
          ],
          theme: theme,
          home: Editor(path: path),
        ),
      ),
    ),
  );
  final editor = tester.state<EditorState>(find.byType(Editor));
  while (editor.coreInfo.readOnlyReason == .placeholder) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  return editor;
}

/// Adds a photo to the first page of [path] and saves it, so the photo is
/// an asset file like images in real notes.
Future<void> addSavedPhoto(WidgetTester tester, String path) async {
  final editor = await openNote(tester, path);
  Camera.addPhoto(
    editor,
    File('test/demo_notes/Annotate images and diagrams.sbn2.0')
        .readAsBytesSync(),
    extension: '.png',
  );
  // its size, which it gets when it's first shown
  await tester.runAsync(editor.coreInfo.pages.first.images.single.firstLoad);
  await tester.runAsync(editor.saveToFile);
  await tester.pumpWidget(const SizedBox());
}

/// Saves, closes the editor and loads the note again.
Future<EditorCoreInfo> saveAndReload(
  WidgetTester tester,
  EditorState editor,
) async {
  final path = editor.coreInfo.filePath;
  await tester.runAsync(editor.saveToFile);
  await tester.pumpWidget(const SizedBox());
  return (await tester.runAsync(() => EditorCoreInfo.loadFromFilePath(path)))!;
}

void rebuild(WidgetTester tester) =>
    tester.element(find.byType(Editor)).markNeedsBuild();

/// Selects [area] of the first page with the lasso
/// (only the images if [imagesOnly]).
Future<void> lasso(
  WidgetTester tester,
  EditorState editor,
  Rect area, {
  bool imagesOnly = false,
}) async {
  final page = editor.coreInfo.pages.first;
  final select = Select.currentSelect
    ..onDragStart(area.topLeft, 0)
    ..onDragUpdate(area.topRight)
    ..onDragUpdate(area.bottomRight)
    ..onDragUpdate(area.bottomLeft);
  select.onDragEnd(imagesOnly ? const [] : page.strokes, page.images);
  editor.currentTool = select;
  rebuild(tester);
  // let the selection bar open
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Finder inToolbar(Finder finder) =>
    find.descendant(of: find.byType(Toolbar), matching: finder);

/// Opens [path] in the Higan Night theme at [size], runs [interact],
/// then writes `<higanSnapshotDir>/<name>.png`.
Future<void> snapshot(
  WidgetTester tester, {
  required String name,
  required String path,
  Size size = const Size(1180, 820),
  required Future<void> Function(EditorState editor) interact,
}) async {
  const platform = TargetPlatform.iOS;
  stows.platform.value = platform;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = size.width < 600
        ? const FakeViewPadding(top: 47, bottom: 34)
        : const FakeViewPadding(top: 24, bottom: 20);
  addTearDown(tester.view.reset);

  debugDisableShadows = false;
  try {
    final editor = await openNote(
      tester,
      path,
      theme: HiganTheme.night(platform),
    );
    await interact(editor);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundaryKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: .png);
      image.dispose();
      await File('$higanSnapshotDir/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
    // Dispose the editor while shadows are still allowed
    await tester.pumpWidget(const SizedBox());
  } finally {
    debugDisableShadows = true;
  }
}
