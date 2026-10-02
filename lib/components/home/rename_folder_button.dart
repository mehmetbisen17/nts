import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/home/new_folder_dialog.dart';
import 'package:nts/components/theming/adaptive_alert_dialog.dart';
import 'package:nts/components/theming/adaptive_text_field.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/i18n/strings.g.dart';

class RenameFolderButton extends StatelessWidget {
  const new({
    super.key,
    required this.folderName,
    required this.doesFolderExist,
    required this.renameFolder,
  });

  final String folderName;
  final bool Function(String) doesFolderExist;
  final Future<void> Function(String newName) renameFolder;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: .zero,
      tooltip: t.home.renameFolder.renameFolder,
      onPressed: () => showRenameFolderDialog(
        context,
        folderName: folderName,
        doesFolderExist: doesFolderExist,
        renameFolder: renameFolder,
      ),
      icon: const Icon(Symbols.edit, weight: 300),
    );
  }
}

/// Asks for a new name for [folderName], then calls [renameFolder].
Future<void> showRenameFolderDialog(
  BuildContext context, {
  required String folderName,
  required bool Function(String) doesFolderExist,
  required Future<void> Function(String newName) renameFolder,
}) => showDialog(
  context: context,
  builder: (context) => _RenameFolderDialog(
    folderName: folderName,
    doesFolderExist: doesFolderExist,
    renameFolder: renameFolder,
  ),
);

class _RenameFolderDialog extends StatefulWidget {
  const new({
    required this.folderName,
    required this.doesFolderExist,
    required this.renameFolder,
  });

  final String folderName;
  final bool Function(String) doesFolderExist;
  final Future<void> Function(String newName) renameFolder;

  @override
  State<_RenameFolderDialog> createState() => _RenameFolderDialogState();
}

class _RenameFolderDialogState extends State<_RenameFolderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  String? validateFolderName(String? folderName) {
    if (folderName == null || folderName.isEmpty) {
      return t.home.renameFolder.folderNameEmpty;
    }
    if (folderName.contains('/') || folderName.contains('\\')) {
      return t.home.renameFolder.folderNameContainsSlash;
    }
    if (folderName != widget.folderName && widget.doesFolderExist(folderName)) {
      return t.home.renameFolder.folderNameExists;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _controller.text = widget.folderName;
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAlertDialog(
      title: Text(t.home.renameFolder.renameFolder),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: DialogFieldKeys(
          controller: _controller,
          onSubmit: submit,
          child: AdaptiveTextField(
            controller: _controller,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            focusOrder: const NumericFocusOrder(1),
            placeholder: t.home.renameFolder.folderName,
            prefixIcon: const Icon(Symbols.edit, weight: 300),
            validator: validateFolderName,
          ),
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
          onPressed: submit,
          child: Text(t.home.renameFolder.rename),
        ),
      ],
    );
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_controller.text != widget.folderName) {
      await widget.renameFolder(_controller.text);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
