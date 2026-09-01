import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

const double _kDefaultHorizontalPadding = 12.0;

/// A dropdown choice selector that uses a [FilledButton.tonal] as its anchor widget.
///
/// Similar to [DropdownMenuChip], this component is a modified version of [DropdownMenu]
/// that replaces the text field with a tonal filled button, displaying the currently selected choice.
///
/// The menu is composed of a list of [DropdownMenuEntry]s. When the user taps the button or uses
/// keyboard navigation (up/down arrow keys, enter), the menu opens and allows selecting an item.
class DropdownMenuButton<T> extends StatefulWidget {
  /// Creates a [DropdownMenuButton].
  const DropdownMenuButton({
    super.key,
    this.enabled = true,
    this.leadingIcon,
    this.trailingIcon,
    this.showTrailingIcon = true,
    this.selectedTrailingIcon,
    this.style,
    this.menuStyle,
    this.initialSelection,
    this.onSelected,
    this.expandedInsets,
    this.alignmentOffset,
    required this.dropdownMenuEntries,
    this.closeBehavior = DropdownMenuCloseBehavior.all,
    this.focusNode,
    this.autofocus = false,
  });

  /// Determine if the [DropdownMenuButton] is enabled.
  ///
  /// Defaults to true.
  final bool enabled;

  /// An optional leading icon placed before the label in the button.
  final Widget? leadingIcon;

  /// An optional trailing icon placed after the label in the button.
  ///
  /// Defaults to an [Icon] with [Icons.arrow_drop_down].
  ///
  /// If [showTrailingIcon] is false, the trailing icon will not be shown.
  final Widget? trailingIcon;

  /// Specifies if the [DropdownMenuButton] should show a trailing icon.
  ///
  /// Defaults to true.
  final bool showTrailingIcon;

  /// An optional icon displayed when the dropdown menu is open.
  ///
  /// Defaults to an [Icon] with [Icons.arrow_drop_up].
  final Widget? selectedTrailingIcon;

  /// The [ButtonStyle] that defines the visual attributes of the tonal filled button.
  final ButtonStyle? style;

  /// The [MenuStyle] that defines the visual attributes of the dropdown menu.
  final MenuStyle? menuStyle;

  /// The value used for the initial selection.
  final T? initialSelection;

  /// The callback called when a selection is made.
  final ValueChanged<T?>? onSelected;

  /// Descriptions of the menu items in the [DropdownMenuButton].
  final List<DropdownMenuEntry<T>> dropdownMenuEntries;

  /// Defines the button's width to match its parent's width plus horizontal insets.
  final EdgeInsetsGeometry? expandedInsets;

  /// Offset applied to the menu position relative to the anchor.
  final Offset? alignmentOffset;

  /// Defines the behavior for closing the dropdown menu when an item is selected.
  ///
  /// Defaults to [DropdownMenuCloseBehavior.all].
  final DropdownMenuCloseBehavior closeBehavior;

  /// Defines the keyboard focus for this widget.
  final FocusNode? focusNode;

  /// Whether this button should focus itself automatically.
  ///
  /// Defaults to false.
  final bool autofocus;

  @override
  State<DropdownMenuButton<T>> createState() => _DropdownMenuButtonState<T>();
}

class _DropdownMenuButtonState<T> extends State<DropdownMenuButton<T>> {
  final GlobalKey _anchorKey = GlobalKey();
  late List<GlobalKey> buttonItemKeys;
  final MenuController _controller = MenuController();
  List<Widget>? _initialMenu;
  int? currentHighlight;
  double? leadingPadding;
  bool _menuHasEnabledItem = false;
  String _label = '';
  final FocusNode _internalFocusNode = FocusNode();
  int? _selectedEntryIndex;

  @override
  void initState() {
    super.initState();
    final entries = widget.dropdownMenuEntries;
    buttonItemKeys = List<GlobalKey>.generate(
      entries.length,
      (int index) => GlobalKey(),
    );
    _menuHasEnabledItem = entries.any(
      (DropdownMenuEntry<T> entry) => entry.enabled,
    );
    final int index = entries.indexWhere(
      (DropdownMenuEntry<T> entry) => entry.value == widget.initialSelection,
    );
    if (index != -1) {
      _label = entries[index].label;
      _selectedEntryIndex = index;
    }
  }

