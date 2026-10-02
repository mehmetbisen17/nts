import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/home/delete_folder_button.dart';
import 'package:nts/components/home/masonry_files.dart';
import 'package:nts/components/home/new_folder_dialog.dart';
import 'package:nts/components/home/preview_card.dart';
import 'package:nts/components/home/rename_folder_button.dart';
import 'package:nts/components/theming/higan/higan_lily.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/components/toolbar/floating_bar.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/folder_style.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';

/// What a folder tile shows: how many notes, when the newest one was saved,
/// and up to 3 of the newest notes for the fanned preview stack.
class FolderInfo {
  const new({
    this.notes = 0,
    this.modified,
    this.previews = const [],
    this.style = FolderStyle.none,
  });

  final int notes;
  final DateTime? modified;

  /// Note paths without the extension.
  final List<String> previews;

  /// Its colour and emblem.
  final FolderStyle style;

  static Future<FolderInfo> load(String folderPath) async {
    final dir = folderPath.endsWith('/') ? folderPath : '$folderPath/';
    final (children, style) = await (
      FileManager.getChildrenOfDirectory(
        dir,
        sortMetric: .lastModifiedNewToOld,
      ),
      FolderStyle.read(dir),
    ).wait;
    final files = children?.files ?? const [];
    return FolderInfo(
      notes: files.length,
      modified: files.isEmpty
          ? null
          : FileManager.lastModified('$dir${files.first}${Editor.extension}'),
      previews: [for (final file in files.take(3)) '$dir$file'],
      style: style,
    );
  }

  /// "12 notes · 2h ago" (uppercase it, or use [HiganLabel]).
  String describe() => [
    t.higan.notesCount(n: notes),
    if (modified != null) higanRelativeTime(modified!),
  ].join(' · ');
}

/// A sliver of folders: tiles with a fanned stack of note previews
/// ([FolderViewMode.gallery]) or rows ([FolderViewMode.list]).
///
/// Long-press a folder to rename or delete it, or right-click it for a
/// menu. [showNavigation] adds "back" and "new folder" rows at the top
/// (list mode, used by the move dialog).
class GridFolders extends StatelessWidget {
  const new({
    super.key,
    required this.isAtRoot,
    required this.onTap,
    required this.createFolder,
    required this.renameFolder,
    required this.isFolderEmpty,
    required this.deleteFolder,
    required this.doesFolderExist,
    required this.folders,
    this.infos = const {},
    this.viewMode = .gallery,
    this.showNavigation = false,
    this.onDropNotes,
    this.path = '',
  });

  final bool isAtRoot;

  /// The folder these are in, e.g. '' at the root or '/School',
  /// for their styles (see [FolderStyle]).
  final String path;

  /// Called with a folder's name, or '..' for the back row.
  final void Function(String) onTap;

  final void Function(String) createFolder;
  final bool Function(String) doesFolderExist;
  final Future<void> Function(String oldName, String newName) renameFolder;
  final Future<bool> Function(String) isFolderEmpty;
  final Future<void> Function(String) deleteFolder;

  final List<String> folders;

  /// Folder name -> info. Missing folders show blank pages.
  final Map<String, FolderInfo> infos;
  final FolderViewMode viewMode;
  final bool showNavigation;

  /// Called with a folder's name and the notes dragged onto it
  /// (see [MouseDraggable]). Null to not accept drops.
  final void Function(String folder, List<String> files)? onDropNotes;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: stows.galleryScale,
      builder: (context, _) => SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          Widget folder(int index) => _Folder(
            name: folders[index],
            folderPath: '$path/${folders[index]}',
            info: infos[folders[index]] ?? const FolderInfo(),
            viewMode: viewMode,
            narrow: width < 560,
            topBorder: index == 0 && !showNavigation,
            onTap: onTap,
            doesFolderExist: doesFolderExist,
            renameFolder: renameFolder,
            isFolderEmpty: isFolderEmpty,
            deleteFolder: deleteFolder,
            onDropNotes: onDropNotes,
          );
          if (viewMode == .gallery) {
            return SliverAlignedGrid.count(
              crossAxisCount: galleryColumns(width, 300),
              mainAxisSpacing: 34,
              crossAxisSpacing: 26,
              itemCount: folders.length,
              itemBuilder: (context, index) => folder(index),
            );
          }
          final navigation = [
            if (showNavigation && !isAtRoot)
              HiganListRow(
                title: t.higan.back,
                topBorder: true,
                showChevron: false,
                leading: const _RowIcon(Icons.arrow_back),
                onTap: () => onTap('..'),
              ),
            if (showNavigation)
              HiganListRow(
                title: t.home.newFolder.newFolder,
                topBorder: isAtRoot,
                showChevron: false,
                leading: const _RowIcon(Symbols.create_new_folder),
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => NewFolderDialog(
                    createFolder: createFolder,
                    doesFolderExist: doesFolderExist,
                  ),
                ),
              ),
          ];
          return SliverList.list(
            children: [
              ...navigation,
              for (var i = 0; i < folders.length; i++) folder(i),
            ],
          );
        },
      ),
    );
  }
}

