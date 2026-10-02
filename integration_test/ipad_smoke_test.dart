// Walks the real app on an iPad (simulator or device) and screenshots each
// screen, in portrait and landscape, in Night and Paper:
//   flutter test integration_test/ipad_smoke_test.dart -d <iPad id> \
//     --dart-define=IPAD_SMOKE_OUT=/folder/for/screenshots
// Without IPAD_SMOKE_OUT, screenshots go to the app's temp folder (printed as
// IPAD_SMOKE_OUT). Every check prints `IPAD_SMOKE OK|FAIL ...`; Flutter
// errors (e.g. overflows), severe logs and missing plugins print
// `IPAD_SMOKE PROBLEM ...` and fail the test at the end.
//
// It expects a fresh account state: no AI account signed in and iCloud not
// connected (the simulator's default). iPadOS windowing refuses programmatic
// rotation, so the other orientation (and a narrow window) is faked with the
// view size and screenshotted from Flutter's own frame.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logging/logging.dart';
import 'package:nts/components/ai/ai_menu.dart';
import 'package:nts/components/settings/ai_accounts.dart';
import 'package:nts/components/settings/settings_icloud.dart';
import 'package:nts/components/toolbar/customize_toolbar_sheet.dart';
import 'package:nts/components/toolbar/selection_bar.dart';
import 'package:nts/components/toolbar/toolbar.dart';
import 'package:nts/data/ai/providers/claude_code_provider.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/main.dart' as app;
import 'package:nts/pages/editor/editor.dart';
import 'package:nts/pages/home/home.dart';
import 'package:permission_handler/permission_handler.dart';

const _outArg = String.fromEnvironment('IPAD_SMOKE_OUT');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Animations run as in the app, not only when the test pumps.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('iPad smoke', timeout: const Timeout(Duration(minutes: 20)), (
    tester,
  ) async {
    final smoke = _Smoke(tester, binding);
    final onError = FlutterError.onError;
    FlutterError.onError = smoke.onFlutterError;
    final logs = Logger.root.onRecord.listen(smoke.onLog);
    try {
      await smoke.run();
    } finally {
      await logs.cancel();
      FlutterError.onError = onError;
      await SystemChrome.setPreferredOrientations(const []);
      tester.view.reset();
    }
    smoke.report();
    expect(smoke.problems, isEmpty, reason: smoke.problems.join('\n'));
  });
}

class _Smoke {
  new(this.tester, this.binding);

  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;
  final problems = <String>[];
  final notes = <String>[];
  late final Directory out;
  var _shots = 0;
  var orientation = 'portrait';
  var theme = 'night';
  var step = 'starting';

  /// The note made in the first pass, opened again in the others.
  String? notePath;

  String get _where => '[$orientation $theme] $step';

  void problem(String what) {
    problems.add('$_where: $what');
    debugPrint('IPAD_SMOKE PROBLEM $_where: $what');
  }

  void note(String what) {
    notes.add('$_where: $what');
    debugPrint('IPAD_SMOKE NOTE $_where: $what');
  }

  void check(bool ok, String what) {
    debugPrint('IPAD_SMOKE ${ok ? 'OK' : 'FAIL'} $_where: $what');
    if (!ok) problems.add('$_where: $what');
  }

  void onFlutterError(FlutterErrorDetails details) {
    problem('Flutter error: ${details.exceptionAsString().split('\n').first}');
    FlutterError.dumpErrorToConsole(details, forceReport: true);
  }

  void onLog(LogRecord record) {
    final line =
        '${record.level.name} ${record.loggerName}: ${record.message}'
        '${record.error == null ? '' : ' (${record.error})'}';
    if (record.level >= Level.SEVERE ||
        line.contains('MissingPluginException')) {
      problem('log $line');
    } else if (record.level >= Level.WARNING) {
      note('log $line');
    }
  }

