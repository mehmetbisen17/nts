import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nts/components/home/masonry_files.dart';
import 'package:nts/components/home/new_folder_dialog.dart';
import 'package:nts/components/navbar/home_sidebar.dart';
import 'package:nts/components/settings/settings_row.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/data/sentry/sentry_init.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:nts/pages/home/browse.dart';
import 'package:nts/pages/home/home.dart';

/// Home screen with a mouse (and trackpad clicks, which are mouse events)
/// on macOS: menus, Finder-style selection, drag to move, keyboard.
void main() {
  FlavorConfig.setup();
  disableSentryForTesting();
  final docs = '${Directory.systemTemp.path}/nts-mouse-home-test';
  final mac = TargetPlatformVariant.only(.macOS);
  final windowCalls = <String>[];
  late GoRouter router;

  setUp(() {
    stows.sentryConsent.value = .granted;
    stows.folderViewModes.value = {};
    windowCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), (
          call,
        ) async {
          windowCalls.add(call.method);
          return null;
        });
  });

  /// Lets file IO finish (the lily keeps animating, so no pumpAndSettle).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Folders Alpha (with a note) and Beta, and notes A to D at the root.
  Future<void> pumpHome(
    WidgetTester tester, {
    String? path,
    double height = 1400,
  }) async {
    await tester.runAsync(() async {
      if (Directory(docs).existsSync()) {
        Directory(docs).deleteSync(recursive: true);
      }
      await Directory('$docs/Alpha').create(recursive: true);
      await Directory('$docs/Beta').create(recursive: true);
      await File('$docs/Alpha/Inside.sbn2').writeAsBytes(const [0]);
      for (final name in ['A', 'B', 'C', 'D']) {
        await File('$docs/Note $name.sbn2').writeAsBytes(const [0]);
      }
    });
    await FileManager.init(
      documentsDirectory: docs,
      shouldWatchRootDirectory: false,
    );

    // Tall enough that the notes below the folders are on screen.
    tester.view
      ..physicalSize = Size(1280, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    router = GoRouter(
      initialLocation: HomeRoutes.browseFilePath(path),
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => HomePage(
            subpage: state.pathParameters['subpage'] ?? HomePage.recentSubpage,
            path: state.uri.queryParameters['path'],
          ),
        ),
        GoRoute(
          path: RoutePaths.edit,
          builder: (context, state) => const Scaffold(body: Text('editor')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp.router(
          theme: HiganTheme.night(.macOS),
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
  }

  Finder inBrowse(String text) =>
      find.descendant(of: find.byType(BrowsePage), matching: find.text(text));
  Finder inSidebar(String text) =>
      find.descendant(of: find.byType(HomeSidebar), matching: find.text(text));
  String? path() => router.state.uri.queryParameters['path'];
  Set<String> selected() => find.byType(NoteSelectionBar).evaluate().isEmpty
      ? const {}
      : {
          ...(find.byType(NoteSelectionBar).evaluate().single.widget
                  as NoteSelectionBar)
              .selectedFiles
              .value,
        };
  bool exists(WidgetTester tester, String file) =>
      File('$docs$file').existsSync();

  Future<void> click(
    WidgetTester tester,
    Finder finder, {
    int buttons = kPrimaryMouseButton,
    Offset wobble = Offset.zero,
  }) async {
    final gesture = await tester.startGesture(
      tester.getCenter(finder),
      kind: .mouse,
      buttons: buttons,
    );
    if (wobble != Offset.zero) await gesture.moveBy(wobble);
    await gesture.up();
    await tester.pump();
    await gesture.removePointer();
    await settle(tester);
  }

  Future<void> withKey(
    WidgetTester tester,
    LogicalKeyboardKey key,
    Future<void> Function() action,
  ) async {
    await tester.sendKeyDownEvent(key);
    await action();
    await tester.sendKeyUpEvent(key);
  }

  Future<void> cmd(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(.metaLeft);
    if (shift) await tester.sendKeyDownEvent(.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(.shiftLeft);
    await tester.sendKeyUpEvent(.metaLeft);
    await settle(tester);
  }

  Future<void> drag(
    WidgetTester tester,
    Finder from,
    Finder to, {
    PointerDeviceKind kind = .mouse,
  }) async {
    final start = tester.getCenter(from);
    final end = tester.getCenter(to);
    final gesture = await tester.startGesture(start, kind: kind);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
  }

  bool isFocused(WidgetTester tester, Finder field) =>
      tester.widget<EditableText>(field).focusNode.hasFocus;

  testWidgets('Right-click a note: menu; Rename works from the keyboard', (
    tester,
  ) async {
    await pumpHome(tester);
    await click(tester, inBrowse('Note A'), buttons: kSecondaryMouseButton);

    for (final label in [
      t.home.menu.open,
      t.home.menu.select,
      t.home.renameNote.rename,
      t.home.moveNote.move,
      t.home.menu.exportPdf,
      t.home.menu.exportSba,
      t.home.deleteNoteDialog.delete,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(selected(), isEmpty, reason: 'right-click no longer selects');

    await click(tester, find.text(t.home.renameNote.rename));
    final field = find.byType(EditableText);
    expect(field, findsOneWidget);
    expect(isFocused(tester, field), isTrue, reason: 'autofocused');

    await tester.enterText(field, 'Renamed');
    await tester.sendKeyEvent(.enter);
    await settle(tester);
    expect(find.byType(EditableText), findsNothing, reason: 'Return submits');
    expect(exists(tester, '/Renamed.sbn2'), isTrue);
    expect(exists(tester, '/Note A.sbn2'), isFalse);
  }, variant: mac);

  testWidgets('Right-click a list row: menu; Delete asks first', (
    tester,
  ) async {
    FolderViewMode.set('/', .list);
    await pumpHome(tester);
    await click(tester, inBrowse('Note B'), buttons: kSecondaryMouseButton);
    await click(tester, find.text(t.home.deleteNoteDialog.delete));
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(exists(tester, '/Note B.sbn2'), isTrue);
  }, variant: mac);

  testWidgets('Finder-style selection: Cmd-click, Shift-click, Cmd+A, Esc', (
    tester,
  ) async {
    await pumpHome(tester);

    await withKey(tester, .metaLeft, () async {
      await click(tester, inBrowse('Note A'));
    });
    expect(selected(), {'/Note A'});
    expect(find.byType(Editor), findsNothing, reason: 'Cmd-click selects');

    await withKey(tester, .shiftLeft, () async {
      await click(tester, inBrowse('Note C'));
    });
    expect(selected(), {'/Note A', '/Note B', '/Note C'});

    await tester.sendKeyEvent(.escape);
    await settle(tester);
    expect(selected(), isEmpty);

    await cmd(tester, .keyA);
    expect(selected(), {'/Note A', '/Note B', '/Note C', '/Note D'});

    // Clicking empty space clears the selection.
    final below = tester.getBottomLeft(inBrowse('Note A'));
    await tester.tapAt(below + const Offset(0, 120), kind: .mouse);
    await settle(tester);
    expect(selected(), isEmpty);

    // A click that wobbles a few pixels is still a click, not a drag.
    await withKey(tester, .metaLeft, () async {
      await click(tester, inBrowse('Note A'));
    });
    await click(tester, inBrowse('Note D'), wobble: const Offset(3, 2));
    expect(selected(), {'/Note A', '/Note D'});
  }, variant: mac);

  testWidgets('Delete key deletes the selection after the usual confirm', (
    tester,
  ) async {
    await pumpHome(tester);
    await withKey(tester, .metaLeft, () async {
      await click(tester, inBrowse('Note A'));
    });
    await tester.sendKeyEvent(.backspace);
    await settle(tester);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await click(tester, find.byType(Checkbox));
    await click(tester, find.text(t.home.deleteNoteDialog.delete));
    expect(exists(tester, '/Note A.sbn2'), isFalse);
    expect(selected(), isEmpty);
  }, variant: mac);

  testWidgets('Folders: right-click menu, Return, mouse back button, Cmd+[', (
    tester,
  ) async {
    await pumpHome(tester);

    // The collapsed tile's rename/delete buttons can't take focus.
    final hiddenRename = find.descendant(
      of: find.byTooltip(t.home.renameFolder.renameFolder),
      matching: find.byType(Icon),
    );
    expect(hiddenRename, findsWidgets);
    expect(Focus.of(tester.element(hiddenRename.first)).canRequestFocus, false);

    await click(tester, inBrowse('Alpha'), buttons: kSecondaryMouseButton);
    expect(find.text(t.home.renameFolder.rename), findsOneWidget);
    expect(find.text(t.home.deleteFolder.delete), findsOneWidget);
    await click(tester, find.text(t.home.menu.open));
    expect(path(), '/Alpha');

    await click(tester, find.byType(BrowsePage), buttons: kBackMouseButton);
    expect(path(), isNull);

    // Tab reaches a tile; Return opens it.
    Focus.of(tester.element(inBrowse('Beta'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(.enter);
    await settle(tester);
    expect(path(), '/Beta');

    await cmd(tester, .bracketLeft);
    expect(path(), isNull);
  }, variant: mac);

  testWidgets('Drag notes onto a folder tile or a sidebar folder', (
    tester,
  ) async {
    await pumpHome(tester);

    await drag(tester, inBrowse('Note A'), inBrowse('Beta'));
    expect(exists(tester, '/Beta/Note A.sbn2'), isTrue);
    expect(exists(tester, '/Note A.sbn2'), isFalse);

    await drag(tester, inBrowse('Note B'), inSidebar('Alpha'));
    expect(exists(tester, '/Alpha/Note B.sbn2'), isTrue);

    // Touch drags scroll, as before: nothing moves.
    await drag(tester, inBrowse('Note C'), inBrowse('Beta'), kind: .touch);
    expect(exists(tester, '/Note C.sbn2'), isTrue);
  }, variant: mac);

  testWidgets('Cmd+N makes a note; Shift+Cmd+N a folder, keyboard only', (
    tester,
  ) async {
    await pumpHome(tester);

    await cmd(tester, .keyN, shift: true);
    expect(find.byType(NewFolderDialog), findsOneWidget);
    final field = find.byType(EditableText);
    expect(isFocused(tester, field), isTrue, reason: 'autofocused');
    await tester.enterText(field, 'Gamma');
    await tester.sendKeyEvent(.enter);
    await settle(tester);
    expect(find.byType(NewFolderDialog), findsNothing);
    expect(Directory('$docs/Gamma').existsSync(), isTrue);

    await cmd(tester, .keyN);
    expect(find.text('editor'), findsOneWidget);
  }, variant: mac);

  testWidgets('Page Down scrolls the page without clicking into it first', (
    tester,
  ) async {
    await pumpHome(tester, height: 600);
    final top = tester.getTopLeft(inBrowse('Alpha')).dy;
    await tester.sendKeyEvent(.pageDown);
    await settle(tester);
    expect(tester.getTopLeft(inBrowse('Alpha')).dy, lessThan(top));
  }, variant: mac);

  testWidgets('A click on the top strip does not start a window drag', (
    tester,
  ) async {
    await pumpHome(tester);
    const strip = Offset(700, 45);
    await tester.tapAt(strip, kind: .mouse);
    await settle(tester);
    expect(windowCalls, isNot(contains('startDragging')));

    final gesture = await tester.startGesture(strip, kind: .mouse);
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.up();
    await settle(tester);
    expect(windowCalls.where((m) => m == 'startDragging'), hasLength(1));
  }, variant: mac);

  testWidgets('Right-click a settings row resets it, like long-press', (
    tester,
  ) async {
    var resets = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: HiganTheme.night(.macOS),
        home: Scaffold(
          body: SettingsRow(title: 'Setting', onLongPress: () => resets++),
        ),
      ),
    );
    await click(tester, find.text('Setting'), buttons: kSecondaryMouseButton);
    expect(resets, 1);
  }, variant: mac);
}
