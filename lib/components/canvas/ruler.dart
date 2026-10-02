import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nts/components/canvas/inner_canvas.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';

/// Where the ruler is, in the [RulerOverlay]'s coordinates:
/// its [center], and its [angle] in radians (clockwise).
typedef RulerPosition = ({Offset center, double angle});

/// An on-screen straightedge over [child] (the canvas). Fingers (and the
/// mouse) move it, two fingers (or scrolling over it) turn it; a stylus
/// draws past it, and pen strokes that start near an edge follow that edge
/// (see [RulerPosition.snap]).
class RulerOverlay extends StatefulWidget {
  const new({super.key, required this.ruler, required this.child});

  /// Null when the ruler is hidden.
  final ValueNotifier<RulerPosition?> ruler;

  /// What the ruler lies over, which gets every pointer
  /// the ruler doesn't claim (including a stylus on the ruler).
  final Widget child;

  /// The ruler's thickness.
  static const double height = 72;

  /// Pen strokes that start this close to an edge follow it.
  static const double snapDistance = 24;

  /// Angles this close to a multiple of 45° snap to it.
  static const _snapAngle = 3 * pi / 180;

  /// The angle snapped to a multiple of 45° if it's close.
  static double snapAngle(double angle) {
    final snapped = (angle / (pi / 4)).roundToDouble() * (pi / 4);
    return (angle - snapped).abs() < _snapAngle ? snapped : angle;
  }

  /// How far scrolling over the ruler turns it: a mouse wheel's notch
  /// (20 pixels) is 5°, so nine make 45°.
  static const radiansPerScrollPixel = pi / 720;

  /// Long enough to cross an overlay of [size] at any angle.
  static double lengthFor(Size size) => 2 * size.longestSide;

  @override
  State<RulerOverlay> createState() => _RulerOverlayState();
}

class _RulerOverlayState extends State<RulerOverlay> {
  /// The ruler and the focal point when the gesture started,
  /// and whether it's a trackpad's (two-finger scroll or rotate).
  (RulerPosition, Offset, {bool trackpad})? _start;

  bool _isOnRuler(Offset point) => switch ((widget.ruler.value, context.size)) {
    (final ruler?, final size?) => ruler.contains(point, size),
    _ => false,
  };

