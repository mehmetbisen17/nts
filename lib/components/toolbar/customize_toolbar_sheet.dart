import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:nts/i18n/strings.g.dart';

/// The toolbar's "+": every tool with a switch, and the toolbar's tools
/// in order (drag to reorder).
///
/// The switches say whether a button is in the toolbar, even for buttons
/// that turn a setting on and off (those settings are also in Settings).
Future<void> showCustomizeToolbarSheet(BuildContext context) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.higan.surface1,
      constraints: const BoxConstraints(maxWidth: 500),
      builder: (context) => const CustomizeToolbarSheet(),
    );

class CustomizeToolbarSheet extends StatelessWidget {
  const new({super.key});

  /// Every row's trailing control is this tall, so all rows are too.
  static const controlHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final strings = t.editor.customizeToolbar;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: ValueListenableBuilder(
        valueListenable: stows.editorToolbarItems,
        builder: (context, _, _) {
          final current = ToolCatalog.current;
          return CustomScrollView(
            shrinkWrap: true,
            slivers: [
              SliverPadding(
                padding: const .fromLTRB(22, 0, 14, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.title,
                          style: HiganText.title(context, size: 24),
                        ),
                      ),
                      TextButton(
                        onPressed: ToolCatalog.resetToBasics,
                        child: Text(strings.resetToBasics),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const .symmetric(horizontal: 22),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    strings.hint,
                    style: HiganText.body(
                      context,
                      size: 14,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
              _Section(strings.inToolbar),
              SliverPadding(
                padding: const .symmetric(horizontal: 16),
                sliver: SliverReorderableList(
                  itemCount: current.length,
                  onReorderItem: ToolCatalog.reorder,
                  proxyDecorator: (child, _, _) => Material(
                    color: c.surface2,
                    shape: RoundedRectangleBorder(
                      borderRadius: const .all(.circular(8)),
                      side: BorderSide(color: c.hairlineStrong),
                    ),
                    child: child,
                  ),
                  itemBuilder: (context, index) {
                    final item = current[index];
                    return HiganListRow(
                      key: ValueKey(item.id),
                      title: item.label(),
                      topBorder: index == 0,
                      showChevron: false,
                      leading: _ItemIcon(item),
                      trailing: [
                        ReorderableDragStartListener(
                          index: index,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: Tooltip(
                              message: strings.reorder,
                              // as tall as the switches below
                              child: SizedBox(
                                height: CustomizeToolbarSheet.controlHeight,
                                child: Icon(
                                  Symbols.drag_handle,
                                  size: 20,
                                  weight: 300,
                                  color: c.textTertiary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              for (final category in ToolCategory.values)
                if (ToolCatalog.items.where(
                      (item) => item.category == category && item.available,
                    )
                    case final items when items.isNotEmpty) ...[
                  _Section(category.label),
                  SliverPadding(
                    padding: const .symmetric(horizontal: 16),
                    sliver: SliverList.list(
                      children: [
                        for (final (i, item) in items.indexed)
                          _ToggleRow(
                            item,
                            inToolbar: current.contains(item),
                            first: i == 0,
                          ),
                      ],
                    ),
                  ),
                ],
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 24 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const .fromLTRB(22, 22, 22, 8),
    sliver: SliverToBoxAdapter(child: HiganLabel(text)),
  );
}

class _ToggleRow extends StatelessWidget {
  const new(this.item, {required this.inToolbar, required this.first});

  final ToolbarItem item;
  final bool inToolbar, first;

  void _toggle() =>
      inToolbar ? ToolCatalog.remove(item.id) : ToolCatalog.add(item.id);

  @override
  Widget build(BuildContext context) => HiganListRow(
    title: item.label(),
    topBorder: first,
    showChevron: false,
    leading: _ItemIcon(item),
    onTap: _toggle,
    trailing: [
      // Higan's switch on every platform, like Settings
      SizedBox(
        height: CustomizeToolbarSheet.controlHeight,
        child: Switch(
          value: inToolbar,
          onChanged: (_) => _toggle(),
          materialTapTargetSize: .shrinkWrap,
        ),
      ),
    ],
  );
}

class _ItemIcon extends StatelessWidget {
  const new(this.item);

  final ToolbarItem item;

  @override
  Widget build(BuildContext context) => Icon(
    item.icon,
    size: 20,
    weight: 300,
    color: context.higan.textSecondary,
  );
}
