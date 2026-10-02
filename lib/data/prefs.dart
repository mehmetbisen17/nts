import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:nts/components/canvas/_calligraphy_stroke.dart';
import 'package:nts/components/home/home_layout_button.dart';
import 'package:nts/components/home/sort_button.dart';
import 'package:nts/components/navbar/responsive_navbar.dart';
import 'package:nts/data/ai/auth/oauth_tokens.dart';
import 'package:nts/data/sentry/sentry_consent.dart';
import 'package:nts/data/services/pen_presets.dart';
import 'package:nts/data/tools/eraser.dart';
import 'package:nts/data/tools/highlighter.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/data/tools/tool_catalog.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/tool_id.dart';
import 'package:stow/stow.dart';
import 'package:stow_codecs/stow_codecs.dart';
import 'package:stow_plain/stow_plain.dart';

/// If false, all stows are stuck at their default values.
var _isOnMainIsolate = false;

final stows = Stows();

class Stows {
  new() {
    recentColorsLength.addListener(() {
      // truncate if needed
      while (recentColorsLength.value < recentColorsPositioned.value.length) {
        // remove oldest color
        final removed = recentColorsChronological.value.removeAt(0);
        recentColorsPositioned.value.remove(removed);
      }
    });
  }

  /// Call this before [runApp] to set [_isOnMainIsolate] to true.
  static void markAsOnMainIsolate() {
    _isOnMainIsolate = true;
  }

  final log = Logger('Stows');

  final customDataDir = PlainStow<String?>(
    'customDataDir',
    null,
    volatile: !_isOnMainIsolate,
  );

  /// Base64 security-scoped bookmark of the notes folder the user picked
  /// (e.g. in iCloud Drive), or empty if none. See `ICloudStorage`.
  final icloudBookmark = PlainStow(
    'icloudBookmark',
    '',
    volatile: !_isOnMainIsolate,
  );

  /// Sign-in tokens of the AI accounts as JSON (see `TokenStore`),
  /// or empty if signed out. Claude has none: Claude Code keeps its own.
  final aiChatgptTokens = KeychainStow(
    'ai.chatgpt.tokens',
    volatile: !_isOnMainIsolate,
  );
  final aiGoogleTokens = KeychainStow(
    'ai.google.tokens',
    volatile: !_isOnMainIsolate,
  );

  /// The OAuth client ID and project ID of the user's own Google Cloud
  /// project, entered in Settings. Public identifiers, not secrets.
  final aiGoogleClientId = PlainStow(
    'ai.google.clientId',
    '',
    volatile: !_isOnMainIsolate,
  );
  final aiGoogleProjectId = PlainStow(
    'ai.google.projectId',
    '',
    volatile: !_isOnMainIsolate,
  );

  /// Which account and model each AI action uses, by `AiAction.name`:
  /// `auto` or `<provider>:<model>`. See `AiRouter`.
  final aiRoutes = {
    for (final action in const [
      'explainExample',
      'paragraph',
      'graph',
      'illustration',
      'video',
      'source',
    ])
      action: PlainStow(
        'ai.route.$action',
        'auto',
        volatile: !_isOnMainIsolate,
      ),
  };