  /// Scrolling over the ruler turns it instead of scrolling the canvas,
  /// but Cmd/Ctrl+scroll still zooms the canvas.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        _zoomKeyHeld ||
        !_isOnRuler(event.localPosition)) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final ruler = widget.ruler.value;
      if (ruler == null) return;
      final delta = event.scrollDelta.dy + event.scrollDelta.dx;
      widget.ruler.value = (
        center: ruler.center,
        angle: ruler.angle + delta * RulerOverlay.radiansPerScrollPixel,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        _RulerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_RulerGestureRecognizer>(
              () => _RulerGestureRecognizer(isOnRuler: _isOnRuler),
              (recognizer) => recognizer
                ..onStart = (details) {
                  _start = switch (widget.ruler.value) {
                    final ruler? => (
                      ruler,
                      details.focalPoint,
                      trackpad: details.kind == .trackpad,
                    ),
                    null => null,
                  };
                }
                ..onUpdate = (details) {
                  final (ruler, focalPoint, :trackpad) =
                      _start ?? (null, null, trackpad: false);
                  if (ruler == null || focalPoint == null) return;
                  final moved = details.focalPoint - focalPoint;
                  // A trackpad scroll turns it like the wheel does (its pan
                  // is the opposite of a wheel's scroll delta)
                  final scrolled = trackpad
                      ? -(moved.dx + moved.dy) *
                            RulerOverlay.radiansPerScrollPixel
                      : 0.0;
                  widget.ruler.value = (
                    center: trackpad ? ruler.center : ruler.center + moved,
                    angle: RulerOverlay.snapAngle(
                      ruler.angle + scrolled + details.rotation,
                    ),
                  );
                }
                ..onEnd = (_) => _start = null,
            ),
      },
      child: Stack(
        fit: .expand,
        children: [
          widget.child,
          // Paint only: pointers are routed by [_RulerGestureRecognizer]
          IgnorePointer(
            child: ValueListenableBuilder(
              valueListenable: widget.ruler,
              builder: (context, position, _) {
                if (position == null) return const SizedBox.shrink();
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final length = RulerOverlay.lengthFor(constraints.biggest);
                    return Stack(
                      children: [
                        Positioned(
                          left: position.center.dx - length / 2,
                          top: position.center.dy - RulerOverlay.height / 2,
                          width: length,
                          height: RulerOverlay.height,
                          child: Transform.rotate(
                            angle: position.angle,
                            child: CustomPaint(
                              painter: _RulerPainter(
                                angle: position.angle,
                                // The page's own tokens: paper pages in
                                // Night too, black ones when inverted
                                colors: InnerCanvas.invertOf(context)
                                    ? HiganColors.night
                                    : HiganColors.paper,
                                textDirection: Directionality.of(context),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Sees scrolls before the canvas does, without taking its pointers
          Listener(behavior: .translucent, onPointerSignal: _onPointerSignal),
        ],
      ),
    );
  }
}

/// Whether Cmd or Ctrl is held, so scrolling zooms the canvas.
bool get _zoomKeyHeld =>
    HardwareKeyboard.instance.isMetaPressed ||
    HardwareKeyboard.instance.isControlPressed;

/// Claims touch, mouse and trackpad pointers that go down on the ruler,
/// before the canvas can pan or draw with them. A stylus isn't claimed,
/// so it draws on the canvas under the ruler; nor is a trackpad scroll
/// with Cmd or Ctrl held, which zooms the canvas.
class _RulerGestureRecognizer extends ScaleGestureRecognizer {
  new({required this.isOnRuler})
    : super(supportedDevices: const {.touch, .mouse, .trackpad});

  final bool Function(Offset localPosition) isOnRuler;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      super.isPointerAllowed(event) && isOnRuler(event.localPosition);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) =>
      !_zoomKeyHeld && isOnRuler(event.localPosition);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, .accepted);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    super.addAllowedPointerPanZoom(event);
    resolvePointer(event.pointer, .accepted);
  }
}

extension RulerSnapping on RulerPosition {
  Offset get _along => Offset(cos(angle), sin(angle));
  Offset get _across => Offset(-sin(angle), cos(angle));

  /// Whether [point] is on the ruler in an overlay of [size].
  bool contains(Offset point, Size size) =>
      _dot(point - center, _across).abs() <= RulerOverlay.height / 2 &&
      _dot(point - center, _along).abs() <= RulerOverlay.lengthFor(size) / 2;

  /// The edge (-1 or 1) that [point] is within [RulerOverlay.snapDistance]
  /// of, or null.
  int? edgeNear(Offset point) {
    final distance = _dot(point - center, _across);
    for (final edge in const [-1, 1]) {
      if ((distance - edge * RulerOverlay.height / 2).abs() <=
          RulerOverlay.snapDistance) {
        return edge;
      }
    }
    return null;
  }

  /// [point] moved onto [edge] (see [edgeNear]).
  Offset snap(Offset point, int edge) =>
      center +
      _across * (edge * RulerOverlay.height / 2) +
      _along * _dot(point - center, _along);

  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
}

/// A translucent glass bar with hairline ticks, and its angle in mono,
/// in the [colors] of the page under it.
class _RulerPainter extends CustomPainter {
  const new({
    required this.angle,
    required this.colors,
    required this.textDirection,
  });

  final double angle;
  final HiganColors colors;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = Offset.zero & size;
    // Glass, so the page and its ink show through
    canvas.drawRect(bar, Paint()..color = colors.bg.withValues(alpha: 0.4));
    // Edges that show on the page in Night and Paper
    final hairline = Paint()
      ..color = colors.textSecondary
      ..strokeWidth = 1;
    canvas.drawLine(bar.topLeft, bar.topRight, hairline);
    canvas.drawLine(bar.bottomLeft, bar.bottomRight, hairline);

    // Ticks every 10px from the middle, longer every 50px
    final tick = Paint()
      ..color = colors.textSecondary
      ..strokeWidth = 1;
    final middle = size.width / 2;
    for (var i = -(middle ~/ 10); i <= middle ~/ 10; i++) {
      final x = middle + i * 10;
      final long = i % 5 == 0;
      final length = long ? 14.0 : 7.0;
      canvas.drawLine(Offset(x, 0), Offset(x, length), tick);
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - length),
        tick,
      );
    }

    // e.g. "45°", measured like a protractor (anticlockwise)
    final degrees = (-angle * 180 / pi).round() % 180;
    final label = TextPainter(
      text: TextSpan(
        text: '$degrees°',
        style: TextStyle(
          fontFamily: HiganText.mono,
          fontSize: 12,
          letterSpacing: 1.2,
          color: colors.text,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    // On a small pill, so ink under the ruler doesn't run into it
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: label.width + 16,
        height: label.height + 6,
      ),
      const .circular(999),
    );
    canvas
      ..drawRRect(
        pill,
        Paint()..color = colors.surface2.withValues(alpha: 0.92),
      )
      ..drawRRect(
        pill,
        Paint()
          ..style = .stroke
          ..color = colors.hairlineStrong,
      );
    label.paint(
      canvas,
      Offset(middle - label.width / 2, (size.height - label.height) / 2),
    );
    label.dispose();
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) =>
      angle != oldDelegate.angle || colors != oldDelegate.colors;
}
