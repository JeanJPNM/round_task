import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:duration/duration.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kalender/kalender.dart';
import 'package:round_task/custom_colors.dart';
import 'package:round_task/db/db.dart';
import 'package:round_task/formatting.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/screens/task_view.dart';
import 'package:round_task/widgets/app_drawer.dart';
import 'package:round_task/widgets/bottom_sheet_safe_area.dart';
import 'package:round_task/widgets/dropdown_chip.dart';
import 'package:round_task/widgets/second_tick_provider.dart';

const _minimumHeightPerMinute = 0.5;
const _maximumHeightPerMinute = 128.0;
const _calendarTileBorderWidth = 2.0;

enum _ViewMode { singleDay, threeDays, week, schedule }

class _TaskEvent extends CalendarEvent {
  _TaskEvent({
    required super.dateTimeRange,
    required this.title,
    required this.taskId,
    required this.measurement,
  }) : super(interaction: EventInteraction.fromCanModify(false));

  final String title;
  final int taskId;
  final TimeMeasurement measurement;
  bool get isActive => measurement.id == -1;
}

final eventsControllerPod =
    NotifierProvider.autoDispose<_EventsControllerNotifier, EventsController>(
      _EventsControllerNotifier.new,
    );

class _EventsControllerNotifier extends Notifier<EventsController> {
  List<String> _loadedIds = [];

  String? _activeEventId;

  @override
  EventsController build() {
    final controller = DefaultEventsController();
    ref.onDispose(controller.dispose);
    final timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _updateActiveEvent(),
    );
    ref.onDispose(timer.cancel);
    ref.listen(fireImmediately: true, allTimeMeasurementsPod, (previous, next) {
      final prev = previous?.value ?? [];
      final nex = next.value ?? [];
      if (prev.isEmpty && nex.isEmpty) return;

      for (final id in _loadedIds) {
        controller.removeById(id);
      }

      _loadedIds = controller.addEvents([
        for (final (:measurement, :title) in nex)
          _TaskEvent(
            dateTimeRange: DateTimeRange(
              start: measurement.start,
              end: measurement.end,
            ),
            title: title,
            taskId: measurement.taskId,
            measurement: measurement,
          ),
      ]);
    });

    ref.listen(fireImmediately: true, currentlyTrackedTaskPod, (
      previous,
      next,
    ) {
      final task = next.value;
      if (_activeEventId case final id?) {
        controller.removeById(id);
      }
      if (task == null) return;

      final start = task.activeTimeMeasurementStart!;
      _activeEventId = controller.addEvent(
        _TaskEvent(
          title: task.title,
          taskId: task.id,
          dateTimeRange: DateTimeRange(start: start, end: DateTime.now()),
          measurement: TimeMeasurement(
            id: -1,
            taskId: task.id,
            start: start,
            end: DateTime.now(),
          ),
        ),
      );
    });

    return controller;
  }

  void _updateActiveEvent() {
    final controller = state;
    final id = _activeEventId;
    if (id == null) {
      return;
    }

    final event = controller.byId(id) as _TaskEvent?;
    if (event case _TaskEvent event) {
      final updatedEvent = _TaskEvent(
        title: event.title,
        taskId: event.taskId,
        measurement: event.measurement,
        dateTimeRange: DateTimeRange(start: event.start, end: DateTime.now()),
      );
      controller.updateEvent(event: event, updatedEvent: updatedEvent);
    } else {
      _activeEventId = null;
    }
  }
}

class CalendarViewScreen extends ConsumerStatefulWidget {
  const CalendarViewScreen({super.key});

  @override
  ConsumerState<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

TextStyle? _cardTextStyle(ThemeData theme) => theme.textTheme.labelSmall;

class _CalendarViewScreenState extends ConsumerState<CalendarViewScreen> {
  final _calendarBodyKey = GlobalKey();
  _ViewMode _viewMode = _ViewMode.singleDay;
  final eventsController = DefaultEventsController();
  final calendarController = CalendarController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    eventsController.dispose();
    calendarController.dispose();
    super.dispose();
  }