  /// Whether the notes of the sandboxed Mac app were copied out of its
  /// container, see `SandboxMigration`.
  final macSandboxNotesCopied = PlainStow(
    'macSandboxNotesCopied',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// Higan: dark ("Night") is the default, light is "Paper".
  final appTheme = PlainStow(
    'appTheme',
    ThemeMode.dark,
    codec: const EnumCodec(ThemeMode.values),
    volatile: !_isOnMainIsolate,
  );

  /// The type of platform to theme. Default value is [defaultTargetPlatform].
  ///
  /// Not saved: Higan has no picker for it, and the layout and window
  /// chrome follow it, so a value saved by an older version must not stick.
  /// Tests set it to render other platforms.
  final platform = PlainStow(
    'platform',
    defaultTargetPlatform,
    codec: const EnumCodec(TargetPlatform.values),
    volatile: true,
  );
  final layoutSize = PlainStow(
    'layoutSize',
    LayoutSize.auto,
    codec: LayoutSize.codec,
    volatile: !_isOnMainIsolate,
  );

  /// The accent color of the app. If 0, the system accent color will be used.
  final accentColor = PlainStow<Color?>(
    'accentColor',
    null,
    codec: const ColorCodec(),
    volatile: !_isOnMainIsolate,
  );
  final hyperlegibleFont = PlainStow(
    'hyperlegibleFont',
    false,
    volatile: !_isOnMainIsolate,
  );

  final editorToolbarAlignment = PlainStow(
    'editorToolbarAlignment',
    AxisDirection.down,
    codec: const EnumCodec(AxisDirection.values),
    volatile: !_isOnMainIsolate,
  );
  final editorToolbarShowInFullscreen = PlainStow(
    'editorToolbarShowInFullscreen',
    true,
    volatile: !_isOnMainIsolate,
  );

  /// The toolbar's buttons in order, as [ToolbarItem.id]s.
  /// Unknown ids (e.g. from a newer version) are ignored, see [ToolCatalog].
  final editorToolbarItems = PlainStow(
    'editorToolbarItems',
    ToolCatalog.basics,
    volatile: !_isOnMainIsolate,
  );

  /// Whether [ToolCatalog.seed] has run.
  final editorToolbarSeeded = PlainStow(
    'editorToolbarSeeded',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// Where the user moved the editor's floating bars, as
  /// `'<bar>.<compact|wide>': [x, y]` fractions of the free space.
  /// No entry means the bar is in its default place. See `FloatingBar`.
  final editorBarPositions = PlainStow.json(
    'editorBarPositions',
    const <String, List<double>>{},
    fromJson: (json) => {
      for (final MapEntry(:key, :value) in (json as Map).entries)
        key as String: [for (final x in value as List) (x as num).toDouble()],
    },
    volatile: !_isOnMainIsolate,
  );

  /// Ids of the editor's floating bars that are minimized.
  final editorMinimizedBars = PlainStow(
    'editorMinimizedBars',
    <String>[],
    volatile: !_isOnMainIsolate,
  );

  /// The pen favorites in the toolbar, see [PenPreset].
  final penPresets = PlainStow.json(
    'penPresets',
    const <PenPreset>[],
    fromJson: PenPreset.listFromJson,
    volatile: !_isOnMainIsolate,
  );

  final editorFingerDrawing = PlainStow(
    'editorFingerDrawing',
    true,
    volatile: !_isOnMainIsolate,
  );

  /// "Pages: Black" in settings. Pages are paper-colored by default.
  final editorAutoInvert = PlainStow(
    'editorAutoInvert',
    false,
    volatile: !_isOnMainIsolate,
  );
  final preferGreyscale = PlainStow(
    'preferGreyscale',
    false,
    volatile: !_isOnMainIsolate,
  );
  final editorPromptRename = PlainStow(
    'editorPromptRename',
    isDesktop,
    volatile: !_isOnMainIsolate,
  );
  final autosaveDelay = PlainStow(
    'autosaveDelay',
    10000,
    volatile: !_isOnMainIsolate,
  );
  final shapeRecognitionDelay = PlainStow(
    'shapeRecognitionDelay',
    500,
    volatile: !_isOnMainIsolate,
  );
  final autoStraightenLines = PlainStow(
    'autoStraightenLines',
    true,
    volatile: !_isOnMainIsolate,
  );

  final printPageIndicators = PlainStow(
    'printPageIndicators',
    false,
    volatile: !_isOnMainIsolate,
  );

  final maxImageSize = PlainStow<double>(
    'maxImageSize',
    1000,
    volatile: !_isOnMainIsolate,
  );

  final autoClearWhiteboardOnExit = PlainStow(
    'autoClearWhiteboardOnExit',
    false,
    volatile: !_isOnMainIsolate,
  );

  final disableEraserAfterUse = PlainStow(
    'disableEraserAfterUse',
    false,
    volatile: !_isOnMainIsolate,
  );
  final eraserMode = PlainStow(
    'eraserMode',
    EraserMode.stroke,
    codec: const EnumCodec(EraserMode.values),
    volatile: !_isOnMainIsolate,
  );

  /// The eraser's radius in page units.
  final eraserSize = PlainStow<double>(
    'eraserSize',
    10,
    volatile: !_isOnMainIsolate,
  );
  final hideFingerDrawingToggle = PlainStow(
    'hideFingerDrawingToggle',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// People don't know to turn off finger drawing when using a stylus,
  /// so we can do it automatically.
  final autoDisableFingerDrawingWhenStylusDetected = PlainStow(
    'autoDisableFingerDrawingWhenStylusDetected',
    true,
    volatile: !_isOnMainIsolate,
  );

  final recentColorsChronological = PlainStow(
    'recentColorsChronological',
    <String>[],
    volatile: !_isOnMainIsolate,
  );
  final recentColorsPositioned = PlainStow(
    'recentColorsPositioned',
    <String>[],
    volatile: !_isOnMainIsolate,
  );
  final pinnedColors = PlainStow(
    'pinnedColors',
    <String>[],
    volatile: !_isOnMainIsolate,
  );
  final recentColorsDontSavePresets = PlainStow(
    'dontSavePresetColors',
    false,
    volatile: !_isOnMainIsolate,
  );
  final recentColorsLength = PlainStow(
    'recentColorsLength',
    5,
    volatile: !_isOnMainIsolate,
  );

  final lastTool = PlainStow(
    'lastTool',
    ToolId.fountainPen,
    codec: ToolId.codec,
    volatile: !_isOnMainIsolate,
  );
  static StrokeOptions _strokeOptionsFromJson(Object json) =>
      StrokeOptions.fromJson(json as Map<String, dynamic>);
  final lastFountainPenOptions = PlainStow.json(
        'lastFountainPenProperties',
        Pen.fountainPenOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      ),
      lastBallpointPenOptions = PlainStow.json(
        'lastBallpointPenProperties',
        Pen.ballpointPenOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      ),
      lastHighlighterOptions = PlainStow.json(
        'lastHighlighterProperties',
        Pen.highlighterOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      ),
      lastPencilOptions = PlainStow.json(
        'lastPencilProperties',
        Pen.pencilOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      ),
      lastShapePenOptions = PlainStow.json(
        'lastShapePenProperties',
        Pen.shapePenOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      );
  final lastFountainPenColor = PlainStow(
        'lastFountainPenColor',
        Colors.black.toARGB32(),
        volatile: !_isOnMainIsolate,
      ),
      lastBallpointPenColor = PlainStow(
        'lastBallpointPenColor',
        Colors.black.toARGB32(),
        volatile: !_isOnMainIsolate,
      ),
      lastHighlighterColor = PlainStow(
        'lastHighlighterColor',
        Colors.yellow.withAlpha(Highlighter.alpha).toARGB32(),
        volatile: !_isOnMainIsolate,
      ),
      lastPencilColor = PlainStow(
        'lastPencilColor',
        Colors.black.toARGB32(),
        volatile: !_isOnMainIsolate,
      ),
      lastShapePenColor = PlainStow(
        'lastShapePenColor',
        Colors.black.toARGB32(),
        volatile: !_isOnMainIsolate,
      );

  // Canvas tools (see lib/data/tools)
  final lastTapeOptions = PlainStow.json(
        'lastTapeProperties',
        Pen.tapeOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      ),
      lastBrushPenOptions = PlainStow.json(
        'lastBrushPenProperties',
        Pen.brushPenOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      ),
      lastCalligraphyPenOptions = PlainStow.json(
        'lastCalligraphyPenProperties',
        Pen.calligraphyPenOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      );

  /// The calligraphy pen's nib angle, in degrees.
  final calligraphyNibAngle = PlainStow<double>(
    'calligraphyNibAngle',
    CalligraphyStroke.defaultNibAngle,
    volatile: !_isOnMainIsolate,
  );
  final lassoMode = PlainStow(
    'lassoMode',
    LassoMode.freehand,
    codec: const EnumCodec(LassoMode.values),
    volatile: !_isOnMainIsolate,
  );

  /// Scribbling over ink with a pen erases it.
  final scribbleToErase = PlainStow(
    'scribbleToErase',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// Holding a pen still at the end of a stroke snaps it into a shape.
  final holdToSnapShape = PlainStow(
    'holdToSnapShape',
    true,
    volatile: !_isOnMainIsolate,
  );
  final lastBackgroundPattern = PlainStow(
    'lastBackgroundPattern',
    CanvasBackgroundPattern.none,
    codec: const EnumCodec(CanvasBackgroundPattern.values),
    volatile: !_isOnMainIsolate,
  );
  static const defaultLineHeight = 40;
  static const defaultLineThickness = 3;
  final lastLineHeight = PlainStow(
    'lastLineHeight',
    defaultLineHeight,
    volatile: !_isOnMainIsolate,
  );
  final lastLineThickness = PlainStow(
    'lastLineThickness',
    defaultLineThickness,
    volatile: !_isOnMainIsolate,
  );
  final lastZoomLock = PlainStow(
        'lastZoomLock',
        false,
        volatile: !_isOnMainIsolate,
      ),
      lastSingleFingerPanLock = PlainStow(
        'lastSingleFingerPanLock',
        false,
        volatile: !_isOnMainIsolate,
      ),
      lastAxisAlignedPanLock = PlainStow(
        'lastAxisAlignedPanLock',
        false,
        volatile: !_isOnMainIsolate,
      );

  final homeLayout = PlainStow(
    'homeLayout',
    HomeLayout.masonryGrid,
    codec: HomeLayout.codec,
    volatile: !_isOnMainIsolate,
  );
  final browseSortMetric = PlainStow(
    'browseSortMetric',
    SortMetric.nameAToZ,
    codec: SortMetric.codec,
    volatile: !_isOnMainIsolate,
  );

  /// Folder path -> [FolderViewMode.name]. Use [FolderViewMode.of] and
  /// [FolderViewMode.set] instead of reading this directly.
  final folderViewModes = PlainStow.json(
    'folderViewModes',
    const <String, String>{},
    fromJson: (json) => (json as Map).cast<String, String>(),
    volatile: !_isOnMainIsolate,
  );

  /// How big note cards and folder tiles are in galleries, as a multiple
  /// of their default width (see `galleryColumns`).
  final galleryScale = PlainStow<double>(
    'galleryScale',
    1,
    volatile: !_isOnMainIsolate,
  );
  final recentFiles = PlainStow(
    'recentFiles',
    <String>[],
    volatile: !_isOnMainIsolate,
  );

  final locale = PlainStow('locale', '', volatile: !_isOnMainIsolate);

  final sentryConsent = PlainStow(
    'sentryConsent',
    SentryConsent.unknown,
    codec: SentryConsent.codec,
    volatile: !_isOnMainIsolate,
  );

  @pragma('vm:platform-const')
  static final isDesktop =
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;
}

/// An [Stow] that transforms the value of another [Stow].
class TransformedStow<T_in, T_out> extends Stow<dynamic, T_out, dynamic> {
  final Stow<dynamic, T_in, dynamic> parent;
  final T_out Function(T_in) transform;
  final T_in Function(T_out) reverseTransform;

  @override
  T_out get value => transform(parent.value);

  @override
  set value(T_out value) => parent.value = reverseTransform(value);

  new(this.parent, this.transform, this.reverseTransform)
    : super(parent.key, transform(parent.defaultValue), volatile: true) {
    parent.addListener(notifyListeners);
  }

  @override
  Future<dynamic> protectedRead() async => null;

  @override
  Future<void> protectedWrite(dynamic value) async {}

  @override
  String toString() {
    return 'TransformedPref<$T_in, $T_out>(from ${parent.key}, $value)';
  }

  @override
  void dispose() {
    parent.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Whether a folder (or the Recent page) shows notes as a gallery or a list.
/// Each folder remembers its own choice in [Stows.folderViewModes].
enum FolderViewMode {
  gallery,
  list;

  /// Key for the Recent page, which isn't a folder.
  static const recentKey = '@recent';

  /// The saved mode for [path], or [gallery] if none was saved.
  /// To rebuild on changes, listen to [Stows.folderViewModes].
  factory of(String path) =>
      values.asNameMap()[stows.folderViewModes.value[_key(path)]] ?? gallery;

  static void set(String path, FolderViewMode mode) {
    final modes = {...stows.folderViewModes.value};
    if (mode == gallery) {
      modes.remove(_key(path));
    } else {
      modes[_key(path)] = mode.name;
    }
    stows.folderViewModes.value = modes;
  }

  /// Treats '' and '/' (and trailing slashes) as the same folder.
  static String _key(String path) {
    final trimmed = path.replaceFirst(RegExp(r'/+$'), '');
    return trimmed.isEmpty ? '/' : trimmed;
  }
}
