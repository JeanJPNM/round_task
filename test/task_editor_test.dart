import 'package:flutter_test/flutter_test.dart';
import 'package:round_task/db/db.dart';
import 'package:round_task/screens/task_view.dart';
import 'package:rrule/rrule.dart';

void main() {
  group('getNextTaskStatus', () {
    test('marking active task with no autoInsertDate done'
        ' transitions to archived', () {
      final status = getNextTaskStatus(
        currentStatus: TaskStatus.active,
        done: true,
        hasAutoInsertDate: false,
      );
      expect(status, equals(TaskStatus.archived));
    });

    test('marking active task with autoInsertDate done'
        ' transitions to pending', () {
      final status = getNextTaskStatus(
        currentStatus: TaskStatus.active,
        done: true,
        hasAutoInsertDate: true,
      );
      expect(status, equals(TaskStatus.pending));
    });

    test('editing archived task with autoInsertDate'
        ' unarchives to pending', () {
      final status = getNextTaskStatus(
        currentStatus: TaskStatus.archived,
        done: false,
        hasAutoInsertDate: true,
      );
      expect(status, equals(TaskStatus.pending));
    });

    test('editing archived task without autoInsertDate'
        ' remains archived', () {
      final status = getNextTaskStatus(
        currentStatus: TaskStatus.archived,
        done: false,
        hasAutoInsertDate: false,
      );
      expect(status, equals(TaskStatus.archived));
    });

    test('creating new task with null status defaults to pending', () {
      final status = getNextTaskStatus(
        currentStatus: null,
        done: false,
        hasAutoInsertDate: false,
      );
      expect(status, equals(TaskStatus.pending));
    });

    test('existing active task not marked done remains active', () {
      final status = getNextTaskStatus(
        currentStatus: TaskStatus.active,
        done: false,
        hasAutoInsertDate: false,
      );
      expect(status, equals(TaskStatus.active));
    });

    test('existing pending task not marked done remains pending', () {
      final status = getNextTaskStatus(
        currentStatus: TaskStatus.pending,
        done: false,
        hasAutoInsertDate: false,
      );
      expect(status, equals(TaskStatus.pending));
    });
  });

  group('getNextDate', () {
    final fixedNow = DateTime(2026, 3, 10, 12, 0);

    test('returns next date instance after now', () {
      final rule = RecurrenceRule(frequency: Frequency.daily, interval: 1);
      final startDate = DateTime(2026, 3, 5, 9, 0);

      final next = getNextDate(rule, startDate, fixedNow);

      expect(next, equals(DateTime(2026, 3, 11, 9, 0)));
    });

    test('returns next date when startDate is in the future', () {
      final rule = RecurrenceRule(frequency: Frequency.weekly, interval: 1);
      final futureStart = DateTime(2026, 3, 15, 10, 0);

      final next = getNextDate(rule, futureStart, fixedNow);

      expect(next, equals(DateTime(2026, 3, 22, 10, 0)));
    });
  });

  group('getNextOccurrence', () {
    final fixedNow = DateTime(2026, 5, 1, 10, 0);
    final dailyRule = RecurrenceRule(frequency: Frequency.daily, interval: 1);

    test('shifts start and maintains duration'
        ' when both start and end date provided', () {
      final start = DateTime(2026, 4, 25, 9, 0);
      final end = DateTime(2026, 4, 25, 11, 30); // 2h30m duration

      final next = getNextOccurrence(
        startDate: start,
        endDate: end,
        recurrence: dailyRule,
        now: fixedNow,
      );

      expect(next.startDate, equals(DateTime(2026, 5, 2, 9, 0)));
      expect(next.endDate, equals(DateTime(2026, 5, 2, 11, 30)));
      expect(next.recurrence, equals(dailyRule));
    });

    test('shifts end date when only endDate is provided', () {
      final end = DateTime(2026, 4, 25, 18, 0);

      // fixedNow is 2026-05-01 10:00, so today at 18:00 is next
      final next = getNextOccurrence(
        startDate: null,
        endDate: end,
        recurrence: dailyRule,
        now: fixedNow,
      );

      expect(next.startDate, isNull);
      expect(next.endDate, equals(DateTime(2026, 5, 1, 18, 0)));
      expect(next.recurrence, equals(dailyRule));

      // When now is after 18:00, shifts to tomorrow
      final afterNext = getNextOccurrence(
        startDate: null,
        endDate: end,
        recurrence: dailyRule,
        now: DateTime(2026, 5, 1, 19, 0),
      );
      expect(afterNext.endDate, equals(DateTime(2026, 5, 2, 18, 0)));
    });

    test('returns null dates when both start and end are null', () {
      final next = getNextOccurrence(
        startDate: null,
        endDate: null,
        recurrence: dailyRule,
        now: fixedNow,
      );

      expect(next.startDate, isNull);
      expect(next.endDate, isNull);
      expect(next.recurrence, equals(dailyRule));
    });

    test('decrements recurrence count when count > 1', () {
      final limitedRule = RecurrenceRule(frequency: Frequency.daily, count: 5);

      final next = getNextOccurrence(
        startDate: DateTime(2026, 4, 20),
        endDate: null,
        recurrence: limitedRule,
        now: fixedNow,
      );

      expect(next.recurrence?.count, equals(4));
    });

    test('clears recurrence rule when count reaches 1', () {
      final lastRule = RecurrenceRule(frequency: Frequency.daily, count: 1);

      final next = getNextOccurrence(
        startDate: DateTime(2026, 4, 20),
        endDate: null,
        recurrence: lastRule,
        now: fixedNow,
      );

      expect(next.recurrence, isNull);
    });
  });

  group('getQueueEditAction', () {
    test('removing active task from queue returns RemoveTaskFromQueue', () {
      final action = getQueueEditAction(
        position: null,
        taskStatus: TaskStatus.active,
      );
      expect(action, equals(const RemoveTaskFromQueue()));
    });

    test('position null for non-active task returns null', () {
      final action = getQueueEditAction(
        position: null,
        taskStatus: TaskStatus.pending,
      );
      expect(action, isNull);
    });

    test('preferred position for already active task returns null', () {
      final action = getQueueEditAction(
        position: QueueInsertionPosition.preferred,
        taskStatus: TaskStatus.active,
      );
      expect(action, isNull);
    });

    test(
      'preferred position for pending task returns PutTaskInQueue(preferred)',
      () {
        final action = getQueueEditAction(
          position: QueueInsertionPosition.preferred,
          taskStatus: TaskStatus.pending,
        );
        expect(
          action,
          isA<PutTaskInQueue>().having(
            (a) => a.position,
            'position',
            QueueInsertionPosition.preferred,
          ),
        );
      },
    );

    test('explicit start position returns PutTaskInQueue(start)', () {
      final action = getQueueEditAction(
        position: QueueInsertionPosition.start,
        taskStatus: TaskStatus.active,
      );
      expect(
        action,
        isA<PutTaskInQueue>().having(
          (a) => a.position,
          'position',
          QueueInsertionPosition.start,
        ),
      );
    });

    test('explicit end position returns PutTaskInQueue(end)', () {
      final action = getQueueEditAction(
        position: QueueInsertionPosition.end,
        taskStatus: TaskStatus.pending,
      );
      expect(
        action,
        isA<PutTaskInQueue>().having(
          (a) => a.position,
          'position',
          QueueInsertionPosition.end,
        ),
      );
    });
  });

  group('getShiftedEndDate', () {
    test('shifts end date by duration between newStart and previousStart', () {
      final prevStart = DateTime(2026, 6, 1, 9, 0);
      final currentEnd = DateTime(2026, 6, 1, 12, 0); // 3-hour difference
      final newStart = DateTime(2026, 6, 5, 14, 0);

      final shifted = getShiftedEndDate(
        newStart: newStart,
        previousStart: prevStart,
        currentEnd: currentEnd,
      );

      expect(shifted, equals(DateTime(2026, 6, 5, 17, 0)));
    });

    test('returns null if any argument is null', () {
      expect(
        getShiftedEndDate(
          newStart: null,
          previousStart: DateTime(2026, 1, 1),
          currentEnd: DateTime(2026, 1, 2),
        ),
        isNull,
      );
      expect(
        getShiftedEndDate(
          newStart: DateTime(2026, 1, 1),
          previousStart: null,
          currentEnd: DateTime(2026, 1, 2),
        ),
        isNull,
      );
      expect(
        getShiftedEndDate(
          newStart: DateTime(2026, 1, 1),
          previousStart: DateTime(2026, 1, 1),
          currentEnd: null,
        ),
        isNull,
      );
    });
  });

  group('getDefaultStartDate', () {
    test('returns midnight of end date', () {
      final endDate = DateTime(2026, 7, 20, 15, 30);
      final defaultStart = getDefaultStartDate(endDate);

      expect(defaultStart, equals(DateTime(2026, 7, 20, 0, 0)));
    });

    test('returns null when endDate is null', () {
      expect(getDefaultStartDate(null), isNull);
    });
  });

  group('isQueueLocked', () {
    final fixedNow = DateTime(2026, 8, 15, 12, 0);

    test('returns true when date is before now', () {
      final pastDate = DateTime(2026, 8, 15, 11, 59);
      expect(isQueueLocked(pastDate, fixedNow), isTrue);
    });

    test('returns false when date is after now', () {
      final futureDate = DateTime(2026, 8, 15, 12, 1);
      expect(isQueueLocked(futureDate, fixedNow), isFalse);
    });

    test('returns false when date is null', () {
      expect(isQueueLocked(null, fixedNow), isFalse);
    });
  });

  group('mapSubtaskIndex', () {
    test('returns exact index when no controllers are removed', () {
      final sub1 = SubTaskController(title: 'Sub 1', done: false);
      final sub2 = SubTaskController(title: 'Sub 2', done: false);
      final sub3 = SubTaskController(title: 'Sub 3', done: false);
      final list = [sub1, sub2, sub3];

      expect(mapSubtaskIndex(0, list), equals(0));
      expect(mapSubtaskIndex(1, list), equals(1));
      expect(mapSubtaskIndex(2, list), equals(2));
      expect(mapSubtaskIndex(3, list), equals(3));
    });

    test('skips removed controllers when mapping relative index', () {
      final sub1 = SubTaskController(title: 'Sub 1', done: false);
      final sub2 = SubTaskController(title: 'Sub 2', done: false)
        ..removed = true;
      final sub3 = SubTaskController(title: 'Sub 3', done: false);
      final list = [sub1, sub2, sub3];

      expect(mapSubtaskIndex(0, list), equals(0));
      expect(mapSubtaskIndex(1, list), equals(2));
      expect(mapSubtaskIndex(2, list), equals(3));
    });
  });

  group('SubTasksController', () {
    test('progress is null when no subtasks exist', () {
      final controller = SubTasksController([]);
      expect(controller.getProgress(), isNull);
    });

    test('progress calculates ratio of completed active subtasks', () {
      final sub1 = SubTaskController(title: 'Sub 1', done: true);
      final sub2 = SubTaskController(title: 'Sub 2', done: false);
      final sub3 = SubTaskController(title: 'Sub 3', done: true);
      final controller = SubTasksController([sub1, sub2, sub3]);

      expect(controller.getProgress(), closeTo(2 / 3, 0.001));

      controller.markAsRemoved(sub1);
      expect(controller.getProgress(), equals(0.5));
    });

    test(
      'calculateProgress with resetDone returns 0.0 when subtasks exist',
      () {
        final sub = SubTaskController(title: 'Sub 1', done: true);
        final controller = SubTasksController([sub]);

        expect(controller.getProgress(resetDone: true), equals(0.0));
      },
    );

    test('toCompanions sets reference sequentially and respects resetDone', () {
      final sub1 = SubTaskController(id: 1, title: 'First', done: true);
      final sub2 = SubTaskController(id: 2, title: 'Second', done: true);
      final controller = SubTasksController([sub1, sub2]);

      final normalCompanions = controller.toCompanions(resetDone: false);
      expect(normalCompanions[0].reference.value, equals(0));
      expect(normalCompanions[0].done.value, isTrue);
      expect(normalCompanions[1].reference.value, equals(1));
      expect(normalCompanions[1].done.value, isTrue);

      final resetCompanions = controller.toCompanions(resetDone: true);
      expect(resetCompanions[0].done.value, isFalse);
      expect(resetCompanions[1].done.value, isFalse);
    });

    test('setSubTasks clears and repopulates controllers from models', () {
      final controller = SubTasksController([
        SubTaskController(title: 'Initial', done: false),
      ]);

      controller.setSubTasks([
        const SubTask(
          id: 10,
          taskId: 1,
          title: 'Model 1',
          done: true,
          reference: 0,
        ),
        const SubTask(
          id: 11,
          taskId: 1,
          title: 'Model 2',
          done: false,
          reference: 1,
        ),
      ]);

      expect(controller.activeControllers, hasLength(2));
      expect(controller.controllers.first.id, equals(10));
      expect(
        controller.controllers.first.textController.value,
        equals('Model 1'),
      );
      expect(controller.controllers.first.doneController.value, isTrue);
    });

    test('markAsRemoved and markAsActive toggle removal and tracking', () {
      final sub1 = SubTaskController(id: 101, title: 'Item 1', done: false);
      final sub2 = SubTaskController(id: 102, title: 'Item 2', done: false);
      final controller = SubTasksController([sub1, sub2]);

      expect(controller.removedSubTaskIds(), isEmpty);

      controller.markAsRemoved(sub1);
      expect(controller.activeControllers, equals([sub2]));
      expect(controller.removedSubTaskIds(), equals([101]));

      controller.markAsActive(sub1);
      expect(controller.activeControllers, equals([sub1, sub2]));
      expect(controller.removedSubTaskIds(), isEmpty);
    });

    test('reorderActiveController reorders active items'
        ' accounting for removed ones', () {
      final sub1 = SubTaskController(title: 'A', done: false);
      final sub2 = SubTaskController(title: 'B', done: false)..removed = true;
      final sub3 = SubTaskController(title: 'C', done: false);
      final sub4 = SubTaskController(title: 'D', done: false);
      final controller = SubTasksController([sub1, sub2, sub3, sub4]);

      // Move 'D' (relative index 2) to before 'A' (relative index 0)
      controller.reorderActiveController(2, 0);

      final titles = controller.activeControllers
          .map((c) => c.textController.value)
          .toList();
      expect(titles, equals(['D', 'A', 'C']));
      expect(controller.controllers[2].textController.value, equals('B'));
    });
  });
}
