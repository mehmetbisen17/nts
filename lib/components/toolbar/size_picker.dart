import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/tools/pen.dart';
import 'package:nts/i18n/strings.g.dart';

class SizePicker extends StatefulWidget {
  const new({
    super.key,
    required this.axis,
    required this.pen,
    this.length = largeLength,
  });

  final Axis axis;
  final Pen pen;

  /// The slider's length along [axis].
  final double length;

  @override
  State<SizePicker> createState() => _SizePickerState();

  static const double smallLength = 25;
  static const double largeLength = 150;
}

/// Returns a string representation of [num] that:
/// - Has no decimal point if [num] is an integer
/// - Has one decimal point if [num] has a non-zero fractional part
String _prettyNum(double num) {
  final rounded = num.round();
  if (num == rounded) return rounded.toString();
  return num.toStringAsFixed(1);
}

class _SizePickerState extends State<SizePicker> {
  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final size = _prettyNum(widget.pen.options.size);
    return Flex(
      direction: widget.axis,
      mainAxisSize: .min,
      children: [
        Semantics(
          label: t.editor.penOptions.size,
          value: size,
          child: _SizeSlider(
            pen: widget.pen,
            axis: widget.axis,
            length: widget.length,
            setState: setState,
          ),
        ),
        const SizedBox.square(dimension: 10),
        SizedBox(
          width: 26,
          child: Text(
            size,
            style: HiganText.label(context, size: 10, color: c.text),
          ),
        ),
      ],
    );
  }
}

class _SizeSlider extends StatelessWidget {
  const new({
    required this.pen,
    required this.axis,
    required this.length,
    required this.setState,
  });

  final Pen pen;
  final Axis axis;
  final double length;
  final void Function(void Function()) setState;

  /// [percent] is a value between 0 and 1
  /// where 0 is the start of the slider and 1 is the end.
  ///
  /// Values outside of this range are allowed but will be clamped.
  void onDrag(double percent) {
    percent = clampDouble(percent, 0, 1);
    final stepsFromMin = (percent * pen.sizeStepsBetweenMinAndMax).round();
    final newSize = pen.sizeMin + stepsFromMin * pen.sizeStep;
    if (newSize == pen.options.size) return;
    setState(() {
      pen.options.size = newSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return GestureDetector(
      onHorizontalDragStart: axis == Axis.horizontal
          ? (details) => onDrag(details.localPosition.dx / length)
          : null,
      onHorizontalDragUpdate: axis == Axis.horizontal
          ? (details) => onDrag(details.localPosition.dx / length)
          : null,
      onVerticalDragStart: axis == Axis.vertical
          ? (details) => onDrag(details.localPosition.dy / length)
          : null,
      onVerticalDragUpdate: axis == Axis.vertical
          ? (details) => onDrag(details.localPosition.dy / length)
          : null,
      onTapUp: (details) => onDrag(
        (axis == Axis.horizontal
                ? details.localPosition.dx
                : details.localPosition.dy) /
            length,
      ),
      child: RotatedBox(
        quarterTurns: axis == Axis.horizontal ? 0 : 1,
        child: CustomPaint(
          size: Size(length, SizePicker.smallLength),
          painter: _SizeSliderPainter(
            minSize: pen.sizeMin,
            maxSize: pen.sizeMax,
            currentSize: pen.options.size,
            trackColor: c.hairlineStrong,
            thumbColor: c.text,
          ),
        ),
      ),
    );
  }
}

/// A 2px track with a 12px thumb, like the app's other sliders.
class _SizeSliderPainter extends CustomPainter {
  new({
    required this.minSize,
    required this.maxSize,
    required this.currentSize,
    required this.trackColor,
    required this.thumbColor,
  });

  final double minSize;
  final double maxSize;
  final double currentSize;
  final Color trackColor;
  final Color thumbColor;

  static const thumbRadius = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final ratio = clampDouble(
      (currentSize - minSize) / (maxSize - minSize),
      0,
      1,
    );
    final thumbX = thumbRadius + (size.width - 2 * thumbRadius) * ratio;
    final track = Paint()
      ..strokeWidth = 2
      ..strokeCap = .round;

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      track..color = trackColor,
    );
    canvas.drawLine(Offset(0, y), Offset(thumbX, y), track..color = thumbColor);
    canvas.drawCircle(
      Offset(thumbX, y),
      thumbRadius,
      Paint()..color = thumbColor,
    );
  }

  @override
  bool shouldRepaint(_SizeSliderPainter oldDelegate) =>
      oldDelegate.minSize != minSize ||
      oldDelegate.maxSize != maxSize ||
      oldDelegate.currentSize != currentSize ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.thumbColor != thumbColor;
}
