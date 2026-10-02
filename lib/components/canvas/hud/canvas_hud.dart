import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/canvas/hud/canvas_gesture_lock_btn.dart';
import 'package:nts/components/canvas/hud/canvas_zoom_indicator.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/extensions/matrix4_extensions.dart';
import 'package:nts/i18n/strings.g.dart';

class CanvasHud extends HookWidget {
  const new({
    super.key,
    required this.transformationController,
    required this.zoomLock,
    required this.setZoomLock,
    required this.resetZoom,
    required this.singleFingerPanLock,
    required this.setSingleFingerPanLock,
    required this.axisAlignedPanLock,
    required this.setAxisAlignedPanLock,
  });

  final TransformationController transformationController;
  final bool zoomLock;
  final ValueChanged<bool> setZoomLock;
  final VoidCallback? resetZoom;
  final bool singleFingerPanLock;
  final ValueChanged<bool> setSingleFingerPanLock;
  final bool axisAlignedPanLock;
  final ValueChanged<bool> setAxisAlignedPanLock;

  @override
  Widget build(BuildContext context) {
    /// The opacity of the HUD
    final opacity = useState(0.0);

    /// A timer to set the opacity to 0 after inactivity
    final hideTimer = useRef<Timer?>(null);
    useEffect(() {
      return () => hideTimer.value?.cancel();
    }, const []);

    void onTransform() {
      opacity.value = 1;
      hideTimer.value?.cancel();
      hideTimer.value = Timer(
        const Duration(seconds: 5),
        () => opacity.value = 0,
      );
    }

    useOnListenableChange(transformationController, onTransform);

    /// Shows the HUD while a mouse is over [child], without taking the
    /// canvas's pointers while it's hidden.
    Widget revealOnHover(Widget child) => MouseRegion(
      opaque: false,
      hitTestBehavior: .translucent,
      onEnter: (_) => onTransform(),
      onHover: (_) => onTransform(),
      child: IgnorePointer(ignoring: opacity.value < 0.5, child: child),
    );

    return AnimatedOpacity(
      opacity: opacity.value,
      duration: const Duration(milliseconds: 200),
      child: Stack(
        children: [
          Positioned(
            top: 5,
            left: 5,
            child: revealOnHover(
              // 8 apart, or touching 44px tap targets on touch screens
              Column(
                mainAxisSize: .min,
                spacing: HiganTap.isTouch(context) ? 0 : 8,
                children: [
                  CanvasGestureLockBtn(
                    lock: zoomLock,
                    setLock: setZoomLock,
                    icon: zoomLock ? Symbols.lock : Symbols.lock_open_right,
                    tooltip: zoomLock
                        ? t.editor.hud.unlockZoom
                        : t.editor.hud.lockZoom,
                  ),
                  CanvasGestureLockBtn(
                    lock: singleFingerPanLock,
                    setLock: setSingleFingerPanLock,
                    icon: singleFingerPanLock
                        ? Symbols.pinch
                        : Symbols.swipe_up,
                    tooltip: singleFingerPanLock
                        ? t.editor.hud.unlockSingleFingerPan
                        : t.editor.hud.lockSingleFingerPan,
                  ),
                  CanvasGestureLockBtn(
                    lock: axisAlignedPanLock,
                    setLock: setAxisAlignedPanLock,
                    tooltip: axisAlignedPanLock
                        ? t.editor.hud.unlockAxisAlignedPan
                        : t.editor.hud.lockAxisAlignedPan,
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: axisAlignedPanLock ? 0 : 1 / 8,
                      child: const Icon(Symbols.drag_pan),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: revealOnHover(
              AnimatedBuilder(
                animation: transformationController,
                builder: (context, _) => CanvasZoomIndicator(
                  scale: transformationController.value.approxScale,
                  resetZoom: resetZoom,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
