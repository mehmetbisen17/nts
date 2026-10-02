import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nts/components/home/move_note_button.dart';
import 'package:nts/components/icloud/icloud_widgets.dart';
import 'package:nts/components/navbar/responsive_navbar.dart';
import 'package:nts/components/theming/higan/higan_lily.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/home/home.dart';
import 'package:path/path.dart' as p;

/// Desktop sidebar: mark, Recent / Folders / Whiteboard / Settings,
/// the root folders with their note counts, and the iCloud status.
class HomeSidebar extends HookWidget {
  const new({
    super.key,
    required this.selectedIndex,
    required this.path,
    required this.onDestinationSelected,
    required this.onFolderSelected,
  });

  /// Index into [HomePage.subpages].
  final int selectedIndex;

  /// The folder the browse page shows, or null for the root.
  final String? path;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<String> onFolderSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final isMac = Theme.of(context).platform == .macOS;
    final folders = useState<List<(String, int)>?>(null);
    final recentCount = useState<int?>(null);

    useEffect(() {
      var disposed = false;
      Future<void> load() async {
        final root = await FileManager.getChildrenOfDirectory('/');
        final names = root?.directories ?? const <String>[];
        final counts = await Future.wait([
          for (final name in names)
            FileManager.getChildrenOfDirectory('/$name')
                .then((children) => children?.files.length ?? 0),
        ]);
        final recent = await FileManager.getRecentlyAccessed();
        if (disposed) return;
        folders.value = [
          for (var i = 0; i < names.length; i++) (names[i], counts[i]),
        ];
        recentCount.value = recent.length;
      }

      Timer? debounce;
      void reload([_]) {
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 300), load);
      }

      load();
      final subscription = FileManager.fileWriteStream.stream.listen(reload);
      ICloudStorage.state.addListener(reload);
      return () {
        disposed = true;
        debounce?.cancel();
        subscription.cancel();
        ICloudStorage.state.removeListener(reload);
      };
    }, const []);

    final browseIndex = HomePage.subpages.indexOf(HomePage.browseSubpage);
    final isBrowsing = selectedIndex == browseIndex;
    final openRootFolder = isBrowsing ? _rootFolderOf(path) : null;
    String count(int n) => n.toString().padLeft(2, '0');

    final labels = {
      HomePage.recentSubpage: t.higan.recent,
      HomePage.browseSubpage: t.higan.folders,
      HomePage.whiteboardSubpage: t.higan.whiteboard,
      HomePage.settingsSubpage: t.higan.settings,
    };

    return Container(
      width: HiganSpace.sidebar,
      decoration: BoxDecoration(
        color: c.bg.withValues(alpha: 0.6),
        border: BorderDirectional(end: BorderSide(color: c.hairline)),
      ),
      padding: const .fromLTRB(18, 0, 18, 22),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          WindowDragArea(
            child: Padding(
              // Room for the traffic lights on macOS.
              padding: .only(top: isMac ? 52 : 22, bottom: 26),
              child: const Align(
                alignment: .centerStart,
                child: HiganMark(size: 24),
              ),
            ),
          ),
          for (var i = 0; i < HomePage.subpages.length; i++)
            _SidebarRow(
              label: labels[HomePage.subpages[i]]!,
              count: switch (HomePage.subpages[i]) {
                HomePage.recentSubpage => recentCount.value?.toString(),
                HomePage.browseSubpage => folders.value?.length.toString(),
                _ => null,
              },
              selected:
                  i == selectedIndex && (!isBrowsing || openRootFolder == null),
              onTap: () => onDestinationSelected(i),
            ),
          if (folders.value?.isNotEmpty ?? false) ...[
            Padding(
              padding: const .fromLTRB(10, 26, 10, 8),
              child: HiganLabel(t.higan.folders, size: 10),
            ),
            Expanded(
              child: ListView(
                padding: .zero,
                children: [
                  for (final (name, n) in folders.value!)
                    // Drop notes here to move them into the folder.
                    DragTarget<List<String>>(
                      onWillAcceptWithDetails: (details) => details.data.any(
                        (file) => p.dirname(file) != '/$name',
                      ),
                      onAcceptWithDetails: (details) =>
                          moveNotes(context, details.data, '/$name/'),
                      builder: (context, candidates, _) => _SidebarRow(
                        label: name,
                        count: count(n),
                        selected:
                            name == openRootFolder || candidates.isNotEmpty,
                        onTap: () => onFolderSelected('/$name'),
                      ),
                    ),
                ],
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(height: HiganSpace.m),
          const _SyncStatus(),
        ],
      ),
    );
  }

  /// `Mathematics` for `/Mathematics/Linear algebra`.
  static String? _rootFolderOf(String? path) {
    final parts = (path ?? '').split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.first;
  }
}

class _SidebarRow extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final String? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final color = selected ? c.text : c.textSecondary;
    const radius = BorderRadius.all(.circular(8));
    return Padding(
      padding: const .only(bottom: 2),
      child: Semantics(
        selected: selected,
        button: true,
        child: HiganFocusRing(
          shape: const RoundedRectangleBorder(borderRadius: radius),
          child: Material(
            color: selected ? c.surface2 : Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              mouseCursor: SystemMouseCursors.click,
              hoverColor: c.text.withValues(alpha: 0.05),
              borderRadius: radius,
              child: Padding(
                padding: const .symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: HiganText.body(context, size: 14, color: color),
                      ),
                    ),
                    if (count != null)
                      HiganLabel(count!, color: selected ? c.text : null),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "iCloud · synced", "On this device" or "iCloud · reconnect".
/// Tap to connect or reconnect.
class _SyncStatus extends HookWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final state = useValueListenable(ICloudStorage.state);
    final (label, dot) = iCloudStatus(context, state);
    final canConnect = state == .needsReconnect || state == .notConnected;
    final row = Padding(
      padding: const .symmetric(horizontal: 10, vertical: 6),
      child: Row(
        spacing: 8,
        children: [
          SizedBox.square(
            dimension: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(color: dot, shape: .circle),
            ),
          ),
          Flexible(child: HiganLabel(label)),
        ],
      ),
    );
    if (!canConnect) return row;
    return Tooltip(
      message: state == .needsReconnect
          ? t.icloud.reconnect
          : t.icloud.connectICloud,
      child: InkWell(
        onTap: () => connectICloud(context),
        borderRadius: const .all(.circular(8)),
        child: row,
      ),
    );
  }
}
