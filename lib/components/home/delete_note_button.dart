import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/adaptive_alert_dialog.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';

class DeleteNoteButton extends StatelessWidget {
  const new({
    super.key,
    required this.filesToDelete,
    required this.unselectNotes,
  });

  final List<String> filesToDelete;
  final void Function() unselectNotes;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      tooltip: t.home.deleteNote,
      onPressed: () =>
          showDeleteNoteDialog(context, filesToDelete, unselectNotes),
      icon: const Icon(Symbols.delete, weight: 300),
    );
  }
}

/// Asks to confirm, then deletes [filesToDelete].
Future<void> showDeleteNoteDialog(
  BuildContext context,
  List<String> filesToDelete,
  VoidCallback unselectNotes,
) => showDialog(
  context: context,
  builder: (context) => _DeleteNoteDialog(
    filesToDelete: filesToDelete,
    unselectNotes: unselectNotes,
  ),
);

class _DeleteNoteDialog extends StatefulWidget {
  const new({required this.filesToDelete, required this.unselectNotes});

  final List<String> filesToDelete;
  final void Function() unselectNotes;

  @override
  State<_DeleteNoteDialog> createState() => _DeleteNoteDialogState();
}

class _DeleteNoteDialogState extends State<_DeleteNoteDialog> {
  var deleteAllowed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAlertDialog(
      title: widget.filesToDelete.length < 5
          ? Text(
              t.home.deleteNoteDialog.deleteName(
                f: widget.filesToDelete.join(', '),
              ),
            )
          : Text(
              t.home.deleteNoteDialog.deleteNotes(
                n: widget.filesToDelete.length,
              ),
            ),
      content: CheckboxListTile.adaptive(
        value: deleteAllowed,
        onChanged: (value) => setState(() => deleteAllowed = value!),
        controlAffinity: .leading,
        title: Text(
          t.home.deleteNoteDialog.confirmDelete(n: widget.filesToDelete.length),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          textStyle: TextStyle(color: context.higan.text),
          child: Text(t.common.cancel),
        ),
        CupertinoDialogAction(
          onPressed: deleteAllowed
              ? () async {
                  await Future.wait([
                    for (final String filePath in widget.filesToDelete)
                      Future.value(
                        FileManager.doesFileExist(
                          filePath + Editor.extensionOldJson,
                        ),
                      ).then(
                        (oldExtension) => FileManager.deleteFile(
                          filePath +
                              (oldExtension
                                  ? Editor.extensionOldJson
                                  : Editor.extension),
                        ),
                      ),
                  ]);
                  if (context.mounted) Navigator.of(context).pop();
                  widget.unselectNotes();
                }
              : null,
          isDestructiveAction: true,
          textStyle: TextStyle(color: context.higan.higanText),
          child: Text(t.home.deleteNoteDialog.delete),
        ),
      ],
    );
  }
}
