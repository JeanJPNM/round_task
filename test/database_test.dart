import 'dart:ui' show Color;

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:round_task/db/db.dart';
import 'package:rrule/rrule.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_better_trigram/sqlite_better_trigram.dart';
import 'test_helpers.dart';

void main() {
  late AppDatabase db;

  setUpAll(() {
    sqlite3.ensureExtensionLoaded(BetterTrigram.load());
  });

  setUp(() async {
    db = AppDatabase(
      immediate: true,
      drift.DatabaseConnection(
        NativeDatabase.memory(sqlite3: () => sqlite3),
        closeStreamsSynchronously: true,
      ),
    );
    await db.init();
  });

  tearDown(() async {
    await db.close();
  });

  group('Queue management & reordering', () {
    test(
      'PutTaskInQueue with QueueInsertionPosition.start on empty queue assigns reference 0 and active status',
      () async {
        final task = await db.writeTask(
          _createTaskCompanion(status: TaskStatus.pending),
          [PutTaskInQueue(QueueInsertionPosition.start)],
        );

        expect(task.status, equals(TaskStatus.active));
        expect(task.reference, equals(0));

        final fetched = (await db.getTaskById(task.id).getSingleOrNull())!;
        expect(fetched.status, equals(TaskStatus.active));
        expect(fetched.reference, equals(0));
      },
    );

    test(
      'PutTaskInQueue with QueueInsertionPosition.start on non-empty queue prepends with min - 256',
      () async {
        await db.writeTask(
          _createTaskCompanion(reference: const drift.Value(100)),
        );
        await db.writeTask(
          _createTaskCompanion(reference: const drift.Value(300)),
        );

        final newTask = await db.writeTask(
          _createTaskCompanion(title: 'Prepended Task'),
          [PutTaskInQueue(QueueInsertionPosition.start)],
        );

        expect(newTask.reference, equals(100 - 256));
      },
    );

    test(
      'PutTaskInQueue with QueueInsertionPosition.end on non-empty queue appends with max + 256',
      () async {
        await db.writeTask(
          _createTaskCompanion(reference: const drift.Value(100)),
        );
        await db.writeTask(
          _createTaskCompanion(reference: const drift.Value(300)),
        );

        final newTask = await db.writeTask(
          _createTaskCompanion(title: 'Appended Task'),
          [PutTaskInQueue(QueueInsertionPosition.end)],
        );

        expect(newTask.reference, equals(300 + 256));
      },
    );

    test(
      'PutTaskInQueue with QueueInsertionPosition.preferred places task at start when autoInsertDate is in the past',
      () async {
        await db.writeTask(
          _createTaskCompanion(reference: const drift.Value(100)),
        );

        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        final newTask = await db.writeTask(
          _createTaskCompanion(
            title: 'Past Task',
            startDate: drift.Value(pastDate),
          ),
          [PutTaskInQueue(QueueInsertionPosition.preferred)],
        );

        expect(newTask.reference, equals(100 - 256));
      },
    );

    test(
      'PutTaskInQueue with QueueInsertionPosition.preferred places task at end when autoInsertDate is in the future or null',
      () async {
        await db.writeTask(
          _createTaskCompanion(reference: const drift.Value(100)),
        );

        final futureDate = DateTime.now().add(const Duration(days: 1));
        final newTaskWithFutureDate = await db.writeTask(
          _createTaskCompanion(
            title: 'Future Task',
            startDate: drift.Value(futureDate),
          ),
          [PutTaskInQueue(QueueInsertionPosition.preferred)],
        );

        expect(newTaskWithFutureDate.reference, equals(100 + 256));

        final newTaskWithoutDate = await db.writeTask(
          _createTaskCompanion(title: 'No Date Task'),
          [PutTaskInQueue(QueueInsertionPosition.preferred)],
        );

        expect(newTaskWithoutDate.reference, equals(356 + 256));
      },
    );

    test(
      'RemoveTaskFromQueue sets status to pending and clears reference',
      () async {
        final activeTask = await db.writeTask(
          _createTaskCompanion(
            status: TaskStatus.active,
            reference: const drift.Value(256),
          ),
        );

        final updatedTask = await db.writeTask(activeTask, [
          const RemoveTaskFromQueue(),
        ]);

        expect(updatedTask.status, equals(TaskStatus.pending));
        expect(updatedTask.reference, isNull);

        final fetched = (await db
            .getTaskById(activeTask.id)
            .getSingleOrNull())!;
        expect(fetched.status, equals(TaskStatus.pending));
        expect(fetched.reference, isNull);
      },
    );

    test(
      'reorderTasks updates task references sequentially in multiples of 256',
      () async {
        final taskA = await db.writeTask(
          _createTaskCompanion(title: 'A', reference: const drift.Value(0)),
        );
        final taskB = await db.writeTask(
          _createTaskCompanion(title: 'B', reference: const drift.Value(256)),
        );
        final taskC = await db.writeTask(
          _createTaskCompanion(title: 'C', reference: const drift.Value(512)),
        );

        // Reorder to [C, A, B]
        await db.reorderTasks([taskC, taskA, taskB]);

        final queued = await db.getQueuedTasksStream().first;
        expect(queued.map((t) => t.id), equals([taskC.id, taskA.id, taskB.id]));
        expect(queued.map((t) => t.reference), equals([0, 256, 512]));
      },
    );
  });

  group('Time measurements', () {
    test(
      'UndoStopTimeMeasurement should restore the active time measurement',
      () async {
        // 1. Create a task and start a time measurement
        final task = UserTasksCompanion.insert(
          title: 'Test Task',
          description: 'Test Description',
          status: TaskStatus.active,
          createdAt: DateTime.now(),
          updatedByUserAt: DateTime.now(),
        );
        final insertedTask = await db.writeTask(task);
        final taskId = insertedTask.id;

        final startTime = DateTime.now();
        final startedTask = await db.writeTask(insertedTask, [
          StartTimeMeasurement(startTime),
        ]);

        // 2. Stop the time measurement
        final stopTime = startTime.add(const Duration(minutes: 1));
        final stoppedTask = await db.writeTask(startedTask, [
          StopTimeMeasurement(stopTime),
        ]);

        // 3. Verify the time measurement is stopped
        expect(stoppedTask.activeTimeMeasurementStart, isNull);
        expect(await _getMeasurementCount(db, taskId), equals(1));

        // 4. Undo the stop time measurement
        final restoredTask = await db.writeTask(insertedTask, [
          UndoStopTimeMeasurement(startTime),
        ]);

        // 5. Verify the time measurement is restored
        expect(restoredTask.activeTimeMeasurementStart, equalsDate(startTime));
        expect(await _getMeasurementCount(db, taskId), equals(0));
      },
    );

    test(
      'PutTimeMeasurement assigns the correct taskId to timeMeasurements',
      () async {
        final task = UserTasksCompanion.insert(
          title: 'Test Task',
          description: 'Test Description',
          status: TaskStatus.active,
          createdAt: DateTime.now(),
          updatedByUserAt: DateTime.now(),
        );

        final insertedTask = await db.writeTask(task, [
          PutTimeMeasurement(
            TimeMeasurementsCompanion.insert(
              taskId: 200,
              start: DateTime.now(),
              end: DateTime.now().add(const Duration(minutes: 30)),
            ),
          ),
        ]);

        final taskId = insertedTask.id;
        final timeMeasurements = await db.getTaskTimeMeasurements(taskId).get();

        expect(timeMeasurements.first.taskId, equals(taskId));
      },
    );

    test('getAllTimeMeasurements should ignore soft-deleted tasks', () async {
      // 1. Create a task and add a time measurement
      final task = UserTasksCompanion.insert(
        title: 'Test Task',
        description: 'Test Description',
        status: TaskStatus.active,
        createdAt: DateTime.now(),
        updatedByUserAt: DateTime.now(),
      );
      final insertedTask = await db.writeTask(task, [
        PutTimeMeasurement(
          TimeMeasurementsCompanion.insert(
            taskId: -1,
            start: DateTime.now(),
            end: DateTime.now().add(const Duration(minutes: 30)),
          ),
        ),
      ]);

      // 2. Soft-delete the task
      await db.writeTask(insertedTask, [SoftDeleteTask(DateTime.now())]);

      // 3. Verify the time measurement is not returned in getAllTimeMeasurements
      final measurements = await db.getAllTimeMeasurements().get();
      expect(measurements, isEmpty);
    });

    test(
      'StartTimeMeasurement stops any currently active time measurement on another task and logs measurement',
      () async {
        final taskA = await db.writeTask(_createTaskCompanion(title: 'Task A'));
        final taskB = await db.writeTask(_createTaskCompanion(title: 'Task B'));

        final startA = DateTime(2025, 1, 1, 10, 0);
        final startedTaskA = await db.writeTask(taskA, [
          StartTimeMeasurement(startA),
        ]);
        expect(startedTaskA.activeTimeMeasurementStart, equalsDate(startA));

        // Start measurement on Task B
        final startB = DateTime(2025, 1, 1, 10, 30);
        final startedTaskB = await db.writeTask(taskB, [
          StartTimeMeasurement(startB),
        ]);
        expect(startedTaskB.activeTimeMeasurementStart, equalsDate(startB));

        // Verify taskA was automatically stopped and its measurement recorded
        final updatedTaskA = (await db
            .getTaskById(taskA.id)
            .getSingleOrNull())!;
        expect(updatedTaskA.activeTimeMeasurementStart, isNull);

        final measurementsA = await db.getTaskTimeMeasurements(taskA.id).get();
        expect(measurementsA, hasLength(1));
        expect(measurementsA.first.start, equalsDate(startA));
        expect(measurementsA.first.end, equalsDate(startB));
      },
    );

    test(
      'StopTimeMeasurement records a TimeMeasurement entry and clears active tracking',
      () async {
        final task = await db.writeTask(_createTaskCompanion(title: 'Task'));
        final start = DateTime(2025, 1, 1, 10, 0);
        final started = await db.writeTask(task, [StartTimeMeasurement(start)]);

        final stop = DateTime(2025, 1, 1, 10, 45);
        final stopped = await db.writeTask(started, [
          StopTimeMeasurement(stop),
        ]);

        expect(stopped.activeTimeMeasurementStart, isNull);
        final measurements = await db.getTaskTimeMeasurements(task.id).get();
        expect(measurements, hasLength(1));
        expect(measurements.first.start, equalsDate(start));
        expect(measurements.first.end, equalsDate(stop));
      },
    );

    test(
      'StopTimeMeasurement does nothing if task was not actively tracking',
      () async {
        final task = await db.writeTask(_createTaskCompanion(title: 'Task'));
        final stop = DateTime(2025, 1, 1, 10, 45);
        final result = await db.writeTask(task, [StopTimeMeasurement(stop)]);

        expect(result.activeTimeMeasurementStart, isNull);
        final measurements = await db.getTaskTimeMeasurements(task.id).get();
        expect(measurements, isEmpty);
      },
    );

    test(
      'RemoveTimeMeasurement removes the specified time measurement',
      () async {
        final task = await db.writeTask(_createTaskCompanion(title: 'Task'));
        final m1 = await db
            .into(db.timeMeasurements)
            .insertReturning(
              TimeMeasurementsCompanion.insert(
                taskId: task.id,
                start: DateTime(2025, 1, 1, 9, 0),
                end: DateTime(2025, 1, 1, 9, 30),
              ),
            );
        final m2 = await db
            .into(db.timeMeasurements)
            .insertReturning(
              TimeMeasurementsCompanion.insert(
                taskId: task.id,
                start: DateTime(2025, 1, 1, 10, 0),
                end: DateTime(2025, 1, 1, 10, 30),
              ),
            );

        expect(await db.getTaskTimeMeasurements(task.id).get(), hasLength(2));

        await db.writeTask(task, [RemoveTimeMeasurement(m1)]);

        final remaining = await db.getTaskTimeMeasurements(task.id).get();
        expect(remaining, hasLength(1));
        expect(remaining.first.id, equals(m2.id));
      },
    );

    test(
      'getCurrentlyTrackedTaskStream emits updates as tracking starts and stops',
      () async {
        expect(await db.getCurrentlyTrackedTaskStream().first, isNull);

        final task = await db.writeTask(_createTaskCompanion(title: 'Task'));
        final started = await db.writeTask(task, [
          StartTimeMeasurement(DateTime(2025, 1, 1, 10, 0)),
        ]);
        expect(
          (await db.getCurrentlyTrackedTaskStream().first)?.id,
          equals(started.id),
        );

        await db.writeTask(started, [
          StopTimeMeasurement(DateTime(2025, 1, 1, 11, 0)),
        ]);
        expect(await db.getCurrentlyTrackedTaskStream().first, isNull);
      },
    );

    test(
      'getTaskTimeMeasurements returns only measurements for specified task ordered by start descending',
      () async {
        final task1 = await db.writeTask(_createTaskCompanion(title: 'Task 1'));
        final task2 = await db.writeTask(_createTaskCompanion(title: 'Task 2'));

        await db
            .into(db.timeMeasurements)
            .insert(
              TimeMeasurementsCompanion.insert(
                taskId: task1.id,
                start: DateTime(2025, 1, 1, 8, 0),
                end: DateTime(2025, 1, 1, 8, 30),
              ),
            );
        await db
            .into(db.timeMeasurements)
            .insert(
              TimeMeasurementsCompanion.insert(
                taskId: task1.id,
                start: DateTime(2025, 1, 1, 12, 0),
                end: DateTime(2025, 1, 1, 12, 30),
              ),
            );
        await db
            .into(db.timeMeasurements)
            .insert(
              TimeMeasurementsCompanion.insert(
                taskId: task2.id,
                start: DateTime(2025, 1, 1, 10, 0),
                end: DateTime(2025, 1, 1, 10, 30),
              ),
            );

        final measurements1 = await db.getTaskTimeMeasurements(task1.id).get();
        expect(measurements1, hasLength(2));
        expect(measurements1[0].start, equalsDate(DateTime(2025, 1, 1, 12, 0)));
        expect(measurements1[1].start, equalsDate(DateTime(2025, 1, 1, 8, 0)));
      },
    );

    test(
      'getAllTimeMeasurements filters by after and before dates and orders by start ascending',
      () async {
        final task1 = await db.writeTask(_createTaskCompanion(title: 'Alpha'));
        final task2 = await db.writeTask(_createTaskCompanion(title: 'Beta'));

        await db
            .into(db.timeMeasurements)
            .insert(
              TimeMeasurementsCompanion.insert(
                taskId: task1.id,
                start: DateTime(2025, 1, 1, 9, 0),
                end: DateTime(2025, 1, 1, 10, 0),
              ),
            );
        await db
            .into(db.timeMeasurements)
            .insert(
              TimeMeasurementsCompanion.insert(
                taskId: task2.id,
                start: DateTime(2025, 1, 1, 11, 0),
                end: DateTime(2025, 1, 1, 12, 0),
              ),
            );

        final all = await db.getAllTimeMeasurements().get();
        expect(all, hasLength(2));
        expect(all[0].title, equals('Alpha'));
        expect(all[1].title, equals('Beta'));

        // Filter before 10:30 (end <= 10:30)
        final beforeFilter = await db
            .getAllTimeMeasurements(before: DateTime(2025, 1, 1, 10, 30))
            .get();
        expect(beforeFilter, hasLength(1));
        expect(beforeFilter.first.title, equals('Alpha'));

        // Filter after 10:00 (start <= 10:00)
        final afterFilter = await db
            .getAllTimeMeasurements(after: DateTime(2025, 1, 1, 10, 0))
            .get();
        expect(afterFilter, hasLength(1));
        expect(afterFilter.first.title, equals('Alpha'));
      },
    );
  });

  group('Subtasks', () {
    test(
      "getSubTasks should order the subTasks by their reference property",
      () async {
        final task = UserTasksCompanion.insert(
          title: 'Test Task',
          description: 'Test Description',
          status: TaskStatus.active,
          createdAt: DateTime.now(),
          updatedByUserAt: DateTime.now(),
        );
        final insertedTask = await db.writeTask(task, [
          PutSubTasks([
            SubTasksCompanion.insert(
              taskId: -1,
              title: 'Sub Task 2',
              done: true,
              reference: 2,
            ),
            SubTasksCompanion.insert(
              taskId: -1,
              title: 'Sub Task 1',
              done: false,
              reference: 1,
            ),
            SubTasksCompanion.insert(
              taskId: -1,
              title: "Sub Task 3",
              done: false,
              reference: 3,
            ),
          ]),
        ]);

        final taskId = insertedTask.id;
        final subTasks = await db.getSubTasks(taskId).get();

        expect([for (final subTask in subTasks) subTask.reference], [1, 2, 3]);
      },
    );

    test("PutSubTasks assigns the correct taskId to subTasks", () async {
      final task = UserTasksCompanion.insert(
        title: 'Test Task',
        description: 'Test Description',
        status: TaskStatus.active,
        createdAt: DateTime.now(),
        updatedByUserAt: DateTime.now(),
      );
      final insertedTask = await db.writeTask(task, [
        PutSubTasks([
          SubTasksCompanion.insert(
            taskId: 2,
            title: 'Sub Task 1',
            done: false,
            reference: 0,
          ),
          SubTasksCompanion.insert(
            taskId: 4,
            title: 'Sub Task 2',
            done: true,
            reference: 1,
          ),
          SubTasksCompanion.insert(
            taskId: 6,
            title: "Sub Task 3",
            done: false,
            reference: 2,
          ),
        ]),
      ]);

      final taskId = insertedTask.id;
      final subTasks = await db.getSubTasks(taskId).get();

      expect(subTasks, [
        SubTask(
          id: 1,
          taskId: taskId,
          title: 'Sub Task 1',
          done: false,
          reference: 0,
        ),
        SubTask(
          id: 2,
          taskId: taskId,
          title: 'Sub Task 2',
          done: true,
          reference: 1,
        ),
        SubTask(
          id: 3,
          taskId: taskId,
          title: "Sub Task 3",
          done: false,
          reference: 2,
        ),
      ]);
    });

    test("RestoreSubTasks should restore the original subTasks", () async {
      // 1. Create a task with sub-tasks
      final task = UserTasksCompanion.insert(
        title: 'Test Task',
        description: 'Test Description',
        status: TaskStatus.active,
        createdAt: DateTime.now(),
        updatedByUserAt: DateTime.now(),
      );
      final insertedTask = await db.writeTask(task, [
        PutSubTasks([
          SubTasksCompanion.insert(
            // writeTask will assign an ID, so we use -1 as a placeholder
            taskId: -1,
            title: 'Sub Task 1',
            done: false,
            reference: 0,
          ),
          SubTasksCompanion.insert(
            taskId: -1,
            title: 'Sub Task 2',
            done: false,
            reference: 1,
          ),
        ]),
      ]);
      final taskId = insertedTask.id;
      final subTasks = await db.getSubTasks(taskId).get();

      // 2. Remove the sub-tasks
      await db.writeTask(insertedTask, [
        RemoveSubTasks([subTasks.first.id]),
        PutSubTasks([
          SubTasksCompanion.insert(
            taskId: taskId,
            title: 'New Sub Task',
            done: false,
            reference: 0,
          ),
          SubTasksCompanion(
            id: drift.Value(subTasks.last.id),
            title: const drift.Value('Sub Task 2'),
            reference: const drift.Value(-1),
            done: const drift.Value(true),
          ),
        ]),
      ]);

      final newSubTasks = await db.getSubTasks(taskId).get();

      expect(newSubTasks, [
        SubTask(
          id: subTasks.last.id,
          taskId: taskId,
          title: 'Sub Task 2',
          done: true,
          reference: -1,
        ),
        SubTask(
          id: newSubTasks.last.id,
          taskId: taskId,
          title: 'New Sub Task',
          done: false,
          reference: 0,
        ),
      ]);

      // 4. Restore the original sub-tasks
      await db.writeTask(insertedTask, [RestoreSubTasks(subTasks)]);

      // 5. Verify the original sub-tasks are restored
      final restoredSubTasks = await db.getSubTasks(taskId).get();
      expect(restoredSubTasks, subTasks);
    });

    test('RemoveSubTasks removes only specified subtasks by id', () async {
      final task = await db.writeTask(_createTaskCompanion());
      final sub1 = await db
          .into(db.subTasks)
          .insertReturning(
            SubTasksCompanion.insert(
              taskId: task.id,
              title: 'Sub 1',
              done: false,
              reference: 1,
            ),
          );
      final sub2 = await db
          .into(db.subTasks)
          .insertReturning(
            SubTasksCompanion.insert(
              taskId: task.id,
              title: 'Sub 2',
              done: false,
              reference: 2,
            ),
          );
      final sub3 = await db
          .into(db.subTasks)
          .insertReturning(
            SubTasksCompanion.insert(
              taskId: task.id,
              title: 'Sub 3',
              done: false,
              reference: 3,
            ),
          );

      await db.writeTask(task, [
        RemoveSubTasks([sub1.id, sub3.id]),
      ]);

      final remaining = await db.getSubTasks(task.id).get();
      expect(remaining, hasLength(1));
      expect(remaining.first.id, equals(sub2.id));
    });

    test('PutSubTasks updates an existing subtask on conflict', () async {
      final task = await db.writeTask(_createTaskCompanion());
      final sub = await db
          .into(db.subTasks)
          .insertReturning(
            SubTasksCompanion.insert(
              taskId: task.id,
              title: 'Old Title',
              done: false,
              reference: 1,
            ),
          );

      await db.writeTask(task, [
        PutSubTasks([
          SubTasksCompanion(
            id: drift.Value(sub.id),
            taskId: drift.Value(task.id),
            title: const drift.Value('Updated Title'),
            done: const drift.Value(true),
            reference: const drift.Value(1),
          ),
        ]),
      ]);

      final subtasks = await db.getSubTasks(task.id).get();
      expect(subtasks, hasLength(1));
      expect(subtasks.first.title, equals('Updated Title'));
      expect(subtasks.first.done, isTrue);
    });
  });

  group('Task streams & reactive queries', () {
    test(
      'getQueuedTasksStream emits only active non-deleted tasks ordered by reference ascending',
      () async {
        await db.writeTask(
          _createTaskCompanion(title: 'Pending', status: TaskStatus.pending),
        );
        final a2 = await db.writeTask(
          _createTaskCompanion(
            title: 'A2',
            status: TaskStatus.active,
            reference: const drift.Value(200),
          ),
        );
        final a1 = await db.writeTask(
          _createTaskCompanion(
            title: 'A1',
            status: TaskStatus.active,
            reference: const drift.Value(100),
          ),
        );
        final softDeleted = await db.writeTask(
          _createTaskCompanion(
            title: 'Deleted',
            status: TaskStatus.active,
            reference: const drift.Value(50),
          ),
        );
        await db.writeTask(softDeleted, [SoftDeleteTask(DateTime.now())]);

        final queued = await db.getQueuedTasksStream().first;
        expect(queued.map((t) => t.id), equals([a1.id, a2.id]));
      },
    );

    test(
      'getPendingTasksStream emits only pending non-deleted tasks ordered by createdAt ascending',
      () async {
        final p2 = await db.writeTask(
          _createTaskCompanion(
            title: 'P2',
            status: TaskStatus.pending,
            createdAt: DateTime(2025, 1, 2),
          ),
        );
        final p1 = await db.writeTask(
          _createTaskCompanion(
            title: 'P1',
            status: TaskStatus.pending,
            createdAt: DateTime(2025, 1, 1),
          ),
        );
        await db.writeTask(
          _createTaskCompanion(title: 'Active', status: TaskStatus.active),
        );

        final pending = await db.getPendingTasksStream().first;
        expect(pending.map((t) => t.id), equals([p1.id, p2.id]));
      },
    );

    test(
      'getArchivedTasksStream emits only archived non-deleted tasks ordered by updatedByUserAt descending',
      () async {
        final a1 = await db.writeTask(
          _createTaskCompanion(
            title: 'A1',
            status: TaskStatus.archived,
            updatedByUserAt: DateTime(2025, 1, 1),
          ),
        );
        final a2 = await db.writeTask(
          _createTaskCompanion(
            title: 'A2',
            status: TaskStatus.archived,
            updatedByUserAt: DateTime(2025, 1, 2),
          ),
        );
        await db.writeTask(
          _createTaskCompanion(title: 'Active', status: TaskStatus.active),
        );

        final archived = await db.getArchivedTasksStream().first;
        expect(archived.map((t) => t.id), equals([a2.id, a1.id]));
      },
    );

    test(
      'getSoftDeletedTasksStream emits only soft-deleted tasks ordered by deletedAt descending',
      () async {
        final t1 = await db.writeTask(_createTaskCompanion(title: 'T1'));
        final t2 = await db.writeTask(_createTaskCompanion(title: 'T2'));
        await db.writeTask(_createTaskCompanion(title: 'Active'));

        await db.writeTask(t1, [SoftDeleteTask(DateTime(2025, 1, 1))]);
        await db.writeTask(t2, [SoftDeleteTask(DateTime(2025, 1, 2))]);

        final softDeleted = await db.getSoftDeletedTasksStream().first;
        expect(softDeleted.map((t) => t.id), equals([t2.id, t1.id]));
      },
    );
  });

  group('Scheduled tasks & cleanup', () {
    test(
      'getNextPendingTaskDate returns earliest autoInsertDate of pending tasks or null',
      () async {
        expect(await db.getNextPendingTaskDate(), isNull);

        final dateEarly = DateTime(2025, 3, 1, 10, 0);
        final dateLate = DateTime(2025, 3, 5, 10, 0);

        await db
            .into(db.userTasks)
            .insert(
              _createTaskCompanion(
                title: 'Late',
                status: TaskStatus.pending,
                startDate: drift.Value(dateLate),
              ),
            );
        await db
            .into(db.userTasks)
            .insert(
              _createTaskCompanion(
                title: 'Early',
                status: TaskStatus.pending,
                startDate: drift.Value(dateEarly),
              ),
            );

        final nextDate = await db.getNextPendingTaskDate();
        expect(nextDate, equalsDate(dateEarly));
      },
    );

    test(
      'getNextPendingTaskDate ignores active and archived tasks with autoInsertDate',
      () async {
        final date = DateTime(2025, 3, 1, 10, 0);

        await db
            .into(db.userTasks)
            .insert(
              _createTaskCompanion(
                title: 'Active Task',
                status: TaskStatus.active,
                startDate: drift.Value(date),
              ),
            );
        await db
            .into(db.userTasks)
            .insert(
              _createTaskCompanion(
                title: 'Archived Task',
                status: TaskStatus.archived,
                startDate: drift.Value(date),
              ),
            );

        expect(await db.getNextPendingTaskDate(), isNull);
      },
    );

    test(
      'addScheduledTasks promotes due pending tasks to active queue and prepends them',
      () async {
        // Existing active task with reference 100
        await db
            .into(db.userTasks)
            .insert(
              _createTaskCompanion(
                title: 'Active Task',
                status: TaskStatus.active,
                reference: const drift.Value(100),
              ),
            );

        final pastDate = DateTime.now().subtract(const Duration(hours: 1));
        final futureDate = DateTime.now().add(const Duration(hours: 2));

        final dueTask = await db
            .into(db.userTasks)
            .insertReturning(
              _createTaskCompanion(
                title: 'Due Task',
                status: TaskStatus.pending,
                startDate: drift.Value(pastDate),
              ),
            );

        final futureTask = await db
            .into(db.userTasks)
            .insertReturning(
              _createTaskCompanion(
                title: 'Future Task',
                status: TaskStatus.pending,
                startDate: drift.Value(futureDate),
              ),
            );

        final nextDate = await db.addScheduledTasks();

        // Due task should now be active and prepended (reference: 100 - 256 = -156)
        final updatedDueTask = (await db
            .getTaskById(dueTask.id)
            .getSingleOrNull())!;
        expect(updatedDueTask.status, equals(TaskStatus.active));
        expect(updatedDueTask.reference, equals(100 - 256));

        // Future task should still be pending
        final updatedFutureTask = (await db
            .getTaskById(futureTask.id)
            .getSingleOrNull())!;
        expect(updatedFutureTask.status, equals(TaskStatus.pending));

        // nextPendingDate returned should be the future task's date
        expect(nextDate, equalsDate(futureDate));
      },
    );

    test(
      'deleteSoftDeletedTasks deletes tasks older than 30 days and retains recent ones',
      () async {
        final now = DateTime.now();
        final oldDate = now.subtract(const Duration(days: 35));
        final recentDate = now.subtract(const Duration(days: 5));

        final oldTask = await db
            .into(db.userTasks)
            .insertReturning(
              _createTaskCompanion(
                title: 'Old Soft Deleted',
                deletedAt: drift.Value(oldDate),
              ),
            );
        final recentTask = await db
            .into(db.userTasks)
            .insertReturning(
              _createTaskCompanion(
                title: 'Recent Soft Deleted',
                deletedAt: drift.Value(recentDate),
              ),
            );

        await db.deleteSoftDeletedTasks();

        expect(await db.getTaskById(oldTask.id).getSingleOrNull(), isNull);
        expect(
          await db.getTaskById(recentTask.id).getSingleOrNull(),
          isNotNull,
        );
      },
    );

    test(
      'clearSoftDeletedTasks permanently removes all soft-deleted tasks immediately',
      () async {
        final task = await db
            .into(db.userTasks)
            .insertReturning(
              _createTaskCompanion(
                title: 'Soft Deleted',
                deletedAt: drift.Value(DateTime.now()),
              ),
            );

        await db.clearSoftDeletedTasks();

        expect(await db.getTaskById(task.id).getSingleOrNull(), isNull);
      },
    );
  });

  group('AppSettings', () {
    test('getAppSettings emits default settings when no row exists', () async {
      final settings = await db.getAppSettings().first;
      expect(settings.id, equals(0));
      expect(settings.brightness, equals(AppBrightness.system));
      expect(settings.seedColor, isNull);
    });

    test(
      'saveAppSettings inserts initial settings and updates existing settings',
      () async {
        // Insert
        await db.saveAppSettings(
          const AppSettingsTableCompanion(
            brightness: drift.Value(AppBrightness.dark),
            seedColor: drift.Value(Color(0xFF00FF00)),
          ),
        );

        final saved = await db.getAppSettings().first;
        expect(saved.brightness, equals(AppBrightness.dark));
        expect(saved.seedColor, equals(const Color(0xFF00FF00)));

        // Update
        await db.saveAppSettings(
          const AppSettingsTableCompanion(
            brightness: drift.Value(AppBrightness.light),
          ),
        );

        final updated = await db.getAppSettings().first;
        expect(updated.brightness, equals(AppBrightness.light));
        expect(updated.seedColor, equals(const Color(0xFF00FF00)));
      },
    );
  });

  group('Full-text search & triggers', () {
    test("searchTasks should ignore soft-deleted tasks", () async {
      // 1. Create a task and add a time measurement
      final task = UserTasksCompanion.insert(
        title: 'Test Task',
        description: 'Test Description',
        status: TaskStatus.active,
        createdAt: DateTime.now(),
        updatedByUserAt: DateTime.now(),
      );
      final insertedTask = await db.writeTask(task);

      // 2. Soft-delete the task
      await db.writeTask(insertedTask, [SoftDeleteTask(DateTime.now())]);

      // 3. Verify the time measurement is not returned in getAllTimeMeasurements
      final searchedTasks = await db
          .searchTasks(TaskStatus.active, "test")
          .get();
      // fts5 doesn't handle empty strings, so searchTasks uses another query in that case
      final emptySearchTasks = await db
          .searchTasks(TaskStatus.active, "")
          .get();

      expect(searchedTasks, isEmpty);
      expect(emptySearchTasks, isEmpty);
    });

    test(
      'searchTasks finds tasks by matching query in title or description',
      () async {
        await db.writeTask(
          _createTaskCompanion(
            title: 'Groceries',
            description: 'Buy organic almond milk',
          ),
        );
        await db.writeTask(
          _createTaskCompanion(
            title: 'Workout',
            description: 'Run 5 kilometers',
          ),
        );

        final titleSearch = await db
            .searchTasks(TaskStatus.active, 'Groceries')
            .get();
        expect(titleSearch, hasLength(1));
        expect(titleSearch.first.title, equals('Groceries'));

        final descSearch = await db
            .searchTasks(TaskStatus.active, 'almond')
            .get();
        expect(descSearch, hasLength(1));
        expect(descSearch.first.title, equals('Groceries'));

        final noMatch = await db
            .searchTasks(TaskStatus.active, 'nonexistent')
            .get();
        expect(noMatch, isEmpty);
      },
    );

    test('searchTasks filters results by TaskStatus', () async {
      await db.writeTask(
        _createTaskCompanion(title: 'Read book', status: TaskStatus.active),
      );
      await db.writeTask(
        _createTaskCompanion(
          title: 'Read newspaper',
          status: TaskStatus.pending,
        ),
      );
      await db.writeTask(
        _createTaskCompanion(
          title: 'Read journal',
          status: TaskStatus.archived,
        ),
      );

      final activeMatches = await db
          .searchTasks(TaskStatus.active, 'Read')
          .get();
      expect(activeMatches, hasLength(1));
      expect(activeMatches.first.title, equals('Read book'));

      final pendingMatches = await db
          .searchTasks(TaskStatus.pending, 'Read')
          .get();
      expect(pendingMatches, hasLength(1));
      expect(pendingMatches.first.title, equals('Read newspaper'));

      final archivedMatches = await db
          .searchTasks(TaskStatus.archived, 'Read')
          .get();
      expect(archivedMatches, hasLength(1));
      expect(archivedMatches.first.title, equals('Read journal'));
    });

    test(
      'searchTasks with empty search text returns all tasks matching status',
      () async {
        await db.writeTask(
          _createTaskCompanion(title: 'Task A', status: TaskStatus.active),
        );
        await db.writeTask(
          _createTaskCompanion(title: 'Task B', status: TaskStatus.active),
        );
        await db.writeTask(
          _createTaskCompanion(title: 'Task C', status: TaskStatus.pending),
        );

        final activeTasks = await db
            .searchTasks(TaskStatus.active, '   ')
            .get();
        expect(activeTasks, hasLength(2));
      },
    );

    test(
      'task_fts triggers update and delete search index synchronously',
      () async {
        final task = await db.writeTask(
          _createTaskCompanion(
            title: 'Alpha Title',
            description: 'Some description',
          ),
        );

        expect(
          await db.searchTasks(TaskStatus.active, 'Alpha').get(),
          hasLength(1),
        );

        // Update title
        await db.writeTask(task.copyWith(title: 'Beta Title'));
        expect(
          await db.searchTasks(TaskStatus.active, 'Beta').get(),
          hasLength(1),
        );
        expect(await db.searchTasks(TaskStatus.active, 'Alpha').get(), isEmpty);

        // Delete task
        await db.deleteTask(task);
        expect(await db.searchTasks(TaskStatus.active, 'Beta').get(), isEmpty);
      },
    );
  });

  group('Task CRUD & cascading deletion', () {
    test('undoSoftDeleteTask should restore a soft-deleted task', () async {
      // 1. Create and soft-delete a task
      final task = UserTasksCompanion.insert(
        title: 'Test Task',
        description: 'Test Description',
        status: TaskStatus.pending,
        createdAt: DateTime.now(),
        updatedByUserAt: DateTime.now(),
      );
      final insertedTask = await db.writeTask(task);
      await db.writeTask(insertedTask, [SoftDeleteTask(DateTime.now())]);

      // 2. Verify the task is soft-deleted
      final deletedTask = await (db.select(
        db.userTasks,
      )..where((t) => t.id.equals(insertedTask.id))).getSingle();
      expect(deletedTask.deletedAt, isNotNull);

      // 3. Undo the soft-delete
      await db.writeTask(deletedTask, [const UndoSoftDeleteTask()]);

      // 4. Verify the task is restored
      final restoredTask = await (db.select(
        db.userTasks,
      )..where((t) => t.id.equals(insertedTask.id))).getSingle();

      expect(restoredTask, equals(insertedTask));
    });

    test(
      "deleting a task also deletes the subTasks and timeMeasurements",
      () async {
        final task = UserTasksCompanion.insert(
          title: 'Test Task',
          description: 'Test Description',
          status: TaskStatus.active,
          createdAt: DateTime.now(),
          updatedByUserAt: DateTime.now(),
        );

        final insertedTask = await db.writeTask(task, [
          PutSubTasks([
            SubTasksCompanion.insert(
              taskId: -1,
              title: 'Sub Task 1',
              done: false,
              reference: 0,
            ),
            SubTasksCompanion.insert(
              taskId: -1,
              title: 'Sub Task 2',
              done: true,
              reference: 1,
            ),
          ]),
          PutTimeMeasurement(
            TimeMeasurementsCompanion.insert(
              taskId: -1,
              start: DateTime.now(),
              end: DateTime.now().add(const Duration(minutes: 30)),
            ),
          ),
          StartTimeMeasurement(DateTime.now()),
        ]);

        final taskId = insertedTask.id;
        final subTasks = await db.getSubTasks(taskId).get();
        final timeMeasurements = await db.getTaskTimeMeasurements(taskId).get();

        expect(subTasks, hasLength(2));
        expect(timeMeasurements, hasLength(1));

        // Delete the task
        await db.deleteTask(insertedTask);
        final deletedTask = await db.getTaskById(taskId).getSingleOrNull();
        final deletedSubTasks = await db.getSubTasks(taskId).get();
        final deletedTimeMeasurements = await db
            .getTaskTimeMeasurements(taskId)
            .get();

        expect(deletedTask, isNull);
        expect(deletedSubTasks, isEmpty);
        expect(deletedTimeMeasurements, isEmpty);
      },
    );

    test(
      "writing a task with null fields should set them to null, not treat them as missing",
      () async {
        final originalTask = await db.writeTask(
          UserTasksCompanion.insert(
            title: 'Test Task',
            description: 'Test Description',
            startDate: Value(DateTime(2025, 1, 1)),
            endDate: Value(DateTime(2025, 12, 31)),
            recurrence: Value(
              RecurrenceRule(frequency: Frequency.daily, interval: 1),
            ),
            status: TaskStatus.active,
            createdAt: DateTime.now(),
            updatedByUserAt: DateTime.now(),
          ),
        );

        await db.writeTask(
          originalTask.copyWith(
            recurrence: const Value(null),
            endDate: const Value(null),
          ),
        );

        final fetchedTask = (await db
            .getTaskById(originalTask.id)
            .getSingleOrNull())!;

        expect(fetchedTask.recurrence, isNull);
        expect(fetchedTask.endDate, isNull);
      },
    );

    test(
      'getTaskById returns the task if found, or null if not found',
      () async {
        final task = await db.writeTask(
          _createTaskCompanion(title: 'Unique Task'),
        );

        final found = await db.getTaskById(task.id).getSingleOrNull();
        expect(found, isNotNull);
        expect(found!.title, equals('Unique Task'));

        final notFound = await db.getTaskById(999999).getSingleOrNull();
        expect(notFound, isNull);
      },
    );

    test('writeTask updates existing task on conflict', () async {
      final original = await db.writeTask(
        _createTaskCompanion(
          title: 'Old Title',
          description: 'Old Description',
        ),
      );

      final updated = await db.writeTask(
        original.copyWith(
          title: 'New Title',
          progress: const drift.Value(0.75),
        ),
      );

      expect(updated.id, equals(original.id));
      expect(updated.title, equals('New Title'));
      expect(updated.progress, equals(0.75));

      final fetched = (await db.getTaskById(original.id).getSingleOrNull())!;
      expect(fetched.title, equals('New Title'));
      expect(fetched.progress, equals(0.75));
    });
  });
}

