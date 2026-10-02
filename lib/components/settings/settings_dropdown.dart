import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/settings/settings_row.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/pages/home/settings.dart';
import 'package:stow/stow.dart';

/// A settings row with a pill that opens a menu, for long option lists
/// (e.g. languages).
class SettingsDropdown<T> extends StatefulWidget {
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
  State<SettingsDropdown<T>> createState() => _SettingsDropdownState<T>();
}

class _SettingsDropdownState<T> extends State<SettingsDropdown<T>> {
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
    final c = context.higan;
    final label = widget.options
        .where((option) => option.value == widget.pref.value)
        .firstOrNull
        ?.label;

    return SettingsRow(
      title: widget.title,
      subtitle: widget.subtitle,
      modified: widget.pref.value != widget.pref.defaultValue,
      onLongPress: () {
        SettingsPage.showResetDialog(
          context: context,
          pref: widget.pref,
          prefTitle: widget.title,
        );
      },
      trailing: PopupMenuButton<T>(
        initialValue: widget.pref.value,
        onSelected: (value) => widget.pref.value = value,
        tooltip: widget.title,
        itemBuilder: (context) => [
          for (final option in widget.options)
            PopupMenuItem(value: option.value, child: Text(option.label)),
        ],
        child: Container(
          height: 34,
          padding: const .only(left: 14, right: 9),
          decoration: ShapeDecoration(
            shape: StadiumBorder(side: BorderSide(color: c.hairlineStrong)),
          ),
          child: Row(
            mainAxisSize: .min,
            spacing: 6,
            children: [
              Text(label ?? '', style: HiganText.body(context, size: 13.5)),
              Icon(
                Symbols.expand_more,
                size: 16,
                weight: 300,
                color: c.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.pref.removeListener(onChanged);
    super.dispose();
  }
}
