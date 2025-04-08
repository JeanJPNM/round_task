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
  const RecurrencePicker({super.key, this.initialRecurrenceRule});

  final RecurrenceRule? initialRecurrenceRule;
  @override
  State<RecurrencePicker> createState() => _RecurrencePickerState();
}

class _RecurrencePickerState extends State<RecurrencePicker> {
  final numberController = TextEditingController();
  Frequency frequency = Frequency.daily;

  List<bool> weekSelection = List.generate(7, (index) => false);
  DateTime? endDate;
  int? occurrences;

  _EndOption endOption = _EndOption.never;

  @override
  void initState() {
    super.initState();

    final recurrenceRule = widget.initialRecurrenceRule;
    if (recurrenceRule != null) {
      frequency = recurrenceRule.frequency;
      numberController.text = recurrenceRule.actualInterval.toString();
      endDate = recurrenceRule.until;
      occurrences = recurrenceRule.count;
      weekSelection = _getWeekSelection(recurrenceRule.byWeekDays);
    } else {
      numberController.text = "1";
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

  List<bool> _getWeekSelection(List<ByWeekDayEntry> entries) {
    final selection = List.generate(7, (index) => false);
    for (final entry in entries) {
      switch (entry.day) {
        case DateTime.sunday:
          selection[0] = true;
        case DateTime.monday:
          selection[1] = true;
        case DateTime.tuesday:
          selection[2] = true;
        case DateTime.wednesday:
          selection[3] = true;
        case DateTime.thursday:
          selection[4] = true;
        case DateTime.friday:
          selection[5] = true;
        case DateTime.saturday:
          selection[6] = true;
      }
    }
    return selection;
  }

  RecurrenceRule _getRecurrenceRule() {
    RecurrenceRule rule = RecurrenceRule(
      frequency: frequency,
      interval: int.parse(numberController.text),
      byWeekDays: switch (frequency) {
        Frequency.weekly => _getByWeekDays(),
        _ => [],
      },
      until: endOption == _EndOption.onDate ? endDate?.toUtc() : null,
      count: endOption == _EndOption.afterOccurrences ? occurrences : null,
    );

    return rule;
  }

  @override
  Widget build(BuildContext context) {
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
              Text("Repeat every"),
              const SizedBox(width: 10),
              SizedBox(
                width: 40,
                child: TextField(
                  textAlign: TextAlign.center,
                  controller: numberController,
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
                initialSelection: Frequency.daily,
                onSelected: (value) {
                  setState(() {
                    frequency = value ?? Frequency.daily;
                  });
                },
                dropdownMenuEntries: [
                  DropdownMenuEntry(value: Frequency.daily, label: "Dia"),
                  DropdownMenuEntry(value: Frequency.weekly, label: "Semana"),
                  DropdownMenuEntry(value: Frequency.monthly, label: "Mês"),
                  DropdownMenuEntry(value: Frequency.yearly, label: "Ano"),
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
                  children: const [
                    Text("D"),
                    Text("S"),
                    Text("T"),
                    Text("Q"),
                    Text("Q"),
                    Text("S"),
                    Text("S"),
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
                child: Text(
                  endDate == null
                      ? "Selecione uma data"
                      : DateFormat.yMMMMd("pt_BR").format(endDate!),
                ),
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
                  print("Recurrence rule: ${_getRecurrenceRule()}");
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
}) async {
  return await showModalBottomSheet<RecurrenceRule>(
    context: context,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(15.0),
        child: RecurrencePicker(
          initialRecurrenceRule: initialRecurrenceRule,
        ),
      );
    },
  );
}
