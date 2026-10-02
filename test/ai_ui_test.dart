import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:nts/components/ai/ai_chart.dart';
import 'package:nts/components/ai/ai_menu.dart';
import 'package:nts/components/ai/ai_result_sheet.dart';
import 'package:nts/components/ai/web_results_sheet.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/components/canvas/pencil_shader.dart';
import 'package:nts/components/settings/ai_accounts.dart';
import 'package:nts/components/settings/ai_actions_settings.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/components/toolbar/selection_bar.dart';
import 'package:nts/components/toolbar/toolbar.dart';
import 'package:nts/components/toolbar/toolbar_button.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/ai_router.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/services/ai_actions.dart';
import 'package:nts/data/services/selection_clipboard.dart';
import 'package:nts/data/services/selection_image.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:sbn/tool_id.dart';

import 'fake_ai_provider.dart';
import 'higan_snapshot_util.dart';
import 'utils/test_mock_channel_handlers.dart';

/// The AI menu, its answers, the link list, the "Ask AI" lasso and the
/// AI settings, with fake accounts. With `HIGAN_SNAPSHOT=1` this also
/// writes PNGs of them (aiacc_*.png).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    ServicesBinding.rootIsolateToken!,
  );
  setupMockPathProvider();
  setupMockPrinting();
  setupMockWindowManager();
  FlavorConfig.setup();

  late FakeAiProvider chatgpt, claude, google;
  var run = 0;
  var notePath = '';

  setUpAll(() async {
    await Future.wait([
      FileManager.init(shouldWatchRootDirectory: false),
      PencilShader.init(),
    ]);
    EditorImage.shouldLoadOutImmediately = true;
    if (higanSnapshotsEnabled) await loadAppFonts();
  });

  setUp(() {
    [chatgpt, claude, google] = FakeAiProvider.install();
    stows.lastTool.value = ToolId.fountainPen;
    Pen.currentPen = Pen.fountainPen();
    stows.editorToolbarAlignment.value = .down;
    stows.editorToolbarItems.value = [...ToolCatalog.basics, 'askAi'];
    stows.editorBarPositions.value = const {};
    stows.editorMinimizedBars.value = const [];
    stows.editorAutoInvert.value = false;
    stows.aiGoogleClientId.value = '';
    stows.aiGoogleProjectId.value = '';
    Select.currentSelect.unselect();
    AiMenu.lassoArmed = false;

    // A fresh copy of a demo note
    notePath = '/ai${run++}/Metric Spaces Week 1';
    FileManager.getFile('$notePath${Editor.extension}')
      ..createSync(recursive: true)
      ..writeAsBytesSync(
        File('test/demo_notes/Metric Spaces Week 1.sbn2').readAsBytesSync(),
      );
  });
  tearDown(() {
    AiRouter.debugProviders = null;
    AiMenu.render = selectionPng;
  });

  void signOutAll() {
    for (final provider in [chatgpt, claude, google]) {
      provider.setStatus(AiAccountStatus.signedOut);
    }
  }

  test('"Ask AI" is in the catalog, but not in the basics', () {
    final item = ToolCatalog.byId('askAi')!;
    expect(ToolCatalog.basics, isNot(contains('askAi')));
    expect(item.category, ToolCategory.eraseAndSelect);
  });

  group('menu', () {
    Future<(List<AiAction>, List<void>)> pumpMenu(WidgetTester tester) async {
      final picked = <AiAction>[];
      final settings = <void>[];
      await tester.pumpWidget(
        _app(
          AiMenu(
            prepare: (action) {
              picked.add(action);
              return Completer<String?>().future; // stays busy
            },
            onOpenSettings: () => settings.add(null),
          ),
        ),
      );
      return (picked, settings);
    }

    testWidgets('all six, with the account each uses', (tester) async {
      final (picked, _) = await pumpMenu(tester);
      for (final action in AiAction.values) {
        expect(find.text(action.title), findsOneWidget);
      }
      expect(find.text('CHATGPT'), findsNWidgets(4));
      expect(find.text('CLAUDE'), findsOneWidget); // illustration
      expect(find.text('GOOGLE'), findsOneWidget); // video
      await tester.tap(find.text(AiAction.graph.title));
      await tester.pump();
      expect(picked, [AiAction.graph]);
    });

    testWidgets('no account: says where to sign in', (tester) async {
      signOutAll();
      final (picked, settings) = await pumpMenu(tester);
      expect(find.text(t.ai.signInToUse), findsOneWidget);
      expect(find.text(AiAction.paragraph.title), findsNothing);

      // Signing in elsewhere (e.g. Claude Code in Terminal) turns it on
      claude.setStatus(const AiAccountStatus(.signedIn));
      await tester.pump();
      expect(find.text(t.ai.signInToUse), findsNothing);
      expect(find.text('CLAUDE'), findsNWidgets(6));
      claude.setStatus(AiAccountStatus.signedOut);
      await tester.pump();

      await tester.tap(find.text(t.ai.openSettings));
      await tester.pump();
      expect(settings, hasLength(1));
      expect(picked, isEmpty);
    });

    testWidgets('a chosen account that is signed out: the row says so, '
        'and opens Settings', (tester) async {
      AiRouter.routes[AiAction.paragraph]!.value = 'claude:opus';
      claude.setStatus(AiAccountStatus.signedOut);
      final (picked, settings) = await pumpMenu(tester);
      final reason = t.ai.route.signedOut(provider: 'Claude');
      expect(find.text(reason), findsOneWidget);
      await tester.tap(find.text(AiAction.paragraph.title));
      await tester.pump();
      expect(picked, isEmpty);
      expect(settings, hasLength(1));
    });

    testWidgets('a failed query shows on its row, over which nothing hides '
        'it', (tester) async {
      await tester.pumpWidget(
        _app(
          AiMenu(
            prepare: (_) async => throw const AiError(
              AiError.failed,
              'Claude took too long. Try again.',
            ),
          ),
        ),
      );
      await tester.tap(find.text(AiAction.video.title));
      await tester.pump();
      expect(find.text('Claude took too long. Try again.'), findsOneWidget);
      expect(find.text(AiAction.video.description), findsNothing);
      expect(find.byType(AiMenu), findsOneWidget);
    });

    testWidgets('dismissed while preparing: only the menu closes', (
      tester,
    ) async {
      final query = Completer<String?>();
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => AiMenu(prepare: (_) => query.future),
              ),
              child: const Text('note'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AiAction.video.title));
      await tester.pump();
      Navigator.of(tester.element(find.byType(AiMenu))).pop();
      await tester.pump(); // closing
      query.complete('light reactions');
      await tester.pumpAndSettle();
      expect(find.text('note'), findsOneWidget);
      expect(find.byType(AiMenu), findsNothing);
    });
  });

  group('answer', () {
    testWidgets('streams in, copies, and adds to the page', (tester) async {
      final gate = Completer<String>();
      void Function(String)? partial;
      chatgpt.onRespond = (_, onPartial) {
        partial = onPartial;
        return gate.future;
      };
      final added = <String>[];
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _openSheet(tester, action: .paragraph, onAddText: added.add);
      expect(find.text(t.ai.working), findsOneWidget);
      expect(
        find.text(t.ai.madeBy(provider: 'ChatGPT', model: 'GPT-5.4')),
        findsOneWidget,
      );
      expect(chatgpt.requests.single.$2.imagePng, testPng);

      partial!('A **metric** space is');
      await tester.pump();
      expect(find.text('A metric space is'), findsOneWidget);
      expect(find.text(t.ai.working), findsNothing);
      // Not before it's done
      await tester.tap(find.text(t.ai.addToPage));
      expect(added, isEmpty);

      gate.complete('A metric space is a set with a **distance**.');
      await tester.pumpAndSettle();
      const answer = 'A metric space is a set with a distance.';
      expect(find.text(answer), findsOneWidget);

      await tester.tap(find.text(t.ai.copy));
      await tester.pump();
      expect(copied, [answer]);
      expect(find.text(t.ai.copied), findsOneWidget);

      await tester.tap(find.text(t.ai.addToPage));
      await tester.pumpAndSettle();
      expect(added, [answer]);
      expect(find.byType(AiResultSheet), findsNothing);
    });

    testWidgets('adds the answer beside the page, on either side', (
      tester,
    ) async {
      chatgpt.onRespond = (_, _) async => 'Beside the page.';
      final added = <(String, int)>[];
      await _openSheet(
        tester,
        action: .paragraph,
        onAddTextAt: (text, side) => added.add((text, side)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t.nts.side.addLeft));
      await tester.pumpAndSettle();
      expect(added, [('Beside the page.', -1)]);

      await _openSheet(
        tester,
        action: .paragraph,
        onAddTextAt: (text, side) => added.add((text, side)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t.nts.side.addRight));
      await tester.pumpAndSettle();
      expect(added.last, ('Beside the page.', 1));
    });

    testWidgets('closing it stops the request', (tester) async {
      chatgpt.onRespond = (_, _) => Completer<String>().future;
      await _openSheet(tester, action: .explainExample);
      final id = chatgpt.requests.single.$1;
      await tester.tap(find.text(t.ai.close));
      await tester.pumpAndSettle();
      expect(chatgpt.cancelled, [id]);
    });

    testWidgets('shows what went wrong, and tries again', (tester) async {
      var limit = true;
      chatgpt.onRespond = (_, _) async {
        if (limit) {
          throw const AiError(AiError.limit, 'ChatGPT plan limit reached.');
        }
        return 'Fine.';
      };
      await _openSheet(tester, action: .paragraph);
      await tester.pumpAndSettle();
      expect(find.text('ChatGPT plan limit reached.'), findsOneWidget);
      // e.g. to pick another account
      expect(find.text(t.ai.openSettings), findsOneWidget);
      expect(find.textContaining('Made by'), findsNothing, reason: 'nothing');
      limit = false;
      await tester.tap(find.text(t.ai.tryAgain));
      await tester.pumpAndSettle();
      expect(find.text('Fine.'), findsOneWidget);
    });

    testWidgets('signed out: says so, and offers Settings', (tester) async {
      signOutAll();
      await _openSheet(tester, action: .paragraph);
      await tester.pumpAndSettle();
      expect(find.text(t.ai.signInToUse), findsOneWidget);
      await tester.tap(find.text(t.ai.openSettings));
      await tester.pumpAndSettle();
      // Over the answer (and the note): closing it goes back there
      expect(find.byType(AiAccountsSection), findsOneWidget);
      expect(find.byType(AiResultSheet), findsOneWidget);
    });

    testWidgets('graph: a chart, added as a PNG', (tester) async {
      chatgpt.onRespond = (_, _) async => _functionJson;
      final added = <String>[];
      await _openSheet(
        tester,
        action: .graph,
        onAddImage: (_, extension) => added.add(extension),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AiChart), findsOneWidget);
      expect(chatgpt.requests.single.$2.jsonSchema, AiActions.chartSchema);
      await tester.tap(find.text(t.ai.addToPage));
      await _until(tester, () => added.isNotEmpty);
      expect(added, ['.png']);
    });

    testWidgets('graph: tapping Add twice adds one chart', (tester) async {
      chatgpt.onRespond = (_, _) async => _functionJson;
      final added = <String>[];
      await _openSheet(
        tester,
        action: .graph,
        onAddImage: (_, extension) => added.add(extension),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.ai.addToPage));
      await tester.pump();
      await tester.tap(find.text(t.ai.addToPage)); // while making the PNG
      await _until(tester, () => added.isNotEmpty);
      await _realWait(tester);
      await tester.pumpAndSettle();
      expect(added, ['.png']);
      expect(find.byType(AiResultSheet), findsNothing);
      expect(find.text('open'), findsOneWidget, reason: 'the note stays');
    });

    testWidgets('graph: closing while adding adds nothing', (tester) async {
      chatgpt.onRespond = (_, _) async => _functionJson;
      final added = <String>[];
      await _openSheet(
        tester,
        action: .graph,
        onAddImage: (_, extension) => added.add(extension),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.ai.addToPage));
      await tester.pump();
      await tester.tap(find.text(t.ai.close));
      await _realWait(tester);
      await tester.pumpAndSettle();
      expect(added, isEmpty);
      expect(find.text('open'), findsOneWidget, reason: 'the note stays');
    });

    testWidgets('illustration: a line drawing, added as a PNG', (tester) async {
      claude.onRespond = (_, _) async => _drawing;
      final added = <String>[];
      await _openSheet(
        tester,
        action: .illustration,
        onAddImage: (_, extension) => added.add(extension),
      );
      await _until(tester, () => find.byType(Image).evaluate().length > 1);
      expect(
        find.text(t.ai.madeBy(provider: 'Claude', model: 'Sonnet')),
        findsOneWidget,
      );
      await tester.tap(find.text(t.ai.addToPage));
      await tester.pumpAndSettle();
      expect(added, ['.png']);
    });

    testWidgets('shows what it read; a fix asks again with it', (tester) async {
      final second = Completer<String>();
      chatgpt.onRespond = (_, _) => chatgpt.requests.length == 1
          ? Future.value('You wrote: | + | = ∫\n\nThat is an integral.')
          : second.future;
      final added = <String>[];
      await _openSheet(tester, action: .paragraph, onAddText: added.add);
      await tester.pumpAndSettle();
      expect(find.text(t.ai.youWrote.toUpperCase()), findsOneWidget);
      expect(find.text('| + | = ∫'), findsOneWidget);
      expect(find.text('That is an integral.'), findsOneWidget);

      // The same reading: no need to ask again
      await tester.tap(find.text('| + | = ∫'));
      await tester.pump();
      await tester.tap(find.text(t.ai.askAgain));
      await tester.pump();
      expect(chatgpt.requests, hasLength(1));

      await tester.tap(find.text('| + | = ∫'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), ' 1 + 1 = 2 ');
      await tester.tap(find.text(t.ai.askAgain));
      await tester.pump();
      expect(find.text(t.ai.rereading), findsOneWidget);
      expect(find.text('1 + 1 = 2'), findsOneWidget);
      final (_, request, _) = chatgpt.requests.last;
      expect(chatgpt.requests, hasLength(2));
      expect(
        request.prompt,
        contains('The student confirmed the circled part says: 1 + 1 = 2'),
      );
      expect(request.imagePng, testPng, reason: 'with the picture');

      second.complete('You wrote: 1 + 1 = 2\n\nOne plus one is two.');
      await tester.pumpAndSettle();
      expect(find.text(t.ai.rereading), findsNothing);
      expect(find.text('1 + 1 = 2'), findsOneWidget);
      await tester.tap(find.text(t.ai.addToPage));
      await tester.pumpAndSettle();
      expect(added, ['One plus one is two.'], reason: 'not "You wrote"');
    });

    testWidgets("can't read it: says so, and the student can say", (
      tester,
    ) async {
      chatgpt.onRespond = (_, _) async =>
          chatgpt.requests.length == 1 ? _unreadableJson : _functionJson;
      await _openSheet(tester, action: .graph);
      await tester.pumpAndSettle();
      expect(find.text(t.ai.nothingToRead), findsOneWidget);
      await tester.tap(find.text(t.ai.typeReading));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'y = x^2 - 2x');
      await tester.testTextInput.receiveAction(.done);
      await tester.pumpAndSettle();
      expect(find.byType(AiChart), findsOneWidget);
      expect(
        chatgpt.requests.last.$2.prompt,
        contains('The student confirmed the circled part says: y = x^2 - 2x'),
      );
    });

    testWidgets("can't read words: nothing to add; fixing it is above the "
        'keyboard', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      chatgpt.onRespond = (_, _) async => 'You wrote: ?\nToo tangled.';
      await _openSheet(tester, action: .paragraph, onAddText: (_) {});
      await tester.pumpAndSettle();
      expect(find.text(t.ai.nothingToRead), findsOneWidget);
      expect(find.text('Too tangled.'), findsNothing);
      final add = find.ancestor(
        of: find.text(t.ai.addToPage),
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      expect(
        tester.widgetList(add).every((b) {
          return (b as ButtonStyleButton).onPressed == null;
        }),
        isTrue,
      );

      await tester.tap(find.text(t.ai.typeReading));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      const keyboard = 844.0 - 336;
      expect(tester.getRect(find.byType(TextField)).bottom, lessThan(keyboard));
      expect(
        tester.getRect(find.text(t.ai.askAgain)).bottom,
        lessThan(keyboard),
      );
    });

    testWidgets('a narrow sheet stacks its buttons', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      chatgpt.onRespond = (_, _) async => 'Fine.';
      await _openSheet(tester, action: .paragraph, onAddText: (_) {});
      await tester.pumpAndSettle();
      // An overflow would fail the test
      expect(find.text(t.ai.addToPage).hitTestable(), findsOneWidget);
    });
  });

  group('editor', () {
    testWidgets('an "Ask AI" lasso opens the menu; the answer is added '
        'as text and the ink stays', (tester) async {
      chatgpt.onRespond = (_, _) async => 'A metric measures distance.';
      tester.view
        ..physicalSize = const Size(1180, 820)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final editor = await _openNote(tester, notePath);
      final page = editor.coreInfo.pages.first;
      final strokes = page.strokes.length;

      await tester.tap(
        find.descendant(
          of: find.byType(Toolbar),
          matching: find.byTooltip(t.ai.askAi),
        ),
      );
      await tester.pump();
      expect(editor.currentTool, Select.currentSelect);
      expect(AiMenu.lassoArmed, isTrue);
      bool selected(String tooltip) => tester
          .widget<ToolbarIconButton>(
            find.ancestor(
              of: find.descendant(
                of: find.byType(Toolbar),
                matching: find.byTooltip(tooltip),
              ),
              matching: find.byType(ToolbarIconButton),
            ),
          )
          .selected;
      expect(selected(t.ai.askAi), isTrue);
      expect(selected(t.editor.toolbar.select), isFalse, reason: 'one tool');

      await _stylus(tester, editor, [
        _title.topLeft,
        _title.topRight,
        _title.bottomRight,
        _title.bottomLeft,
        _title.topLeft + const Offset(0, 8),
      ]);
      await _until(tester, () => find.byType(AiMenu).evaluate().isNotEmpty);
      expect(Select.currentSelect.selectResult.strokes, isNotEmpty);
      final circled = (await tester.runAsync(() => selectionPngOf(editor)))!;
      AiMenu.render = (_, _, {hasText = false}) async => circled;

      await tester.tap(find.text(AiAction.paragraph.title));
      await _until(
        tester,
        () => find.text('A metric measures distance.').evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AiMenu), findsNothing);
      // The circled part of the page, as a PNG
      final png = chatgpt.requests.single.$2.imagePng!;
      expect(png, same(circled));
      expect(png.sublist(1, 4), 'PNG'.codeUnits);
      expect(png.length, greaterThan(1000));

      await tester.tap(find.text(t.ai.addToPage));
      await tester.pumpAndSettle();
      // In a text box under what was circled, on the page
      final box = page.textBoxes.single;
      expect(box.text, 'A metric measures distance.');
      expect(
        box.position.dy,
        greaterThan(Select.currentSelect.selectionBounds!.bottom),
      );
      expect(box.position.dx, greaterThanOrEqualTo(0));
      expect(page.strokes, hasLength(strokes));

      // Any other tool ends "Ask AI"
      await tester.tap(find.byTooltip(Pen.currentPen.name));
      await tester.pump();
      expect(AiMenu.lassoArmed, isFalse);
      editor.cancelAutosaveAndMarkSaved();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('video: the query, then a list of links', (tester) async {
      google.onRespond = (_, _) async =>
          'You wrote: Metric Spaces\nQUERY: metric space definition';
      google.onSearch = (_, _) async => _videos;
      tester.view
        ..physicalSize = const Size(1180, 820)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final editor = await _openNote(tester, notePath);
      await _lassoTitle(tester, editor);
      AiMenu.render = (_, _, {hasText = false}) async => testPng;
      unawaited(showAiMenu(editor.context, editor));
      await _until(tester, () => find.byType(AiMenu).evaluate().isNotEmpty);
      await tester.tap(find.text(AiAction.video.title));
      await _until(
        tester,
        () => find.byType(WebResultsSheet).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(google.searches.single.$1, 'metric space definition');
      expect(find.text(_videos.first.title), findsOneWidget);
      editor.cancelAutosaveAndMarkSaved();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('small phone: the selection bar and menu fit', (tester) async {
      tester.view
        ..physicalSize = const Size(375, 667)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // with Paste too
      SelectionClipboard.content.value = (
        strokes: const [],
        images: const [],
        assets: const [],
        path: Path(),
      );
      addTearDown(() => SelectionClipboard.content.value = null);
      final editor = await _openNote(tester, notePath);
      await _lassoTitle(tester, editor);
      // An overflow would fail the test
      expect(
        find
            .descendant(
              of: find.byType(SelectionBar),
              matching: find.byTooltip(t.editor.selectionBar.delete),
            )
            .hitTestable(),
        findsOneWidget,
      );

      unawaited(showAiMenu(editor.context, editor));
      await _until(tester, () => find.byType(AiMenu).evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      expect(find.text(AiAction.source.title).hitTestable(), findsOneWidget);
      editor.cancelAutosaveAndMarkSaved();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('landscape phone: the menu is a sheet', (tester) async {
      tester.view
        ..physicalSize = const Size(844, 390)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final editor = await _openNote(tester, notePath);
      await _lassoTitle(tester, editor);
      unawaited(showAiMenu(editor.context, editor));
      await _until(tester, () => find.byType(AiMenu).evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(AiAction.source.title),
        50,
        scrollable: find.descendant(
          of: find.byType(AiMenu),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text(AiAction.source.title).hitTestable(), findsOneWidget);
      editor.cancelAutosaveAndMarkSaved();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('nothing circled: says so', (tester) async {
      final editor = await _openNote(tester, notePath);
      final select = Select.currentSelect
        ..onDragStart(const Offset(980, 1370), 0)
        ..onDragUpdate(const Offset(995, 1370))
        ..onDragUpdate(const Offset(995, 1395));
      final page = editor.coreInfo.pages.first;
      select.onDragEnd(page.strokes, page.images);
      editor.currentTool = select;
      await tester.pump();
      expect(select.selectResult.isEmpty, isTrue);
      unawaited(showAiMenu(editor.context, editor));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AiMenu), findsNothing);
      expect(find.text(t.ai.nothingToRead), findsOneWidget);
      editor.cancelAutosaveAndMarkSaved();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an "Ask AI" lasso around nothing says so, and goes', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1180, 820)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final editor = await _openNote(tester, notePath);
      await tester.tap(
        find.descendant(
          of: find.byType(Toolbar),
          matching: find.byTooltip(t.ai.askAi),
        ),
      );
      await tester.pump();
      await _stylus(tester, editor, _nothing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(t.ai.nothingToRead), findsOneWidget);
      expect(find.byType(AiMenu), findsNothing);
      expect(Select.currentSelect.doneSelecting, isFalse, reason: 'it goes');
      editor.cancelAutosaveAndMarkSaved();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('typed text: only the text boxes inside the lasso', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1180, 820)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final editor = await _openNote(tester, '/ai${run++}/typed');
      final page = editor.coreInfo.pages.first;
      PageTextBox box(int id, Offset at, String text) =>
          PageTextBox(id: id, position: at, width: 200, text: text);
      page.textBoxes = [
        box(0, const Offset(100, 100), 'alpha beta'),
        box(1, const Offset(100, 300), 'gamma'),
        box(2, const Offset(600, 300), 'delta'),
      ];
      await tester.pump();
      // Around "gamma": not the box above, nor "delta" beside it
      const lasso = Rect.fromLTRB(80, 280, 420, 380);
      final select = Select.currentSelect
        ..onDragStart(lasso.topLeft, 0)
        ..onDragUpdate(lasso.topRight)
        ..onDragUpdate(lasso.bottomRight)
        ..onDragUpdate(lasso.bottomLeft)
        ..onDragEnd(page.strokes, page.images);
      editor.currentTool = select;
      await tester.pump();
      (bool, bool)? rendered;
      AiMenu.render = (_, selection, {hasText = false}) async {
        rendered = (selection.isEmpty, hasText);
        return testPng;
      };
      unawaited(showAiMenu(editor.context, editor));
      await _until(tester, () => find.byType(AiMenu).evaluate().isNotEmpty);
      await tester.tap(find.text(AiAction.paragraph.title));
      await _until(tester, () => chatgpt.requests.isNotEmpty);
      expect(rendered, (true, true), reason: 'no ink, but text');
      expect(
        chatgpt.requests.single.$2.prompt,
        startsWith('TYPED TEXT IN THE CIRCLED PART:\ngamma\n'),
      );
      await tester.pumpAndSettle();
      editor.cancelAutosaveAndMarkSaved();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a plain lasso doesn\'t open the menu', (tester) async {
      final editor = await _openNote(tester, notePath);
      editor.currentTool = Select.currentSelect;
      await _stylus(tester, editor, [
        _title.topLeft,
        _title.topRight,
        _title.bottomRight,
        _title.bottomLeft,
      ]);
      await tester.pump(const Duration(seconds: 1));
      expect(Select.currentSelect.doneSelecting, isTrue);
      expect(find.byType(AiMenu), findsNothing);
      expect(chatgpt.requests, isEmpty);
      editor.cancelAutosaveAndMarkSaved();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('settings', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1000, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const _AiSettings()));
      await tester.pump();
    }

    testWidgets('accounts sign in and out', (tester) async {
      signOutAll();
      await pumpSettings(tester);
      expect(
        find.text(t.ai.accounts.notSignedIn.toUpperCase()),
        findsNWidgets(2),
      );
      expect(find.text(t.ai.google.title), findsOneWidget, reason: 'setup');
      await tester.tap(find.text(t.ai.accounts.signIn).first);
      await tester.pump();
      expect(chatgpt.status.value.isSignedIn, isTrue);
      expect(
        find.text(
          t.ai.accounts.signedInAs(who: 'mehmet@example.com').toUpperCase(),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(t.ai.accounts.signOut));
      await tester.pump();
      expect(chatgpt.status.value.isSignedIn, isFalse);
    });

    testWidgets('Claude asks before signing Claude Code out', (tester) async {
      chatgpt.setStatus(AiAccountStatus.signedOut);
      await pumpSettings(tester);
      await tester.tap(find.text(t.ai.accounts.signOut));
      await tester.pumpAndSettle();
      expect(find.text(t.ai.accounts.claudeSignOutBody), findsOneWidget);
      await tester.tap(find.text(t.common.cancel).last);
      await tester.pumpAndSettle();
      expect(claude.status.value.isSignedIn, isTrue);
    });

    testWidgets('Google setup checks and saves the IDs', (tester) async {
      await pumpSettings(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'not an id');
      await tester.enterText(fields.last, 'nts-notes');
      await tester.tap(find.text(t.ai.google.save));
      await tester.pump();
      expect(find.text(t.ai.google.invalidClientId), findsOneWidget);
      expect(stows.aiGoogleClientId.value, '');

      await tester.enterText(
        fields.first,
        ' 123456789-abc123.apps.googleusercontent.com ',
      );
      await tester.tap(find.text(t.ai.google.save));
      await tester.pump();
      expect(
        stows.aiGoogleClientId.value,
        '123456789-abc123.apps.googleusercontent.com',
      );
      expect(stows.aiGoogleProjectId.value, 'nts-notes');
      expect(find.text(t.ai.google.title), findsNothing);
      expect(find.text(t.ai.google.change), findsOneWidget);
    });

    testWidgets('changing Google\'s setup keeps it signed in until saved', (
      tester,
    ) async {
      _setUpGoogle((chatgpt: chatgpt, claude: claude, google: google));
      claude.setStatus(AiAccountStatus.signedOut);
      chatgpt.setStatus(AiAccountStatus.signedOut);
      await pumpSettings(tester);
      await tester.tap(find.text(t.ai.google.change));
      await tester.pump();
      expect(find.text(t.ai.google.title), findsOneWidget);
      expect(
        find.text(
          t.ai.accounts.signedInAs(who: 'mehmet@gmail.com').toUpperCase(),
        ),
        findsOneWidget,
      );
      expect(find.text(t.ai.accounts.signOut), findsOneWidget);
      expect(find.text(t.ai.google.changeSignsOut), findsNothing);
      await tester.enterText(
        find.byType(TextField).first,
        '987654321-xyz.apps.googleusercontent.com',
      );
      await tester.pump();
      expect(find.text(t.ai.google.changeSignsOut), findsOneWidget);
    });

    testWidgets('a ChatGPT code sign-in shows the code', (tester) async {
      chatgpt.setStatus(
        const AiAccountStatus(
          .signingIn,
          detail: 'Enter the code WXYZ-1234 at auth.openai.com/codex/device',
        ),
      );
      await pumpSettings(tester);
      expect(find.text('WXYZ-1234'), findsOneWidget);
      expect(find.text(t.ai.accounts.deviceCode.copy), findsOneWidget);
    });

    testWidgets('an action picks a model, lazily', (tester) async {
      await pumpSettings(tester);
      expect(
        find.text(
          t.ai.actionsSettings.automaticUses(provider: 'Claude · Sonnet'),
        ),
        findsOneWidget, // illustration
      );
      await tester.tap(find.byTooltip(AiAction.illustration.title));
      await tester.pumpAndSettle();
      expect(find.text('GPT Image 2'), findsOneWidget);
      expect(find.text('Fable'), findsOneWidget);
      await tester.tap(find.text('Opus'));
      await tester.pumpAndSettle();
      expect(AiRouter.routes[AiAction.illustration]!.value, 'claude:opus');
      expect(find.text('Claude · Opus'), findsOneWidget);

      // Searches can't use picture models
      await tester.tap(find.byTooltip(AiAction.video.title));
      await tester.pumpAndSettle();
      expect(find.text('GPT Image 2'), findsNothing);
      await tester.tap(find.text(t.ai.actionsSettings.automatic).last);
      await tester.pumpAndSettle();
      expect(AiRouter.routes[AiAction.video]!.value, AiRouter.auto);
    });
  });

  group('snapshots', skip: !higanSnapshotsEnabled, () {
    const devices = [
      ('ipad', Size(1180, 820), TargetPlatform.iOS),
      ('mac', Size(1440, 900), TargetPlatform.macOS),
    ];
    const themes = [('night', Brightness.dark), ('paper', Brightness.light)];

    for (final (device, size, platform) in devices) {
      for (final (theme, brightness) in themes) {
        void onIpad() {
          if (platform != .iOS) return;
          claude.setStatus(
            const AiAccountStatus(
              .unavailable,
              detail:
                  'Claude runs through Claude Code on your Mac and isn\'t '
                  'available on iPad.',
            ),
          );
        }

        testWidgets('menu $device $theme', (tester) async {
          onIpad();
          await _snapshot(
            tester,
            name: 'aiacc_menu_${device}_$theme',
            path: notePath,
            size: size,
            platform: platform,
            brightness: brightness,
            interact: (editor) async {
              await _lassoTitle(tester, editor);
              unawaited(showAiMenu(editor.context, editor));
              await tester.pump();
            },
          );
        });

        testWidgets('menu gated $device $theme', (tester) async {
          signOutAll();
          onIpad();
          await _snapshot(
            tester,
            name: 'aiacc_menu_gated_${device}_$theme',
            path: notePath,
            size: size,
            platform: platform,
            brightness: brightness,
            interact: (editor) async {
              await _lassoTitle(tester, editor);
              unawaited(showAiMenu(editor.context, editor));
              await tester.pump();
            },
          );
        });

        for (final (state, action, setUp) in _states) {
          testWidgets('$state $device $theme', (tester) async {
            onIpad();
            final fakes = (chatgpt: chatgpt, claude: claude, google: google);
            setUp(fakes);
            // What it read (see _readingStates): acc_*
            final prefix = _readingStates.contains(state) ? 'acc' : 'aiacc';
            await _snapshot(
              tester,
              name: '${prefix}_${state}_${device}_$theme',
              path: notePath,
              size: size,
              platform: platform,
              brightness: brightness,
              interact: (editor) async {
                await _lassoTitle(tester, editor);
                final png = await tester.runAsync(() => selectionPngOf(editor));
                unawaited(
                  showAiResult(
                    editor.context,
                    action: action,
                    input: AiInput(png: png!),
                    onAddText: (_, _) {},
                    onAddImage: (_, _, _) {},
                  ),
                );
                await _realWait(tester);
                await tester.pump(const Duration(milliseconds: 400));
                if (state == 'streaming') {
                  _partial?.call(_answer.substring(0, 120));
                }
                if (state == 'editing' || state == 'rereading') {
                  await tester.tap(find.text('Metric Spaces'));
                  await tester.pump();
                  await tester.enterText(
                    find.descendant(
                      of: find.byType(AiResultSheet),
                      matching: find.byType(TextField),
                    ),
                    'Metric spaces',
                  );
                }
                if (state == 'rereading') {
                  await tester.tap(find.text(t.ai.askAgain));
                }
                await tester.pump();
              },
            );
          });
        }

        testWidgets('nothing to read $device $theme', (tester) async {
          onIpad();
          await _snapshot(
            tester,
            name: 'acc_nothing_${device}_$theme',
            path: notePath,
            size: size,
            platform: platform,
            brightness: brightness,
            interact: (editor) async {
              await tester.tap(
                find.descendant(
                  of: find.byType(Toolbar),
                  matching: find.byTooltip(t.ai.askAi),
                ),
              );
              await tester.pump();
              await _stylus(tester, editor, _nothing);
            },
          );
        });

        testWidgets('video $device $theme', (tester) async {
          onIpad();
          google.onSearch = (_, _) async => _videos;
          await _snapshot(
            tester,
            name: 'aiacc_video_${device}_$theme',
            path: notePath,
            size: size,
            platform: platform,
            brightness: brightness,
            interact: (editor) async {
              await _lassoTitle(tester, editor);
              unawaited(
                showWebResults(
                  editor.context,
                  initialQuery: 'metric space definition',
                  kind: .video,
                ),
              );
              await _realWait(tester);
            },
          );
        });

        for (final (state, setUp) in _settingsStates) {
          testWidgets('settings $state $device $theme', (tester) async {
            setUp((chatgpt: chatgpt, claude: claude, google: google));
            onIpad();
            await higanSnapshot(
              tester,
              name: 'aiacc_settings_${state}_${device}_$theme',
              size: size,
              brightness: brightness,
              platform: platform,
              child: const _AiSettings(),
            );
            if (state == 'picker') {
              await tester.tap(find.byTooltip(AiAction.illustration.title));
              await _recapture(
                tester,
                'aiacc_settings_${state}_${device}_$theme',
              );
            }
          });
        }
      }
    }
  });
}

typedef _Fakes = ({
  FakeAiProvider chatgpt,
  FakeAiProvider claude,
  FakeAiProvider google,
});

/// Streams the "streaming" snapshot's answer.
void Function(String)? _partial;

/// Result sheet states for snapshots: (name, action, fake setup).
final _states = <(String, AiAction, void Function(_Fakes))>[
  (
    'loading',
    .explainExample,
    (ai) => ai.chatgpt.onRespond = (_, _) => Completer<String>().future,
  ),
  (
    'streaming',
    .paragraph,
    (ai) => ai.chatgpt.onRespond = (_, onPartial) {
      _partial = onPartial;
      return Completer<String>().future;
    },
  ),
  ('text', .paragraph, (ai) => ai.chatgpt.onRespond = (_, _) async => _answer),
  (
    'chart',
    .graph,
    (ai) => ai.chatgpt.onRespond = (_, _) async => _functionJson,
  ),
  ('bars', .graph, (ai) => ai.chatgpt.onRespond = (_, _) async => _dataJson),
  (
    'illustration',
    .illustration,
    (ai) {
      ai.claude.onRespond = (_, _) async => _drawing;
      // On iPad, Claude isn't there: ChatGPT draws lines (Free plan)
      ai.chatgpt.modelList = const [AiModel('gpt-5.4', 'GPT-5.4')];
      ai.chatgpt.onRespond = (_, _) async => _drawing;
    },
  ),
  ('reading', .paragraph, _answersWithReading),
  ('editing', .paragraph, _answersWithReading),
  (
    'rereading',
    .paragraph,
    (ai) => ai.chatgpt.onRespond = (_, _) => ai.chatgpt.requests.length == 1
        ? Future.value(_withReading)
        : Completer<String>().future,
  ),
  (
    'unreadable',
    .graph,
    (ai) => ai.chatgpt.onRespond = (_, _) async => _unreadableJson,
  ),
  (
    'error',
    .paragraph,
    (ai) => ai.chatgpt.onRespond = (_, _) async => throw const AiError(
      AiError.limit,
      'ChatGPT plan limit reached. It resets in 2 hours.',
    ),
  ),
];

/// The [_states] about what the AI read.
const _readingStates = {'reading', 'editing', 'rereading', 'unreadable'};

const _withReading = 'You wrote: Metric Spaces\n\n$_answer';

void _answersWithReading(_Fakes ai) =>
    ai.chatgpt.onRespond = (_, _) async => _withReading;

/// A lasso between the title and the name: nothing to read.
const _nothing = [
  Offset(430, 25),
  Offset(690, 25),
  Offset(690, 85),
  Offset(430, 85),
  Offset(430, 30),
];

/// AI settings states for snapshots: (name, fake setup).
final _settingsStates = <(String, void Function(_Fakes))>[
  (
    'none',
    (ai) {
      ai.chatgpt.setStatus(AiAccountStatus.signedOut);
      ai.claude.setStatus(AiAccountStatus.signedOut);
      ai.google.setStatus(
        const AiAccountStatus(.unavailable, detail: 'Set up Google first.'),
      );
    },
  ),
  (
    'code',
    (ai) {
      ai.chatgpt.setStatus(
        const AiAccountStatus(
          .signingIn,
          detail: 'Enter the code WXYZ-1234 at auth.openai.com/codex/device',
        ),
      );
      ai.claude.setStatus(
        const AiAccountStatus(
          .signedOut,
          detail: 'Open Terminal, run claude, then type /login.',
        ),
      );
      stows.aiGoogleClientId.value =
          '123456789-abc123.apps.googleusercontent.com';
      stows.aiGoogleProjectId.value = 'nts-notes';
      ai.google.setStatus(AiAccountStatus.signedOut);
    },
  ),
  ('all', _setUpGoogle),
  (
    'picker',
    (ai) {
      _setUpGoogle(ai);
      AiRouter.routes[AiAction.paragraph]!.value = 'claude:opus';
    },
  ),
];

void _setUpGoogle(_Fakes _) {
  stows.aiGoogleClientId.value = '123456789-abc123.apps.googleusercontent.com';
  stows.aiGoogleProjectId.value = 'nts-notes';
}

/// The two AI sections of Settings, as they are laid out there.
class _AiSettings extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const .fromLTRB(44, 0, 44, 96),
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: const Column(
          crossAxisAlignment: .stretch,
          children: [AiAccountsSection(), AiActionsSection()],
        ),
      ),
    ),
  );
}

/// Pumps a little, then writes what [higanSnapshot] drew as [name] again.
Future<void> _recapture(WidgetTester tester, String name) async {
  debugDisableShadows = false;
  try {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: .png);
      image.dispose();
      await File('$higanSnapshotDir/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
  } finally {
    debugDisableShadows = true;
  }
}

/// The lasso's selection in [editor] as the AI menu sends it.
Future<Uint8List?> selectionPngOf(EditorState editor) => selectionPng(
  editor.coreInfo,
  SelectionActions.selectionOf(editor.currentTool)!,
);

const _drawing =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" '
    'fill="none" stroke="#2B2A28" stroke-width="3" stroke-linecap="round" '
    'stroke-linejoin="round">'
    '<circle cx="140" cy="360" r="14"/><circle cx="372" cy="160" r="14"/>'
    '<circle cx="400" cy="380" r="14"/>'
    '<path d="M152 350 L360 170" stroke="#D0283A"/>'
    '<path d="M154 362 L386 378"/><path d="M376 174 L398 366"/>'
    '<path d="M250 250 q20 -30 40 -8" stroke="#A87A2E"/></svg>';

final _videos = [
  AiLink(
    title: 'Metric spaces — definition and examples',
    url: Uri.parse('https://www.youtube.com/watch?v=abc'),
    source: 'Dr Peyam',
  ),
  AiLink(
    title: 'What is a metric space? | Real analysis',
    url: Uri.parse('https://www.youtube.com/watch?v=def'),
    source: 'The Bright Side of Mathematics',
  ),
  AiLink(
    title: 'The triangle inequality, visually',
    url: Uri.parse('https://www.youtube.com/watch?v=ghi'),
    source: '3Blue1Brown',
  ),
];

const _answer =
    'A metric space is a set where you can measure the distance between '
    'any two points. The distance is never negative, and it is zero only '
    'when the two points are the same. It is the same in both directions, '
    'and going through a third point is never shorter than going straight '
    'there: that last rule is the triangle inequality.';

const _functionJson =
    '{"kind":"function","title":"f(x) = x² − 2x","expression":"x^2 - 2*x",'
    '"xMin":-2,"xMax":4,"xLabel":"x","yLabel":"f(x)","points":[]}';

const _unreadableJson =
    '{"reading":"?","kind":"none","title":"","expression":"","xMin":0,'
    '"xMax":0,"xLabel":"","yLabel":"","points":[]}';

const _dataJson =
    '{"kind":"bar","title":"Hours studied","expression":"","xMin":0,'
    '"xMax":0,"xLabel":"Day","yLabel":"Hours","points":[{"label":"Mon","y":2},'
    '{"label":"Tue","y":3.5},{"label":"Wed","y":1},{"label":"Thu","y":4},'
    '{"label":"Fri","y":2.5}]}';

Widget _app(Widget home, {ThemeData? theme}) => TranslationProvider(
  child: MaterialApp(
    theme: theme ?? HiganTheme.night(.iOS),
    home: Scaffold(body: home),
  ),
);

/// Opens the answer sheet for [action] from a button, like the menu does.
Future<void> _openSheet(
  WidgetTester tester, {
  required AiAction action,
  void Function(String)? onAddText,
  void Function(Uint8List, String)? onAddImage,
  void Function(String text, int side)? onAddTextAt,
}) async {
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showAiResult(
            context,
            action: action,
            input: testInput(),
            onAddText:
                onAddTextAt ??
                (onAddText == null ? null : (text, _) => onAddText(text)),
            onAddImage: onAddImage == null
                ? null
                : (bytes, extension, _) => onAddImage(bytes, extension),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// "Metric Spaces", in page coordinates.
const _title = Rect.fromLTRB(5, 15, 350, 110);

/// For [_snapshot].
final _boundaryKey = GlobalKey();

Future<EditorState> _openNote(
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

/// Draws through [points] (page coordinates) with a stylus.
Future<void> _stylus(
  WidgetTester tester,
  EditorState editor,
  List<Offset> points,
) async {
  final box = editor.coreInfo.pages.first.renderBox!;
  final gesture = await tester.createGesture(kind: .stylus);
  await gesture.down(box.localToGlobal(points.first));
  for (final point in points.skip(1)) {
    await gesture.moveTo(box.localToGlobal(point));
  }
  await gesture.up();
  await tester.pump();
}

/// Pumps, with real time passing (for images and PNGs), until [done].
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(done(), isTrue);
}

/// Lets real time pass (e.g. for a PNG to be made), pumping.
Future<void> _realWait(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

/// Selects the title with the lasso, without the gesture.
Future<void> _lassoTitle(WidgetTester tester, EditorState editor) async {
  final page = editor.coreInfo.pages.first;
  final select = Select.currentSelect
    ..onDragStart(_title.topLeft, 0)
    ..onDragUpdate(_title.topRight)
    ..onDragUpdate(_title.bottomRight)
    ..onDragUpdate(_title.bottomLeft);
  select.onDragEnd(page.strokes, page.images);
  editor.currentTool = select;
  tester.element(find.byType(Editor)).markNeedsBuild();
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Opens [path] at [size], runs [interact], then writes
/// `<higanSnapshotDir>/<name>.png`.
Future<void> _snapshot(
  WidgetTester tester, {
  required String name,
  required String path,
  required Size size,
  required TargetPlatform platform,
  required Brightness brightness,
  required Future<void> Function(EditorState editor) interact,
}) async {
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
    final editor = await _openNote(
      tester,
      path,
      theme: brightness == .dark
          ? HiganTheme.night(platform)
          : HiganTheme.paper(platform),
    );
    await interact(editor);
    for (var i = 0; i < 12; i++) {
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
    editor.cancelAutosaveAndMarkSaved();
    // Dispose the editor while shadows are still allowed
    await tester.pumpWidget(const SizedBox());
  } finally {
    debugDisableShadows = true;
  }
}