class _Folder extends StatefulWidget {
  const new({
    required this.name,
    required this.folderPath,
    required this.info,
    required this.viewMode,
    required this.narrow,
    required this.topBorder,
    required this.onTap,
    required this.doesFolderExist,
    required this.renameFolder,
    required this.isFolderEmpty,
    required this.deleteFolder,
    required this.onDropNotes,
  });

  final String name;

  /// From the root, e.g. '/School/Physics'.
  final String folderPath;
  final FolderInfo info;
  final FolderViewMode viewMode;
  final bool narrow, topBorder;
  final void Function(String) onTap;
  final bool Function(String) doesFolderExist;
  final Future<void> Function(String oldName, String newName) renameFolder;
  final Future<bool> Function(String) isFolderEmpty;
  final Future<void> Function(String) deleteFolder;
  final void Function(String folder, List<String> files)? onDropNotes;

  @override
  State<_Folder> createState() => _FolderState();
}

class _FolderState extends State<_Folder> {
  /// Whether the rename/delete actions are showing.
  var expanded = false;
  var hovered = false;

  /// Its style as just changed here, until the folder list reloads.
  FolderStyle? _style;
  FolderStyle get style => _style ?? widget.info.style;

  @override
  void didUpdateWidget(_Folder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The list reloaded (e.g. with a style from another device)
    if (widget.info.style != oldWidget.info.style ||
        widget.folderPath != oldWidget.folderPath) {
      _style = null;
    }
  }

  Future<void> _editStyle() async {
    // (Captured first: this tile may show another folder by the time the
    // sheet closes. And from disk, as the move dialog doesn't load styles.)
    final path = widget.folderPath;
    final initial = _style ?? await FolderStyle.read(path);
    if (!mounted) return;
    final picked = await showFolderStyleSheet(context, initial);
    if (picked == null || picked == initial) return;
    if (mounted && widget.folderPath == path) {
      setState(() {
        _style = picked;
        expanded = false;
      });
    }
    await FolderStyle.write(path, picked);
  }

  /// Where the last click landed, for the menu (right-click on a list row
  /// doesn't say where).
  var _lastDown = Offset.zero;

  void _toggle() => setState(() => expanded = !expanded);
  void _tap() {
    final mac = Theme.of(context).platform == .macOS;
    if (mac && HardwareKeyboard.instance.isControlPressed) return _showMenu();
    expanded ? _toggle() : widget.onTap(widget.name);
  }

  void _showMenu() => showBarMenu(
    context,
    _lastDown,
    actions: [
      (t.home.menu.open, () => widget.onTap(widget.name)),
      (t.nts.folderStyle.title, _editStyle),
      (
        t.home.renameFolder.rename,
        () => showRenameFolderDialog(
          context,
          folderName: widget.name,
          doesFolderExist: widget.doesFolderExist,
          renameFolder: (newName) => widget.renameFolder(widget.name, newName),
        ),
      ),
      (
        t.home.deleteFolder.delete,
        () => showDeleteFolderDialog(
          context,
          folderName: widget.name,
          deleteFolder: widget.deleteFolder,
          isFolderEmpty: widget.isFolderEmpty,
        ),
      ),
    ],
  );

  /// Lets notes be dropped on the folder; [builder] is told while
  /// they're over it.
  Widget _dropTarget(Widget Function(bool dropping) builder) {
    final onDropNotes = widget.onDropNotes;
    return Listener(
      onPointerDown: (event) => _lastDown = event.position,
      child: onDropNotes == null
          ? builder(false)
          : DragTarget<List<String>>(
              onAcceptWithDetails: (details) =>
                  onDropNotes(widget.name, details.data),
              builder: (context, candidates, _) =>
                  builder(candidates.isNotEmpty),
            ),
    );
  }

