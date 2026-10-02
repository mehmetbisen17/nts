import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/home/grid_folders.dart';
import 'package:nts/components/home/masonry_files.dart';
import 'package:nts/components/home/move_note_button.dart';
import 'package:nts/components/home/new_folder_dialog.dart';
import 'package:nts/components/home/new_note_button.dart';
import 'package:nts/components/home/path_components.dart';
import 'package:nts/components/home/sort_button.dart';
import 'package:nts/components/icloud/icloud_widgets.dart';
import 'package:nts/components/navbar/responsive_navbar.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:path/path.dart' as p;

/// The Folders screen: a folder's subfolders, then its notes,
/// as a gallery or a list (each folder remembers its own choice).
class BrowsePage extends StatefulHookWidget {
  const new({super.key, String? path}) : initialPath = path;

  final String? initialPath;

  @visibleForTesting
  static DirectoryChildren? overrideChildren;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  DirectoryChildren? children;
  var loaded = false;

  /// Subfolder name -> what its tile shows.
  var folderInfos = <String, FolderInfo>{};

  /// Notes in the whole library (only counted at the root).
  int? libraryNotes;

  String? path;

  final ValueNotifier<List<String>> selectedFiles = ValueNotifier([]);

  @override
  void initState() {
    path = widget.initialPath;

    findChildrenOfPath();
    fileWriteSubscription = FileManager.fileWriteStream.stream.listen(
      fileWriteListener,
    );
    selectedFiles.addListener(_setState);

    super.initState();
  }

  @override
  void didUpdateWidget(BrowsePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // e.g. the system back button changed the route's folder
    if (widget.initialPath != oldWidget.initialPath &&
        widget.initialPath != path) {
      path = widget.initialPath;
      selectedFiles.value = [];
      findChildrenOfPath();
    }
  }

  @override
  void dispose() {
    selectedFiles.removeListener(_setState);
    fileWriteSubscription?.cancel();
    super.dispose();
  }

  StreamSubscription? fileWriteSubscription;
  void fileWriteListener(FileOperation event) {
    if (!event.filePath.startsWith(path ?? '/')) return;
    findChildrenOfPath(fromFileListener: true);
  }

  void _setState() => setState(() {});

  Future findChildrenOfPath({bool fromFileListener = false}) async {
    if (!mounted) return;

    if (fromFileListener) {
      // don't refresh if we're not on the home page
      final location = GoRouterState.of(context).uri.toString();
      if (!location.startsWith(RoutePaths.prefixOfHome)) return;
    }

    final path = this.path;
    final children =
        BrowsePage.overrideChildren ??
        await FileManager.getChildrenOfDirectory(
          path ?? '/',
          sortMetric: stows.browseSortMetric.value,
        );
    if (!mounted || path != this.path) return;
    setState(() {
      this.children = children;
      loaded = true;
    });

    // Then the folder tiles' previews and the library count.
    final folders = children?.directories ?? const <String>[];
    final (infos, allFiles) = await (
      Future.wait([
        for (final folder in folders)
          FolderInfo.load(p.join(path ?? '/', folder)),
      ]),
      path == null ? FileManager.getAllFiles() : Future<List<String>?>.value(),
    ).wait;
    if (!mounted || path != this.path) return;
    setState(() {
      folderInfos = Map.fromIterables(folders, infos);
      libraryNotes = allFiles?.length;
    });
  }

  void onDirectoryTap(String folder) {
    if (folder == '..') {
      final parent = p.dirname(path ?? '/');
      return onPathComponentTap(parent);
    }
    onPathComponentTap(p.join(path ?? '/', folder));
  }

  void onPathComponentTap(String? newPath) {
    selectedFiles.value = [];
    if (newPath == null || newPath.isEmpty || newPath == '/') {
      newPath = null;
    }
    path = newPath;
    context.go(HomeRoutes.browseFilePath(path ?? '/'));
    findChildrenOfPath();
  }

  Future<void> createFolder(String folderName) async {
    final folderPath = '${path ?? ''}/$folderName';
    await FileManager.createFolder(folderPath);
    findChildrenOfPath();
  }

  bool doesFolderExist(String folderName) =>
      children?.directories.contains(folderName) ?? false;

  void showNewFolderDialog() => showDialog(
    context: context,
    builder: (context) => NewFolderDialog(
      createFolder: createFolder,
      doesFolderExist: doesFolderExist,
    ),
  );

