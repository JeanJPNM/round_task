import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rrule/rrule.dart';

enum _EndOption {
  never,
  onDate,
  afterOccurrences,
}

class RecurrencePicker extends StatefulWidget {
  const RecurrencePicker({
    super.key,
    this.initialRecurrenceRule,
    this.initialWeekDays = const [],
  });

  final RecurrenceRule? initialRecurrenceRule;
  final List<int> initialWeekDays;
  @override
  State<RecurrencePicker> createState() => _RecurrencePickerState();
}

class _RecurrencePickerState extends State<RecurrencePicker> {
  final intervalController = TextEditingController();
  final limitController = TextEditingController();
  Frequency frequency = Frequency.daily;

  Set<int> weekSelection = {};
  DateTime? endDate;

  _EndOption endOption = _EndOption.never;

  @override
  void initState() {
    super.initState();

    final recurrenceRule = widget.initialRecurrenceRule;
    if (recurrenceRule != null) {
      frequency = recurrenceRule.frequency;
      intervalController.text = recurrenceRule.actualInterval.toString();
      endDate = recurrenceRule.until;
      final occurrences = recurrenceRule.count;
      if (occurrences != null) {
        limitController.text = occurrences.toString();
      }

      endOption = switch ((endDate, occurrences)) {
        (null, null) => _EndOption.never,
        (null, _) => _EndOption.afterOccurrences,
        (_, null) => _EndOption.onDate,
        _ => _EndOption.never,
      };

      weekSelection = _getWeekSelection(
        recurrenceRule.byWeekDays.isNotEmpty
            ? recurrenceRule.byWeekDays
            : widget.initialWeekDays.map(ByWeekDayEntry.new),
      );
    } else {
      intervalController.text = "1";
      weekSelection = _getWeekSelection(
        widget.initialWeekDays.map(ByWeekDayEntry.new),
      );
    }
  }

  List<ByWeekDayEntry> _getByWeekDays() {
    final entries = <ByWeekDayEntry>[];
    for (final day in const [
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
    ]) {
      if (weekSelection.contains(day)) {
        entries.add(ByWeekDayEntry(day));
      }
    }
    return entries;
  }

  Set<int> _getWeekSelection(Iterable<ByWeekDayEntry> entries) {
    final selection = <int>{};
    for (final entry in entries) {
      selection.add(entry.day);
    }
    return selection;
  }

  RecurrenceRule _getRecurrenceRule() {
    RecurrenceRule rule = RecurrenceRule(
      frequency: frequency,
      interval: int.parse(intervalController.text),
      byWeekDays: switch (frequency) {
        Frequency.weekly => _getByWeekDays(),
        _ => [],
      },
      until: endOption == _EndOption.onDate ? endDate?.toUtc() : null,
      count: endOption == _EndOption.afterOccurrences
          ? int.tryParse(limitController.text)
          : null,
    );

    return rule;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("recurrence"),
            style: theme.textTheme.titleSmall,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr("repeat_every")),
              const SizedBox(width: 10),
              SizedBox(
                width: 40,
                child: TextField(
                  textAlign: TextAlign.center,
                  controller: intervalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
              const SizedBox(width: 10),
              DropdownMenu(
                requestFocusOnTap: false,
                initialSelection: frequency,
                onSelected: (value) {
                  setState(() {
                    frequency = value ?? Frequency.daily;
                  });
                },
                dropdownMenuEntries: [
                  DropdownMenuEntry(
                    value: Frequency.hourly,
                    label: context.tr("repeat_menu.hour"),
                  ),
                  DropdownMenuEntry(
                    value: Frequency.daily,
                    label: context.tr("repeat_menu.day"),
                  ),
                  DropdownMenuEntry(
                    value: Frequency.weekly,
                    label: context.tr("repeat_menu.week"),
                  ),
                  DropdownMenuEntry(
                    value: Frequency.monthly,
                    label: context.tr("repeat_menu.month"),
                  ),
                  DropdownMenuEntry(
                    value: Frequency.yearly,
                    label: context.tr("repeat_menu.year"),
                  ),
                ],
              ),
            ],
          ),
          ...switch (frequency) {
            Frequency.weekly => [
                Text(context.tr("repeat")),
                SegmentedButton(
                  showSelectedIcon: false,
                  multiSelectionEnabled: true,
                  expandedInsets: const EdgeInsets.symmetric(vertical: 10),
                  segments: [
                    for (final (day, string) in const [
                      (DateTime.sunday, "weekday_letter.sunday"),
                      (DateTime.monday, "weekday_letter.monday"),
                      (DateTime.tuesday, "weekday_letter.tuesday"),
                      (DateTime.wednesday, "weekday_letter.wednesday"),
                      (DateTime.thursday, "weekday_letter.thursday"),
                      (DateTime.friday, "weekday_letter.friday"),
                      (DateTime.saturday, "weekday_letter.saturday"),
                    ])
                      ButtonSegment(
                        value: day,
                        label: Text(context.tr(string)),
                      ),
                  ],
                  selected: weekSelection,
                  onSelectionChanged: (value) {
                    setState(() {
                      weekSelection = value;
                    });
                  },
                ),
              ],
            // TODO: handle montly on same day and montly
            // on same weekday
            _ => [],
          },
          Text(
            context.tr("ends"),
            style: theme.textTheme.titleSmall,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio(
                value: _EndOption.never,
                groupValue: endOption,
                onChanged: (value) {
                  setState(() => endOption = value ?? _EndOption.never);
                },
              ),
              Text(context.tr("end_option.never"))
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio(
                value: _EndOption.onDate,
                groupValue: endOption,
                onChanged: (value) {
                  setState(() => endOption = value ?? _EndOption.never);
                },
              ),
              Text(context.tr("end_option.on_date")),
              TextButton(
                onPressed: endOption != _EndOption.onDate
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (date != null) {
                          setState(() {
                            endDate = date;
                          });
                        }
                      },
                child: Text(switch (endDate) {
                  final endDate? => DateFormat.yMMMEd(locale).format(endDate),
                  null => context.tr("select_date"),
                }),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio(
                value: _EndOption.afterOccurrences,
                groupValue: endOption,
                onChanged: (value) {
                  setState(() => endOption = value ?? _EndOption.never);
                },
              ),
              Text(context.tr("end_option.after_first")),
              SizedBox(
                width: 100,
                child: TextField(
                  textAlign: TextAlign.center,
                  controller: limitController,
                  enabled: endOption == _EndOption.afterOccurrences,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
              Text(context.tr("end_option.after_second")),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(context.tr("cancel")),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(_getRecurrenceRule());
                },
                child: Text(context.tr("done")),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<RecurrenceRule?> showRecurrencePicker(
  BuildContext context, {
  RecurrenceRule? initialRecurrenceRule,
  List<int> initialWeekDays = const [],
}) async {
  return await showModalBottomSheet<RecurrenceRule>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final viewInsets = EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      );
      return Padding(
        padding: const EdgeInsets.all(15.0) + viewInsets,
        child: RecurrencePicker(
          initialRecurrenceRule: initialRecurrenceRule,
          initialWeekDays: initialWeekDays,
        ),
      );
    },
  );
}
