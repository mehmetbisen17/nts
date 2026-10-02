import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/_tool.dart';
import 'package:nts/data/tools/highlighter.dart';
import 'package:nts/data/tools/pencil.dart';
import 'package:nts/data/tools/shape_pen.dart';
import 'package:nts/data/tools/tape.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:sbn/tool_id.dart';

class Pen extends Tool {
  @protected
  @visibleForTesting
  new({
    required this.name,
    required this.sizeMin,
    required this.sizeMax,
    required this.sizeStep,
    required this.icon,
    required this.options,
    required this.pressureEnabled,
    required this.color,
    required this.toolId,
  });

  new fountainPen()
    : name = t.editor.pens.fountainPen,
      sizeMin = 1,
      sizeMax = 25,
      sizeStep = 1,
      icon = fountainPenIcon,
      options = stows.lastFountainPenOptions.value,
      pressureEnabled = true,
      color = Color(stows.lastFountainPenColor.value),
      toolId = .fountainPen;

  new ballpointPen()
    : name = t.editor.pens.ballpointPen,
      sizeMin = 1,
      sizeMax = 25,
      sizeStep = 1,
      icon = ballpointPenIcon,
      options = stows.lastBallpointPenOptions.value,
      pressureEnabled = false,
      color = Color(stows.lastBallpointPenColor.value),
      toolId = .ballpointPen;

  /// Tapers strongly with pressure (or speed), for lettering.
  new brushPen()
    : name = t.editor.canvasTools.brushPen,
      sizeMin = 1,
      sizeMax = 40,
      sizeStep = 1,
      icon = brushPenIcon,
      options = stows.lastBrushPenOptions.value,
      pressureEnabled = true,
      color = Colors.black,
      toolId = .brushPen;

  final String name;
  final double sizeMin, sizeMax, sizeStep;
  late final int sizeStepsBetweenMinAndMax = ((sizeMax - sizeMin) / sizeStep)
      .round();
  final Object icon;

  @override
  final ToolId toolId;

  static const fountainPenIcon = FontAwesomeIcons.penFancy;
  static const ballpointPenIcon = FontAwesomeIcons.pen;
  static const brushPenIcon = FontAwesomeIcons.paintbrush;

  static Stroke? currentStroke;
  Color color;
  bool pressureEnabled;
  StrokeOptions options;

  static var _currentPen = Pen.fountainPen();
  static Pen get currentPen => _currentPen;
  static set currentPen(Pen currentPen) {
    assert(
      currentPen is! Highlighter,
      'Use Highlighter.currentHighlighter instead',
    );
    assert(currentPen is! Pencil, 'Use Pencil.currentPencil instead');
    assert(currentPen is! Tape, 'Use Tape.currentTape instead');
    _currentPen = currentPen;
  }

  void onDragStart(
    Offset position,
    EditorPage page,
    int pageIndex,
    double? pressure,
  ) {
    currentStroke = newStroke(page, pageIndex);
    onDragUpdate(position, pressure);
  }

  /// The stroke that [onDragStart] starts.
  @protected
  Stroke newStroke(EditorPage page, int pageIndex) => Stroke(
    color: color,
    pressureEnabled: pressureEnabled,
    options: options.copyWith(isComplete: false),
    pageIndex: pageIndex,
    page: page,
    toolId: toolId,
  );

  void onDragUpdate(Offset position, double? pressure) {
    currentStroke?.addPoint(position, pressure);
    if (_canHoldToSnap) _restartHoldTimer(position);
  }

  Stroke? onDragEnd() {
    _holdTimer?.cancel();
    _holdTimer = _holdAnchor = null;
    final stroke = currentStroke;
    final snapped = snapPreview;
    currentStroke = snapPreview = null;
    if (stroke == null) return null;

    stroke
      ..options.isComplete = true
      ..markPolygonNeedsUpdating();
    return snapped ?? stroke;
  }

  /// The clean shape that [currentStroke] becomes if the pen lifts now,
  /// shown instead of it while the pen is held (see [Stows.holdToSnapShape]).
  static Stroke? snapPreview;

