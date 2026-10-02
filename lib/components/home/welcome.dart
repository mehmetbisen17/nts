import 'package:flutter/material.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/i18n/strings.g.dart';

/// Shown on Recent before any note has been opened.
class const Welcome({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HiganEmptyState(title: t.home.welcome, body: t.home.createNewNote);
  }
}
