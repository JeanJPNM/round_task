import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

  List<bool> weekSelection = List.generate(7, (index) => false);
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
    if (weekSelection[0]) entries.add(ByWeekDayEntry(DateTime.sunday));
    if (weekSelection[1]) entries.add(ByWeekDayEntry(DateTime.monday));
    if (weekSelection[2]) entries.add(ByWeekDayEntry(DateTime.tuesday));
    if (weekSelection[3]) entries.add(ByWeekDayEntry(DateTime.wednesday));
    if (weekSelection[4]) entries.add(ByWeekDayEntry(DateTime.thursday));
    if (weekSelection[5]) entries.add(ByWeekDayEntry(DateTime.friday));
    if (weekSelection[6]) entries.add(ByWeekDayEntry(DateTime.saturday));
    return entries;
  }

  List<bool> _getWeekSelection(Iterable<ByWeekDayEntry> entries) {
    final selection = List.generate(7, (index) => false);
    for (final entry in entries) {
      final index = switch (entry.day) {
        DateTime.sunday => 0,
        DateTime.monday => 1,
        DateTime.tuesday => 2,
        DateTime.wednesday => 3,
        DateTime.thursday => 4,
        DateTime.friday => 5,
        DateTime.saturday => 6,
        _ => null,
      };
      if (index == null) continue;
      selection[index] = true;
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
    final weekLetterStyle = Theme.of(context).textTheme.labelLarge;
    final locale = Localizations.localeOf(context).languageCode;
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recurrence",
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Repeat every"),
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
                enableFilter: false,
                enableSearch: false,
                initialSelection: frequency,
                onSelected: (value) {
                  setState(() {
                    frequency = value ?? Frequency.daily;
                  });
                },
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: Frequency.daily, label: "Dia"),
                  const DropdownMenuEntry(
                      value: Frequency.weekly, label: "Semana"),
                  const DropdownMenuEntry(
                      value: Frequency.monthly, label: "Mês"),
                  const DropdownMenuEntry(
                      value: Frequency.yearly, label: "Ano"),
                ],
              ),
            ],
          ),
          ...switch (frequency) {
            Frequency.weekly => [
                const Text("Repetir"),
                ToggleButtons(
                  isSelected: weekSelection,
                  onPressed: (index) {
                    setState(() {
                      weekSelection[index] = !weekSelection[index];
                    });
                  },
                  children: [
                    Text("D", style: weekLetterStyle),
                    Text("S", style: weekLetterStyle),
                    Text("T", style: weekLetterStyle),
                    Text("Q", style: weekLetterStyle),
                    Text("Q", style: weekLetterStyle),
                    Text("S", style: weekLetterStyle),
                    Text("S", style: weekLetterStyle),
                  ],
                ),
              ],
            // TODO: handle montly on same day and montly
            // on same weekday
            _ => [],
          },
          Text(
            "Termina em:",
            style: Theme.of(context).textTheme.titleSmall,
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
              const Text("Nunca")
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
              const Text("Em"),
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
                  null => "Selecione uma data",
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
              const Text("Após"),
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
              const Text("ocorrências"),
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
                child: const Text("Cancelar"),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(_getRecurrenceRule());
                },
                child: const Text("Concluir"),
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
