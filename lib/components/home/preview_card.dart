import 'dart:async';
import 'dart:io';

import 'package:animations/animations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/canvas/inner_canvas.dart';
import 'package:nts/components/canvas/invert_widget.dart';
import 'package:nts/components/home/delete_note_button.dart';
import 'package:nts/components/home/export_note_button.dart';
import 'package:nts/components/home/move_note_button.dart';
import 'package:nts/components/home/rename_note_button.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/components/toolbar/floating_bar.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/is_this_a_test.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';

/// A note, as a paper card ([FolderViewMode.gallery]) or a row
/// ([FolderViewMode.list]), with its title and "2H AGO · 4 PAGES".
///
/// Tap opens the editor. Long-press toggles selection, and while anything
/// is selected, tap toggles selection too. With a mouse: right-click (or
/// Control-click on macOS) opens a menu, ⌘/Ctrl-click toggles selection,
/// Shift-click selects a range, and dragging moves the note (or the
/// selection) onto a folder.
class PreviewCard extends StatefulWidget {
  new({
    required this.filePath,
    required this.selectedFiles,
    required this.selectRange,
    this.viewMode = .gallery,
    this.narrow = false,
    this.topBorder = false,
  }) : super(key: ValueKey('PreviewCard$filePath'));

  final String filePath;
  final ValueNotifier<List<String>> selectedFiles;

  /// Shift-click: select the notes from the last selected one to this one.
  final VoidCallback selectRange;
  final FolderViewMode viewMode;

  /// List rows only: show just the date, not the page count.
  final bool narrow;

  /// List rows only: draw a hairline above (for the first row).
  final bool topBorder;

  bool get selected => selectedFiles.value.contains(filePath);
  bool get isAnythingSelected => selectedFiles.value.isNotEmpty;

