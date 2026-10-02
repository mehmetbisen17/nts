import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/home/delete_note_button.dart';
import 'package:nts/components/home/export_note_button.dart';
import 'package:nts/components/home/move_note_button.dart';
import 'package:nts/components/home/new_note_button.dart';
import 'package:nts/components/home/preview_card.dart';
import 'package:nts/components/home/rename_note_button.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/i18n/strings.g.dart';

/// A sliver of notes: a gallery of paper cards or a list of rows
/// (see [PreviewCard]). Long-press or ⌘-click adds to [selectedFiles].
///
/// It adds no horizontal padding; put it inside the page's gutter.
class MasonryFiles extends StatelessWidget {
  const new({
    super.key,
    required this.files,
    required this.selectedFiles,
    this.viewMode = .gallery,
    this.crossAxisCount,
  });

  /// Note paths without the extension, e.g. `/Mathematics/Limits`.
  final List<String> files;
  final ValueNotifier<List<String>> selectedFiles;
  final FolderViewMode viewMode;

  /// Gallery columns. Defaults to one per ~190px (see [galleryColumns]).
  final int? crossAxisCount;

  /// Shift-click: selects from the last selected note to [filePath].
  /// That note stays last, so the next Shift-click extends from it too.
  void selectRange(String filePath) {
    final selected = selectedFiles.value;
    final anchor = selected.isEmpty ? -1 : files.indexOf(selected.last);
    final index = files.indexOf(filePath);
    if (anchor < 0) {
      selectedFiles.value = {...selected, filePath}.toList();
      return;
    }
    final range = files.sublist(
      math.min(anchor, index),
      math.max(anchor, index) + 1,
    );
    selectedFiles.value = [
      for (final file in {...selected, ...range})
        if (file != files[anchor]) file,
      files[anchor],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([selectedFiles, stows.galleryScale]),
      builder: (context, _) => SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          PreviewCard card(int index) => PreviewCard(
            filePath: files[index],
            selectedFiles: selectedFiles,
            selectRange: () => selectRange(files[index]),
            viewMode: viewMode,
            narrow: width < 560,
            topBorder: index == 0,
          );
          return switch (viewMode) {
            .gallery => SliverAlignedGrid.count(
              crossAxisCount: crossAxisCount ?? galleryColumns(width, 190),
              mainAxisSpacing: 30,
              crossAxisSpacing: 22,
              itemCount: files.length,
              itemBuilder: (context, index) => card(index),
            ),
            .list => SliverList.builder(
              itemCount: files.length,
              itemBuilder: (context, index) => card(index),
            ),
          };
        },
      ),
    );
  }
}

/// Columns for a gallery [width] wide whose items are about [itemWidth]
/// wide, times [Stows.galleryScale]. At least 2, except that phones
/// (under 600 wide) go down to 1 when scaled up.
int galleryColumns(double width, double itemWidth) {
  final scale = stows.galleryScale.value.clamp(0.5, 2.0);
  final min = scale > 1 && width < 600 ? 1 : 2;
  return math.max(min, width ~/ (itemWidth * scale));
}

/// Floating pill with actions for the notes in [selectedFiles]:
/// clear, rename (one note), move, delete, export.
///
/// Use it as the [Scaffold.floatingActionButton] (with
/// [FloatingActionButtonLocation.centerFloat]) while anything is selected.
class NoteSelectionBar extends StatelessWidget {
  const new({super.key, required this.selectedFiles});

  final ValueNotifier<List<String>> selectedFiles;

  @override
  Widget build(BuildContext context) {
    final files = selectedFiles.value;
    void unselect() => selectedFiles.value = [];
    return HiganPill(
      padding: const .symmetric(horizontal: 7),
      child: AnimatedSize(
        duration: HiganMotion.fast,
        curve: HiganMotion.curve,
        child: Row(
          mainAxisSize: .min,
          children: [
            HiganCircleButton(
              icon: Symbols.close,
              tooltip: t.common.cancel,
              bordered: false,
              onPressed: unselect,
            ),
            Padding(
              padding: const .only(left: 2, right: 10),
              child: HiganLabel('${files.length}', color: context.higan.text),
            ),
            if (files.length == 1)
              RenameNoteButton(
                existingPath: files.first,
                unselectNotes: unselect,
              ),
            MoveNoteButton(filesToMove: files, unselectNotes: unselect),
            DeleteNoteButton(filesToDelete: files, unselectNotes: unselect),
            ExportNoteButton(selectedFiles: files),
          ],
        ),
      ),
    );
  }
}

/// ⌘[key] on Apple platforms, Ctrl+[key] elsewhere.
SingleActivator cmdKey(LogicalKeyboardKey key, {bool shift = false}) {
  final apple =
      defaultTargetPlatform == .macOS || defaultTargetPlatform == .iOS;
  return SingleActivator(key, meta: apple, control: !apple, shift: shift);
}

/// Finder-style keys for a page of notes: ⌘A selects all of [files], Esc
/// clears the selection, Delete or ⌫ deletes it (after the usual
/// confirmation), and ⌘N makes a new note in [folder]. Clicking empty
/// space with the mouse clears the selection too.
///
/// It takes focus when nothing else has it, so the keys work straight away.
class NoteShortcuts extends StatelessWidget {
  const new({
    super.key,
    required this.files,
    required this.selectedFiles,
    this.folder,
    required this.child,
  });

  final List<String> files;
  final ValueNotifier<List<String>> selectedFiles;

  /// Where new notes go, or null for the root.
  final String? folder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    void unselect() => selectedFiles.value = [];
    void delete() {
      if (selectedFiles.value.isEmpty) return;
      showDeleteNoteDialog(context, selectedFiles.value, unselect);
    }

    return CallbackShortcuts(
      bindings: {
        cmdKey(.keyA): () => selectedFiles.value = [...files],
        const SingleActivator(.escape): unselect,
        const SingleActivator(.delete): delete,
        const SingleActivator(.backspace): delete,
        cmdKey(.keyN): () => createNote(context, folder),
      },
      child: Focus(
        autofocus: true,
        // Clicks on notes and buttons still go to them.
        child: GestureDetector(
          supportedDevices: const {.mouse},
          onTap: selectedFiles.value.isEmpty ? null : unselect,
          child: child,
        ),
      ),
    );
  }
}
