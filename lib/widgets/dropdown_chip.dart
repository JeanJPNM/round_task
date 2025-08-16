import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const double _kDefaultHorizontalPadding = 12.0;

/// A dropdown menu that can be opened from a [TextField]. The selected
/// menu item is displayed in that field.
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=giV9AbM2gd8}
///
/// This widget is used to help people make a choice from a menu and put the
/// selected item into the text input field. People can also filter the list based
/// on the text input or search one item in the menu list.
///
/// The menu is composed of a list of [DropdownMenuEntry]s. People can provide information,
/// such as: label, leading icon or trailing icon for each entry. The [TextField]
/// will be updated based on the selection from the menu entries. The text field
/// will stay empty if the selected entry is disabled.
///
/// When the dropdown menu has focus, it can be traversed by pressing the up or down key.
/// During the process, the corresponding item will be highlighted and
/// the text field will be updated. Disabled items will be skipped during traversal.
///
/// The menu can be scrollable if not all items in the list are displayed at once.
///
/// {@tool dartpad}
/// This sample shows how to display outlined [DropdownMenu] and filled [DropdownMenu].
///
/// ** See code in examples/api/lib/material/dropdown_menu/dropdown_menu.0.dart **
/// {@end-tool}
///
/// See also:
///
/// * [MenuAnchor], which is a widget used to mark the "anchor" for a set of submenus.
///   The [DropdownMenu] uses a [TextField] as the "anchor".
/// * [TextField], which is a text input widget that uses an [InputDecoration].
/// * [DropdownMenuEntry], which is used to build the [MenuItemButton] in the [DropdownMenu] list.
class DropdownMenuChip<T> extends StatefulWidget {
  /// Creates a const [DropdownMenu].
  ///
  /// The leading and trailing icons in the text field can be customized by using
  /// [leadingIcon], [trailingIcon] and [selectedTrailingIcon] properties. They are
  /// passed down to the [InputDecoration] properties, and will override values
  /// in the [InputDecoration.prefixIcon] and [InputDecoration.suffixIcon].
  ///
  /// Except leading and trailing icons, the text field can be configured by the
  /// [inputDecorationTheme] property. The menu can be configured by the [menuStyle].
  const DropdownMenuChip({
    super.key,
    this.enabled = true,
    this.trailingIcon,
    this.showTrailingIcon = true,
    this.selectedTrailingIcon,
    this.menuStyle,
    this.initialSelection,
    this.onSelected,
    this.expandedInsets,
    this.alignmentOffset,
    required this.dropdownMenuEntries,
    this.closeBehavior = DropdownMenuCloseBehavior.all,
  });

  /// Determine if the [DropdownMenu] is enabled.
  ///
  /// Defaults to true.
  ///
  /// {@tool dartpad}
  /// This sample demonstrates how the [enabled] and [requestFocusOnTap] properties
  /// affect the textfield's hover cursor.
  ///
  /// ** See code in examples/api/lib/material/dropdown_menu/dropdown_menu.2.dart **
  /// {@end-tool}
  final bool enabled;

  /// An optional icon at the end of the text field.
  ///
  /// Defaults to an [Icon] with [Icons.arrow_drop_down].
  ///
  /// If [showTrailingIcon] is false, the trailing icon will not be shown.
  final Widget? trailingIcon;

  /// Specifies if the [DropdownMenu] should show a [trailingIcon].
  ///
  /// If [trailingIcon] is set, [DropdownMenu] will use that trailing icon,
  /// otherwise a default trailing icon will be created.
  ///
  /// Defaults to true.
  final bool showTrailingIcon;

  /// An optional icon at the end of the text field to indicate that the text
  /// field is pressed.
  ///
  /// Defaults to an [Icon] with [Icons.arrow_drop_up].
  final Widget? selectedTrailingIcon;

  /// The [MenuStyle] that defines the visual attributes of the menu.
  ///
  /// The default width of the menu is set to the width of the text field.
  final MenuStyle? menuStyle;

  /// The value used to for an initial selection.
  ///
  /// Defaults to null.
  final T? initialSelection;

  /// The callback is called when a selection is made.
  ///
  /// Defaults to null. If null, only the text field is updated.
  final ValueChanged<T?>? onSelected;

  /// Descriptions of the menu items in the [DropdownMenu].
  ///
  /// This is a required parameter. It is recommended that at least one [DropdownMenuEntry]
  /// is provided. If this is an empty list, the menu will be empty and only
  /// contain space for padding.
  final List<DropdownMenuEntry<T>> dropdownMenuEntries;