UserTasksCompanion _createTaskCompanion({
  String title = 'Test Task',
  String description = 'Test Description',
  TaskStatus status = TaskStatus.active,
  DateTime? createdAt,
  DateTime? updatedByUserAt,
  drift.Value<DateTime?> startDate = const drift.Value.absent(),
  drift.Value<DateTime?> endDate = const drift.Value.absent(),
  drift.Value<int?> reference = const drift.Value.absent(),
  drift.Value<double?> progress = const drift.Value.absent(),
  drift.Value<DateTime?> deletedAt = const drift.Value.absent(),
  drift.Value<DateTime?> activeTimeMeasurementStart =
      const drift.Value.absent(),
  drift.Value<TaskPriority> priority = const drift.Value.absent(),
}) {
  final now = DateTime(2026, 1, 1, 0, 0);
  return UserTasksCompanion.insert(
    title: title,
    description: description,
    status: status,
    createdAt: createdAt ?? now,
    updatedByUserAt: updatedByUserAt ?? now,
    startDate: startDate,
    endDate: endDate,
    reference: reference,
    progress: progress,
    deletedAt: deletedAt,
    activeTimeMeasurementStart: activeTimeMeasurementStart,
    priority: priority,
  );
}

Future<int> _getMeasurementCount(AppDatabase db, int taskId) async {
  final count = db.timeMeasurements.count(
    where: (t) => t.taskId.equals(taskId),
  );
  return await count.getSingle();
}
