import 'package:flutter/material.dart';
import 'package:nts/components/settings/settings_row.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/pages/home/settings.dart';
import 'package:stow/stow.dart';

/// A settings row with a pill segmented control, e.g. NIGHT | PAPER | SYSTEM.
class SettingsSelection<T> extends StatefulWidget {
  const new({
    super.key,
    required this.title,
    this.subtitle,
    required this.pref,
    required this.options,
    this.afterChange,
  });

  final String title;
  final String? subtitle;

  final Stow<dynamic, T, dynamic> pref;
  final List<HiganSegment<T>> options;
  final ValueChanged<T>? afterChange;

  @override
  State<SettingsSelection<T>> createState() => _SettingsSelectionState<T>();
}

class _SettingsSelectionState<T> extends State<SettingsSelection<T>> {
  @override
  void initState() {
    widget.pref.addListener(onChanged);
    super.initState();
  }

  void onChanged() {
    widget.afterChange?.call(widget.pref.value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      title: widget.title,
      subtitle: widget.subtitle,
      wide: true,
      modified: widget.pref.value != widget.pref.defaultValue,
      onTap: () {
        // cycle through options
        final i = widget.options.indexWhere(
          (option) => option.value == widget.pref.value,
        );
        widget.pref.value =
            widget.options[(i + 1) % widget.options.length].value;
      },
      onLongPress: () {
        SettingsPage.showResetDialog(
          context: context,
          pref: widget.pref,
          prefTitle: widget.title,
        );
      },
      trailing: HiganSegmented<T>(
        segments: widget.options,
        value: widget.pref.value,
        onChanged: (value) => widget.pref.value = value,
      ),
    );
  }

  @override
  void dispose() {
    widget.pref.removeListener(onChanged);
    super.dispose();
  }
}
