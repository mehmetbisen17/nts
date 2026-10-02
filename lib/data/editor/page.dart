import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show FragmentShader;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:nts/components/canvas/_asset_cache.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/components/canvas/inner_canvas.dart';
import 'package:nts/components/canvas/pencil_shader.dart';
import 'package:nts/data/editor/editor_exporter.dart';
import 'package:nts/data/tools/laser_pointer.dart';
import 'package:sbn/has_size.dart';

typedef CanvasKey = GlobalKey<State<InnerCanvas>>;

/// What kind of note it is, saved as `nt` (see [EditorCoreInfo.noteType]).
enum NoteType(final String id, final Size pageSize) {
  /// Pages of paper, one after another.
  pages('', EditorPage.defaultSize),

  /// No paper: one surface to pan around in any direction.
  /// ponytail: a fixed 20000 square, starting in the middle (about 15
  /// screens each way); grow it on demand if anyone reaches an edge.
  whiteboard('whiteboard', Size(20000, 20000)),

  /// One sheet that grows as you write (see [EditorPage.growToFit]).
  endless('endless', EditorPage.defaultSize),

  /// Landscape 16:9 pages, like lecture slides.
  slides(
    'slides',
    Size(EditorPage.defaultWidth, EditorPage.defaultWidth * 9 / 16),
  ),

  /// Index cards, each a front page and a back page.
  flashcards(
    'flashcards',
    Size(EditorPage.defaultWidth, EditorPage.defaultWidth * 0.6),
  );

  /// Whether it's always one page.
  bool get singlePage => this == whiteboard || this == endless;

  static NoteType fromId(String? id) =>
      values.firstWhere((type) => type.id == id, orElse: () => pages);
}

class EditorPage extends ChangeNotifier implements HasSize {
  static const double defaultWidth = 1000;
  static const double defaultHeight = defaultWidth * 1.4;
  static const defaultSize = Size(defaultWidth, defaultHeight);

  /// Not final: an endless page grows (see [growToFit]).
  @override
  Size size;

  /// Whether this is a whiteboard: no paper, and not shrunk to fit the
  /// screen's width (see [NoteType.whiteboard]). Not saved; set from the
  /// note's type.
  var isBoard = false;

  /// How far the space beside the page reaches on each side, where
  /// images, moved notes and writing can go too (none on a whiteboard).
  double get sideWidth => isBoard ? 0 : sideWidthOf(size);
  static double sideWidthOf(Size pageSize) => pageSize.width;

  /// The page and the space beside it.
  Rect get areaWithSides =>
      Rect.fromLTRB(-sideWidth, 0, size.width + sideWidth, size.height);

  /// The gap between the page and things moved beside it.
  static const sideGap = 24.0;

  late final CanvasKey innerCanvasKey = CanvasKey();
  RenderBox? _renderBox;
  RenderBox? get renderBox {
    return _renderBox ??=
        innerCanvasKey.currentState?.context.findRenderObject() as RenderBox?;
  }

  var _isRendered = false;
  bool get isRendered => _isRendered;
  set isRendered(bool isRendered) {
    if (isRendered == _isRendered) return;
    _isRendered = isRendered;

    // reset renderBox as renderObject has changed
    _renderBox = null;
  }

  FragmentShader get pencilShader => _pencilShader ??= PencilShader.create();
  FragmentShader? _pencilShader;

  final List<Stroke> strokes;
  final List<LaserStroke> laserStrokes;
  final List<EditorImage> images;
  final QuillStruct quill;

  /// Areas that open a web page or another page of the note.
  /// Replaced (not changed in place) so undo can keep the old list.
  List<PageLink> links;

  /// Typed text that can go anywhere on the page or beside it.
  /// Replaced (not changed in place) so undo can keep the old list.
  List<PageTextBox> textBoxes;

  /// The tape strokes that show what's under them. Not saved, so every
  /// tape covers its content again when the note opens.
  final revealedTapes = <Stroke>{};

  EditorImage? backgroundImage;

  bool get isEmpty =>
      strokes.isEmpty &&
      images.isEmpty &&
      links.isEmpty &&
      textBoxes.isEmpty &&
      quill.controller.document.isEmpty() &&
      backgroundImage == null;
  bool get isNotEmpty => !isEmpty;

