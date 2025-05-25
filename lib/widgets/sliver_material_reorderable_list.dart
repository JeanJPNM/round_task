import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Modified version of [ReorderableListView] that returns the inner [SliverReorderableList]
/// instead of wrapping it in a [CustomScrollView].
class SliverMaterialReorderableList extends StatefulWidget {
  SliverMaterialReorderableList({
    super.key,
    required List<Widget> children,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.proxyDecorator,
    this.buildDefaultDragHandles = true,
    this.scrollDirection = Axis.vertical,
    this.autoScrollerVelocityScalar,
    this.dragBoundaryProvider,
    this.mouseCursor,
  })  : assert(
          (itemExtent == null && prototypeItem == null) ||
              (itemExtent == null && itemExtentBuilder == null) ||
              (prototypeItem == null && itemExtentBuilder == null),
          'You can only pass one of itemExtent, prototypeItem and itemExtentBuilder.',
        ),
        assert(
          children.every((Widget w) => w.key != null),
          'All children of this widget must have a key.',
        ),
        itemBuilder = ((BuildContext context, int index) => children[index]),
        itemCount = children.length;

  /// Creates a reorderable list from widget items that are created on demand.
  ///
  /// This constructor is appropriate for list views with a large number of
  /// children because the builder is called only for those children
  /// that are actually visible.
  ///
  /// The `itemBuilder` callback will be called only with indices greater than
  /// or equal to zero and less than `itemCount`.
  ///
  /// The `itemBuilder` should always return a non-null widget, and actually
  /// create the widget instances when called. Avoid using a builder that
  /// returns a previously-constructed widget; if the list view's children are
  /// created in advance, or all at once when the [SliverMaterialReorderableList] itself
  /// is created, it is more efficient to use the [SliverMaterialReorderableList]
  /// constructor. Even more efficient, however, is to create the instances
  /// on demand using this constructor's `itemBuilder` callback.
  ///
  /// This example creates a list using the
  /// [ReorderableListView.builder] constructor. Using the [IndexedWidgetBuilder], The
  /// list items are built lazily on demand.
  /// {@tool dartpad}
  ///
  /// ** See code in examples/api/lib/material/reorderable_list/reorderable_list_view.reorderable_list_view_builder.0.dart **
  /// {@end-tool}
  /// See also:
  ///
  ///   * [SliverMaterialReorderableList], which allows you to build a reorderable
  ///     list with all the items passed into the constructor.
  const SliverMaterialReorderableList.builder({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.proxyDecorator,
    this.buildDefaultDragHandles = true,
    this.scrollDirection = Axis.vertical,
    this.autoScrollerVelocityScalar,
    this.dragBoundaryProvider,
    this.mouseCursor,
  })  : assert(itemCount >= 0),
        assert(
          (itemExtent == null && prototypeItem == null) ||
              (itemExtent == null && itemExtentBuilder == null) ||
              (prototypeItem == null && itemExtentBuilder == null),
          'You can only pass one of itemExtent, prototypeItem and itemExtentBuilder.',
        );

  /// {@macro flutter.widgets.reorderable_list.itemBuilder}
  final IndexedWidgetBuilder itemBuilder;

  /// {@macro flutter.widgets.reorderable_list.itemCount}
  final int itemCount;

  /// {@macro flutter.widgets.reorderable_list.onReorder}
  final ReorderCallback onReorder;

  /// {@macro flutter.widgets.reorderable_list.onReorderStart}
  final void Function(int index)? onReorderStart;

  /// {@macro flutter.widgets.reorderable_list.onReorderEnd}
  final void Function(int index)? onReorderEnd;

  /// {@macro flutter.widgets.reorderable_list.proxyDecorator}
  final ReorderItemProxyDecorator? proxyDecorator;

  /// If true: on desktop platforms, a drag handle is stacked over the
  /// center of each item's trailing edge; on mobile platforms, a long
  /// press anywhere on the item starts a drag.
  ///
  /// The default desktop drag handle is just an [Icons.drag_handle]
  /// wrapped by a [ReorderableDragStartListener]. On mobile
  /// platforms, the entire item is wrapped with a
  /// [ReorderableDelayedDragStartListener].
  ///
  /// To change the appearance or the layout of the drag handles, make
  /// this parameter false and wrap each list item, or a widget within
  /// each list item, with [ReorderableDragStartListener] or
  /// [ReorderableDelayedDragStartListener], or a custom subclass
  /// of [ReorderableDragStartListener].
  ///
  /// The following sample specifies `buildDefaultDragHandles: false`, and
  /// uses a [Card] at the leading edge of each item for the item's drag handle.
  ///
  /// {@tool dartpad}
  ///
  ///
  /// ** See code in examples/api/lib/material/reorderable_list/reorderable_list_view.build_default_drag_handles.0.dart **
  /// {@end-tool}
  final bool buildDefaultDragHandles;

  /// {@macro flutter.widgets.scroll_view.scrollDirection}
  final Axis scrollDirection;

  /// {@macro flutter.widgets.list_view.itemExtent}
  final double? itemExtent;

  /// {@macro flutter.widgets.list_view.itemExtentBuilder}
  final ItemExtentBuilder? itemExtentBuilder;

