import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class DateTimeEditingController extends ValueNotifier<DateTime?> {
  DateTimeEditingController([super.value]);

  DateTime? previous;

  @override
  set value(DateTime? newValue) {
    previous = value;
    super.value = newValue;
  }
}

class DateTimeInput extends StatefulWidget {
  DateTimeInput({
    super.key,
    this.label,
    required this.controller,
    this.defaultHour = 0,
    this.defaultMinute = 0,
    DateTime? firstDate,
    DateTime? lastDate,
    this.allowDelete = true,
  })  : firstDate = firstDate ?? DateTime(2000),
        lastDate = lastDate ?? DateTime(2100);
  final DateTimeEditingController? controller;
  final Widget? label;
  final DateTime firstDate;
  final DateTime lastDate;
  final int defaultHour;
  final int defaultMinute;
  final bool allowDelete;
  @override
  State<DateTimeInput> createState() => _DateTimeInputState();
}

class _DateTimeInputState extends State<DateTimeInput> {
  bool _disposeController = false;
  late final DateTimeEditingController _controller;

  @override
  void initState() {
    super.initState();

    if (widget.controller == null) {
      _controller = DateTimeEditingController();
      _disposeController = true;
    } else {
      _controller = widget.controller!;
    }
  }

  @override
  void dispose() {
    if (_disposeController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, value, child) {
        final input = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: value,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                );

                if (date != null) {
                  _controller.value = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    value?.hour ?? widget.defaultHour,
                    value?.minute ?? widget.defaultMinute,
                  );
                }
              },
              child: Text(switch (value) {
                null => context.tr("select_date"),
                _ => DateFormat.yMMMEd(locale).format(value),
              }),
            ),
            if (value != null) ...[
              TextButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(value),
                  );
                  if (time != null) {
                    _controller.value = DateTime(
                      value.year,
                      value.month,
                      value.day,
                      time.hour,
                      time.minute,
                    );
                  }
                },
                child: Text(DateFormat.jm(locale).format(value)),
              ),
              if (widget.allowDelete)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    _controller.value = null;
                  },
                ),
            ],
          ],
        );

        if (widget.label == null) {
          return input;
        }

        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            widget.label!,
            input,
          ],
        );
      },
    );
  }
}