  /// The height of the canvas cropped to the content.
  double previewHeight({required int lineHeight}) {
    // avoid dividing by zero (this should never happen)
    assert(size.height != 0);
    assert(size.width != 0);
    if (size.height == 0 || size.width == 0) {
      return 0;
    }

    // if we have a background image, show full height
    if (backgroundImage != null) {
      return size.height;
    }

    /// The maximum y value of any stroke, image, or text.
    double maxY = 0;
    for (final stroke in strokes) {
      maxY = max(maxY, stroke.maxY);
    }
    for (final image in images) {
      maxY = max(maxY, image.dstRect.bottom);
    }
    for (final box in textBoxes) {
      maxY = max(maxY, box.estimatedBounds.bottom);
    }
    if (!quill.controller.document.isEmpty()) {
      // this does not account for text that wraps to the next line
      final int linesOfText = quill.controller.document
          .toPlainText()
          .split('\n')
          .length;
      maxY = max(maxY, linesOfText * lineHeight * 1.5); // ×1.5 fudge factor
    }

    /// The uncropped height of the page.
    /// In lots of cases, this is [Editor.defaultHeight].
    final fullHeight = size.height;

    /// The height of the canvas (cropped),
    /// adjusted to be between 10% and 100% of the full height.
    final croppedHeight = min(fullHeight, max(maxY, 0) + (0.1 * fullHeight));

    return croppedHeight;
  }

  new({
    Size? size,
    double? width,
    double? height,
    List<Stroke>? strokes,
    List<EditorImage>? images,
    QuillStruct? quill,
    this.backgroundImage,
    List<PageLink>? links,
    List<PageTextBox>? textBoxes,
  }) : assert(
         (size == null) || (width == null && height == null),
         "size and width/height shouldn't both be specified",
       ),
       size = size ?? Size(width ?? defaultWidth, height ?? defaultHeight),
       strokes = strokes ?? [],
       laserStrokes = [],
       images = images ?? [],
       links = links ?? const [],
       textBoxes = textBoxes ?? const [],
       quill =
           quill ??
           QuillStruct(
             controller: QuillController.basic(),
             focusNode: FocusNode(debugLabel: 'Quill Focus Node'),
           );

  factory fromJson(
    Map<String, dynamic> json, {
    required List<Uint8List>? inlineAssets,
    required bool readOnly,
    required int fileVersion,
    required String sbnPath,
    required AssetCache assetCache,
  }) {
    final size = Size(json['w'] ?? defaultWidth, json['h'] ?? defaultHeight);
    return EditorPage(
      size: size,
      strokes: parseStrokesJson(
        json['s'] as List?,
        page: HasSize(size),
        onlyFirstPage: false,
        fileVersion: fileVersion,
      ),
      images: parseImagesJson(
        json['i'] as List?,
        inlineAssets: inlineAssets,
        isThumbnail: readOnly,
        onlyFirstPage: false,
        sbnPath: sbnPath,
        assetCache: assetCache,
      ),
      quill: QuillStruct(
        controller: json['q'] != null
            ? QuillController(
                document: Document.fromJson(json['q'] as List),
                selection: const TextSelection.collapsed(offset: 0),
              )
            : QuillController.basic(),
        focusNode: FocusNode(debugLabel: 'Quill Focus Node'),
      ),
      backgroundImage: json['b'] != null
          ? parseImageJson(
              json['b'],
              inlineAssets: inlineAssets,
              isThumbnail: false,
              sbnPath: sbnPath,
              assetCache: assetCache,
            )
          : null,
      links: [
        for (final link in json['lk'] as List? ?? const [])
          PageLink.fromJson(link as Map<String, dynamic>),
      ],
      textBoxes: [
        for (final box in json['tb'] as List? ?? const [])
          PageTextBox.fromJson(box as Map<String, dynamic>),
      ],
    );
  }

  /// The lowest point of what's on the page.
  double get contentBottom => [
    0.0,
    for (final stroke in strokes)
      if (stroke.bounds.isFinite) stroke.bounds.bottom + stroke.options.size,
    for (final image in images) image.dstRect.bottom,
    for (final box in textBoxes) box.estimatedBounds.bottom,
  ].reduce(max);