  /// How long the pen must stay still for [Stows.holdToSnapShape].
  static const holdToSnapDelay = Duration(milliseconds: 600);

  /// Moving less than this (in page units) still counts as holding still.
  static const _holdSlop = 3.0;

  static Timer? _holdTimer;
  static Offset? _holdAnchor;

  bool get _canHoldToSnap =>
      stows.holdToSnapShape.value && _snapsTo != null && !followsRuler;

  /// Whether the current stroke follows the ruler, so it's straight
  /// already, and snapping would pull it off the ruler's edge.
  static var followsRuler = false;

  /// The shapes this pen snaps to: all of them, or just straight lines for
  /// the highlighter (a highlighted circle would be filled in).
  Set<DefaultUnistrokeNames>? get _snapsTo => switch (toolId) {
    .fountainPen ||
    .ballpointPen ||
    .pencil ||
    .brushPen => DefaultUnistrokeNames.values.toSet(),
    .highlighter => const {DefaultUnistrokeNames.line},
    _ => null,
  };

  /// Snaps [currentStroke] into a shape if the pen stays near [position]
  /// for [holdToSnapDelay]. Moving on drops the shape again.
  void _restartHoldTimer(Offset position) {
    final anchor = _holdAnchor;
    if (anchor != null && (position - anchor).distance < _holdSlop) return;
    _holdAnchor = position;
    final page = currentStroke?.page;
    if (snapPreview != null && page is EditorPage) page.redrawStrokes();
    snapPreview = null;
    _holdTimer?.cancel();
    _holdTimer = Timer(holdToSnapDelay, () {
      final stroke = currentStroke;
      if (stroke == null) return;
      final shape = stroke.detectShape();
      // (The score can be NaN, e.g. for a loop that ends where it started)
      if (shape?.name == null ||
          !(_snapsTo?.contains(shape!.name) ?? false) ||
          !(shape!.score >= holdToSnapMinScore)) {
        return;
      }
      final copy = stroke.copy()
        ..options.isComplete = true
        ..markPolygonNeedsUpdating();
      snapPreview = ShapePen.applyDetectedShape(copy, shape);
      if (stroke.page case final EditorPage page) page.redrawStrokes();
    });
  }

  /// How closely a held stroke must match a shape to snap,
  /// so pausing mid-word doesn't turn handwriting into shapes.
  static const holdToSnapMinScore = 0.8;

  /// The default stroke options.
  ///
  /// Note that these are different to the default options in [StrokeOptions]
  /// e.g. [StrokeOptions.defaultSize] for historical reasons
  /// (i.e. [StrokeOptions.toJson] does not include default values.)
  static final defaultOptions = StrokeOptions(size: 5);

  static StrokeOptions get fountainPenOptions => defaultOptions.copyWith();
  static StrokeOptions get ballpointPenOptions => defaultOptions.copyWith();
  static StrokeOptions get shapePenOptions =>
      defaultOptions.copyWith(smoothing: 0, streamline: 0);
  static StrokeOptions get highlighterOptions =>
      defaultOptions.copyWith(size: 50);
  static StrokeOptions get pencilOptions => defaultOptions.copyWith(
    streamline: 0.1,
    start: StrokeEndOptions.start(taperEnabled: true, customTaper: 1),
    end: StrokeEndOptions.end(taperEnabled: true, customTaper: 1),
  );
  static StrokeOptions get tapeOptions => defaultOptions.copyWith(
    size: 40,
    thinning: 0,
    start: StrokeEndOptions.start(cap: false),
    end: StrokeEndOptions.end(cap: false),
  );
  static StrokeOptions get brushPenOptions => defaultOptions.copyWith(
    size: 10,
    thinning: 0.9,
    start: StrokeEndOptions.start(taperEnabled: true, customTaper: 25),
    end: StrokeEndOptions.end(taperEnabled: true, customTaper: 25),
  );
  static StrokeOptions get calligraphyPenOptions =>
      defaultOptions.copyWith(size: 12, thinning: 0);
}
