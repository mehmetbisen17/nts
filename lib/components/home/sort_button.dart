import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:stow_codecs/stow_codecs.dart';

class const BrowseSortButton({super.key}) extends StatelessWidget {
  void _openDialog(BuildContext context) async {
    final selection = await showDialog<SortMetric>(
      context: context,
      builder: (context) => _SortDialog(selected: stows.browseSortMetric.value),
    );
    if (selection == null) return;
    stows.browseSortMetric.value = selection;
  }

  @override
  Widget build(BuildContext context) {
    return HiganCircleButton(
      icon: Symbols.swap_vert,
      tooltip: t.home.sort.sortBy,
      onPressed: () => _openDialog(context),
    );
  }
}

class _SortDialog extends StatelessWidget {
  const new({required this.selected});

  final SortMetric selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      alignment: .topEnd,
      insetPadding: const .all(8),
      title: Text(t.home.sort.sortBy),
      content: Column(
        mainAxisSize: .min,
        children: [
          for (final option in SortMetric.values)
            _SortDialogOption(sortMetric: option, selected: option == selected),
        ],
      ),
    );
  }
}

class _SortDialogOption extends StatelessWidget {
  const new({required this.sortMetric, required this.selected});

  final SortMetric sortMetric;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        context.pop(sortMetric);
      },
      title: Text(switch (sortMetric) {
        .nameAToZ => t.home.sort.nameAToZ,
        .nameZToA => t.home.sort.nameZToA,
        .lastModifiedNewToOld => t.home.sort.lastModifiedNewToOld,
        .lastModifiedOldToNew => t.home.sort.lastModifiedOldToNew,
      }),
      trailing: selected ? const Icon(Symbols.check, weight: 300) : null,
      selected: selected,
      selectedTileColor: Colors.transparent,
    );
  }
}

enum SortMetric {
  nameAToZ,
  nameZToA,
  lastModifiedNewToOld,
  lastModifiedOldToNew;

  static const codec = EnumCodec(values);
}
