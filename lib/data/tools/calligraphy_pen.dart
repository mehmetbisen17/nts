import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nts/components/canvas/_calligraphy_stroke.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/i18n/strings.g.dart';

/// A flat-nib (reed) pen: see [CalligraphyStroke].
class CalligraphyPen extends Pen {
  new()
    : super(
        name: t.editor.canvasTools.calligraphyPen,
        sizeMin: 2,
        sizeMax: 40,
        sizeStep: 1,
        icon: calligraphyPenIcon,
        options: stows.lastCalligraphyPenOptions.value,
        pressureEnabled: false,
        color: Colors.black,
        toolId: .calligraphyPen,
      );

  static const calligraphyPenIcon = FontAwesomeIcons.penNib;

  @override
  Stroke newStroke(EditorPage page, int pageIndex) => CalligraphyStroke(
    color: color,
    pressureEnabled: pressureEnabled,
    options: options.copyWith(isComplete: false),
    pageIndex: pageIndex,
    page: page,
    toolId: toolId,
    nibAngle: stows.calligraphyNibAngle.value,
  );
}
