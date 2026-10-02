import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/adaptive_alert_dialog.dart';
import 'package:nts/components/theming/adaptive_text_field.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/i18n/strings.g.dart';

/// Asks for a link to add to (or change on) a selection.
///
/// Pops with the new link, an empty string to remove the [initial] link,
/// or null if cancelled.
class LinkDialog extends StatefulWidget {
  const new({super.key, required this.initial, required this.pageCount});

  final String? initial;

  /// For checking `#page=N` links.
  final int pageCount;

  @override
  State<LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<LinkDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initial);

  String? get _url =>
      PageLink.parse(_controller.text, pageCount: widget.pageCount);

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_url);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAlertDialog(
      title: Text(
        widget.initial == null
            ? t.editor.canvasTools.addLink
            : t.editor.canvasTools.editLink,
      ),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: AdaptiveTextField(
          controller: _controller,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          focusOrder: const NumericFocusOrder(1),
          placeholder: t.editor.canvasTools.linkHint,
          prefixIcon: const Icon(Symbols.link, weight: 300),
          validator: (_) =>
              _url == null ? t.editor.canvasTools.invalidLink : null,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          textStyle: TextStyle(color: context.higan.text),
          child: Text(t.common.cancel),
        ),
        if (widget.initial != null)
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(''),
            isDestructiveAction: true,
            child: Text(t.editor.canvasTools.removeLink),
          ),
        CupertinoDialogAction(
          onPressed: _save,
          child: Text(t.editor.canvasTools.save),
        ),
      ],
    );
  }
}