  @override
  void dispose() {
    _internalFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DropdownMenuButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.dropdownMenuEntries != widget.dropdownMenuEntries) {
      currentHighlight = null;
      final entries = widget.dropdownMenuEntries;
      buttonItemKeys = List<GlobalKey>.generate(
        entries.length,
        (int index) => GlobalKey(),
      );
      _menuHasEnabledItem = entries.any(
        (DropdownMenuEntry<T> entry) => entry.enabled,
      );
      if (_selectedEntryIndex != null) {
        final T oldSelectionValue =
            oldWidget.dropdownMenuEntries[_selectedEntryIndex!].value;
        final int index = entries.indexWhere(
          (DropdownMenuEntry<T> entry) => entry.value == oldSelectionValue,
        );
        if (index != -1) {
          _label = entries[index].label;
          _selectedEntryIndex = index;
        } else {
          _selectedEntryIndex = null;
          _label = '';
        }
      }
    }

    if (oldWidget.initialSelection != widget.initialSelection) {
      final entries = widget.dropdownMenuEntries;
      final int index = entries.indexWhere(
        (DropdownMenuEntry<T> entry) => entry.value == widget.initialSelection,
      );

      if (index != -1) {
        _label = entries[index].label;
        _selectedEntryIndex = index;
      } else {
        _label = '';
        _selectedEntryIndex = null;
      }
    }
  }

  double? getWidth(GlobalKey key) {
    final BuildContext? context = key.currentContext;
    if (context != null) {
      final RenderBox box = context.findRenderObject()! as RenderBox;
      return box.hasSize ? box.size.width : null;
    }
    return null;
  }

  List<Widget> _buildButtons(
    List<DropdownMenuEntry<T>> filteredEntries,
    TextDirection textDirection, {
    int? focusedIndex,
    bool enableScrollToHighlight = true,
    bool excludeSemantics = false,
  }) {
    final List<Widget> result = <Widget>[];
    for (int i = 0; i < filteredEntries.length; i++) {
      final DropdownMenuEntry<T> entry = filteredEntries[i];

      final double padding = entry.leadingIcon == null
          ? (leadingPadding ?? _kDefaultHorizontalPadding)
          : _kDefaultHorizontalPadding;
      ButtonStyle effectiveStyle =
          entry.style ??
          MenuItemButton.styleFrom(
            padding: EdgeInsetsDirectional.only(
              start: padding,
              end: _kDefaultHorizontalPadding,
            ),
          );

      final ButtonStyle? themeStyle = MenuButtonTheme.of(context).style;

      final WidgetStateProperty<Color?>? effectiveForegroundColor =
          entry.style?.foregroundColor ?? themeStyle?.foregroundColor;
      final WidgetStateProperty<Color?>? effectiveIconColor =
          entry.style?.iconColor ?? themeStyle?.iconColor;
      final WidgetStateProperty<Color?>? effectiveOverlayColor =
          entry.style?.overlayColor ?? themeStyle?.overlayColor;
      final WidgetStateProperty<Color?>? effectiveBackgroundColor =
          entry.style?.backgroundColor ?? themeStyle?.backgroundColor;

      if (entry.enabled && i == focusedIndex) {
        final ButtonStyle defaultStyle = const MenuItemButton().defaultStyleOf(
          context,
        );

        Color? resolveFocusedColor(
          WidgetStateProperty<Color?>? colorStateProperty,
        ) {
          return colorStateProperty?.resolve(const {WidgetState.focused});
        }

        final Color focusedForegroundColor = resolveFocusedColor(
          effectiveForegroundColor ?? defaultStyle.foregroundColor!,
        )!;
        final Color focusedIconColor = resolveFocusedColor(
          effectiveIconColor ?? defaultStyle.iconColor!,
        )!;
        final Color focusedOverlayColor = resolveFocusedColor(
          effectiveOverlayColor ?? defaultStyle.overlayColor!,
        )!;
        final Color focusedBackgroundColor =
            resolveFocusedColor(effectiveBackgroundColor) ??
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);

        effectiveStyle = effectiveStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll<Color>(
            focusedBackgroundColor,
          ),
          foregroundColor: WidgetStatePropertyAll<Color>(
            focusedForegroundColor,
          ),
          iconColor: WidgetStatePropertyAll<Color>(focusedIconColor),
          overlayColor: WidgetStatePropertyAll<Color>(focusedOverlayColor),
        );
      } else {
        effectiveStyle = effectiveStyle.copyWith(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveForegroundColor,
          iconColor: effectiveIconColor,
          overlayColor: effectiveOverlayColor,
        );
      }

      final Widget label = entry.labelWidget ?? Text(entry.label);

      final Widget menuItemButton = ExcludeSemantics(
        excluding: excludeSemantics,
        child: MenuItemButton(
          key: enableScrollToHighlight ? buttonItemKeys[i] : null,
          style: effectiveStyle,
          leadingIcon: entry.leadingIcon,
          trailingIcon: entry.trailingIcon,
          closeOnActivate:
              widget.closeBehavior == DropdownMenuCloseBehavior.all,
          onPressed: entry.enabled && widget.enabled
              ? () {
                  if (!mounted) {
                    _label = entry.label;
                    widget.onSelected?.call(entry.value);
                    return;
                  }

                  _label = entry.label;
                  _selectedEntryIndex = i;
                  currentHighlight = null;
                  widget.onSelected?.call(entry.value);
                  if (widget.closeBehavior == DropdownMenuCloseBehavior.self) {
                    _controller.close();
                  }
                  setState(() {});
                }
              : null,
          requestFocusOnHover: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 0.0),
            child: label,
          ),
        ),
      );
      result.add(menuItemButton);
    }

    return result;
  }

  void handleUpKeyInvoke(_ArrowUpIntent _) {
    setState(() {
      if (!widget.enabled || !_menuHasEnabledItem || !_controller.isOpen) {
        return;
      }
      final entries = widget.dropdownMenuEntries;
      currentHighlight ??= 0;
      currentHighlight = (currentHighlight! - 1) % entries.length;
      while (!entries[currentHighlight!].enabled) {
        currentHighlight = (currentHighlight! - 1) % entries.length;
      }
      final String currentLabel = entries[currentHighlight!].label;
      _label = currentLabel;
    });
  }

  void handleDownKeyInvoke(_ArrowDownIntent _) {
    setState(() {
      if (!widget.enabled || !_menuHasEnabledItem || !_controller.isOpen) {
        return;
      }
      final entries = widget.dropdownMenuEntries;
      currentHighlight ??= -1;
      currentHighlight = (currentHighlight! + 1) % entries.length;
      while (!entries[currentHighlight!].enabled) {
        currentHighlight = (currentHighlight! + 1) % entries.length;
      }
      final String currentLabel = entries[currentHighlight!].label;
      _label = currentLabel;
    });
  }

  void handlePressed(MenuController controller) {
    if (controller.isOpen) {
      currentHighlight = null;
      controller.close();
    } else {
      controller.open();
    }
    setState(() {});
  }

  void _handleEditingComplete() {
    if (currentHighlight != null) {
      final DropdownMenuEntry<T> entry =
          widget.dropdownMenuEntries[currentHighlight!];
      if (entry.enabled) {
        setState(() {
          _label = entry.label;
          _selectedEntryIndex = currentHighlight;
        });
        widget.onSelected?.call(entry.value);
      }
    } else {
      if (_controller.isOpen) {
        widget.onSelected?.call(null);
      }
    }
    currentHighlight = null;

    _controller.close();
  }

  @override
  Widget build(BuildContext context) {
    final TextDirection textDirection = Directionality.of(context);
    _initialMenu ??= _buildButtons(
      widget.dropdownMenuEntries,
      textDirection,
      enableScrollToHighlight: false,
      excludeSemantics: true,
    );
    final ThemeData themeData = Theme.of(context);
    final ColorScheme colorScheme = themeData.colorScheme;
    final ButtonStyle? filledButtonThemeStyle =
        FilledButtonTheme.of(context).style;
    final Color defaultButtonBackgroundColor =
        widget.style?.backgroundColor?.resolve({}) ??
        filledButtonThemeStyle?.backgroundColor?.resolve({}) ??
        colorScheme.secondaryContainer;

    final DropdownMenuThemeData defaults = _DropdownMenuDefaultsM3(
      context,
      buttonBackgroundColor: defaultButtonBackgroundColor,
    );
    final entries = widget.dropdownMenuEntries;
    _menuHasEnabledItem = entries.any(
      (DropdownMenuEntry<T> entry) => entry.enabled,
    );

    final List<Widget> menu = _buildButtons(
      entries,
      textDirection,
      focusedIndex: currentHighlight,
    );

    final DropdownMenuThemeData dropdownTheme = DropdownMenuTheme.of(context);
    MenuStyle effectiveMenuStyle =
        widget.menuStyle ?? dropdownTheme.menuStyle ?? defaults.menuStyle!;

    if (effectiveMenuStyle.backgroundColor == null) {
      effectiveMenuStyle = effectiveMenuStyle.copyWith(
        backgroundColor: WidgetStatePropertyAll<Color?>(
          defaultButtonBackgroundColor,
        ),
      );
    }

    if (effectiveMenuStyle.surfaceTintColor == null) {
      effectiveMenuStyle = effectiveMenuStyle.copyWith(
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      );
    }

    final double? anchorWidth = getWidth(_anchorKey);
    if (anchorWidth != null) {
      effectiveMenuStyle = effectiveMenuStyle.copyWith(
        minimumSize: WidgetStateProperty.resolveWith<Size?>((
          Set<WidgetState> states,
        ) {
          final double? effectiveMaximumWidth = effectiveMenuStyle.maximumSize
              ?.resolve(states)
              ?.width;
          return Size(math.min(anchorWidth, effectiveMaximumWidth ?? 0.0), 0.0);
        }),
      );
    }

    Widget menuAnchor = MenuAnchor(
      style: effectiveMenuStyle,
      alignmentOffset: widget.alignmentOffset,
      controller: _controller,
      menuChildren: menu,
      crossAxisUnconstrained: false,
      animated: true,
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            assert(_initialMenu != null);

            final Widget trailingButton = switch ((
              widget.showTrailingIcon,
              controller.isOpen,
            )) {
              (false, _) => const SizedBox.shrink(),
              (true, true) =>
                widget.selectedTrailingIcon ?? const Icon(Icons.arrow_drop_up),
              (true, false) =>
                widget.trailingIcon ?? const Icon(Icons.arrow_drop_down),
            };

            final Widget buttonContent = widget.expandedInsets != null
                ? Text(_label)
                : _DropdownMenuBody(
                    children: <Widget>[
                      Text(_label),
                      for (final entry in widget.dropdownMenuEntries)
                        ExcludeSemantics(child: Text(entry.label)),
                    ],
                  );

            final Widget filledButton = FilledButton.tonal(
              key: _anchorKey,
              style: widget.style,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              onPressed: !widget.enabled
                  ? null
                  : () => handlePressed(controller),
              child: Row(
                mainAxisSize: widget.expandedInsets != null
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.leadingIcon != null) ...[
                    widget.leadingIcon!,
                    const SizedBox(width: 8.0),
                  ],
                  if (widget.expandedInsets != null)
                    Expanded(child: buttonContent)
                  else
                    buttonContent,
                  if (widget.showTrailingIcon) ...[
                    const SizedBox(width: 8.0),
                    trailingButton,
                  ],
                ],
              ),
            );

            final Widget body = filledButton;

            return Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(
                  LogicalKeyboardKey.arrowLeft,
                ): ExtendSelectionByCharacterIntent(
                  forward: false,
                  collapseSelection: true,
                ),
                SingleActivator(
                  LogicalKeyboardKey.arrowRight,
                ): ExtendSelectionByCharacterIntent(
                  forward: true,
                  collapseSelection: true,
                ),
                SingleActivator(LogicalKeyboardKey.arrowUp): _ArrowUpIntent(),
                SingleActivator(LogicalKeyboardKey.arrowDown):
                    _ArrowDownIntent(),
              },
              child: body,
            );
          },
    );

    if (widget.expandedInsets case final EdgeInsetsGeometry padding) {
      menuAnchor = Padding(
        padding: padding.clamp(
          EdgeInsets.zero,
          const EdgeInsets.only(
            left: double.infinity,
            right: double.infinity,
          ).add(
            const EdgeInsetsDirectional.only(
              end: double.infinity,
              start: double.infinity,
            ),
          ),
        ),
        child: menuAnchor,
      );
    }

    menuAnchor = Align(
      alignment: AlignmentDirectional.topStart,
      widthFactor: 1.0,
      heightFactor: 1.0,
      child: menuAnchor,
    );

    return Actions(
      actions: <Type, Action<Intent>>{
        _ArrowUpIntent: CallbackAction<_ArrowUpIntent>(
          onInvoke: handleUpKeyInvoke,
        ),
        _ArrowDownIntent: CallbackAction<_ArrowDownIntent>(
          onInvoke: handleDownKeyInvoke,
        ),
        _EnterIntent: CallbackAction<_EnterIntent>(
          onInvoke: (_) => _handleEditingComplete(),
        ),
      },
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.arrowUp): _ArrowUpIntent(),
              SingleActivator(LogicalKeyboardKey.arrowDown): _ArrowDownIntent(),
              SingleActivator(LogicalKeyboardKey.enter): _EnterIntent(),
            },
            child: Focus(
              focusNode: _internalFocusNode,
              skipTraversal: true,
              child: const SizedBox.shrink(),
            ),
          ),
          menuAnchor,
        ],
      ),
    );
  }
}

