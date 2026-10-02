import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nts/components/theming/adaptive_circular_progress_indicator.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/i18n/strings.g.dart';

class ExportBar extends StatefulWidget {
  const new({
    super.key,
    required this.axis,
    required this.toggleExportBar,
    required this.exportAsSba,
    required this.exportAsPdf,
    required this.exportAsPng,
  });

  final Axis axis;

  final VoidCallback toggleExportBar;

  final Future Function(BuildContext)? exportAsSba;
  final Future Function(BuildContext)? exportAsPdf;
  final Future Function(BuildContext)? exportAsPng;

  @override
  State<ExportBar> createState() => _ExportBarState();
}

class _ExportBarState extends State<ExportBar> {
  /// The current export function being executed.
  /// If this is null, no export is being executed.
  Future Function(BuildContext)? _currentlyExporting;

  void Function()? _onPressed(
    Future Function(BuildContext)? exportFunction,
    BuildContext context,
  ) {
    if (_currentlyExporting != null) return null;
    if (exportFunction == null) return null;
    return () {
      setState(() => _currentlyExporting = exportFunction);
      exportFunction(context).then((_) {
        widget.toggleExportBar();
        setState(() => _currentlyExporting = null);
      });
    };
  }

  Widget _buttonChild(
    Future Function(BuildContext)? exportFunction,
    String text,
  ) {
    if (exportFunction == null || _currentlyExporting != exportFunction) {
      return Text(text);
    } else {
      // if this is currently exporting, show a loading icon
      return AdaptiveCircularProgressIndicator.textStyled(alpha: 0.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final style = TextButton.styleFrom(
      foregroundColor: c.text,
      textStyle: HiganText.label(context, size: 11),
      minimumSize: const Size(52, 36),
      padding: const .symmetric(horizontal: 12),
    );
    Widget button(Future Function(BuildContext)? export, String text) =>
        Builder(
          builder: (context) => TextButton(
            style: style,
            onPressed: _onPressed(export, context),
            child: _buttonChild(export, text),
          ),
        );

    final children = <Widget>[
      Padding(
        padding: const .symmetric(horizontal: 10, vertical: 6),
        child: HiganLabel(t.editor.toolbar.exportAs),
      ),
      button(widget.exportAsSba, 'SBA'),
      button(widget.exportAsPdf, 'PDF'),
      button(widget.exportAsPng, 'PNG'),
    ];

    return ScrollConfiguration(
      // A mouse drag scrolls it too
      behavior: ScrollConfiguration.of(context)
          .copyWith(dragDevices: PointerDeviceKind.values.toSet()),
      child: SingleChildScrollView(
        scrollDirection: widget.axis,
        child: Flex(
          direction: widget.axis,
          mainAxisSize: .min,
          children: children,
        ),
      ),
    );
  }
}
