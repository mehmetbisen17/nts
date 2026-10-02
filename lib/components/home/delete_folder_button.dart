import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/adaptive_alert_dialog.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/i18n/strings.g.dart';

class DeleteFolderButton extends StatelessWidget {
  const new({
    super.key,
    required this.folderName,
    required this.deleteFolder,
    required this.isFolderEmpty,
  });

  final String folderName;
  final Future<void> Function(String) deleteFolder;
  final Future<bool> Function(String) isFolderEmpty;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: .zero,
      tooltip: t.home.deleteFolder.deleteFolder,
      onPressed: () => showDeleteFolderDialog(
        context,
        folderName: folderName,
        deleteFolder: deleteFolder,
        isFolderEmpty: isFolderEmpty,
      ),
      icon: const Icon(Symbols.delete, weight: 300),
    );
  }
}

/// Asks to confirm (and whether to delete the notes inside), then calls
/// [deleteFolder].
Future<void> showDeleteFolderDialog(
  BuildContext context, {
  required String folderName,
  required Future<void> Function(String) deleteFolder,
  required Future<bool> Function(String) isFolderEmpty,
}) => showDialog(
  context: context,
  builder: (context) => _DeleteFolderDialog(
    folderName: folderName,
    deleteFolder: deleteFolder,
    isFolderEmpty: isFolderEmpty,
  ),
);

class _DeleteFolderDialog extends StatefulWidget {
  const new({
    required this.folderName,
    required this.deleteFolder,
    required this.isFolderEmpty,
  });

  final String folderName;
  final Future<void> Function(String) deleteFolder;
  final Future<bool> Function(String) isFolderEmpty;

  @override
  State<_DeleteFolderDialog> createState() => _DeleteFolderDialogState();
}

class _DeleteFolderDialogState extends State<_DeleteFolderDialog> {
  var isFolderEmpty = false;
  var alsoDeleteContents = false;

  @override
  void initState() {
    super.initState();
    checkIfFolderIsEmpty();
  }

  Future<void> checkIfFolderIsEmpty() async {
    isFolderEmpty = await widget.isFolderEmpty(widget.folderName);
    if (isFolderEmpty) alsoDeleteContents = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final deleteAllowed = isFolderEmpty || alsoDeleteContents;
    return AdaptiveAlertDialog(
      title: Text(t.home.deleteFolder.deleteName(f: widget.folderName)),
      content: isFolderEmpty
          ? const SizedBox.shrink()
          : Row(
              children: [
                Checkbox(
                  value: alsoDeleteContents,
                  onChanged: isFolderEmpty
                      ? null
                      : (value) {
                          setState(() => alsoDeleteContents = value!);
                        },
                ),
                Expanded(child: Text(t.home.deleteFolder.alsoDeleteContents)),
              ],
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
                  await widget.deleteFolder(widget.folderName);
                  if (context.mounted) Navigator.of(context).pop();
                }
              : null,
          isDestructiveAction: true,
          textStyle: TextStyle(color: context.higan.higanText),
          child: Text(t.home.deleteFolder.delete),
        ),
      ],
    );
  }
}
