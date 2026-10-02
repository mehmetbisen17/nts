import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/home/grid_folders.dart';
import 'package:nts/components/theming/adaptive_alert_dialog.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';

class MoveNoteButton extends StatelessWidget {
  const new({
    super.key,
    required this.filesToMove,
    required this.unselectNotes,
  });

  final List<String> filesToMove;
  final void Function() unselectNotes;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: .zero,
      tooltip: t.home.moveNote.moveNote,
      onPressed: () => showMoveNoteDialog(context, filesToMove, unselectNotes),
      icon: const Icon(Symbols.drive_file_move, weight: 300),
    );
  }
}

/// Asks which folder to move [filesToMove] to, then moves them.
Future<void> showMoveNoteDialog(
  BuildContext context,
  List<String> filesToMove,
  VoidCallback unselectNotes,
) => showDialog(
  context: context,
  builder: (context) =>
      _MoveNoteDialog(filesToMove: filesToMove, unselectNotes: unselectNotes),
);

/// Moves the notes [files] (paths without the extension) into [folder]
/// (with a trailing slash, e.g. `/Maths/`), renaming any whose name is
/// taken there. Shows a snack bar if a note couldn't be moved.
Future<void> moveNotes(
  BuildContext context,
  List<String> files,
  String folder,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  String? error;
  for (final file in files) {
    final extension =
        FileManager.doesFileExist('$file${Editor.extensionOldJson}')
        ? Editor.extensionOldJson
        : Editor.extension;
    final name = file.substring(file.lastIndexOf('/') + 1);
    try {
      await FileManager.moveFile('$file$extension', '$folder$name$extension');
    } on FileSystemException catch (e) {
      // e.g. an asset is still downloading from iCloud
      error = e.message;
    }
  }
  if (error != null) messenger?.showSnackBar(SnackBar(content: Text(error)));
}

class _MoveNoteDialog extends StatefulWidget {
  const new({required this.filesToMove, required this.unselectNotes});

  final List<String> filesToMove;
  final void Function() unselectNotes;

  @override
  State<_MoveNoteDialog> createState() => _MoveNoteDialogState();
}

class _MoveNoteDialogState extends State<_MoveNoteDialog> {
  /// The original file names of the notes.
  late final List<String> originalFileNames = widget.filesToMove
      .map((path) => path.substring(path.lastIndexOf('/') + 1))
      .toList();

  /// The original parent folders of the notes,
  /// including the trailing slash.
  late final List<String> parentFolders = widget.filesToMove
      .map((path) => path.substring(0, path.lastIndexOf('/') + 1))
      .toList();

  /// Whether each file uses [Editor.extensionOldJson].
  /// This is populated in [findOldExtensions].
  late List<bool> oldExtensions = widget.filesToMove
      .map((name) => false)
      .toList();
  Future<void> findOldExtensions() async {
    oldExtensions = [
      for (int i = 0; i < widget.filesToMove.length; ++i)
        FileManager.doesFileExist(
          '${widget.filesToMove[i]}${Editor.extensionOldJson}',
        ),
    ];
  }

  late String _currentFolder;

  /// The current folder browsed to in the dialog.
  String get currentFolder => _currentFolder;
  set currentFolder(String folder) {
    _currentFolder = folder;
    currentFolderChildren = null;
    findChildrenOfCurrentFolder();
  }

  /// The children of [currentFolder].
  DirectoryChildren? currentFolderChildren;

  /// The file names that the notes will be moved to.
  ///
  /// These will be the same as in [fileNames], unless
  /// a file needs to be renamed to avoid a name conflict.
  /// Such a file will also be in [changedFileNames].
  late List<String> newFileNames = [];

  /// The new names of the files that needed to be renamed.
  late List<String> changedFileNames = [];