  @override
  State<PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<PreviewCard> {
  final thumbnail = _ThumbnailState();
  var hovered = false;
  _NoteMeta? meta;

  /// Where the last click landed, for the menu (right-click on a list row
  /// doesn't say where).
  var _lastDown = Offset.zero;

  @override
  void initState() {
    fileWriteSubscription = FileManager.fileWriteStream.stream.listen(
      fileWriteListener,
    );
    super.initState();
    _loadMeta();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    thumbnail.image = notePreviewImage(widget.filePath, evenIfMissing: true);
  }

  StreamSubscription? fileWriteSubscription;
  void fileWriteListener(FileOperation event) {
    if (event.filePath != widget.filePath) return;
    if (event.type == .delete) {
      thumbnail.image = null;
    } else if (event.type == .write) {
      thumbnail.image?.evict();
      thumbnail.markAsChanged();
      _loadMeta();
    } else {
      throw Exception('Unknown file operation type: ${event.type}');
    }
  }

  Future<void> _loadMeta() async {
    final meta = await _NoteMeta.load(widget.filePath);
    if (mounted) setState(() => this.meta = meta);
  }

  void _toggleSelection() {
    final others = [
      for (final file in widget.selectedFiles.value)
        if (file != widget.filePath) file,
    ];
    widget.selectedFiles.value = widget.selected
        ? others
        : [...others, widget.filePath];
  }

  void _unselectAll() => widget.selectedFiles.value = [];

  void _tap(VoidCallback open) {
    final keys = HardwareKeyboard.instance;
    final mac = Theme.of(context).platform == .macOS;
    if (keys.isShiftPressed) return widget.selectRange();
    if (mac && keys.isControlPressed) return _showMenu(open);
    if (keys.isMetaPressed || keys.isControlPressed) {
      return _toggleSelection();
    }
    widget.isAnythingSelected ? _toggleSelection() : open();
  }

  /// The notes a menu or drag acts on: the selection if this note is
  /// in it, otherwise just this note.
  List<String> get _targets =>
      widget.selected ? widget.selectedFiles.value : [widget.filePath];

  void _showMenu(VoidCallback open) {
    final files = _targets;
    showBarMenu(
      context,
      _lastDown,
      title: files.length > 1 ? t.higan.notesCount(n: files.length) : null,
      actions: [
        (t.home.menu.open, open),
        (
          widget.selected ? t.home.menu.deselect : t.home.menu.select,
          _toggleSelection,
        ),
        if (files.length == 1)
          (
            t.home.renameNote.rename,
            () => showRenameNoteDialog(context, files.single, _unselectAll),
          ),
        (
          t.home.moveNote.move,
          () => showMoveNoteDialog(context, files, _unselectAll),
        ),
        (t.home.menu.exportPdf, () => exportNotes(context, files, pdf: true)),
        (t.home.menu.exportSba, () => exportNotes(context, files, pdf: false)),
        (
          t.home.deleteNoteDialog.delete,
          () => showDeleteNoteDialog(context, files, _unselectAll),
        ),
      ],
    );
  }

  /// Mouse only (touch drags scroll): drag the note, or the selection,
  /// onto a folder to move it there.
  Widget _draggable(Widget child) {
    final files = _targets;
    return MouseDraggable<List<String>>(
      data: files,
      feedback: _DragFeedback(paper: _paper, count: files.length),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      onDragCompleted: () {
        if (widget.selected) _unselectAll();
      },
      child: child,
    );
  }

  Timer? _refreshThumbnailTimer;
  void _refreshThumbnailAfterDelay() {
    _refreshThumbnailTimer?.cancel();
    _refreshThumbnailTimer = Timer(const Duration(milliseconds: 500), () {
      thumbnail.image?.evict();
      thumbnail.markAsChanged();
      _loadMeta();
    });
  }

  String get _name =>
      widget.filePath.substring(widget.filePath.lastIndexOf('/') + 1);

  Widget get _paper => ListenableBuilder(
    listenable: thumbnail,
    builder: (context, _) => AnimatedSwitcher(
      duration: HiganMotion.medium,
      child: NotePaper(
        key: ValueKey(thumbnail.updateCount),
        image: thumbnail.doesImageExist ? thumbnail.image : null,
      ),
    ),
  );

  Widget _gallery(VoidCallback open) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final lift = hovered && !disableAnimations && !widget.isAnythingSelected;
    // Focusable, so Tab reaches it and Return opens it (like a list row).
    return HiganFocusRing(
      shape: const RoundedRectangleBorder(
        borderRadius: .all(.circular(HiganRadius.page + 4)),
      ),
      child: FocusableActionDetector(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _tap(open),
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(
            behavior: .opaque,
            onTap: () => _tap(open),
            onSecondaryTap: () => _showMenu(open),
            onLongPress: _toggleSelection,
            child: _galleryContent(lift),
          ),
        ),
      ),
    );
  }

  Widget _galleryContent(bool lift) => Column(
    crossAxisAlignment: .start,
    mainAxisSize: .min,
    children: [
      AnimatedContainer(
        duration: HiganMotion.medium,
        curve: HiganMotion.curve,
        transform: .translationValues(0, lift ? -3 : 0, 0),
        child: Stack(
          clipBehavior: .none,
          children: [
            HiganPaperThumb(
              aspectRatio: HiganPaperThumb.galleryAspectRatio,
              child: _paper,
            ),
            if (widget.selected)
              const Positioned.fill(
                left: -4,
                top: -4,
                right: -4,
                bottom: -4,
                child: _SelectedRing(),
              ),
            if (widget.isAnythingSelected)
              Positioned(
                top: 8,
                right: 8,
                child: SelectionBadge(selected: widget.selected),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        _name,
        maxLines: 1,
        overflow: .ellipsis,
        style: HiganText.body(context),
      ),
      const SizedBox(height: 5),
      LayoutBuilder(
        builder: (context, constraints) {
          // Just the time on small cards, if the page count won't fit
          final full = meta?.describe() ?? '';
          final painter = TextPainter(
            text: TextSpan(
              text: full.toUpperCase(),
              style: HiganText.label(context, size: 10),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final fits = painter.width <= constraints.maxWidth;
          painter.dispose();
          return HiganLabel(fits ? full : meta?.describeTime() ?? '', size: 10);
        },
      ),
    ],
  );

  Widget _row(VoidCallback open) {
    return HoverTint(
      child: HiganListRow(
        title: _name,
        topBorder: widget.topBorder,
        selected: widget.selected,
        onTap: () => _tap(open),
        onLongPress: _toggleSelection,
        onSecondaryTap: () => _showMenu(open),
        leading: SizedBox(
          width: 44,
          height: 57,
          child: Stack(
            clipBehavior: .none,
            children: [
              Positioned.fill(
                child: HiganPaperThumb(radius: 3, shadow: false, child: _paper),
              ),
              if (widget.isAnythingSelected)
                Positioned(
                  top: -6,
                  right: -6,
                  child: SelectionBadge(selected: widget.selected, size: 18),
                ),
            ],
          ),
        ),
        trailing: [
          if (!widget.narrow)
            SizedBox(
              width: 140,
              child: HiganLabel(meta?.describePages() ?? ''),
            ),
          SizedBox(
            width: widget.narrow ? null : 150,
            child: HiganLabel(meta?.describeTime() ?? ''),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return OpenContainer(
      tappable: false,
      clipBehavior: .none,
      closedColor: Colors.transparent,
      closedShape: const RoundedRectangleBorder(),
      closedElevation: 0,
      closedBuilder: (context, open) => Listener(
        onPointerDown: (event) => _lastDown = event.position,
        child: _draggable(
          widget.viewMode == .gallery ? _gallery(open) : _row(open),
        ),
      ),
      openColor: c.bg,
      openElevation: 0,
      middleColor: c.bg,
      openBuilder: (context, action) => Editor(path: widget.filePath),
      transitionDuration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 300),
      routeSettings: RouteSettings(
        name: RoutePaths.editFilePath(widget.filePath),
      ),
      onClosed: (_) => _refreshThumbnailAfterDelay(),
    );
  }

  @override
  void dispose() {
    _refreshThumbnailTimer?.cancel();
    fileWriteSubscription?.cancel();
    super.dispose();
  }
}

/// A paper page showing [image] (a note's first-page preview), or blank.
/// The preview's white page blends into the paper color, and everything
/// turns dark when Settings › Pages is Black.
class NotePaper extends StatelessWidget {
  const new({super.key, this.image});

  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final invert = InnerCanvas.invertOf(context);
    return InvertWidget(
      invert: invert,
      child: ColoredBox(
        color: c.thumbPaper,
        child: SizedBox.expand(
          child: image == null
              ? null
              // Previews stop where the note's content does; fade their
              // bottom edge into the paper so there's no seam.
              : Align(
                  alignment: .topCenter,
                  child: ShaderMask(
                    blendMode: .dstIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: .topCenter,
                      end: .bottomCenter,
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0, 0.88, 1],
                    ).createShader(rect),
                    child: Image(
                      image: image!,
                      width: double.infinity,
                      fit: .fitWidth,
                      alignment: .topCenter,
                      color: c.thumbPaper,
                      colorBlendMode: .multiply,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The first-page preview image that the editor saves next to a note,
/// or null if there isn't one (unless [evenIfMissing], for a card whose
/// preview might be written later).
ImageProvider? notePreviewImage(String filePath, {bool evenIfMissing = false}) {
  final file = FileManager.getFile('$filePath${Editor.extension}.p');
  if (isThisATest) {
    // Avoid FileImages in tests
    return file.existsSync() ? MemoryImage(file.readAsBytesSync()) : null;
  }
  if (!evenIfMissing && !file.existsSync()) return null;
  return FileImage(file);
}

/// Round check shown on notes while selecting.
class SelectionBadge extends StatelessWidget {
  const new({super.key, required this.selected, this.size = 22});

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: HiganMotion.fast,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: .circle,
        color: selected
            ? context.higan.higan
            : Colors.white.withValues(alpha: 0.75),
        border: selected
            ? null
            : Border.all(color: Colors.black.withValues(alpha: 0.28)),
      ),
      child: selected
          ? Icon(
              Symbols.check,
              size: size * 0.64,
              weight: 600,
              color: Colors.white,
            )
          : null,
    );
  }
}

class const _SelectedRing() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const .all(.circular(HiganRadius.page + 4)),
          border: Border.all(color: context.higan.higan, width: 1.5),
        ),
      ),
    );
  }
}

/// What follows the mouse while dragging notes: a paper, with a count
/// when there are several.
class _DragFeedback extends StatelessWidget {
  const new({required this.paper, required this.count});

  final Widget paper;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return SizedBox(
      width: 64,
      child: Stack(
        clipBehavior: .none,
        children: [
          HiganPaperThumb(
            aspectRatio: HiganPaperThumb.galleryAspectRatio,
            radius: HiganRadius.paper,
            child: paper,
          ),
          if (count > 1)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const .symmetric(horizontal: 6),
                alignment: .center,
                decoration: BoxDecoration(
                  color: c.higan,
                  borderRadius: const .all(.circular(11)),
                ),
                child: Text(
                  '$count',
                  style: HiganText.label(
                    context,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A [Draggable] that only a mouse (or trackpad click) drags, and only
/// after it moves a few pixels, so a slightly shaky click still opens
/// the note. Touch keeps scrolling and long-pressing as before.
class MouseDraggable<T extends Object> extends Draggable<T> {
  const new({
    super.key,
    required super.child,
    required super.feedback,
    super.data,
    super.childWhenDragging,
    super.onDragCompleted,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => _MouseDragRecognizer()..onStart = onStart;
}

class _MouseDragRecognizer extends MultiDragGestureRecognizer {
  new() : super(debugOwner: null, supportedDevices: const {.mouse});

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _MouseDragState(event.position, event.kind, gestureSettings);

  @override
  String get debugDescription => 'mouse drag';
}

class _MouseDragState extends MultiDragPointerState {
  new(super.initialPosition, super.kind, super.gestureSettings);

  /// Farther than a click wobbles, nearer than a tap gives up (18).
  static const _slop = 6.0;

  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > _slop) resolve(.accepted);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) =>
      starter(initialPosition);
}

/// A faint tint behind a list row while the mouse is over it, on top of
/// the row's own (barely visible) hover color.
class HoverTint extends StatefulWidget {
  const new({super.key, required this.child});

  final Widget child;

  @override
  State<HoverTint> createState() => _HoverTintState();
}

class _HoverTintState extends State<HoverTint> {
  var hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: HiganMotion.fast,
        color: hovered
            ? context.higan.text.withValues(alpha: 0.03)
            : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}

class _ThumbnailState extends ChangeNotifier {
  var updateCount = 0;
  ImageProvider? _image;

  void markAsChanged() {
    ++updateCount;
    notifyListeners();
  }

  ImageProvider? get image => _image;
  set image(ImageProvider? image) {
    _image = image;
    markAsChanged();
  }

  bool get doesImageExist => switch (image) {
    (final FileImage fileImage) => fileImage.file.existsSync(),
    null => false,
    _ => true,
  };
}

/// When a note was last saved, and how many pages it has.
class _NoteMeta {
  const new(this.modified, this.pages);

  final DateTime? modified;
  final int? pages;

  static final _cache = <String, _NoteMeta>{};

  static Future<_NoteMeta> load(String filePath) async {
    try {
      final file = FileManager.getFile('$filePath${Editor.extension}');
      if (!file.existsSync()) {
        // An old json note, or an iCloud placeholder.
        final old = FileManager.getFile('$filePath${Editor.extensionOldJson}');
        return _NoteMeta(
          old.existsSync() ? old.lastModifiedSync() : null,
          null,
        );
      }
      final modified = file.lastModifiedSync();
      final cached = _cache[filePath];
      if (cached?.modified == modified) return cached!;
      final bytes = isThisATest
          ? file.readAsBytesSync()
          : await file.readAsBytes();
      return _cache[filePath] = _NoteMeta(modified, countSbnPages(bytes));
    } on FileSystemException {
      return const _NoteMeta(null, null);
    }
  }

  String describeTime() => modified == null ? '' : higanRelativeTime(modified!);
  String describePages() => pages == null ? '' : t.higan.pagesCount(n: pages!);
  String describe() =>
      [describeTime(), describePages()].where((s) => s.isNotEmpty).join(' · ');
}

/// The number of pages in an sbn2 (BSON) note, up to its last non-empty
/// page, without decoding any strokes: it walks the top-level fields to the
/// `z` (pages) array and steps over each page by its length.
/// Null if [bytes] isn't a note it understands.
///
/// ponytail: a page document of at most 27 bytes (just `w` and `h`) counts
/// as empty; look inside the pages if they gain other always-present keys.
int? countSbnPages(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  try {
    var pos = 4; // skip the document's length
    while (bytes[pos] != 0) {
      final type = bytes[pos];
      final keyEnd = bytes.indexOf(0, pos + 1);
      final isPages =
          type == 0x04 && keyEnd == pos + 2 && bytes[pos + 1] == 0x7A; // z
      if (!isPages) {
        final next = _skipBsonValue(bytes, data, type, keyEnd + 1);
        if (keyEnd < 0 || next <= pos) return null; // corrupt
        pos = next;
        continue;
      }
      var pages = 0, lastNonEmpty = 0;
      var element = keyEnd + 1 + 4; // skip the array's length
      while (bytes[element] != 0) {
        final valueStart = bytes.indexOf(0, element + 1) + 1;
        final next = _skipBsonValue(bytes, data, bytes[element], valueStart);
        if (valueStart <= 0 || next <= element) return null; // corrupt
        element = next;
        pages++;
        if (element - valueStart > 27) lastNonEmpty = pages;
      }
      return lastNonEmpty > 0 ? lastNonEmpty : (pages > 0 ? 1 : 0);
    }
    return null;
  } on RangeError {
    return null;
  } on FormatException {
    return null;
  }
}

int _skipBsonValue(Uint8List bytes, ByteData data, int type, int pos) {
  int int32(int at) => data.getInt32(at, .little);
  return switch (type) {
    0x01 || 0x09 || 0x11 || 0x12 => pos + 8,
    0x02 || 0x0D || 0x0E => pos + 4 + int32(pos),
    0x03 || 0x04 || 0x0F => pos + int32(pos),
    0x05 => pos + 5 + int32(pos),
    0x06 || 0x0A || 0x7F || 0xFF => pos,
    0x07 => pos + 12,
    0x08 => pos + 1,
    0x0B => bytes.indexOf(0, bytes.indexOf(0, pos) + 1) + 1,
    0x10 => pos + 4,
    0x13 => pos + 16,
    _ => throw const FormatException('Unknown BSON type'),
  };
}
