import 'package:material_ui/material_ui.dart';
import 'package:round_task/widgets/dropdown_menu_button.dart';

class SelectDropdown<T> extends StatefulWidget {
  const SelectDropdown({
    super.key,
    this.style,
    required this.entries,
    this.onChanged,
    this.value,
  });

  final ButtonStyle? style;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?>? onChanged;
  final T? value;

  @override
  State<SelectDropdown<T>> createState() => _SelectDropdownState<T>();
}

class _SelectDropdownState<T> extends State<SelectDropdown<T>> {
  @override
  Widget build(BuildContext context) {
    return DropdownMenuButton(
      dropdownMenuEntries: widget.entries,
      onSelected: widget.onChanged,
      initialSelection: widget.value,
    );
  }
}
