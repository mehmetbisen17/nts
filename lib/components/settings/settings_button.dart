import 'package:flutter/material.dart';
import 'package:nts/components/settings/settings_row.dart';

class SettingsButton extends StatelessWidget {
  const new({
    super.key,
    required this.title,
    this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      title: title,
      subtitle: subtitle,
      showChevron: true,
      onTap: onPressed,
    );
  }
}
