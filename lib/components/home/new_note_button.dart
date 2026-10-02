import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/navbar/responsive_navbar.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';

/// `null` for the root folder.
String? _folder(String? path) =>
    (path == null || path.isEmpty || path == '/') ? null : path;

/// Opens a new note in the folder [path] (null for the root).
Future<void> createNote(BuildContext context, String? path) async {
  path = _folder(path);
  if (path == null) {
    context.push(RoutePaths.edit);
    return;
  }
  final newFilePath = await FileManager.newFilePath('$path/');
  if (!context.mounted) return;
  context.push(RoutePaths.editFilePath(newFilePath));
}

/// Lets the user pick an sbn, sbn2, sba or pdf file and opens it
/// as a note in the folder [path] (null for the root).
Future<void> importNote(BuildContext context, String? path) async {
  final folder = _folder(path) ?? '';
  final file = await FilePicker.pickFile(type: FileType.any);
  if (file == null) return;

  final filePath = file.path;
  final fileName = file.name;
  if (filePath == null) return;

  if (filePath.toLowerCase().endsWith('.sbn') ||
      filePath.toLowerCase().endsWith('.sbn2') ||
      filePath.toLowerCase().endsWith('.sba')) {
    final newPath = await FileManager.importFile(filePath, '$folder/');
    if (newPath == null) return;
    if (!context.mounted) return;

    context.push(RoutePaths.editFilePath(newPath));
  } else if (filePath.toLowerCase().endsWith('.pdf')) {
    if (!Editor.canRasterPdf) return;
    if (!context.mounted) return;

    final fileNameWithoutExtension = fileName.substring(
      0,
      fileName.length - '.pdf'.length,
    );
    final sbnFilePath = await FileManager.suffixFilePathToMakeItUnique(
      '$folder/$fileNameWithoutExtension',
    );
    if (!context.mounted) return;

    context.push(RoutePaths.editImportPdf(sbnFilePath, filePath));
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.home.invalidFormat)));
    }
    throw 'Invalid file type';
  }
}

/// The red new-note button for a page's [Scaffold.floatingActionButton].
/// Tapping it offers "New note" and "Import note".
///
/// Shows nothing in the desktop sidebar layout, where the shell shows
/// [NewNotePill] above the page instead.
class NewNoteButton extends StatefulWidget {
  const new({super.key, this.cupertino = false, this.path});

  /// Unused; kept so existing callers still compile.
  final bool cupertino;

  /// The folder new notes go in, or null for the root.
  final String? path;

  @override
  State<NewNoteButton> createState() => _NewNoteButtonState();
}

class _NewNoteButtonState extends State<NewNoteButton> {
  final isDialOpen = ValueNotifier(false);

  @override
  void dispose() {
    isDialOpen.dispose();
    super.dispose();
  }

  SpeedDialChild _child(IconData icon, String label, VoidCallback onTap) {
    final c = context.higan;
    return SpeedDialChild(
      child: Icon(icon, size: 18, weight: 300),
      label: label,
      onTap: onTap,
      backgroundColor: c.surface2,
      foregroundColor: c.text,
      elevation: 0,
      shape: CircleBorder(side: BorderSide(color: c.hairlineStrong)),
      labelBackgroundColor: c.surface2,
      labelStyle: HiganText.body(context, size: 14),
      labelShadow: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveNavbar.isSidebarLayout(context)) {
      return const SizedBox.shrink();
    }
    final c = context.higan;
    return Padding(
      // With the Scaffold's 16px margin: 30 from the right, 34 from the bottom.
      padding: const .only(right: 14, bottom: 18),
      child: SpeedDial(
        openCloseDial: isDialOpen,
        spacing: 10,
        spaceBetweenChildren: 8,
        childPadding: const .all(5),
        switchLabelPosition: Directionality.of(context) == .rtl,
        overlayColor: c.bg,
        overlayOpacity: 0.6,
        dialRoot: (context, open, toggleChildren) => HiganFab(
          onPressed: toggleChildren,
          tooltip: t.home.tooltips.newNote,
          icon: open ? Symbols.close : Symbols.add,
        ),
        children: [
          _child(
            Symbols.edit,
            t.home.create.newNote,
            () => createNote(context, widget.path),
          ),
          _child(
            Symbols.file_open,
            t.home.create.importNote,
            () => importNote(context, widget.path),
          ),
        ],
      ),
    );
  }
}

/// Desktop: an import button and the red "New note" pill,
/// top-right of the content.
class NewNotePill extends StatelessWidget {
  const new({super.key, this.path});

  /// The folder new notes go in, or null for the root.
  final String? path;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return Row(
      mainAxisSize: .min,
      spacing: 10,
      children: [
        HiganCircleButton(
          icon: Symbols.file_open,
          tooltip: t.home.create.importNote,
          onPressed: () => importNote(context, path),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const .all(.circular(HiganRadius.pill)),
            boxShadow: [
              BoxShadow(
                color: c.higan.withValues(alpha: 0.28),
                offset: const Offset(0, 8),
                blurRadius: 24,
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: () => createNote(context, path),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const .fromLTRB(13, 0, 16, 0),
              textStyle: HiganText.body(context, size: 13.5),
            ),
            icon: const Icon(Symbols.add, size: 15, weight: 500),
            label: Text(t.higan.newNote),
          ),
        ),
      ],
    );
  }
}