  /// Defines the menu text field's width to be equal to its parent's width
  /// plus the horizontal width of the specified insets.
  ///
  /// If this property is null, the width of the text field will be determined
  /// by the width of menu items or [DropdownMenu.width]. If this property is not null,
  /// the text field's width will match the parent's width plus the specified insets.
  /// If the value of this property is [EdgeInsets.zero], the width of the text field will be the same
  /// as its parent's width.
  ///
  /// The [expandedInsets]' top and bottom are ignored, only its left and right
  /// properties are used.
  ///
  /// Defaults to null.
  final EdgeInsetsGeometry? expandedInsets;

  /// {@macro flutter.material.MenuAnchor.alignmentOffset}
  final Offset? alignmentOffset;

  /// Defines the behavior for closing the dropdown menu when an item is selected.
  ///
  /// The close behavior can be set to:
  /// * [DropdownMenuCloseBehavior.all]: Closes all open menus in the widget tree.
  /// * [DropdownMenuCloseBehavior.self]: Closes only the current dropdown menu.
  /// * [DropdownMenuCloseBehavior.none]: Does not close any menus.
  ///
  /// This property allows fine-grained control over the menu's closing behavior,
  /// which can be useful for creating nested or complex menu structures.
  ///
  /// Defaults to [DropdownMenuCloseBehavior.all].
  final DropdownMenuCloseBehavior closeBehavior;

  @override
  State<DropdownMenuChip<T>> createState() => _DropdownMenuState<T>();
}

class _DropdownMenuState<T> extends State<DropdownMenuChip<T>> {
  final GlobalKey _anchorKey = GlobalKey();
  late List<GlobalKey> buttonItemKeys;
  final MenuController _controller = MenuController();
  List<Widget>? _initialMenu;
  int? currentHighlight;
  double? leadingPadding;
  bool _menuHasEnabledItem = false;
  String _label = '';
  final FocusNode _internalFocudeNode = FocusNode();
  int? _selectedEntryIndex;