  /// What's on the page with a margin, at least a page's size: what a
  /// whiteboard shows in its thumbnail and exports. Its middle if empty.
  Rect get contentRect {
    final rects = [
      for (final stroke in strokes)
        if (stroke.bounds.isFinite) stroke.bounds.inflate(stroke.options.size),
      for (final image in images) image.dstRect,
      for (final box in textBoxes) box.estimatedBounds,
    ];
    final content = rects.isEmpty
        ? Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0)
        : rects.reduce((a, b) => a.expandToInclude(b));
    final rect = Rect.fromCenter(
      center: content.center,
      width: max(content.width + 2 * defaultWidth / 10, defaultWidth),
      height: max(content.height + 2 * defaultWidth / 10, defaultWidth * 0.75),
    );
    return rect.intersect(Offset.zero & size);
  }

  /// Makes an endless page longer when its content gets near the bottom,
  /// so there's always half a page or more to write on. Never shrinks it.
  /// Returns whether it grew.
  bool growToFit() {
    final bottom = contentBottom;
    if (bottom <= size.height - defaultHeight / 2) return false;
    size = Size(size.width, bottom + defaultHeight);
    return true;
  }

  /// Turns text typed the old way (which always started at the top of the
  /// page) into a text box in the same place, as plain text.
  /// Nothing changes on disk until the note is next saved.
  void convertTypedText({required int lineHeight}) {
    final document = quill.controller.document;
    if (document.isEmpty()) return;
    final text = document.toPlainText().trimRight();
    quill.controller.clear();
    if (text.isEmpty) return;
    textBoxes = [
      ...textBoxes,
      PageTextBox(
        id: PageTextBox.nextId(textBoxes),
        // Where the old text's padding put it
        position: Offset(lineHeight * 0.5, lineHeight * 1.2),
        width: size.width - lineHeight,
        text: text,
        fontSize: lineHeight * 0.7,
      ),
    ];
  }

  Map<String, dynamic> toJson(OrderedAssetCache assets) => {
    'w': size.width,
    'h': size.height,
    if (strokes.isNotEmpty)
      's': strokes.map((stroke) => stroke.toJson()).toList(),
    if (images.isNotEmpty)
      'i': images.map((image) => image.toJson(assets)).toList(),
    if (!quill.controller.document.isEmpty())
      'q': quill.controller.document.toDelta().toJson(),
    if (backgroundImage != null) 'b': backgroundImage?.toJson(assets),
    if (links.isNotEmpty) 'lk': [for (final link in links) link.toJson()],
    if (textBoxes.isNotEmpty) 'tb': [for (final box in textBoxes) box.toJson()],
  };

  /// Inserts a stroke, while keeping the strokes sorted by
  /// pen type and color.
  void insertStroke(Stroke newStroke) {
    final int newStrokeColor = newStroke.color.toARGB32();

    int index = 0;
    for (final stroke in strokes) {
      final penTypeComparison = stroke.toolId.id.compareTo(newStroke.toolId.id);
      final color = stroke.color.toARGB32();
      if (penTypeComparison > 0) {
        break; // this stroke's pen type comes after the new stroke's pen type
      } else if (stroke.toolId == .highlighter &&
          penTypeComparison == 0 &&
          color > newStrokeColor) {
        break; // this highlighter color comes after the new highlighter color
      }
      index++;
    }

    strokes.insert(index, newStroke);
  }

  /// Sorts the strokes by pen type and color.
  void sortStrokes() {
    strokes.sort((Stroke a, Stroke b) {
      final penTypeComparison = a.toolId.id.compareTo(b.toolId.id);
      if (penTypeComparison != 0) return penTypeComparison;
      if (a.toolId != .highlighter) return 0;
      return a.color.toARGB32().compareTo(b.color.toARGB32());
    });
  }

  static List<Stroke> parseStrokesJson(
    List<dynamic>? strokes, {
    required HasSize page,
    required bool onlyFirstPage,
    required int fileVersion,
  }) => (strokes ?? [])
      .map((dynamic stroke) {
        final map = stroke as Map<String, dynamic>;
        final pageIndex = map['i'] ?? 0;
        if (onlyFirstPage && pageIndex > 0) return null;
        return Stroke.fromJson(
          map,
          fileVersion: fileVersion,
          pageIndex: pageIndex,
          page: page,
        );
      })
      .where((element) => element != null)
      .cast<Stroke>()
      .toList();

  static List<EditorImage> parseImagesJson(
    List<dynamic>? images, {
    required List<Uint8List>? inlineAssets,
    required bool isThumbnail,
    required bool onlyFirstPage,
    required String sbnPath,
    required AssetCache assetCache,
  }) =>
      images
          ?.cast<Map<String, dynamic>>()
          .map((Map<String, dynamic> image) {
            if (onlyFirstPage && image['i'] > 0) return null;
            return parseImageJson(
              image,
              inlineAssets: inlineAssets,
              isThumbnail: isThumbnail,
              sbnPath: sbnPath,
              assetCache: assetCache,
            );
          })
          .where((element) => element != null)
          .cast<EditorImage>()
          .toList() ??
      [];

  static EditorImage parseImageJson(
    Map<String, dynamic> json, {
    required List<Uint8List>? inlineAssets,
    required bool isThumbnail,
    required String sbnPath,
    required AssetCache assetCache,
  }) => EditorImage.fromJson(
    json,
    inlineAssets: inlineAssets,
    isThumbnail: isThumbnail,
    sbnPath: sbnPath,
    assetCache: assetCache,
  );

  /// Triggers a redraw of the strokes. If you need to redraw images,
  /// call [setState] instead.
  void redrawStrokes() {
    notifyListeners();
  }

  /// Updates the `pageIndex` fields of this page's strokes/images.
  void updatePageIndex(int pageIndex) {
    for (final stroke in strokes) stroke.pageIndex = pageIndex;
    for (final stroke in laserStrokes) stroke.pageIndex = pageIndex;
    for (final image in images) image.pageIndex = pageIndex;
    backgroundImage?.pageIndex = pageIndex;
  }

  @override
  void dispose() {
    quill.dispose();
    _pencilShader?.dispose();
    isRendered = false;
    for (final image in images) {
      image.dispose();
    }
    backgroundImage?.dispose();
    super.dispose();
  }

  /// [cloneForRasterization] creates some new resources that need to be
  /// disposed, but it also contains some resources from the original page
  /// that should not be disposed since they are still in use.
  ///
  /// Call this method instead of [dispose] to dispose only the resources
  /// exclusive to the cloned page.
  void disposeClonedData() {
    quill.dispose();
    _pencilShader?.dispose();
    isRendered = false;
    super.dispose();
  }

  EditorPage copyWith({
    Size? size,
    List<Stroke>? strokes,
    List<EditorImage>? images,
    QuillStruct? quill,
    EditorImage? backgroundImage,
  }) => EditorPage(
    size: size ?? this.size,
    strokes: strokes ?? this.strokes,
    images: images ?? this.images,
    quill: quill ?? this.quill,
    backgroundImage: backgroundImage ?? this.backgroundImage,
    links: links,
    textBoxes: textBoxes,
  );

  /// Clones this page for use in a screenshot.
  ///
  /// Avoids bugs caused by the quill editor being attached to multiple
  /// contexts, and filters out strokes that shouldn't be rasterized.
  ///
  /// Make sure to call [disposeClonedData] on the returned page when
  /// you're done with it.
  EditorPage cloneForRasterization({bool rasterizeAllStrokes = false}) {
    return copyWith(
      strokes: rasterizeAllStrokes
          ? strokes
          : [
              for (final stroke in strokes)
                if (EditorExporter.shouldRasterizeStroke(stroke))
                  stroke
                // Fills go under text and images, so they're rasterized
                // even if the stroke itself is drawn as a vector.
                else if (stroke.fillColor != null)
                  stroke.copy()..color = const Color(0x00000000),
            ],
      quill: quill.cloneForScreenshot(),
    );
  }
}

