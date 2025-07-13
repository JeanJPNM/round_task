import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class SelectDropdown<T> extends StatefulWidget {
  const SelectDropdown({
    super.key,
    this.style,
    this.items,
    this.onChanged,
    this.value,
  });

  final ButtonStyle? style;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final T? value;

  @override
  State<SelectDropdown<T>> createState() => _SelectDropdownState<T>();
}

class _SelectDropdownState<T> extends State<SelectDropdown<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final color = colorScheme.secondaryContainer;
    final textColor = colorScheme.onSecondaryContainer;

    return DropdownButton2(
      items: widget.items,
      value: widget.value,
      onChanged: widget.onChanged,
      underline: const SizedBox.shrink(),
      buttonStyleData: ButtonStyleData(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
      ),
      style: theme.textTheme.titleMedium?.copyWith(
        color: textColor,
      ),
      iconStyleData: IconStyleData(
        icon: Icon(
          Icons.arrow_drop_down_rounded,
          color: textColor,
        ),
      ),
      dropdownStyleData: DropdownStyleData(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    );
  }
}
