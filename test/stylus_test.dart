import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/canvas/interactive_canvas.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  group('Stylus', () {
    FlavorConfig.setup();
    FileManager.documentsDirectory = '$tmpDir/stylus_test/nts';
    stows.editorFingerDrawing.value = false;

    // If you quickly draw, sometimes there's no hover event before the pointer down event
    for (final withHover in [true, false]) {
      testWidgets('Normal input should draw a stroke', (tester) async {
        final editorState = await tester._pumpEditor();
        await tester.pump();
        final page = editorState.coreInfo.pages.first;
        expect(page.strokes, isEmpty);
        await tester._stylusDrag(editorState, withHover);
        expect(page.strokes, hasLength(1));
      });

      // Styluses like the S Pen use a button to trigger the eraser.
      testWidgets('Pressing the stylus button should erase', (tester) async {
        final editorState = await tester._pumpEditor();
        await tester.pump();
        final page = editorState.coreInfo.pages.first;
        await tester._stylusDrag(editorState, withHover);
        expect(page.strokes, hasLength(1));
        await tester._stylusDrag(
          editorState,
          withHover,
          buttons: kSecondaryButton,
        );
        expect(page.strokes, hasLength(0));
      });

      // Styluses like the Noris Digital Jumbo have an eraser on the bottom.
      testWidgets('Inverse stylus should erase', (tester) async {
        final editorState = await tester._pumpEditor();
        await tester.pump();
        final page = editorState.coreInfo.pages.first;
        await tester._stylusDrag(editorState, withHover);
        expect(page.strokes, hasLength(1));
        await tester._stylusDrag(editorState, withHover, kind: .invertedStylus);
        expect(page.strokes, hasLength(0));
      });
    }

    testWidgets('A palm on the screen while writing is ignored', (
      tester,
    ) async {
      final editorState = await tester._pumpEditor();
      await tester.pump();
      final page = editorState.coreInfo.pages.first;
      Matrix4 transform() => tester
          .widget<InteractiveCanvasViewer>(find.byType(InteractiveCanvasViewer))
          .transformationController!
          .value
          .clone();
      final before = transform();

      final center = tester.getCenter(find.byType(Editor));
      final pencil = await tester.createGesture(kind: .stylus);
      await pencil.down(center);
      for (var i = 1; i <= 5; ++i) {
        await pencil.moveBy(const Offset(4, 2), timeStamp: .new(seconds: i));
      }
      // The hand lands mid-word, and moves (which would zoom)
      final palm = await tester.createGesture(kind: .touch);
      await palm.down(center + const Offset(80, 160));
      for (var i = 6; i <= 10; ++i) {
        await palm.moveBy(const Offset(30, 30), timeStamp: .new(seconds: i));
        await pencil.moveBy(const Offset(4, 2), timeStamp: .new(seconds: i));
      }
      await palm.up(timeStamp: const .new(seconds: 11));
      await pencil.moveBy(
        const Offset(4, 2),
        timeStamp: const .new(seconds: 11),
      );
      await pencil.up(timeStamp: const .new(seconds: 12));
      await tester.pump();

      expect(page.strokes, hasLength(1), reason: 'one stroke, not cut');
      expect(transform(), before, reason: 'no zoom or pan');
    });
  });
}

extension on WidgetTester {
  Future<EditorState> _pumpEditor() async {
    await pumpWidget(MaterialApp(home: Editor(path: '/stylus-test')));
    return state<EditorState>(find.byType(Editor));
  }

  /// Similar to [timedDragFrom] but with support for [PointerDeviceKind].
  // TODO(adil192): Submit PRs to Flutter:
  //                - Add [PointerDeviceKind] to [timedDragFrom]
  //                - Add [buttons] to [TestPointer.hover]
  Future<void> _stylusDrag(
    EditorState editorState,
    bool withHover, {
    PointerDeviceKind kind = .stylus,
    int buttons = kPrimaryButton,
  }) async {
    final center = getCenter(find.byType(Editor));
    final gesture = await createGesture(kind: kind, buttons: buttons);

    if (withHover) {
      await gesture.moveTo(center);
      if (buttons == kSecondaryButton) {
        // Right now, [TestPointer.hover] doesn't pass through [buttons],
        // so fake it until that gets fixed in Flutter.
        editorState.onStylusButtonChanged(true);
      }
    }

    await gesture.down(center);
    for (var i = 0; i < 10; ++i) {
      await gesture.moveBy(
        Offset(i / 2, i / 2),
        timeStamp: Duration(seconds: i),
      );
    }
    await gesture.up(timeStamp: const Duration(seconds: 10));
  }
}