class QuillStruct {
  final QuillController controller;
  late final FocusNode focusNode;
  StreamSubscription? changeSubscription;

  new({required this.controller, required this.focusNode});

  void dispose() {
    changeSubscription?.cancel();
    focusNode.dispose();
    controller.dispose();
  }

  QuillStruct cloneForScreenshot() => QuillStruct(
    controller: QuillController(
      document: Document.fromDelta(controller.document.toDelta()),
      selection: const TextSelection.collapsed(offset: 0),
    ),
    focusNode: FocusNode(debugLabel: 'Screenshot Quill Focus Node'),
  );
}

/// An area of a page that opens [url] when tapped: a web page, an email
/// address, or `#page=N` for page N of the same note.
class PageLink {
  const new(this.rect, this.url);

  final Rect rect;
  final String url;

  factory fromJson(Map<String, dynamic> json) => PageLink(
    Rect.fromLTWH(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
      (json['w'] as num).toDouble(),
      (json['h'] as num).toDouble(),
    ),
    json['u'] as String,
  );

  Map<String, dynamic> toJson() => {
    'x': rect.left,
    'y': rect.top,
    'w': rect.width,
    'h': rect.height,
    'u': url,
  };

  /// The page index for a `#page=N` link, or null for other links.
  int? get pageIndex => switch (_pageLink.firstMatch(url)?.group(1)) {
    final n? => int.parse(n) - 1,
    null => null,
  };