  @override
  void initState() {
    super.initState();
    final entries = widget.dropdownMenuEntries;
    buttonItemKeys =
        List<GlobalKey>.generate(entries.length, (int index) => GlobalKey());
    _menuHasEnabledItem =
        entries.any((DropdownMenuEntry<T> entry) => entry.enabled);
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
    _internalFocudeNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DropdownMenuChip<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.dropdownMenuEntries != widget.dropdownMenuEntries) {
      currentHighlight = null;
      final entries = widget.dropdownMenuEntries;
      buttonItemKeys =
          List<GlobalKey>.generate(entries.length, (int index) => GlobalKey());
      _menuHasEnabledItem =
          entries.any((DropdownMenuEntry<T> entry) => entry.enabled);
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
    bool? useMaterial3,
  }) {
    final double effectiveInputStartGap = 0.0;
    final List<Widget> result = <Widget>[];
    for (int i = 0; i < filteredEntries.length; i++) {
      final DropdownMenuEntry<T> entry = filteredEntries[i];

      // By default, when the text field has a leading icon but a menu entry doesn't
      // have one, the label of the entry should have extra padding to be aligned
      // with the text in the text input field. When both the text field and the
      // menu entry have leading icons, the menu entry should remove the extra
      // paddings so its leading icon will be aligned with the leading icon of
      // the text field.
      final double padding = entry.leadingIcon == null
          ? (leadingPadding ?? _kDefaultHorizontalPadding)
          : _kDefaultHorizontalPadding;
      ButtonStyle effectiveStyle = entry.style ??
          MenuItemButton.styleFrom(
            padding: EdgeInsetsDirectional.only(
                start: padding, end: _kDefaultHorizontalPadding),
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

      // Simulate the focused state because the text field should always be focused
      // during traversal. Include potential MenuItemButton theme in the focus
      // simulation for all colors in the theme.
      if (entry.enabled && i == focusedIndex) {
        // Query the Material 3 default style.
        // TODO(bleroux): replace once a standard way for accessing defaults will be defined.
        // See: https://github.com/flutter/flutter/issues/130135.
        final ButtonStyle defaultStyle =
            const MenuItemButton().defaultStyleOf(context);

        Color? resolveFocusedColor(
            WidgetStateProperty<Color?>? colorStateProperty) {
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
        // For the background color we can't rely on the default style which is transparent.
        // Defaults to onSurface.withOpacity(0.12).
        final Color focusedBackgroundColor =
            resolveFocusedColor(effectiveBackgroundColor) ??
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);

        effectiveStyle = effectiveStyle.copyWith(
          backgroundColor:
              WidgetStatePropertyAll<Color>(focusedBackgroundColor),
          foregroundColor:
              WidgetStatePropertyAll<Color>(focusedForegroundColor),
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

      Widget label = entry.labelWidget ?? Text(entry.label);

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
                    // In some cases (e.g., nested menus), calling onSelected from MenuAnchor inside a postFrameCallback
                    // can result in the MenuItemButton's onPressed callback being triggered after the state has been disposed.
                    // TODO(ahmedrasar): MenuAnchor should avoid calling onSelected inside a postFrameCallback.

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
          // MenuItemButton implementation is based on M3 spec for menu which specifies a
          // horizontal padding of 12 pixels.
          // In the context of DropdownMenu the M3 spec specifies that the menu item and the text
          // field content should be aligned. The text field has a horizontal padding of 16 pixels.
          // To conform with the 16 pixels padding, a 4 pixels padding is added in front of the item label.
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: effectiveInputStartGap),
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
      // close to open
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
    final bool useMaterial3 = Theme.of(context).useMaterial3;
    final TextDirection textDirection = Directionality.of(context);
    _initialMenu ??= _buildButtons(
      widget.dropdownMenuEntries,
      textDirection,
      enableScrollToHighlight: false,
      // The _initialMenu is invisible, we should not add semantics nodes to it
      excludeSemantics: true,
      useMaterial3: useMaterial3,
    );
    final DropdownMenuThemeData theme = DropdownMenuTheme.of(context);
    final DropdownMenuThemeData defaults = _DropdownMenuDefaultsM3(context);
    final entries = widget.dropdownMenuEntries;
    _menuHasEnabledItem =
        entries.any((DropdownMenuEntry<T> entry) => entry.enabled);

    final List<Widget> menu = _buildButtons(
      entries,
      textDirection,
      focusedIndex: currentHighlight,
      useMaterial3: useMaterial3,
    );

    MenuStyle? effectiveMenuStyle =
        widget.menuStyle ?? theme.menuStyle ?? defaults.menuStyle!;

    final double? anchorWidth = getWidth(_anchorKey);
    if (anchorWidth != null) {
      effectiveMenuStyle = effectiveMenuStyle.copyWith(
        minimumSize:
            WidgetStateProperty.resolveWith<Size?>((Set<WidgetState> states) {
          final double? effectiveMaximumWidth =
              effectiveMenuStyle!.maximumSize?.resolve(states)?.width;
          return Size(math.min(anchorWidth, effectiveMaximumWidth ?? 0.0), 0.0);
        }),
      );
    }

    final MouseCursor? effectiveMouseCursor = switch (widget.enabled) {
      true => SystemMouseCursors.click,
      false => null,
    };

    Widget menuAnchor = MenuAnchor(
      style: effectiveMenuStyle,
      alignmentOffset: widget.alignmentOffset,
      controller: _controller,
      menuChildren: menu,
      crossAxisUnconstrained: false,
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
        assert(_initialMenu != null);

        final Widget trailingButton =
            switch ((widget.showTrailingIcon, controller.isOpen)) {
          (false, _) => const SizedBox.shrink(),
          (true, true) =>
            widget.trailingIcon ?? const Icon(Icons.arrow_drop_up),
          (true, false) =>
            widget.selectedTrailingIcon ?? const Icon(Icons.arrow_drop_down),
        };

        final Widget chipContent = widget.expandedInsets != null
            ? Text(_label)
            : _DropdownMenuBody(
                children: <Widget>[
                  Text(_label),
                  for (final entry in widget.dropdownMenuEntries)
                    ExcludeSemantics(child: Text(entry.label)),
                ],
              );
        final Widget actionChip = ActionChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [chipContent, trailingButton],
          ),
          key: _anchorKey,
          mouseCursor: effectiveMouseCursor,
          onPressed: !widget.enabled ? null : () => handlePressed(controller),
        );

        // If [expandedInsets] is not null, the width of the text field should depend
        // on its parent width. So we don't need to use `_DropdownMenuBody` to
        // calculate the children's width.
        final Widget body = actionChip;

        return Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.arrowLeft):
                ExtendSelectionByCharacterIntent(
              forward: false,
              collapseSelection: true,
            ),
            SingleActivator(LogicalKeyboardKey.arrowRight):
                ExtendSelectionByCharacterIntent(
              forward: true,
              collapseSelection: true,
            ),
            SingleActivator(LogicalKeyboardKey.arrowUp): _ArrowUpIntent(),
            SingleActivator(LogicalKeyboardKey.arrowDown): _ArrowDownIntent(),
          },
          child: body,
        );
      },
    );

    if (widget.expandedInsets case final EdgeInsetsGeometry padding) {
      menuAnchor = Padding(
        // Clamp the top and bottom padding to 0.
        padding: padding.clamp(
          EdgeInsets.zero,
          const EdgeInsets.only(
            left: double.infinity,
            right: double.infinity,
          ).add(const EdgeInsetsDirectional.only(
              end: double.infinity, start: double.infinity)),
        ),
        child: menuAnchor,
      );
    }

    // Wrap the menu anchor with an Align to narrow down the constraints.
    // Without this Align, when tight constraints are applied to DropdownMenu,
    // the menu will appear below these constraints instead of below the
    // text field.
    menuAnchor = Align(
      alignment: AlignmentDirectional.topStart,
      widthFactor: 1.0,
      heightFactor: 1.0,
      child: menuAnchor,
    );

    return Actions(
      actions: <Type, Action<Intent>>{
        _ArrowUpIntent:
            CallbackAction<_ArrowUpIntent>(onInvoke: handleUpKeyInvoke),
        _ArrowDownIntent:
            CallbackAction<_ArrowDownIntent>(onInvoke: handleDownKeyInvoke),
        _EnterIntent: CallbackAction<_EnterIntent>(
            onInvoke: (_) => _handleEditingComplete()),
      },
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Handling keyboard navigation when the Textfield has no focus.
          Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.arrowUp): _ArrowUpIntent(),
              SingleActivator(LogicalKeyboardKey.arrowDown): _ArrowDownIntent(),
              SingleActivator(LogicalKeyboardKey.enter): _EnterIntent(),
            },
            child: Focus(
              focusNode: _internalFocudeNode,
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

// `DropdownMenu` dispatches these private intents on arrow up/down keys.
// They are needed instead of the typical `DirectionalFocusIntent`s because
// `DropdownMenu` does not really navigate the focus tree upon arrow up/down
// keys: the focus stays on the text field and the menu items are given fake
// highlights as if they are focused. Using `DirectionalFocusIntent`s will cause
// the action to be processed by `EditableText`.
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
      BuildContext context, _RenderDropdownMenuBody renderObject) {}
}

