import 'dart:math';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nts/components/canvas/canvas_image_dialog.dart';
import 'package:nts/components/canvas/image/editor_image.dart';
import 'package:nts/components/canvas/inner_canvas.dart';
import 'package:nts/components/canvas/side_hit_region.dart';
import 'package:nts/components/theming/adaptive_alert_dialog.dart';
import 'package:nts/data/editor/page.dart';
import 'package:nts/data/extensions/change_notifier_extensions.dart';
import 'package:nts/i18n/strings.g.dart';

class CanvasImage extends StatefulHookWidget {
  new({
    required this.filePath,
    required this.image,
    this.overrideBoxFit,
    required this.pageSize,
    required this.setAsBackground,
    this.isBackground = false,
    this.readOnly = false,
    this.selected = false,
  }) : super(key: Key('CanvasImage$filePath/${image.id}'));

  /// The path to the note that this image is in.
  final String filePath;
  final EditorImage image;
  final BoxFit? overrideBoxFit;
  final Size pageSize;
  final void Function(EditorImage image)? setAsBackground;
  final bool isBackground;
  final bool readOnly;
  final bool selected;

  /// When notified, all [CanvasImages] will have their [active] property set to false.
  static var activeListener = ChangeNotifier();

  /// The minimum size of the interactive area for the image.
  static double minInteractiveSize = 50;

  /// The minimum size of the image itself, inside of the interactive area.
  static double minImageSize = 10;

  @override
  State<CanvasImage> createState() => _CanvasImageState();
}

class _CanvasImageState extends State<CanvasImage> {
  var _active = false;

  /// Whether this image can be dragged
  bool get active => _active;
  set active(bool value) {
    if (active == value) return;

    if (value) {
      CanvasImage.activeListener
          .notifyListenersPlease(); // de-activate all other images
    }

    _active = value;
    // For Delete and Escape (see [_onKey])
    if (value) {
      _focusNode.requestFocus();
    } else if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }

    if (mounted) {
      try {
        setState(() {});
      } catch (e) {
        // setState throws error if widget is currently building
      }
    }
  }

  Brightness imageBrightness = .light;

  final _focusNode = FocusNode(debugLabel: 'CanvasImage', skipTraversal: true);

  /// Delete or Backspace deletes the active image, Escape deselects it.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!active || event is KeyUpEvent) return .ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.delete || LogicalKeyboardKey.backspace:
        final onDelete = widget.image.onDeleteImage;
        if (onDelete == null) return .ignored;
        active = false;
        onDelete(widget.image);
      case LogicalKeyboardKey.escape:
        active = false;
      default:
        return .ignored;
    }
    return .handled;
  }

  Rect panStartRect = .zero;
  Offset panStartPosition = .zero;

  /// Moving it by pressing and holding, and where the finger was last.
  var _pressDragging = false;
  var _pressLast = Offset.zero;

  /// Moves it by [delta], on the page or into the space beside it.
  void _moveBy(Offset delta) => setState(() {
    final fivePercent = min(
      widget.pageSize.width * 0.05,
      widget.pageSize.height * 0.05,
    );
    final side = EditorPage.sideWidthOf(widget.pageSize);
    final rect = widget.image.dstRect;
    widget.image.dstRect = .fromLTWH(
      (rect.left + delta.dx)
          .clamp(
            fivePercent - side - rect.width,
            widget.pageSize.width + side - fivePercent,
          )
          .toDouble(),
      (rect.top + delta.dy)
          .clamp(
            fivePercent - rect.height,
            widget.pageSize.height - fivePercent,
          )
          .toDouble(),
      rect.width,
      rect.height,
    );
  });

  /// Records a move (for undo) once it's done.
  void _endMove() {
    if (panStartRect == widget.image.dstRect) return;
    widget.image.onMoveImage?.call(
      widget.image,
      .fromLTRB(
        widget.image.dstRect.left - panStartRect.left,
        widget.image.dstRect.top - panStartRect.top,
        widget.image.dstRect.right - panStartRect.right,
        widget.image.dstRect.bottom - panStartRect.bottom,
      ),
    );
    panStartRect = .zero;
  }

  @override
  void initState() {
    widget.image.loadIn();

    if (widget.image.newImage) {
      // if the image is new, make it [active]
      active = true;
      widget.image.newImage = false;
    }

    CanvasImage.activeListener.addListener(disableActive);

    super.initState();
  }

  void disableActive() {
    active = false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);

    useListenable(widget.image);
    if (widget.readOnly) active = false;

    imageBrightness = widget.image.invertible && InnerCanvas.invertOf(context)
        ? .dark
        : .light;

    final Widget unpositioned = SideHittable(
      child: IgnorePointer(
        ignoring: widget.readOnly,
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: _onKey,
          child: Stack(
            fit: StackFit.expand,
            // The handles stick out past its corners
            clipBehavior: .none,
            children: [
              MouseRegion(
                cursor: active ? SystemMouseCursors.grab : MouseCursor.defer,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // Control-click is a right-click on a Mac
                    if (defaultTargetPlatform == .macOS &&
                        HardwareKeyboard.instance.isControlPressed) {
                      active = true;
                      return showModal();
                    }
                    active = !active;
                  },
                  // Its menu, once it's selected
                  onLongPress: active && !_pressDragging ? showModal : null,
                  // Like a right-click in Finder: select it, then its menu
                  onSecondaryTap: () {
                    active = true;
                    showModal();
                  },
                  // Once selected (tapped, or just added), a drag moves it,
                  // following the finger from where it went down. Until
                  // then drags go to the canvas (scrolling, pinching, the
                  // lasso, moving a selection it's part of)
                  dragStartBehavior: .down,
                  onPanStart: active
                      ? (details) => panStartRect = widget.image.dstRect
                      : null,
                  onPanUpdate: active
                      ? (details) => _moveBy(details.delta)
                      : null,
                  onPanEnd: active ? (details) => _endMove() : null,
                  // Not selected: press and hold it, then drag. (Kept until
                  // the press ends, though holding selects it.)
                  onLongPressStart: !active || _pressDragging
                      ? (details) {
                          _pressDragging = true;
                          _pressLast = details.localPosition;
                          panStartRect = widget.image.dstRect;
                          active = true;
                        }
                      : null,
                  onLongPressMoveUpdate: !active || _pressDragging
                      ? (details) {
                          _moveBy(details.localPosition - _pressLast);
                          _pressLast = details.localPosition;
                        }
                      : null,
                  onLongPressEnd: !active || _pressDragging
                      ? (details) {
                          _pressDragging = false;
                          _endMove();
                        }
                      : null,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: active
                            ? colorScheme.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: widget.isBackground
                            ? widget.pageSize.width
                            : max(
                                widget.image.dstRect.width,
                                CanvasImage.minImageSize,
                              ),
                        height: widget.isBackground
                            ? widget.pageSize.height
                            : max(
                                widget.image.dstRect.height,
                                CanvasImage.minImageSize,
                              ),
                        child: SizedOverflowBox(
                          size: widget.image.srcRect.size,
                          child: Transform.translate(
                            offset: -widget.image.srcRect.topLeft,
                            child: widget.image.buildImageWidget(
                              context: context,
                              overrideBoxFit: widget.overrideBoxFit,
                              isBackground: widget.isBackground,
                              invert: imageBrightness == .dark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.selected) // tint image if selected
                ColoredBox(color: colorScheme.primary.withValues(alpha: 0.5)),
              if (!widget.readOnly)
                for (double x = -20; x <= 20; x += 20)
                  for (double y = -20; y <= 20; y += 20)
                    if (x != 0 || y != 0) // ignore (0,0)
                      _CanvasImageResizeHandle(
                        active: active,
                        position: Offset(x, y),
                        image: widget.image,
                        parent: this,
                        afterDrag: () => setState(() {}),
                      ),
            ],
          ),
        ),
      ),
    );

    if (widget.isBackground) {
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastLinearToSlowEaseIn,
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
        child: unpositioned,
      );
    }
    return AnimatedPositioned(
      // no animation if the image is being dragged or it's selected
      duration: (panStartRect != .zero || widget.selected)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.fastLinearToSlowEaseIn,

      left: widget.image.dstRect.left,
      top: widget.image.dstRect.top,
      width: max(widget.image.dstRect.width, CanvasImage.minInteractiveSize),
      height: max(widget.image.dstRect.height, CanvasImage.minInteractiveSize),

      child: unpositioned,
    );
  }

  @override
  void dispose() {
    widget.image.loadOut();
    CanvasImage.activeListener.removeListener(disableActive);
    _focusNode.dispose();
    super.dispose();
  }

  void showModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AdaptiveAlertDialog(
          title: Text(t.editor.imageOptions.title),
          content: CanvasImageDialog(
            filePath: widget.filePath,
            image: widget.image,
            redrawImage: () => setState(() {}),
            isBackground: false,
            toggleAsBackground: () {
              widget.setAsBackground?.call(widget.image);
            },
          ),
          actions: const [],
        );
      },
    );
  }
}