  static final _pageLink = RegExp(r'^#page=(\d+)$');

  /// The link people typed, cleaned up (e.g. `example.com` gets https),
  /// or null if it isn't a web, email or page link in a note with
  /// [pageCount] pages.
  static String? parse(String input, {required int pageCount}) {
    var url = input.trim();
    if (url.isEmpty || url.contains(RegExp(r'\s'))) return null;
    if (_pageLink.hasMatch(url)) {
      final page = int.parse(_pageLink.firstMatch(url)!.group(1)!);
      return page >= 1 && page <= pageCount ? url : null;
    }
    if (!url.contains(':')) {
      url = url.contains('@') ? 'mailto:$url' : 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    return switch (uri.scheme) {
      'http' || 'https' when uri.host.contains('.') => url,
      'mailto' when uri.path.contains('@') => url,
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PageLink && other.rect == rect && other.url == url;

  @override
  int get hashCode => Object.hash(rect, url);
}

/// Typed text in a box that can sit anywhere on a page or beside it,
/// and move. Replaced (not changed) when edited, like [PageLink].
class PageTextBox {
  const new({
    required this.id,
    required this.position,
    required this.width,
    required this.text,
    this.fontSize = defaultFontSize,
    this.color,
  });

  /// Unique on its page, to keep its widget when it's edited.
  final int id;

  /// Its top left.
  final Offset position;
  final double width;
  final String text;
  final double fontSize;

  /// Null for the default ink (black, or white on black pages).
  final Color? color;

  /// The typed text's size the old way, with the default line height.
  static const defaultFontSize = 28.0;
  static const minWidth = 60.0;

  /// The line height, as a multiple of [fontSize]: lines fall
  /// on ruled lines, like the old typed text.
  static const lineSpacing = 1 / 0.7;

  /// Roughly where it is, assuming no line wraps.
  Rect get estimatedBounds => Rect.fromLTWH(
    position.dx,
    position.dy,
    width,
    max(1, '\n'.allMatches(text).length + 1) * fontSize * lineSpacing,
  );

  static int nextId(List<PageTextBox> boxes) =>
      boxes.fold(0, (id, box) => max(id, box.id + 1));

  factory fromJson(Map<String, dynamic> json) => PageTextBox(
    id: json['id'] as int? ?? 0,
    position: Offset(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    ),
    width: (json['w'] as num).toDouble(),
    text: json['t'] as String? ?? '',
    fontSize: (json['fs'] as num?)?.toDouble() ?? defaultFontSize,
    color: switch (json['c']) {
      final int value => Color(value),
      final Int64 value => Color(value.toInt()),
      _ => null,
    },
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': position.dx,
    'y': position.dy,
    'w': width,
    't': text,
    if (fontSize != defaultFontSize) 'fs': fontSize,
    if (color != null) 'c': color!.toARGB32(),
  };

  PageTextBox copyWith({
    Offset? position,
    double? width,
    String? text,
    double? fontSize,
    Color? color,
  }) => PageTextBox(
    id: id,
    position: position ?? this.position,
    width: width ?? this.width,
    text: text ?? this.text,
    fontSize: fontSize ?? this.fontSize,
    color: color ?? this.color,
  );

  @override
  bool operator ==(Object other) =>
      other is PageTextBox &&
      other.id == id &&
      other.position == position &&
      other.width == width &&
      other.text == text &&
      other.fontSize == fontSize &&
      other.color == color;

  @override
  int get hashCode => Object.hash(id, position, width, text, fontSize, color);
}