class _DropdownMenuBodyParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderDropdownMenuBody extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DropdownMenuBodyParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox,
            _DropdownMenuBodyParentData> {
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
    final double widthConstraint =
        math.min(intrinsicWidth, constraints.maxWidth);
    final BoxConstraints innerConstraints = BoxConstraints(
      maxWidth: widthConstraint,
      maxHeight: getMaxIntrinsicHeight(widthConstraint),
    );
    while (child != null) {
      if (child == firstChild) {
        child.layout(innerConstraints, parentUsesSize: true);
        maxHeight ??= child.size.height;
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
    final double widthConstraint =
        math.min(intrinsicWidth, constraints.maxWidth);
    final BoxConstraints innerConstraints = BoxConstraints(
      maxWidth: widthConstraint,
      maxHeight: getMaxIntrinsicHeight(widthConstraint),
    );

    while (child != null) {
      if (child == firstChild) {
        final Size childSize = child.getDryLayout(innerConstraints);
        maxHeight ??= childSize.height;
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
    maxWidth = maxWidth;
    return constraints.constrain(Size(maxWidth, maxHeight!));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    RenderBox? child = firstChild;
    double width = 0;
    while (child != null) {
      if (child == firstChild) {
        final _DropdownMenuBodyParentData childParentData =
            child.parentData! as _DropdownMenuBodyParentData;
        child = childParentData.nextSibling;
        continue;
      }
      final double maxIntrinsicWidth = child.getMinIntrinsicWidth(height);
      // Add the width of leading icon.
      if (child == lastChild) {
        width += maxIntrinsicWidth;
      }
      // Add the width of trailing icon.
      if (child == childBefore(lastChild!)) {
        width += maxIntrinsicWidth;
      }
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
      if (child == firstChild) {
        final _DropdownMenuBodyParentData childParentData =
            child.parentData! as _DropdownMenuBodyParentData;
        child = childParentData.nextSibling;
        continue;
      }
      final double maxIntrinsicWidth = child.getMaxIntrinsicWidth(height);
      // Add the width of leading icon.
      if (child == lastChild) {
        width += maxIntrinsicWidth;
      }
      // Add the width of trailing icon.
      if (child == childBefore(lastChild!)) {
        width += maxIntrinsicWidth;
      }
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
    double width = 0;
    if (child != null) {
      width = math.max(width, child.getMinIntrinsicHeight(width));
    }
    return width;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final RenderBox? child = firstChild;
    double width = 0;
    if (child != null) {
      width = math.max(width, child.getMaxIntrinsicHeight(width));
    }
    return width;
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

  // Children except the text field (first child) are laid out for measurement purpose but not painted.
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

// Hand coded defaults. These will be updated once we have tokens/spec.
class _DropdownMenuDefaultsM3 extends DropdownMenuThemeData {
  _DropdownMenuDefaultsM3(this.context)
      : super(
            disabledColor: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.38));

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);

  @override
  TextStyle? get textStyle => _theme.textTheme.bodyLarge;

  @override
  MenuStyle get menuStyle {
    return const MenuStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size(0.0, 0.0)),
      maximumSize: WidgetStatePropertyAll<Size>(Size.infinite),
      visualDensity: VisualDensity.standard,
    );
  }

  @override
  InputDecorationThemeData get inputDecorationTheme {
    return const InputDecorationThemeData(border: OutlineInputBorder());
  }
}