  void report() {
    debugPrint('IPAD_SMOKE_OUT ${out.path}');
    debugPrint('IPAD_SMOKE_SUMMARY ${problems.length} problems, $_shots shots');
    for (final line in notes) {
      debugPrint('IPAD_SMOKE_SUMMARY note $line');
    }
    for (final line in problems) {
      debugPrint('IPAD_SMOKE_SUMMARY problem $line');
    }
  }

  // ---------------------------------------------------------------- helpers

  Future<void> settle([int ms = 600]) async {
    for (var elapsed = 0; elapsed < ms; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<bool> until(
    bool Function() done,
    String what, {
    int timeoutMs = 10000,
  }) async {
    for (var elapsed = 0; elapsed < timeoutMs; elapsed += 100) {
      if (done()) return true;
      await tester.pump(const Duration(milliseconds: 100));
    }
    final ok = done();
    if (!ok) problem('timed out waiting for $what');
    return ok;
  }

  bool shown(Finder finder) => finder.hitTestable().evaluate().isNotEmpty;

  /// Text (e.g. uppercased labels) regardless of case.
  Finder text(String s) => find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        (widget.data ?? widget.textSpan?.toPlainText())?.toLowerCase() ==
            s.toLowerCase(),
    description: 'text "$s" (any case)',
  );

  Future<bool> tap(Finder finder, String what, {int settleMs = 600}) async {
    final hit = finder.hitTestable();
    if (hit.evaluate().isEmpty) {
      problem("can't tap $what: not on screen");
      return false;
    }
    await tester.tap(hit.first);
    await settle(settleMs);
    return true;
  }

  Future<void> shot(String name) async {
    await settle(400);
    final n = '${++_shots}'.padLeft(2, '0');
    final file = 'sim_${n}_${name}_${orientation}_$theme.png';
    try {
      final bytes = fakeSize
          ? await _renderedFrame()
          : await binding.takeScreenshot(file);
      File('${out.path}/$file').writeAsBytesSync(bytes);
      debugPrint('IPAD_SMOKE SHOT $file');
    } catch (e) {
      problem('screenshot $file failed: $e');
    }
  }

  /// Whether the view's size is faked, e.g. landscape on a portrait
  /// screen. The engine then doesn't show the frames, so [shot] renders
  /// them itself (without native views such as the folder picker).
  var fakeSize = false;

  Future<List<int>> _renderedFrame() async {
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    final image = await layer.toImage(Offset.zero & tester.view.physicalSize);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  Future<void> scrollTo(Finder finder) async {
    if (finder.evaluate().isEmpty) return;
    await Scrollable.ensureVisible(
      tester.element(finder.first),
      alignment: 0.1,
    );
    await settle(400);
  }

  NavigatorState get rootNavigator =>
      tester.state<NavigatorState>(find.byType(Navigator).first);

  /// Closes dialogs, menus and sheets.
  Future<void> closePopups() async {
    rootNavigator.popUntil((route) => route is! PopupRoute);
    await settle(500);
  }

  EditorState get editor => tester.state<EditorState>(find.byType(Editor));

  int get strokeCount =>
      editor.coreInfo.pages.fold(0, (sum, page) => sum + page.strokes.length);

  /// Where the first page's strokes are on screen.
  Rect? strokesOnScreen() {
    final page = editor.coreInfo.pages.first;
    final box = page.innerCanvasKey.currentContext?.findRenderObject();
    if (box is! RenderBox || page.strokes.isEmpty) return null;
    final bounds = page.strokes
        .map((stroke) => stroke.bounds)
        .reduce((a, b) => a.expandToInclude(b));
    return MatrixUtils.transformRect(box.getTransformTo(null), bounds);
  }

  Finder inToolbar(Finder finder) =>
      find.descendant(of: find.byType(Toolbar), matching: finder);

  /// Real event times: a touch right after a stylus lifts (same time
  /// stamp) is a palm and ignored.
  final _clock = Stopwatch()..start();

  Future<void> drawStroke(List<Offset> points, PointerDeviceKind kind) async {
    final gesture = await tester.createGesture(kind: kind);
    await gesture.down(points.first, timeStamp: _clock.elapsed);
    await tester.pump(const Duration(milliseconds: 20));
    for (final point in points.skip(1)) {
      await gesture.moveTo(point, timeStamp: _clock.elapsed);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up(timeStamp: _clock.elapsed);
    await settle(300);
  }

  static List<Offset> line(Offset from, Offset to, {int steps = 12}) => [
    for (var i = 0; i <= steps; i++) Offset.lerp(from, to, i / steps)!,
  ];

  static List<Offset> zigzag(Offset start, {int teeth = 4}) => [
    for (var i = 0; i <= teeth * 2; i++)
      start + Offset(i * 22.0, i.isEven ? 0 : 50),
  ];

  static List<Offset> circle(Offset center, double r) => [
    for (var i = 0; i <= 24; i++)
      center + Offset(cos(i / 24 * 2 * pi) * r, sin(i / 24 * 2 * pi) * r),
  ];

  /// Around [r], stopping just short of the start like a hand would.
  static List<Offset> rect(Rect r) => [
    ...line(r.topLeft, r.topRight, steps: 8),
    ...line(r.topRight, r.bottomRight, steps: 8).skip(1),
    ...line(r.bottomRight, r.bottomLeft, steps: 8).skip(1),
    ...line(r.bottomLeft, r.topLeft + const Offset(0, 12), steps: 8).skip(1),
  ];

  Future<void> setOrientation(bool landscape) async {
    orientation = landscape ? 'landscape' : 'portrait';
    step = 'rotating';
    tester.view.resetPhysicalSize();
    fakeSize = false;
    await SystemChrome.setPreferredOrientations(
      landscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
    await settle(2000);
    final size = tester.view.physicalSize;
    if ((size.width > size.height) != landscape) {
      // The request is ignored where the window can't turn (e.g. iPadOS
      // windowing): show the other layout at the same scale instead.
      note(
        'rotation request ignored (view ${size.width}x${size.height}); '
        'faking it with the view size',
      );
      tester.view.physicalSize = Size(size.height, size.width);
      fakeSize = true;
      await settle(1000);
    }
    final logical = tester.view.physicalSize / tester.view.devicePixelRatio;
    debugPrint('IPAD_SMOKE $orientation logical size $logical');
  }

  Future<void> setTheme(bool night) async {
    theme = night ? 'night' : 'paper';
    stows.appTheme.value = night ? ThemeMode.dark : ThemeMode.light;
    await settle(800);
  }

  BuildContext get homeContext => tester.element(find.byType(HomePage));

  Future<void> goHome(String subpage) async {
    final index = HomePage.subpages.indexOf(subpage);
    GoRouter.of(homeContext).go(HomeRoutes.routes[index].path);
    await settle(900);
  }

  // ------------------------------------------------------------------ run

  Future<void> run() async {
    out = _outDir();
    step = 'launch';
    await app.main(const []);
    await until(
      () => find.byType(HomePage).evaluate().isNotEmpty,
      'the home page',
      timeoutMs: 30000,
    );
    await settle(1500);
    await shot('first_launch');

    // The first launch asks about error reports. Decline, so it stays away.
    if (shown(text(t.sentry.consent.answers.no))) {
      await tap(text(t.sentry.consent.answers.no), 'Sentry "No"');
    }

    await nativeChecks();

    await setOrientation(false);
    await setTheme(true);
    await fullPass();

    for (final (landscape, night) in const [
      (true, true),
      (true, false),
      (false, false),
    ]) {
      await setOrientation(landscape);
      await setTheme(night);
      await screensPass();
    }

    // iPadOS windows can be any size, e.g. a narrow one beside another app.
    await setOrientation(false);
    orientation = 'narrow';
    fakeSize = true;
    tester.view.physicalSize =
        const Size(420, 900) * tester.view.devicePixelRatio;
    await setTheme(true);
    await screensPass();

    // Last: the native folder picker, which the test can't close.
    await setOrientation(false);
    await setTheme(true);
    await connectICloud();
  }

  /// The platform channels and plugins the iPad app relies on.
  Future<void> nativeChecks() async {
    step = 'native';
    Future<void> guarded(String what, Future<void> Function() body) async {
      try {
        await body().timeout(const Duration(seconds: 30));
      } on MissingPluginException catch (e) {
        problem('$what: MissingPluginException $e');
      } catch (e) {
        problem('$what: $e');
      }
    }

    check(ICloudStorage.isSupported, 'iCloud folder is supported');
    check(
      ICloudStorage.state.value == ICloudState.notConnected,
      'iCloud not connected yet (${ICloudStorage.state.value})',
    );
    debugPrint('IPAD_SMOKE notes folder ${FileManager.documentsDirectory}');
    check(Editor.canRasterPdf, 'printing can raster PDFs (PDF import)');

    await guarded('nts/icloud_folder resolveBookmark', () async {
      try {
        await const MethodChannel('nts/icloud_folder')
            .invokeMethod('resolveBookmark', {'bookmark': 'AAAA'});
        problem('a junk bookmark resolved');
      } on PlatformException catch (e) {
        check(e.code == 'RESOLVE_FAILED', 'iCloud channel answers (${e.code})');
      }
    });
    await guarded('nts/icloud_folder startDownloads', () async {
      final count = await const MethodChannel('nts/icloud_folder')
          .invokeMethod<int>('startDownloads', {
            'path': FileManager.documentsDirectory,
          });
      check(count == 0, 'iCloud startDownloads on a local folder ($count)');
    });
    await guarded('nts/handwriting recognize', () async {
      final png = await _textPng('hello world');
      final text = await const MethodChannel('nts/handwriting')
          .invokeMethod<String>('recognize', {
            'png': png,
            'languages': ['en-US'],
          });
      check(
        (text ?? '').toLowerCase().contains('hello'),
        'Vision reads printed text: "$text"',
      );
    });
    await guarded('flutter_secure_storage', () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'ipad_smoke_probe', value: 'ok');
      final value = await storage.read(key: 'ipad_smoke_probe');
      await storage.delete(key: 'ipad_smoke_probe');
      check(value == 'ok', 'keychain round trip ($value)');
    });
    await guarded('permission_handler photosAddOnly', () async {
      final status = await Permission.photosAddOnly.status;
      // Granted beforehand with `simctl privacy grant photos-add`, if so
      debugPrint('IPAD_SMOKE photosAddOnly status $status');
      note('Permission.photosAddOnly.status = $status');
    });
    await guarded('saver_gallery saves to Photos', () async {
      if (!await Permission.photosAddOnly.status.isGranted) {
        note('no add-only Photos access, so no image saved');
        return;
      }
      // What Export → PNG and the lasso's "Save image" do
      await FileManager.exportFile(
        'ipad_smoke.png',
        await _textPng('nts'),
        isImage: true,
        context: tester.element(find.byType(Scaffold).first),
      );
      await settle(300);
      check(
        !shown(find.text(t.common.savePhotoFailed)),
        'an image saves to Photos with add-only access',
      );
      await settle(4000); // the snack bar, if any, goes
    });
  }

  /// Every screen, with the drawing, lasso, AI and toolbar interactions.
  Future<void> fullPass() async {
    await homeScreens();

    step = 'new note';
    await goHome(HomePage.recentSubpage);
    if (!await tap(find.byTooltip(t.home.tooltips.newNote), 'the + button')) {
      return;
    }
    await shot('new_note_dial');
    await tap(text(t.home.create.newNote).last, '"New note"', settleMs: 1500);
    if (!await until(
      () => find.byType(Toolbar).evaluate().isNotEmpty,
      'the editor',
    )) {
      return;
    }
    await settle(1000);
    await shot('editor_new');
    notePath = editor.coreInfo.filePath;
    debugPrint('IPAD_SMOKE note $notePath');

    step = 'stylus strokes';
    final center = tester.getCenter(find.byType(Editor));
    final origin = center + const Offset(-180, -200);
    stows.editorFingerDrawing.value = true;
    await drawStroke(
      line(origin, origin + const Offset(260, 0)),
      PointerDeviceKind.stylus,
    );
    await drawStroke(
      zigzag(origin + const Offset(0, 50)),
      PointerDeviceKind.stylus,
    );
    await drawStroke(
      circle(origin + const Offset(300, 90), 45),
      PointerDeviceKind.stylus,
    );
    check(strokeCount == 3, 'stylus drew 3 strokes ($strokeCount)');
    // A stylus turns finger drawing off (autoDisable...WhenStylusDetected)
    check(
      !stows.editorFingerDrawing.value,
      'the stylus turned finger drawing off',
    );
    await shot('editor_stylus');

    step = 'finger, drawing off';
    stows.editorFingerDrawing.value = false;
    final before = strokeCount;
    final swipe = line(
      origin + const Offset(0, 220),
      origin + const Offset(0, 140),
    );
    await drawStroke(swipe, PointerDeviceKind.touch);
    // and scroll back where it was
    await drawStroke(swipe.reversed.toList(), PointerDeviceKind.touch);
    check(strokeCount == before, 'a finger scrolls, no stroke ($strokeCount)');

    step = 'customize sheet';
    if (await tap(
      find.byTooltip(t.editor.customizeToolbar.customize),
      'the toolbar +',
    )) {
      await shot('toolbar_sheet');
      final item = text(t.editor.customizeToolbar.tools.fingerDrawing);
      final sheetScroll = find
          .descendant(
            of: find.byType(CustomizeToolbarSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      try {
        await tester.scrollUntilVisible(
          item.hitTestable(),
          120,
          scrollable: sheetScroll,
        );
        await settle(300);
        await shot('toolbar_sheet_finger_item');
        await tap(item, '"Draw with finger"');
      } catch (e) {
        problem('finger drawing item not in the sheet: $e');
      }
      await closePopups();
    }

    step = 'finger, drawing on';
    final toggle = inToolbar(
      find.byTooltip(t.editor.toolbar.toggleFingerDrawing),
    );
    check(shown(toggle), 'finger drawing toggle added to the toolbar');
    if (shown(toggle)) {
      await tap(toggle, 'finger drawing toggle');
      check(stows.editorFingerDrawing.value, 'the toggle turns it on');
    } else {
      stows.editorFingerDrawing.value = true;
    }
    await drawStroke(
      line(origin + const Offset(0, 180), origin + const Offset(220, 200)),
      PointerDeviceKind.touch,
    );
    check(strokeCount == before + 1, 'a finger draws ($strokeCount)');
    await shot('editor_finger');

    await lassoAndMenus(center, full: true);

    step = 'back home';
    await backToHome();
    await settingsScreens();
    check(
      find.byType(HomePage).evaluate().isNotEmpty,
      'still running after the full pass',
    );
  }

  /// The main screens again (another orientation or theme).
  Future<void> screensPass() async {
    await homeScreens();
    await settingsScreens();

    final path = notePath;
    if (path == null) return;
    step = 'editor';
    await goHome(HomePage.recentSubpage);
    GoRouter.of(homeContext).push(RoutePaths.editFilePath(path));
    if (!await until(
      () => find.byType(Toolbar).evaluate().isNotEmpty,
      'the editor',
    )) {
      return;
    }
    await settle(1200);
    await shot('editor');
    await lassoAndMenus(tester.getCenter(find.byType(Editor)), full: false);
    step = 'back home';
    await backToHome();
  }

  Future<void> homeScreens() async {
    step = 'recent';
    await goHome(HomePage.recentSubpage);
    check(
      shown(text(t.icloud.connect)),
      'the home iCloud banner offers Connect',
    );
    await shot('home_recent');

    step = 'folders';
    await tap(text(t.higan.folders), 'the Folders tab', settleMs: 900);
    check(find.byType(HomePage).evaluate().isNotEmpty, 'folders page');
    await tap(text(t.higan.gallery), 'Gallery');
    await shot('folders_gallery');
    await tap(text(t.higan.list), 'List');
    await shot('folders_list');
    await tap(text(t.higan.gallery), 'Gallery');

    step = 'whiteboard';
    await tap(text(t.higan.whiteboard), 'the Whiteboard tab', settleMs: 1200);
    await shot('whiteboard');
  }

  Future<void> settingsScreens() async {
    step = 'settings';
    await goHome(HomePage.recentSubpage);
    await tap(find.byTooltip(t.higan.settings), 'the settings button');
    await shot('settings_top');

    step = 'settings iCloud';
    await scrollTo(find.byType(SettingsICloud));
    check(
      shown(text(t.icloud.connectICloud)),
      'settings iCloud card offers "Connect iCloud"',
    );
    await shot('settings_icloud');

    step = 'settings AI accounts';
    await scrollTo(find.byType(AiAccountsSection));
    await settle(800); // each account checks its status
    checkAiAccounts(find.byType(AiAccountsSection));
    await shot('settings_ai_accounts');
    await scrollTo(text(t.ai.actionsSettings.title));
    await shot('settings_ai_actions');
  }

  /// ChatGPT: signed out with Sign in; Claude: Mac only, no buttons;
  /// Google: needs setup.
  void checkAiAccounts(Finder section) {
    Finder inside(Finder f) => find.descendant(of: section, matching: f);
    check(
      inside(text(t.ai.accounts.macOnly)).evaluate().length == 1,
      'Claude says Mac only',
    );
    check(
      inside(find.text(ClaudeCodeProvider.notOnThisDevice)).evaluate().length ==
          1,
      "Claude says why it isn't on iPad",
    );
    check(
      inside(text(t.ai.accounts.notSignedIn)).evaluate().length == 1,
      'ChatGPT is not signed in',
    );
    check(
      inside(find.widgetWithText(FilledButton, t.ai.accounts.signIn))
              .evaluate()
              .length ==
          1,
      'one Sign in button (ChatGPT)',
    );
    check(
      inside(text(t.ai.accounts.useCode)).evaluate().length == 1,
      'ChatGPT offers a code sign-in',
    );
    check(
      inside(text(t.ai.google.notSetUp)).evaluate().length == 1 &&
          inside(text(t.ai.google.title)).evaluate().length == 1,
      'Google shows its setup',
    );
    check(
      inside(text(t.ai.accounts.checkAgain)).evaluate().isEmpty,
      'no account shows "Check again" (an error)',
    );
  }

  /// Lasso the strokes, then the selection bar, handwriting, the AI menu
  /// (and its settings sheet) and the toolbar sheet.
  Future<void> lassoAndMenus(Offset center, {required bool full}) async {
    step = 'lasso';
    await tap(inToolbar(find.byTooltip(t.editor.toolbar.select)), 'Select');
    final area =
        strokesOnScreen()?.inflate(40) ??
        Rect.fromCenter(
          center: center + const Offset(-20, -110),
          width: 560,
          height: 420,
        );
    await drawStroke(rect(area), PointerDeviceKind.stylus);
    await settle(800);
    final select = editor.currentTool;
    check(
      select is Select &&
          select.doneSelecting &&
          select.selectResult.strokes.length == strokeCount,
      'the lasso selected every stroke '
      '(${select is Select ? select.selectResult.strokes.length : '-'} '
      'of $strokeCount)',
    );
    check(
      find.byType(SelectionBar).evaluate().isNotEmpty,
      'the selection bar shows',
    );
    await shot('lasso_selection');

    if (full) {
      step = 'handwriting';
      final bar = find.byType(SelectionBar);
      if (await tap(
        find.descendant(
          of: bar,
          matching: find.byTooltip(t.editor.otherTools.handwriting),
        ),
        'Handwriting to text',
      )) {
        await shot('handwriting_menu');
        await tap(text(t.editor.otherTools.copyAsText), 'Copy as text');
        final failed = text(t.editor.otherTools.handwritingFailed);
        final done = find.byType(SnackBar);
        await until(
          () => done.evaluate().isNotEmpty,
          'the handwriting result',
          timeoutMs: 20000,
        );
        check(!shown(failed), 'Vision read the selection without failing');
        for (final snack
            in find
                .descendant(of: done, matching: find.byType(Text))
                .evaluate()) {
          debugPrint(
            'IPAD_SMOKE handwriting says "${(snack.widget as Text).data}"',
          );
        }
        await shot('handwriting_result');
        ScaffoldMessenger.of(tester.element(find.byType(Editor)))
            .hideCurrentSnackBar();
        await closePopups();
      }
    }

    step = 'AI menu';
    if (await tap(
      find.descendant(
        of: find.byType(SelectionBar),
        matching: find.byTooltip(t.ai.askAi),
      ),
      'Ask AI',
      settleMs: 1000,
    )) {
      check(find.byType(AiMenu).evaluate().isNotEmpty, 'the AI menu opens');
      check(
        shown(find.text(t.ai.signInToUse)),
        'the AI menu says to sign in first',
      );
      await shot('ai_menu_gated');
      if (full && await tap(text(t.ai.openSettings), 'Open Settings')) {
        await settle(800);
        final sheet = find.byType(AiAccountsSection);
        check(shown(sheet), 'AI settings open over the note');
        if (sheet.evaluate().isNotEmpty) checkAiAccounts(sheet);
        await shot('ai_settings_sheet');
      }
      await closePopups();
    }

    step = 'toolbar sheet';
    Select.currentSelect.unselect();
    if (await tap(
      find.byTooltip(t.editor.customizeToolbar.customize),
      'the toolbar +',
    )) {
      await shot('toolbar_sheet');
      await closePopups();
    }
  }

  Future<void> backToHome() async {
    final saveLabel = MaterialLocalizations.of(
      tester.element(find.byType(Editor)),
    ).saveButtonLabel;
    for (var i = 0; i < 40; i++) {
      if (find.byType(Editor).evaluate().isEmpty) break;
      if (shown(find.byTooltip(t.higan.back))) {
        await tap(find.byTooltip(t.higan.back), 'Back', settleMs: 900);
      } else if (shown(find.byTooltip(saveLabel))) {
        await tap(find.byTooltip(saveLabel), 'Save', settleMs: 500);
      } else {
        await settle(250);
      }
    }
    check(find.byType(Editor).evaluate().isEmpty, 'back on the home page');
  }

  Future<void> connectICloud() async {
    step = 'iCloud connect';
    await goHome(HomePage.recentSubpage);
    if (!await tap(text(t.icloud.connect), 'Connect (iCloud banner)')) return;
    await settle(2500);
    await shot('icloud_picker');
    // The picker is native; still running means it didn't crash.
    check(
      find.byType(HomePage).evaluate().isNotEmpty,
      'the folder picker opened without a crash',
    );
  }

  Directory _outDir() {
    if (_outArg.isNotEmpty) {
      try {
        final dir = Directory(_outArg)..createSync(recursive: true);
        File('${dir.path}/.probe')
          ..writeAsStringSync('ok')
          ..deleteSync();
        return dir;
      } catch (e) {
        debugPrint("IPAD_SMOKE can't write to $_outArg: $e");
      }
    }
    return Directory.systemTemp.createTempSync('ipad_smoke');
  }
}

/// [text] in big black print on white.
Future<Uint8List> _textPng(String text) async {
  const size = Size(900, 220);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(Offset.zero & size, Paint()..color = Colors.white);
  TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black, fontSize: 96),
      ),
      textDirection: TextDirection.ltr,
    )
    ..layout()
    ..paint(canvas, const Offset(30, 50));
  final image = await recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
