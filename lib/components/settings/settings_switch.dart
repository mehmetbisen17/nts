import 'package:flutter/material.dart';
import 'package:nts/components/settings/settings_row.dart';
import 'package:nts/pages/home/settings.dart';
import 'package:stow/stow.dart';

class SettingsSwitch extends StatefulWidget {
  const new({
    super.key,
    required this.title,
    this.subtitle,
    required this.pref,
    this.afterChange,
  });

  final String title;
  final String? subtitle;

  final Stow<dynamic, bool, dynamic> pref;
  final ValueChanged<bool>? afterChange;

  @override
  State<SettingsSwitch> createState() => _SettingsSwitchState();
}

class _SettingsSwitchState extends State<SettingsSwitch> {
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
    return MergeSemantics(
      child: SettingsRow(
        title: widget.title,
        subtitle: widget.subtitle,
        modified: widget.pref.value != widget.pref.defaultValue,
        onTap: () => widget.pref.value = !widget.pref.value,
        onLongPress: () {
          SettingsPage.showResetDialog(
            context: context,
            pref: widget.pref,
            prefTitle: widget.title,
          );
        },
        trailing: Switch(
          value: widget.pref.value,
          onChanged: (bool value) => widget.pref.value = value,
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