  Future findChildrenOfCurrentFolder() async {
    currentFolderChildren = await FileManager.getChildrenOfDirectory(
      currentFolder,
    );

    newFileNames = [];
    changedFileNames = [];
    for (int i = 0; i < widget.filesToMove.length; ++i) {
      final oldExtension = oldExtensions[i];
      final newFileName = await FileManager.suffixFilePathToMakeItUnique(
        '$currentFolder${originalFileNames[i]}',
        intendedExtension: oldExtension
            ? Editor.extensionOldJson
            : Editor.extension,
        currentPath:
            '${widget.filesToMove[i]}${oldExtension ? Editor.extensionOldJson : Editor.extension}',
      ).then((newPath) => newPath.substring(newPath.lastIndexOf('/') + 1));

      newFileNames.add(newFileName);

      if (newFileName != originalFileNames[i]) {
        changedFileNames.add(newFileName);
      }
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> createFolder(String folderName) async {
    final folderPath = '$currentFolder/$folderName';
    await FileManager.createFolder(folderPath);
    findChildrenOfCurrentFolder();
  }

  @override
  void initState() {
    currentFolder = _findMostCommonParentFolder();
    if (!currentFolder.startsWith('/')) {
      currentFolder = '/$currentFolder';
    }
    super.initState();

    findOldExtensions().then((_) => findChildrenOfCurrentFolder());
  }

  String _findMostCommonParentFolder() {
    final parentFolderCounts = <String, int>{};
    for (final parentFolder in parentFolders) {
      parentFolderCounts[parentFolder] =
          (parentFolderCounts[parentFolder] ?? 0) + 1;
    }
    return parentFolderCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAlertDialog(
      title: originalFileNames.length < 5
          ? Text(t.home.moveNote.moveName(f: originalFileNames.join(', ')))
          : Text(t.home.moveNote.moveNotes(n: originalFileNames.length)),
      content: SizedBox(
        width: 360,
        height: 360,
        child: Column(
          children: [
            Align(
              alignment: .centerLeft,
              child: HiganLabel(currentFolder, maxLines: 2),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CustomScrollView(
                shrinkWrap: true,
                slivers: [
                  GridFolders(
                    isAtRoot: currentFolder == '/',
                    viewMode: .list,
                    showNavigation: true,
                    onTap: (String folder) {
                      setState(() {
                        if (folder == '..') {
                          currentFolder = currentFolder.substring(
                            0,
                            currentFolder.lastIndexOf(
                                  '/',
                                  currentFolder.length - 2,
                                ) +
                                1,
                          );
                        } else {
                          currentFolder = '$currentFolder$folder/';
                        }
                      });
                    },
                    createFolder: createFolder,
                    doesFolderExist: (String folderName) {
                      return currentFolderChildren?.directories.contains(
                            folderName,
                          ) ??
                          false;
                    },
                    renameFolder: (String oldName, String newName) async {
                      final oldPath = '$currentFolder$oldName';
                      await FileManager.renameDirectory(oldPath, newName);
                      findChildrenOfCurrentFolder();
                    },
                    isFolderEmpty: (String folderName) async {
                      final folderPath = '$currentFolder$folderName';
                      final children = await FileManager.getChildrenOfDirectory(
                        folderPath,
                      );
                      return children?.isEmpty ?? true;
                    },
                    deleteFolder: (String folderName) async {
                      final folderPath = '$currentFolder$folderName';
                      await FileManager.deleteDirectory(folderPath);
                      findChildrenOfCurrentFolder();
                    },
                    folders: [
                      for (final directoryPath
                          in currentFolderChildren?.directories ?? const [])
                        directoryPath,
                    ],
                  ),
                ],
              ),
            ),
            if (changedFileNames.isEmpty)
              const SizedBox.shrink()
            else if (changedFileNames.length == 1)
              Text(t.home.moveNote.renamedTo(newName: changedFileNames.single))
            else if (changedFileNames.length < 5) ...[
              Text(t.home.moveNote.multipleRenamedTo),
              Text(changedFileNames.join(', ')),
            ] else
              Text(t.home.moveNote.numberRenamedTo(n: changedFileNames.length)),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () {
            Navigator.of(context).pop();
          },
          textStyle: TextStyle(color: context.higan.text),
          child: Text(t.common.cancel),
        ),
        CupertinoDialogAction(
          onPressed: () async {
            await moveNotes(context, widget.filesToMove, currentFolder);
            widget.unselectNotes();
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: Text(t.home.moveNote.move),
        ),
      ],
    );
  }
}