  /// Up to the parent folder (the mouse's back button, ⌘[ or ⌘↑).
  void goUp() {
    if (path != null) onDirectoryTap('..');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < 600;
    useValueListenable(stows.folderViewModes);
    useOnListenableChange(stows.browseSortMetric, findChildrenOfPath);
    useOnListenableChange(ICloudStorage.state, findChildrenOfPath);

    final viewMode = FolderViewMode.of(path ?? '/');
    final folders = children?.directories ?? const <String>[];
    final files = [
      for (final file in children?.files ?? const <String>[])
        '${path ?? ''}/$file',
    ];
    final bothKinds = folders.isNotEmpty && files.isNotEmpty;
    final selecting = selectedFiles.value.isNotEmpty;
    final pagePadding = ResponsiveNavbar.pagePadding(context);

    return Scaffold(
      // Let the home shell's background (and ember) show through.
      backgroundColor: Colors.transparent,
      body: CallbackShortcuts(
        bindings: {
          cmdKey(.keyN, shift: true): showNewFolderDialog,
          cmdKey(.bracketLeft): goUp,
          cmdKey(.arrowUp): goUp,
        },
        child: NoteShortcuts(
          files: files,
          selectedFiles: selectedFiles,
          folder: path,
          child: Listener(
            onPointerDown: (event) {
              if (event.buttons & kBackMouseButton != 0) goUp();
            },
            child: CustomScrollView(
              // So the arrow and page keys scroll it on desktop too.
              primary: true,
              slivers: [
                SliverSafeArea(
                  // Less the label's tap padding (see _Header), so the
                  // heading lines up with Recent's.
                  minimum: pagePadding.copyWith(
                    top: pagePadding.top - PathComponents.textInset(context),
                  ),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _Header(
                          path: path,
                          phone: phone,
                          folderCount: folders.length,
                          noteCount: files.length,
                          libraryNotes: libraryNotes,
                          onPathComponentTap: onPathComponentTap,
                          actions: [
                            HiganCircleButton(
                              icon: Symbols.create_new_folder,
                              tooltip: t.home.newFolder.newFolder,
                              onPressed: showNewFolderDialog,
                            ),
                            const BrowseSortButton(),
                            ICloudRefreshButton(
                              onRefreshed: findChildrenOfPath,
                            ),
                          ],
                        ),
                      ),
                      const SliverToBoxAdapter(child: ICloudBanner()),
                      if (bothKinds) _SectionLabel(t.higan.folders),
                      if (folders.isNotEmpty)
                        GridFolders(
                          isAtRoot: path == null,
                          viewMode: viewMode,
                          infos: folderInfos,
                          onTap: onDirectoryTap,
                          createFolder: createFolder,
                          doesFolderExist: doesFolderExist,
                          renameFolder: (String oldName, String newName) async {
                            final oldPath = '${path ?? ''}/$oldName';
                            await FileManager.renameDirectory(oldPath, newName);
                            findChildrenOfPath();
                          },
                          isFolderEmpty: (String folderName) async {
                            final folderPath = '${path ?? ''}/$folderName';
                            final children =
                                await FileManager.getChildrenOfDirectory(
                                  folderPath,
                                );
                            return children?.isEmpty ?? true;
                          },
                          deleteFolder: (String folderName) async {
                            final folderPath = '${path ?? ''}/$folderName';
                            await FileManager.deleteDirectory(folderPath);
                            findChildrenOfPath();
                          },
                          folders: folders,
                          onDropNotes: (folder, files) => moveNotes(
                            context,
                            files,
                            '${path ?? ''}/$folder/',
                          ),
                        ),
                      if (bothKinds) _SectionLabel(t.higan.looseNotes, top: 48),
                      if (files.isNotEmpty)
                        MasonryFiles(
                          files: files,
                          selectedFiles: selectedFiles,
                          viewMode: viewMode,
                        ),
                      if (loaded && folders.isEmpty && files.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const .only(top: 64),
                            child: HiganEmptyState(
                              title: t.higan.emptyFolder.title,
                              body: t.higan.emptyFolder.body,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: selecting
          ? NoteSelectionBar(selectedFiles: selectedFiles)
          : NewNoteButton(path: path),
      floatingActionButtonLocation: selecting ? .centerFloat : .endFloat,
    );
  }
}

/// "LIBRARY · 6 FOLDERS · 47 NOTES" (or the breadcrumb), the big title,
/// the quiet [actions] and the GALLERY | LIST switch.
class _Header extends StatelessWidget {
  const new({
    required this.path,
    required this.phone,
    required this.folderCount,
    required this.noteCount,
    required this.libraryNotes,
    required this.onPathComponentTap,
    required this.actions,
  });

  final String? path;
  final bool phone;
  final int folderCount, noteCount;
  final int? libraryNotes;
  final void Function(String? path) onPathComponentTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final atRoot = path == null;
    final viewSwitch = HiganViewSwitch(path: path ?? '/');
    final controls = Row(
      mainAxisSize: .min,
      spacing: 10,
      children: phone ? actions : [...actions, const SizedBox(), viewSwitch],
    );
    return Padding(
      padding: const .only(bottom: 30),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            crossAxisAlignment: .end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    if (atRoot)
                      // Same height as the breadcrumb's tap targets, so the
                      // header doesn't jump when opening a folder.
                      Padding(
                        padding: .symmetric(
                          vertical: PathComponents.textInset(context),
                        ),
                        child: HiganLabel(
                          [
                            t.higan.library,
                            t.higan.foldersCount(n: folderCount),
                            if (libraryNotes != null)
                              t.higan.notesCount(n: libraryNotes!),
                          ].join(' · '),
                        ),
                      )
                    else
                      PathComponents(
                        path,
                        onPathComponentTap: onPathComponentTap,
                        trailing: t.higan.notesCount(n: noteCount),
                      ),
                    const SizedBox(height: 4),
                    HiganTitle(
                      atRoot ? t.higan.folders : p.basename(path!),
                      size: phone ? 34 : 40,
                    ),
                  ],
                ),
              ),
              if (!phone) ...[const SizedBox(width: 16), controls],
            ],
          ),
          if (phone)
            Padding(
              padding: const .only(top: HiganSpace.l),
              // Wraps at large text sizes instead of overflowing.
              child: Wrap(
                alignment: .spaceBetween,
                crossAxisAlignment: .center,
                spacing: 10,
                runSpacing: 10,
                children: [viewSwitch, controls],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const new(this.text, {this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: .only(top: top, bottom: 16),
      sliver: SliverToBoxAdapter(child: HiganLabel(text, size: 10)),
    );
  }
}