class _CanvasImageResizeHandle extends StatelessWidget {
  const new({
    required this.active,
    required this.position,
    required this.image,
    required this.parent,
    required this.afterDrag,
  });

  final bool active;
  final Offset position;
  final EditorImage image;
  final _CanvasImageState parent;
  final void Function() afterDrag;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Positioned(
      left: (position.dx.sign + 1) / 2 * image.dstRect.width - 20,
      top: (position.dy.sign + 1) / 2 * image.dstRect.height - 20,
      // Beside the page, the side region handles touches (see
      // [SideHittable]), and they're painted in place
      child: DeferPointer(
        link: SideHitRegion.linkOf(context),
        paintOnTop: SideHitRegion.linkOf(context) == null,
        child: MouseRegion(
          cursor: () {
            if (!active) return MouseCursor.defer;

            if (position.dx == 0) return SystemMouseCursors.resizeUpDown;
            if (position.dy == 0) return SystemMouseCursors.resizeLeftRight;

            // A Mac has no diagonal resize cursors, like the lasso's handles
            if (defaultTargetPlatform == .macOS) {
              return SystemMouseCursors.grab;
            }
            if (position.dx < 0 && position.dy < 0)
              return SystemMouseCursors.resizeUpLeft;
            if (position.dx < 0 && position.dy > 0)
              return SystemMouseCursors.resizeDownLeft;
            if (position.dx > 0 && position.dy < 0)
              return SystemMouseCursors.resizeUpRight;
            if (position.dx > 0 && position.dy > 0)
              return SystemMouseCursors.resizeDownRight;

            return MouseCursor.defer;
          }(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: active
                ? (details) {
                    parent.panStartRect = parent.widget.image.dstRect;
                    parent.panStartPosition = details.localPosition;
                  }
                : null,
            onPanUpdate: active
                ? (details) {
                    final Offset delta =
                        details.localPosition - parent.panStartPosition;

                    double newWidth;
                    if (position.dx < 0) {
                      newWidth = parent.panStartRect.width - delta.dx;
                    } else if (position.dx > 0) {
                      newWidth = parent.panStartRect.width + delta.dx;
                    } else {
                      newWidth = parent.panStartRect.width;
                    }

                    double newHeight;
                    if (position.dy < 0) {
                      newHeight = parent.panStartRect.height - delta.dy;
                    } else if (position.dy > 0) {
                      newHeight = parent.panStartRect.height + delta.dy;
                    } else {
                      newHeight = parent.panStartRect.height;
                    }

                    if (newWidth <= 0 || newHeight <= 0) return;

                    // preserve aspect ratio if diagonal
                    if (position.dx != 0 && position.dy != 0) {
                      // if diagonal
                      final aspectRatio =
                          image.dstRect.width / image.dstRect.height;
                      if (newWidth / newHeight > aspectRatio) {
                        newHeight = newWidth / aspectRatio;
                      } else {
                        newWidth = newHeight * aspectRatio;
                      }
                    }

                    // resize from the correct corner
                    double left = image.dstRect.left, top = image.dstRect.top;
                    if (position.dx < 0) {
                      left = image.dstRect.right - newWidth;
                    }
                    if (position.dy < 0) {
                      top = image.dstRect.bottom - newHeight;
                    }

                    image.dstRect = .fromLTWH(left, top, newWidth, newHeight);
                    afterDrag();
                  }
                : null,
            onPanEnd: active
                ? (details) {
                    if (parent.panStartRect == image.dstRect) return;
                    image.onMoveImage?.call(
                      image,
                      .fromLTRB(
                        image.dstRect.left - parent.panStartRect.left,
                        image.dstRect.top - parent.panStartRect.top,
                        image.dstRect.right - parent.panStartRect.right,
                        image.dstRect.bottom - parent.panStartRect.bottom,
                      ),
                    );
                    parent.panStartRect = .zero;
                  }
                : null,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 100),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface,
                  shape: .circle,
                  border: Border.all(color: colorScheme.surface, width: 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
