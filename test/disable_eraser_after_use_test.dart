import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/eraser.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  group('disableEraserAfterUse', () {
    for (final disableEraserAfterUse in const [true, false]) {
      testWidgets('$disableEraserAfterUse', (tester) async {
        FlavorConfig.setup();
        FileManager.documentsDirectory = '$tmpDir/disableEraserAfterUse/nts';
        stows.disableEraserAfterUse.value = disableEraserAfterUse;

        await tester.pumpWidget(MaterialApp(home: Editor()));
        final state = tester.state<EditorState>(find.byType(Editor));
        addTearDown(state.cancelAutosaveAndMarkSaved);

        state.currentTool = Eraser();
        state.dragPageIndex = 0;
        state.onDrawEnd(.new());
        await tester.pump();

        if (disableEraserAfterUse) {
          expect(state.currentTool, isA<Pen>());
        } else {
          expect(state.currentTool, isA<Eraser>());
        }
      });
    }
  });
}