  double _getCalendarBodyHeight() {
    final body = _calendarBodyKey.currentContext?.findRenderObject();

    return switch (body) {
      RenderBox box => box.size.height,
      _ => 0,
    };
  }

  double _getMinimumTileHeight(BuildContext context, ThemeData theme) {
    const verticalPadding = _calendarTileBorderWidth * 2;
    final textScaler = MediaQuery.textScalerOf(context);
    final cardTextStyle =
        _cardTextStyle(theme) ?? DefaultTextStyle.of(context).style;

    final painter = TextPainter(
      maxLines: 1,
      textDirection: TextDirection.ltr,
      text: TextSpan(text: "Ag", style: cardTextStyle),
      textScaler: textScaler,
    );

    final height = painter.preferredLineHeight * 1.1 + verticalPadding;
    painter.dispose();

    return height;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final eventsController = ref.watch(eventsControllerPod);
    final viewConfiguration = switch (_viewMode) {
      _ViewMode.singleDay => MultiDayViewConfiguration.singleDay(
        initialHeightPerMinute: 2,
        firstDayOfWeek: DateTime.sunday,
        initialTimeOfDay: TimeOfDay.now(),
      ),
      _ViewMode.threeDays => MultiDayViewConfiguration.custom(
        numberOfDays: 3,
        firstDayOfWeek: DateTime.sunday,
        initialHeightPerMinute: 2,
        initialTimeOfDay: TimeOfDay.now(),
      ),
      _ViewMode.week => MultiDayViewConfiguration.week(
        initialHeightPerMinute: 2,
        firstDayOfWeek: DateTime.sunday,
        initialTimeOfDay: TimeOfDay.now(),
      ),
      _ViewMode.schedule => ScheduleViewConfiguration.continuous(),
    };
    return Scaffold(
      appBar: AppBar(
        leading: const AppDrawerButton(),
        title: Text(context.tr("calendar_view.title")),
      ),
      body: _CalendarZoomDetector(
        controller: calendarController,
        child: CalendarView(
          eventsController: eventsController,
          calendarController: calendarController,
          viewConfiguration: viewConfiguration,
          components: CalendarComponents(
            multiDayComponents: MultiDayComponents(
              bodyComponents: MultiDayBodyComponents(
                daySeparator: (style) {
                  return DaySeparator(
                    style: DaySeparatorStyle(
                      color: theme.colorScheme.outlineVariant,
                      bottomIndent: style?.bottomIndent,
                      topIndent: style?.topIndent,
                      width: style?.width,
                    ),
                  );
                },
                hourLines:
                    (heightPerMinute, timeOfDayRange, style, timelineStyle) {
                      return HourLines(
                        heightPerMinute: heightPerMinute,
                        timeOfDayRange: timeOfDayRange,
                        style: HourLinesStyle(
                          color: theme.colorScheme.outlineVariant,
                          endIndent: style?.endIndent,
                          indent: style?.indent,
                          thickness: style?.thickness,
                        ),
                        timelineStyle: timelineStyle,
                      );
                    },
              ),
              headerComponents: MultiDayHeaderComponents(
                weekNumberBuilder: (visibleDateTimeRange, style) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
          header: Material(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                _CalendarViewScreenControls(
                  controller: calendarController,
                  viewMode: _viewMode,
                  onViewModeChanged: (value) => setState(() {
                    _viewMode = value;
                  }),
                  getBodyHeight: _getCalendarBodyHeight,
                ),
                CalendarHeader(
                  multiDayTileComponents: _multidayTileComponents(
                    context: context,
                    body: false,
                    theme: theme,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: CalendarBody(
              key: _calendarBodyKey,
              multiDayTileComponents: _multidayTileComponents(
                context: context,
                theme: theme,
              ),
              scheduleTileComponents: _scheduleTileComponents(
                context: context,
                theme: theme,
              ),
              multiDayBodyConfiguration: MultiDayBodyConfiguration(
                showMultiDayEvents: true,
                minimumTileHeight: _getMinimumTileHeight(context, theme),
                horizontalPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TileComponents _multidayTileComponents({
  required BuildContext context,
  required ThemeData theme,
  bool body = true,
}) {
  const outerRadius = 10.0;
  const innerRadius = outerRadius - _calendarTileBorderWidth;

  return TileComponents(
    tileBuilder: (event, tileRange) {
      if (!body) return const SizedBox.shrink();
      final _ = event as _TaskEvent;
      final isActive = event.isActive;
      final colorScheme = theme.colorScheme;
      final (cardColor, onCardColor) = switch (isActive) {
        true => (colorScheme.primary, colorScheme.onPrimary),
        false => (colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
      };

      return Card(
        color: colorScheme.surface,
        // prevent the card "border" from covering the
        // calendar separator lines
        margin: const EdgeInsets.symmetric(horizontal: 1),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(outerRadius)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_calendarTileBorderWidth),
          child: Material(
            clipBehavior: Clip.antiAlias,
            color: cardColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(innerRadius)),
            ),
            child: InkWell(
              overlayColor: onCardColor.toOverlayColorProperty(),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => _DetailsSheet(event: event),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  event.title,
                  style: _cardTextStyle(theme)?.copyWith(color: onCardColor),
                ),
              ),
            ),
          ),
        ),
      );
    },
    dragAnchorStrategy: pointerDragAnchorStrategy,
  );
}

ScheduleTileComponents _scheduleTileComponents({
  required BuildContext context,
  required ThemeData theme,
}) {
  final radius = BorderRadius.circular(8);

  return ScheduleTileComponents(
    tileBuilder: (event, tileRange) {
      final _ = event as _TaskEvent;
      final isActive = event.isActive;
      final colorScheme = theme.colorScheme;
      final (cardColor, onCardColor) = switch (isActive) {
        true => (colorScheme.primary, colorScheme.onPrimary),
        false => (colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
      };

      final locale = Localizations.localeOf(context);
      final colorResolver = onCardColor.toOverlayColorProperty();
      return ListTile(
        tileColor: cardColor,
        focusColor: colorResolver.resolve(const {WidgetState.focused}),
        hoverColor: colorResolver.resolve(const {WidgetState.hovered}),
        splashColor: colorResolver.resolve(const {WidgetState.pressed}),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textColor: onCardColor,
        onTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => _DetailsSheet(event: event),
          );
        },
        title: Text(event.title),
        subtitle: Text(
          context.tr(
            "calendar_view.event_schedule_tile_subtitle",
            namedArgs: {
              "start": DateFormat.Hm(
                locale.toLanguageTag(),
              ).format(event.start),
              "end": DateFormat.Hm(locale.toLanguageTag()).format(event.end),
              "duration": event.end
                  .difference(event.start)
                  .pretty(
                    locale: locale.durationLocale,
                    tersity: DurationTersity.second,
                    upperTersity: DurationTersity.hour,
                  ),
            },
          ),
        ),
      );
    },
  );
}

class _CalendarViewScreenControls extends StatefulWidget {
  const _CalendarViewScreenControls({
    required this.controller,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.getBodyHeight,
  });

  final CalendarController controller;
  final _ViewMode viewMode;
  final ValueChanged<_ViewMode> onViewModeChanged;
  final double Function() getBodyHeight;

  @override
  State<_CalendarViewScreenControls> createState() =>
      __CalendarViewScreenControlsState();
}

class __CalendarViewScreenControlsState
    extends State<_CalendarViewScreenControls> {
  void _applyZoom(MultiDayViewController viewController, double factor) {
    final heightPerMinute = viewController.heightPerMinute;
    final scrollController = viewController.scrollController;
    final height = heightPerMinute.value;
    final newHeight = height * factor;
    final yOffset = widget.getBodyHeight() / 2;

    final clamped = newHeight.clamp(
      _minimumHeightPerMinute,
      _maximumHeightPerMinute,
    );

    final zoomRatio = switch (clamped / height) {
      final ratio when ratio.isFinite => ratio,
      _ => 1.0,
    };

    final scrollPosition = scrollController.position.pixels;

    final pointerPosition = scrollPosition + yOffset;
    final newPosition = (pointerPosition * zoomRatio) - yOffset;
    scrollController.jumpTo(newPosition);
    heightPerMinute.value = clamped;
  }

  Future<void> _changeCurrentDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: widget.controller.visibleDateTimeRange.value?.start,
      firstDate: DateTime(now.year),
      lastDate: DateTime(now.year + 1),
    );

    if (date == null) return;

    widget.controller.jumpToDate(date);
  }

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    final controller = widget.controller;
    final locale = Localizations.localeOf(context);

    return Padding(
      padding: const EdgeInsets.all(spacing),
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          DropdownMenuChip<_ViewMode>(
            dropdownMenuEntries: [
              DropdownMenuEntry(
                label: context.tr("calendar_view.view_mode.single_day"),
                value: _ViewMode.singleDay,
              ),
              DropdownMenuEntry(
                value: _ViewMode.threeDays,
                label: context.tr("calendar_view.view_mode.three_days"),
              ),
              DropdownMenuEntry(
                value: _ViewMode.week,
                label: context.tr("calendar_view.view_mode.week"),
              ),
              DropdownMenuEntry(
                value: _ViewMode.schedule,
                label: context.tr("calendar_view.view_mode.schedule"),
              ),
            ],
            initialSelection: _ViewMode.singleDay,
            onSelected: (value) {
              if (value == null) return;
              widget.onViewModeChanged(value);
            },
          ),
          ValueListenableBuilder(
            valueListenable: controller.visibleDateTimeRange,
            builder: (context, range, child) {
              if (range == null) return const SizedBox.shrink();
              final start = range.start;
              final year = start.year;
              final month = start.monthNameLocalized(locale.toLanguageTag());

              return ActionChip(
                onPressed: _changeCurrentDate,
                padding: const EdgeInsets.all(10),
                label: Text(
                  context.tr(
                    "calendar_view.current_month_and_year",
                    namedArgs: {"year": year.toString(), "month": month},
                  ),
                ),
              );
            },
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: spacing,
            runSpacing: spacing,
            children: [
              if (!Platform.isAndroid &&
                  !Platform.isIOS &&
                  widget.viewMode != _ViewMode.schedule) ...[
                ActionChip(
                  onPressed: () => controller.animateToPreviousPage(),
                  label: const Icon(Icons.navigate_before),
                ),
                ActionChip(
                  onPressed: () => controller.animateToNextPage(),
                  label: const Icon(Icons.navigate_next),
                ),
              ],
              ActionChip(
                onPressed: () => controller.animateToDateTime(DateTime.now()),
                label: const Icon(Icons.today),
              ),
              if (widget.viewMode != _ViewMode.schedule) ...[
                ActionChip(
                  label: const Icon(Icons.zoom_in),
                  onPressed: () {
                    final viewController = controller.viewController;
                    if (viewController is MultiDayViewController) {
                      _applyZoom(viewController, 2);
                    }
                  },
                ),
                ActionChip(
                  label: const Icon(Icons.zoom_out),
                  onPressed: () {
                    final viewController = controller.viewController;
                    if (viewController is MultiDayViewController) {
                      _applyZoom(viewController, 0.5);
                    }
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarZoomDetector extends StatefulWidget {
  final Widget child;
  final CalendarController controller;
  const _CalendarZoomDetector({required this.child, required this.controller});

  @override
  State<_CalendarZoomDetector> createState() => _CalendarZoomDetectorState();
}

class ScrollBehaviorNever extends ScrollBehavior {
  const ScrollBehaviorNever();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const NeverScrollableScrollPhysics();
}

class AllowMultipleGestureRecognizer extends ScaleGestureRecognizer {
  /// Allow this gesture recognizer to always win the gesture arena, this might result in two recognizers winning.
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}

class _CalendarZoomDetectorState extends State<_CalendarZoomDetector> {
  final _scrollSensitivity = 0.1;

  MultiDayViewController? get viewController {
    return switch (widget.controller.viewController) {
      MultiDayViewController controller => controller,
      _ => null,
    };
  }

  ScrollController? get scrollController => viewController?.scrollController;
  ValueNotifier<double>? get heightPerMinute => viewController?.heightPerMinute;
  ValueNotifier<bool> lock = ValueNotifier(false);
  double _yOffset = 0;
  double _previousScale = 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(handler);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(handler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        AllowMultipleGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              AllowMultipleGestureRecognizer
            >(AllowMultipleGestureRecognizer.new, (instance) {
              instance.onStart = (details) {
                _yOffset = details.localFocalPoint.dy;
                _previousScale = 0;
                if (details.pointerCount <= 1) return;
                lock.value = true;
              };
              instance.onEnd = (_) => lock.value = false;
              instance.onUpdate = (details) {
                if (details.pointerCount <= 1) return;
                final height = heightPerMinute?.value;
                if (height == null) return;
                final delta =
                    -(_previousScale - math.log(details.verticalScale));
                _previousScale = math.log(details.verticalScale);
                final newHeight = height + delta;
                update(height, newHeight);
              };
            }),
      },
      child: Listener(
        onPointerHover: (event) => _yOffset = event.localPosition.dy,
        onPointerSignal: (event) {
          // Check that control is pressed
          if (!HardwareKeyboard.instance.isControlPressed) return;

          final height = heightPerMinute?.value;
          if (height == null) return;

          double newHeight;

          if (event is PointerScaleEvent) {
            // Handle web.
            newHeight = scale(event, height);
          } else if (event is PointerScrollEvent) {
            // Handle desktop.
            newHeight = scroll(event, height);
          } else {
            return;
          }

          update(height, newHeight);
        },
        onPointerPanZoomStart: (event) {
          lock.value = true;
        },
        onPointerPanZoomUpdate: (event) {
          if (lock.value == false) return;
          final height = heightPerMinute?.value;
          if (height == null) return;
          final newHeight = scaleTrackpad(event, height);
          update(height, newHeight);
        },
        onPointerPanZoomEnd: (_) => lock.value = false,
        behavior: HitTestBehavior.translucent,
        child: ValueListenableBuilder(
          valueListenable: lock,
          builder: (context, value, _) => ScrollConfiguration(
            behavior: value
                ? const ScrollBehaviorNever()
                : const MaterialScrollBehavior(),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  bool handler(KeyEvent event) {
    lock.value = HardwareKeyboard.instance.isControlPressed;
    return false;
  }

  double scaleTrackpad(PointerPanZoomUpdateEvent event, double height) {
    return height * math.pow(2, math.log(event.scale) / 12);
  }

  double scale(PointerScaleEvent event, double height) {
    return height * math.pow(2, math.log(event.scale) / 4);
  }

  double scroll(PointerScrollEvent event, double height) {
    return height + event.scrollDelta.dy.sign * -1 * _scrollSensitivity;
  }

  void update(double height, double newHeight) {
    final clamped = newHeight.clamp(
      _minimumHeightPerMinute,
      _maximumHeightPerMinute,
    );

    final zoomRatio = switch (clamped / height) {
      final ratio when ratio.isFinite => ratio,
      _ => 1.0,
    };
    final scrollPosition = scrollController?.position.pixels;
    if (scrollPosition == null) return;

    final pointerPosition = scrollPosition + _yOffset;
    final newPosition = (pointerPosition * zoomRatio) - _yOffset;
    scrollController?.jumpTo(newPosition);
    heightPerMinute?.value = clamped;
  }
}

class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final event = this.event as _TaskEvent;
    final measurement = event.measurement;
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);

    if (event.isActive) {
      SecondTickProvider.of(context);
    }

    final start = event.start.toLocal();
    final end = event.isActive ? DateTime.now() : measurement.end;
    final duration = end.difference(start);

    return BottomSheetSafeArea(
      basePadding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(event.title, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  context.pop();
                  context.push(
                    "/task",
                    extra: LazyTaskViewParams(event.taskId),
                  );
                },
                icon: Icon(
                  Icons.launch,
                  size: theme.textTheme.headlineLarge?.fontSize,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              "calendar_view.event_details_duration",
              args: [duration.pretty(locale: locale.durationLocale)],
            ),
          ),
          Text(
            context.tr(
              "calendar_view.event_details_start_end",
              namedArgs: {
                "start": DateFormat.Hm(locale.toLanguageTag()).format(start),
                "end": DateFormat.Hm(locale.toLanguageTag()).format(end),
              },
            ),
          ),
        ],
      ),
    );
  }
}
