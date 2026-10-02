import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:logging/logging.dart';
import 'package:nts/components/home/masonry_files.dart';
import 'package:nts/components/home/new_note_button.dart';
import 'package:nts/components/home/welcome.dart';
import 'package:nts/components/icloud/icloud_widgets.dart';
import 'package:nts/components/navbar/responsive_navbar.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/i18n/strings.g.dart';

class const RecentPage({super.key}) extends StatefulHookWidget {
  @override
  State<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends State<RecentPage> {
  final List<String> filePaths = [];
  var failed = false;

  final ValueNotifier<List<String>> selectedFiles = ValueNotifier([]);

  final log = Logger('RecentPage');

  /// Mitigates a bug where files got imported starting with `null/` instead of `/`.
  ///
  /// This caused them to be written next to the notes folder
  /// (as `<notes folder>null/...`) instead of inside it.
  void moveIncorrectlyImportedFiles() async {
    for (final filePath in stows.recentFiles.value) {
      if (filePath.startsWith('/')) continue;

      final String newFilePath;
      if (filePath.startsWith('null/')) {
        newFilePath = await FileManager.suffixFilePathToMakeItUnique(
          filePath.substring('null'.length),
        );
      } else {
        newFilePath = await FileManager.suffixFilePathToMakeItUnique(
          '/$filePath',
        );
      }

      log.warning(
        'Found incorrectly imported file at `$filePath`; moving to `$newFilePath`',
      );
      await FileManager.moveFile(filePath, newFilePath);
    }
  }

  @override
  void initState() {
    findRecentlyAccessedNotes();
    fileWriteSubscription = FileManager.fileWriteStream.stream.listen(
      fileWriteListener,
    );
    selectedFiles.addListener(_setState);

    super.initState();
    moveIncorrectlyImportedFiles();
  }

  @override
  void dispose() {
    selectedFiles.removeListener(_setState);
    fileWriteSubscription?.cancel();
    super.dispose();
  }

  StreamSubscription? fileWriteSubscription;
  void fileWriteListener(FileOperation event) {
    findRecentlyAccessedNotes(fromFileListener: true);
  }

  void _setState() => setState(() {});

  Future findRecentlyAccessedNotes({bool fromFileListener = false}) async {
    if (!mounted) return;

    if (fromFileListener) {
      // don't refresh if we're not on the home page
      final location = GoRouterState.of(context).uri.toString();
      if (!location.startsWith(RoutePaths.prefixOfHome)) return;
    }

    final children = await FileManager.getRecentlyAccessed();
    filePaths.clear();
    if (children.isEmpty) {
      failed = true;
    } else {
      failed = false;
      filePaths.addAll(children);
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    useValueListenable(stows.folderViewModes);
    useOnListenableChange(ICloudStorage.state, findRecentlyAccessedNotes);

    final phone = MediaQuery.sizeOf(context).width < 600;
    final selecting = selectedFiles.value.isNotEmpty;

    return Scaffold(
      // Let the home shell's background (and ember) show through.
      backgroundColor: Colors.transparent,
      body: NoteShortcuts(
        files: filePaths,
        selectedFiles: selectedFiles,
        child: CustomScrollView(
          // So the arrow and page keys scroll it on desktop too.
          primary: true,
          slivers: [
            SliverSafeArea(
              minimum: ResponsiveNavbar.pagePadding(context),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      phone: phone,
                      onRefreshed: findRecentlyAccessedNotes,
                    ),
                  ),
                  const SliverToBoxAdapter(child: ICloudBanner()),
                  if (failed)
                    const SliverToBoxAdapter(
                      child: Padding(padding: .only(top: 64), child: Welcome()),
                    )
                  else
                    MasonryFiles(
                      files: [...filePaths],
                      selectedFiles: selectedFiles,
                      viewMode: FolderViewMode.of(FolderViewMode.recentKey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: selecting
          ? NoteSelectionBar(selectedFiles: selectedFiles)
          : const NewNoteButton(),
      floatingActionButtonLocation: selecting ? .centerFloat : .endFloat,
    );
  }
}

/// "SAT · 26 SEP", the big "Recent" title, refresh and GALLERY | LIST.
class _Header extends StatelessWidget {
  const new({required this.phone, required this.onRefreshed});

  final bool phone;
  final VoidCallback onRefreshed;

  @override
  Widget build(BuildContext context) {
    const viewSwitch = HiganViewSwitch(path: FolderViewMode.recentKey);
    final refresh = ICloudRefreshButton(onRefreshed: onRefreshed);
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
                  spacing: 10,
                  children: [
                    HiganLabel(
                      DateFormat('EEE · d MMM').format(DateTime.now()),
                    ),
                    HiganTitle(t.higan.recent, size: phone ? 34 : 40),
                  ],
                ),
              ),
              if (!phone) ...[
                const SizedBox(width: 16),
                refresh,
                const SizedBox(width: 10),
                viewSwitch,
              ],
            ],
          ),
          if (phone)
            Padding(
              padding: const .only(top: HiganSpace.l),
              child: Row(children: [viewSwitch, const Spacer(), refresh]),
            ),
        ],
      ),
    );
  }
}