  List<Widget> get _actions => [
    IconButton(
      tooltip: t.nts.folderStyle.title,
      onPressed: _editStyle,
      icon: const Icon(Symbols.palette),
    ),
    RenameFolderButton(
      folderName: widget.name,
      doesFolderExist: widget.doesFolderExist,
      renameFolder: (String newName) async {
        await widget.renameFolder(widget.name, newName);
        if (mounted) setState(() => expanded = false);
      },
    ),
    DeleteFolderButton(
      folderName: widget.name,
      deleteFolder: (String folderName) async {
        await widget.deleteFolder(folderName);
        if (mounted) setState(() => expanded = false);
      },
      isFolderEmpty: widget.isFolderEmpty,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final info = widget.info;

    if (widget.viewMode == .list) {
      return _dropTarget(
        (dropping) => HoverTint(
          child: HiganListRow(
            title: widget.name,
            topBorder: widget.topBorder,
            selected: expanded || dropping,
            onTap: _tap,
            onLongPress: _toggle,
            onSecondaryTap: _showMenu,
            leading: _MiniStack(info.previews.firstOrNull, style: style),
            trailing: expanded
                ? _actions
                : [
                    SizedBox(
                      width: widget.narrow ? null : 140,
                      child: HiganLabel(t.higan.notesCount(n: info.notes)),
                    ),
                    if (!widget.narrow)
                      SizedBox(
                        width: 150,
                        child: HiganLabel(
                          info.modified == null
                              ? ''
                              : higanRelativeTime(info.modified!),
                        ),
                      ),
                  ],
          ),
        ),
      );
    }

    // Focusable, so Tab reaches it and Return opens it (like a list row).
    return _dropTarget(
      (dropping) => HiganFocusRing(
        shape: const RoundedRectangleBorder(
          borderRadius: .all(.circular(HiganRadius.card)),
        ),
        child: FocusableActionDetector(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) => _tap(),
            ),
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => hovered = true),
            onExit: (_) => setState(() => hovered = false),
            child: GestureDetector(
              behavior: .opaque,
              onTap: _tap,
              onLongPress: _toggle,
              onSecondaryTap: _showMenu,
              child: _tile(dropping),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(bool dropping) {
    final c = context.higan;
    final info = widget.info;
    final tint = style.tint;
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: AnimatedContainer(
            duration: HiganMotion.medium,
            clipBehavior: .antiAlias,
            decoration: BoxDecoration(
              // Recessed in Paper, so the pages stand off it.
              // A colour only tints it, so it stays easy on the eyes.
              color: tint == null
                  ? c.well
                  : Color.alphaBlend(
                      tint.withValues(alpha: c.isNight ? 0.2 : 0.16),
                      c.well,
                    ),
              borderRadius: const .all(.circular(HiganRadius.card)),
              border: Border.all(
                color: dropping
                    ? c.higan
                    : tint != null
                    ? tint.withValues(alpha: hovered || expanded ? 0.7 : 0.45)
                    : hovered || expanded
                    ? c.hairlineStrong
                    : c.hairline,
                width: dropping ? 1.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _FanStack(
                    previews: info.previews,
                    fanned: hovered || dropping,
                  ),
                ),
                if (style.emblem != null)
                  Positioned(
                    left: HiganSpace.m,
                    top: HiganSpace.m,
                    child: FolderEmblem(style, size: 22),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: HiganSpace.m,
                  child: Center(
                    child: IgnorePointer(
                      ignoring: !expanded,
                      // Hidden buttons shouldn't take Tab either.
                      child: ExcludeFocus(
                        excluding: !expanded,
                        child: AnimatedOpacity(
                          opacity: expanded ? 1 : 0,
                          duration: HiganMotion.fast,
                          child: HiganPill(
                            height: 44,
                            padding: const .symmetric(horizontal: 4),
                            child: Row(mainAxisSize: .min, children: _actions),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.name,
          maxLines: 1,
          overflow: .ellipsis,
          style: HiganText.body(context),
        ),
        const SizedBox(height: 5),
        HiganLabel(info.describe(), size: 10),
      ],
    );
  }
}

/// Three paper pages fanned at -7°, 0° and 7° (more when [fanned]).
class _FanStack extends StatelessWidget {
  const new({required this.previews, required this.fanned});

  final List<String> previews;
  final bool fanned;

  static const _lefts = [0.13, 0.31, 0.49];

  /// The newest note goes in the middle, on top.
  static const _order = [1, 0, 2];

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : HiganMotion.slow;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.38;
        return Stack(
          children: [
            // The middle page is on top.
            for (final i in const [0, 2, 1])
              Positioned(
                left: constraints.maxWidth * _lefts[i],
                top: constraints.maxHeight * 0.16,
                width: width,
                height: width / HiganPaperThumb.galleryAspectRatio,
                child: AnimatedRotation(
                  turns: (i - 1) * (fanned ? 10 : 7) / 360,
                  duration: duration,
                  curve: HiganMotion.curve,
                  child: AnimatedSlide(
                    offset: i == 1
                        ? Offset.zero
                        : Offset(
                            fanned ? (i - 1) * 0.06 : 0,
                            fanned ? 0.04 : 0.06,
                          ),
                    duration: duration,
                    curve: HiganMotion.curve,
                    child: HiganPaperThumb(
                      radius: HiganRadius.paper,
                      child: NotePaper(
                        image: _order[i] < previews.length
                            ? notePreviewImage(previews[_order[i]])
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A 44×57 list thumbnail: the newest note's page with another behind it,
/// tinted and marked with the folder's [style].
class _MiniStack extends StatelessWidget {
  const new(this.preview, {this.style = FolderStyle.none});

  final String? preview;
  final FolderStyle style;

  @override
  Widget build(BuildContext context) {
    final tint = style.tint;
    return SizedBox(
      width: 44,
      height: 57,
      child: Stack(
        clipBehavior: .none,
        children: [
          Positioned.fill(
            child: Transform.rotate(
              angle: 8 * math.pi / 180,
              child: const Opacity(
                opacity: 0.5,
                child: HiganPaperThumb(radius: 3, shadow: false),
              ),
            ),
          ),
          Positioned.fill(
            child: HiganPaperThumb(
              radius: 3,
              shadow: false,
              child: NotePaper(
                image: preview == null ? null : notePreviewImage(preview!),
              ),
            ),
          ),
          // The colour as a frame on the page (it would be hidden under it)
          if (tint != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: tint.withValues(alpha: 0.85),
                      width: 2,
                    ),
                    borderRadius: const .all(.circular(3)),
                  ),
                ),
              ),
            ),
          if (style.emblem != null)
            Positioned(
              right: -6,
              bottom: -6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.higan.surface2,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.higan.hairlineStrong),
                ),
                child: Padding(
                  padding: const .all(3),
                  child: FolderEmblem(style, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A folder's emblem in its colour: the spider lily, or an icon.
class FolderEmblem extends StatelessWidget {
  const new(this.style, {super.key, this.size = 20});

  final FolderStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    final emblem = style.emblem;
    if (emblem == null) return SizedBox.square(dimension: size);
    final icon = FolderStyle.emblems[emblem];
    if (icon == null) {
      return HiganLily(size: size, animate: false);
    }
    return Icon(
      icon,
      size: size,
      weight: 300,
      color: style.tint ?? context.higan.textSecondary,
    );
  }
}

/// Picks a folder's colour and emblem, or returns null if dismissed.
Future<FolderStyle?> showFolderStyleSheet(
  BuildContext context,
  FolderStyle initial,
) => showModalBottomSheet<FolderStyle>(
  context: context,
  showDragHandle: true,
  backgroundColor: context.higan.surface1,
  constraints: const BoxConstraints(maxWidth: 500),
  // Taller than 9/16 of the window if it needs to be (short Mac windows)
  isScrollControlled: true,
  builder: (context) => _FolderStyleSheet(initial),
);

class _FolderStyleSheet extends StatefulWidget {
  const new(this.initial);

  final FolderStyle initial;

  @override
  State<_FolderStyleSheet> createState() => _FolderStyleSheetState();
}

class _FolderStyleSheetState extends State<_FolderStyleSheet> {
  late var style = widget.initial;

  Widget _choice({
    required bool selected,
    required String label,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final c = context.higan;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: Container(
            width: HiganTap.min,
            height: HiganTap.min,
            alignment: .center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? c.text : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final names = t.nts.folderStyle;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const .fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Text(names.title, style: HiganText.body(context)),
            const SizedBox(height: 16),
            HiganLabel(names.colour),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _choice(
                  selected: style.color == null,
                  label: names.none,
                  onTap: () =>
                      setState(() => style = style.copyWith(color: () => null)),
                  child: Icon(Symbols.block, size: 20, color: c.textTertiary),
                ),
                for (final MapEntry(key: name, value: color)
                    in FolderStyle.colors.entries)
                  _choice(
                    selected: style.color == name,
                    label: names.colours[name] ?? name,
                    onTap: () => setState(
                      () => style = style.copyWith(color: () => name),
                    ),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            HiganLabel(names.emblem),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _choice(
                  selected: style.emblem == null,
                  label: names.none,
                  onTap: () => setState(
                    () => style = style.copyWith(emblem: () => null),
                  ),
                  child: Icon(Symbols.block, size: 20, color: c.textTertiary),
                ),
                for (final name in FolderStyle.emblems.keys)
                  _choice(
                    selected: style.emblem == name,
                    label: names.emblems[name] ?? name,
                    onTap: () => setState(
                      () => style = style.copyWith(emblem: () => name),
                    ),
                    child: FolderEmblem(
                      FolderStyle(color: style.color, emblem: name),
                      size: 22,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: .centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, style),
                child: Text(names.done),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  const new(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    child: Icon(
      icon,
      size: 18,
      weight: 300,
      color: context.higan.textSecondary,
    ),
  );
}