  /// {@macro flutter.widgets.list_view.prototypeItem}
  final Widget? prototypeItem;

  /// {@macro flutter.widgets.EdgeDraggingAutoScroller.velocityScalar}
  ///
  /// {@macro flutter.widgets.SliverReorderableList.autoScrollerVelocityScalar.default}
  final double? autoScrollerVelocityScalar;

  /// {@macro flutter.widgets.reorderable_list.dragBoundaryProvider}
  final ReorderDragBoundaryProvider? dragBoundaryProvider;

  /// The cursor for a mouse pointer when it enters or is hovering over the drag
  /// handle.
  ///
  /// If [mouseCursor] is a [WidgetStateMouseCursor],
  /// [WidgetStateProperty.resolve] is used for the following [WidgetState]s:
  ///
  ///  * [WidgetState.dragged].
  ///
  /// If this property is null, [SystemMouseCursors.grab] will be used when
  ///  hovering, and [SystemMouseCursors.grabbing] when dragging.
  final MouseCursor? mouseCursor;

  @override
  State<SliverMaterialReorderableList> createState() =>
      _SliverMaterialReorderableListState();
}

class _SliverMaterialReorderableListState
    extends State<SliverMaterialReorderableList> {
  final ValueNotifier<bool> _dragging = ValueNotifier<bool>(false);

  Widget _itemBuilder(BuildContext context, int index) {
    final Widget item = widget.itemBuilder(context, index);
    assert(() {
      if (item.key == null) {
        throw FlutterError(
            'Every item of ReorderableListView must have a key.');
      }
      return true;
    }());

    final Key itemGlobalKey =
        _SliverMaterialReorderableListChildGlobalKey(item.key!, this);

    if (widget.buildDefaultDragHandles) {
      switch (Theme.of(context).platform) {
        case TargetPlatform.linux:
        case TargetPlatform.windows:
        case TargetPlatform.macOS:
          final ListenableBuilder dragHandle = ListenableBuilder(
            listenable: _dragging,
            builder: (BuildContext context, Widget? child) {
              final MouseCursor effectiveMouseCursor =
                  WidgetStateProperty.resolveAs<MouseCursor>(
                widget.mouseCursor ??
                    const WidgetStateMouseCursor
                        .fromMap(<WidgetStatesConstraint, MouseCursor>{
                      WidgetState.dragged: SystemMouseCursors.grabbing,
                      WidgetState.any: SystemMouseCursors.grab,
                    }),
                <WidgetState>{if (_dragging.value) WidgetState.dragged},
              );
              return MouseRegion(cursor: effectiveMouseCursor, child: child);
            },
            child: const Icon(Icons.drag_handle),
          );
          switch (widget.scrollDirection) {
            case Axis.horizontal:
              return Stack(
                key: itemGlobalKey,
                children: <Widget>[
                  item,
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    start: 0,
                    end: 0,
                    bottom: 8,
                    child: Align(
                      alignment: AlignmentDirectional.bottomCenter,
                      child: ReorderableDragStartListener(
                          index: index, child: dragHandle),
                    ),
                  ),
                ],
              );
            case Axis.vertical:
              return Stack(
                key: itemGlobalKey,
                children: <Widget>[
                  item,
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    top: 0,
                    bottom: 0,
                    end: 8,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: ReorderableDragStartListener(
                          index: index, child: dragHandle),
                    ),
                  ),
                ],
              );
          }

        case TargetPlatform.iOS:
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          return ReorderableDelayedDragStartListener(
              key: itemGlobalKey, index: index, child: item);
      }
    }

    return KeyedSubtree(key: itemGlobalKey, child: item);
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = lerpDouble(0, 6, animValue)!;
        return Material(elevation: elevation, child: child);
      },
      child: child,
    );
  }

  @override
  void dispose() {
    _dragging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasOverlay(context));

    return SliverReorderableList(
      itemBuilder: _itemBuilder,
      itemExtent: widget.itemExtent,
      itemExtentBuilder: widget.itemExtentBuilder,
      prototypeItem: widget.prototypeItem,
      itemCount: widget.itemCount,
      onReorder: widget.onReorder,
      onReorderStart: (int index) {
        _dragging.value = true;
        widget.onReorderStart?.call(index);
      },
      onReorderEnd: (int index) {
        _dragging.value = false;
        widget.onReorderEnd?.call(index);
      },
      proxyDecorator: widget.proxyDecorator ?? _proxyDecorator,
      autoScrollerVelocityScalar: widget.autoScrollerVelocityScalar,
      dragBoundaryProvider: widget.dragBoundaryProvider,
    );
  }
}

// A global key that takes its identity from the object and uses a value of a
// particular type to identify itself.
//
// The difference with GlobalObjectKey is that it uses [==] instead of [identical]
// of the objects used to generate widgets.
@optionalTypeArgs
class _SliverMaterialReorderableListChildGlobalKey extends GlobalObjectKey {
  const _SliverMaterialReorderableListChildGlobalKey(this.subKey, this.state)
      : super(subKey);

  final Key subKey;
  final State state;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _SliverMaterialReorderableListChildGlobalKey &&
        other.subKey == subKey &&
        other.state == state;
  }

  @override
  int get hashCode => Object.hash(subKey, state);
}
