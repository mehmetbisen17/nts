import 'package:flutter/material.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';

/// Mono section label with a hairline below, e.g. "APPEARANCE".
class SettingsSubtitle extends StatelessWidget {
  const new({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .only(top: HiganSpace.xxl, bottom: HiganSpace.m),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.higan.hairline)),
      ),
      child: HiganLabel(subtitle),
    );
  }
}