class _ArrowUpIntent extends Intent {
  const _ArrowUpIntent();
}

class _ArrowDownIntent extends Intent {
  const _ArrowDownIntent();
}

class _EnterIntent extends Intent {
  const _EnterIntent();
}

class _DropdownMenuBody extends MultiChildRenderObjectWidget {
  const _DropdownMenuBody({super.children});

  @override
  _RenderDropdownMenuBody createRenderObject(BuildContext context) {
    return _RenderDropdownMenuBody();
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDropdownMenuBody renderObject,
  ) {}
}

class _DropdownMenuBodyParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderDropdownMenuBody extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DropdownMenuBodyParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _DropdownMenuBodyParentData
        > {
  _RenderDropdownMenuBody();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DropdownMenuBodyParentData) {
      child.parentData = _DropdownMenuBodyParentData();
    }
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    double maxWidth = 0.0;
    double? maxHeight;
    RenderBox? child = firstChild;

    final double intrinsicWidth = getMaxIntrinsicWidth(constraints.maxHeight);
    final double widthConstraint = math.min(
      intrinsicWidth,
      constraints.maxWidth,
    );
    final BoxConstraints innerConstraints = BoxConstraints(
      maxWidth: widthConstraint,
      maxHeight: getMaxIntrinsicHeight(widthConstraint),
    );
    while (child != null) {
      if (child == firstChild) {
        child.layout(innerConstraints, parentUsesSize: true);
        maxHeight ??= child.size.height;
        maxWidth = math.max(maxWidth, child.size.width);
        final _DropdownMenuBodyParentData childParentData =
            child.parentData! as _DropdownMenuBodyParentData;
        assert(child.parentData == childParentData);
        child = childParentData.nextSibling;
        continue;
      }
      child.layout(innerConstraints, parentUsesSize: true);
      final _DropdownMenuBodyParentData childParentData =
          child.parentData! as _DropdownMenuBodyParentData;
      childParentData.offset = Offset.zero;
      maxWidth = math.max(maxWidth, child.size.width);
      maxHeight ??= child.size.height;
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }

    assert(maxHeight != null);
    size = constraints.constrain(Size(maxWidth, maxHeight!));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = firstChild;
    if (child != null) {
      final _DropdownMenuBodyParentData childParentData =
          child.parentData! as _DropdownMenuBodyParentData;
      context.paintChild(child, offset + childParentData.offset);
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    double maxWidth = 0.0;
    double? maxHeight;
    RenderBox? child = firstChild;
    final double intrinsicWidth = getMaxIntrinsicWidth(constraints.maxHeight);
    final double widthConstraint = math.min(
      intrinsicWidth,
      constraints.maxWidth,
    );
    final BoxConstraints innerConstraints = BoxConstraints(
      maxWidth: widthConstraint,
      maxHeight: getMaxIntrinsicHeight(widthConstraint),
    );

    while (child != null) {
      if (child == firstChild) {
        final Size childSize = child.getDryLayout(innerConstraints);
        maxHeight ??= childSize.height;
        maxWidth = math.max(maxWidth, childSize.width);
        final _DropdownMenuBodyParentData childParentData =
            child.parentData! as _DropdownMenuBodyParentData;
        assert(child.parentData == childParentData);
        child = childParentData.nextSibling;
        continue;
      }
      final Size childSize = child.getDryLayout(innerConstraints);
      final _DropdownMenuBodyParentData childParentData =
          child.parentData! as _DropdownMenuBodyParentData;
      childParentData.offset = Offset.zero;
      maxWidth = math.max(maxWidth, childSize.width);
      maxHeight ??= childSize.height;
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }

    assert(maxHeight != null);
    return constraints.constrain(Size(maxWidth, maxHeight!));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    RenderBox? child = firstChild;
    double width = 0;
    while (child != null) {
      final double maxIntrinsicWidth = child.getMinIntrinsicWidth(height);
      width = math.max(width, maxIntrinsicWidth);
      final _DropdownMenuBodyParentData childParentData =
          child.parentData! as _DropdownMenuBodyParentData;
      child = childParentData.nextSibling;
    }

    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    RenderBox? child = firstChild;
    double width = 0;
    while (child != null) {
      final double maxIntrinsicWidth = child.getMaxIntrinsicWidth(height);
      width = math.max(width, maxIntrinsicWidth);
      final _DropdownMenuBodyParentData childParentData =
          child.parentData! as _DropdownMenuBodyParentData;
      child = childParentData.nextSibling;
    }

    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final RenderBox? child = firstChild;
    double height = 0;
    if (child != null) {
      height = math.max(height, child.getMinIntrinsicHeight(width));
    }
    return height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final RenderBox? child = firstChild;
    double height = 0;
    if (child != null) {
      height = math.max(height, child.getMaxIntrinsicHeight(width));
    }
    return height;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? child = firstChild;
    if (child != null) {
      final _DropdownMenuBodyParentData childParentData =
          child.parentData! as _DropdownMenuBodyParentData;
      final bool isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - childParentData.offset);
          return child.hitTest(result, position: transformed);
        },
      );
      if (isHit) {
        return true;
      }
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitChildren((RenderObject renderObjectChild) {
      final RenderBox child = renderObjectChild as RenderBox;
      if (child == firstChild) {
        visitor(renderObjectChild);
      }
    });
  }
}

class _DropdownMenuDefaultsM3 extends DropdownMenuThemeData {
  _DropdownMenuDefaultsM3(this.context, {this.buttonBackgroundColor})
    : super(
        disabledColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.38),
      );

  final BuildContext context;
  final Color? buttonBackgroundColor;
  late final ThemeData _theme = Theme.of(context);

  @override
  TextStyle? get textStyle => _theme.textTheme.bodyLarge;

  @override
  MenuStyle get menuStyle {
    return MenuStyle(
      backgroundColor: WidgetStatePropertyAll<Color?>(
        buttonBackgroundColor ?? _theme.colorScheme.secondaryContainer,
      ),
      surfaceTintColor: const WidgetStatePropertyAll<Color>(
        Colors.transparent,
      ),
      minimumSize: const WidgetStatePropertyAll<Size>(Size(0.0, 0.0)),
      maximumSize: const WidgetStatePropertyAll<Size>(Size.infinite),
      visualDensity: VisualDensity.standard,
    );
  }
}
