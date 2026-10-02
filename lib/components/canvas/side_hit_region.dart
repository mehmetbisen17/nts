import 'package:collection/collection.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lets things beside a page (e.g. images in its side areas) be touched,
/// although they're outside the page's bounds, which normally stop
/// touches from reaching them.
///
/// Put this around the canvas, and [SideHittable] around such things.
/// Unlike defer_pointer's own handler, the canvas still gets the pointer
/// too, so a pinch or a scroll can start on an image.
class SideHitRegion extends StatefulWidget {
  const new({super.key, required this.child});

  final Widget child;

  /// The nearest region's link, or null outside one (e.g. in exports).
  static DeferredPointerHandlerLink? linkOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SideHitScope>()?.link;

  @override
  State<SideHitRegion> createState() => _SideHitRegionState();
}

class _SideHitRegionState extends State<SideHitRegion> {
  final link = DeferredPointerHandlerLink();

  @override
  void dispose() {
    link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SideHitScope(
    link: link,
    child: _SideHitTarget(link: link, child: widget.child),
  );
}

/// [child], touchable anywhere inside the nearest [SideHitRegion].
class SideHittable extends StatelessWidget {
  const new({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => switch (SideHitRegion.linkOf(context)) {
    final link? => DeferPointer(link: link, child: child),
    null => child,
  };
}

class _SideHitScope extends InheritedWidget {
  const new({required this.link, required super.child});

  final DeferredPointerHandlerLink link;

  @override
  bool updateShouldNotify(_SideHitScope oldWidget) => link != oldWidget.link;
}

class _SideHitTarget extends SingleChildRenderObjectWidget {
  const new({required this.link, required super.child});

  final DeferredPointerHandlerLink link;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSideHitTarget(link);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSideHitTarget renderObject,
  ) => renderObject.link = link;
}

class _RenderSideHitTarget extends RenderProxyBox {
  new(this.link);

  DeferredPointerHandlerLink link;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    // The topmost deferred thing under the pointer, then the canvas.
    // Deeper ones first (an image's handles before the image), then the
    // ones added last (usually painted last, so on top).
    final candidates = [
      for (final deferred in link.painters.reversed)
        if (deferred.child case final child?
            when child.attached && child.hasSize)
          child,
    ];
    mergeSort(candidates, compare: (a, b) => b.depth.compareTo(a.depth));
    for (final child in candidates) {
      final hit = result.addWithPaintTransform(
        transform: child.getTransformTo(this),
        position: position,
        hitTest: (result, position) =>
            child.hitTest(result, position: position),
      );
      if (hit) {
        super.hitTestChildren(result, position: position);
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }
    return super.hitTest(result, position: position);
  }
}
