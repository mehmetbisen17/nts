import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/adaptive_alert_dialog.dart';
import 'package:nts/components/theming/adaptive_text_field.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/i18n/strings.g.dart';

class NewFolderDialog extends StatefulWidget {
  const new({
    super.key,
    required this.createFolder,
    required this.doesFolderExist,
  });

  final void Function(String) createFolder;
  final bool Function(String) doesFolderExist;

  @override
  State<NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<NewFolderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  String? validateFolderName(String? folderName) {
    if (folderName == null || folderName.isEmpty) {
      return t.home.newFolder.folderNameEmpty;
    }
    folderName = reformatFolderName(folderName);
    if (folderName.contains('/') || folderName.contains('\\')) {
      return t.home.newFolder.folderNameContainsSlash;
    }
    if (widget.doesFolderExist(folderName)) {
      return t.home.newFolder.folderNameExists;
    }
    return null;
  }

  String reformatFolderName(String folderName) => folderName.trim();

  void create() {
    if (!_formKey.currentState!.validate()) return;
    final folderName = reformatFolderName(_controller.text);
    widget.createFolder(folderName);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAlertDialog(
      title: Text(t.home.newFolder.newFolder),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: DialogFieldKeys(
          controller: _controller,
          onSubmit: create,
          child: AdaptiveTextField(
            controller: _controller,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            focusOrder: const NumericFocusOrder(1),
            placeholder: t.home.newFolder.folderName,
            prefixIcon: const Icon(Symbols.create_new_folder, weight: 300),
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
          onPressed: create,
          child: Text(t.home.newFolder.create),
        ),
      ],
    );
  }
}

/// Around a dialog's text field: focuses it when the dialog opens, and
/// Return runs [onSubmit] (the dialog's main button), so the dialog works
/// from the keyboard without clicking into it first.
class DialogFieldKeys extends StatefulWidget {
  const new({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.child,
  });

  /// The field's controller: Return while composing (e.g. with an IME)
  /// is left to the field.
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final Widget child;

  @override
  State<DialogFieldKeys> createState() => _DialogFieldKeysState();
}

class _DialogFieldKeysState extends State<DialogFieldKeys> {
  @override
  void initState() {
    super.initState();
    // ponytail: AdaptiveTextField has no autofocus, so find its
    // EditableText; pass autofocus through instead if it gains one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Touch screens keep waiting for a tap (no keyboard popping up).
      if (!mounted || HiganTap.isTouch(context)) return;
      void visit(Element element) {
        final widget = element.widget;
        if (widget is EditableText) {
          widget.focusNode.requestFocus();
        } else {
          element.visitChildren(visit);
        }
      }

      context.visitChildElements(visit);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        final enter =
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter;
        if (event is! KeyDownEvent || !enter) return .ignored;
        if (widget.controller.value.composing.isValid) return .ignored;
        widget.onSubmit();
        return .handled;
      },
      child: widget.child,
    );
  }
}
