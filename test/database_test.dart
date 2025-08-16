import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:round_task/db/db.dart';
import 'package:rrule/rrule.dart';
import 'test_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(drift.DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ));
    await db.init();
  });

  tearDown(() async {
    await db.close();
  });

  test("getSubTasks should order the subTasks by their reference property",
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
      ])
    ]);

    final taskId = insertedTask.id;
    final subTasks = await db.getSubTasks(taskId).get();

    expect([for (final subTask in subTasks) subTask.reference], [1, 2, 3]);
  });

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
    await db.softDeleteTask(insertedTask);

    // 2. Verify the task is soft-deleted
    final deletedTask = await (db.select(db.userTasks)
          ..where((t) => t.id.equals(insertedTask.id)))
        .getSingle();
    expect(deletedTask.deletedAt, isNotNull);

    // 3. Undo the soft-delete
    await db.undoSoftDeleteTask(deletedTask);

    // 4. Verify the task is restored
    final restoredTask = await (db.select(db.userTasks)
          ..where((t) => t.id.equals(insertedTask.id)))
        .getSingle();

    expect(restoredTask, equals(insertedTask));
  });

  test('UndoStopTimeMeasurement should restore the active time measurement',
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
    final startedTask = await db.writeTask(
      insertedTask,
      [StartTimeMeasurement(startTime)],
    );

    // 2. Stop the time measurement
    final stopTime = startTime.add(const Duration(minutes: 1));
    final stoppedTask = await db.writeTask(
      startedTask,
      [StopTimeMeasurement(stopTime)],
    );

    // 3. Verify the time measurement is stopped
    expect(stoppedTask.activeTimeMeasurementStart, isNull);
    expect(await _getMeasurementCount(db, taskId), equals(1));

    // 4. Undo the stop time measurement
    final restoredTask = await db.writeTask(
      insertedTask,
      [UndoStopTimeMeasurement(startTime)],
    );

    // 5. Verify the time measurement is restored
    expect(restoredTask.activeTimeMeasurementStart, equalsDate(startTime));
    expect(await _getMeasurementCount(db, taskId), equals(0));
  });

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
      ])
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

  test("PutTimeMeasurement assigns the correct taskId to timeMeasurements",
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
      ])
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
          id: Value(subTasks.last.id),
          title: const Value('Sub Task 2'),
          reference: const Value(-1),
          done: const Value(true),
        )
      ])
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

  test("deleting a task also deletes the subTasks and timeMeasurements",
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
    final deletedTimeMeasurements =
        await db.getTaskTimeMeasurements(taskId).get();

    expect(deletedTask, isNull);
    expect(deletedSubTasks, isEmpty);
    expect(deletedTimeMeasurements, isEmpty);
  });

  test(
      "writing a task with null fields should set them to null, not treat them as missing",
      () async {
    final originalTask = await db.writeTask(UserTasksCompanion.insert(
      title: 'Test Task',
      description: 'Test Description',
      startDate: Value(DateTime(2025, 1, 1)),
      endDate: Value(DateTime(2025, 12, 31)),
      recurrence: Value(RecurrenceRule(
        frequency: Frequency.daily,
        interval: 1,
      )),
      status: TaskStatus.active,
      createdAt: DateTime.now(),
      updatedByUserAt: DateTime.now(),
    ));

    await db.writeTask(originalTask.copyWith(
      recurrence: const Value(null),
      endDate: const Value(null),
    ));

    final fetchedTask =
        (await db.getTaskById(originalTask.id).getSingleOrNull())!;

    expect(fetchedTask.recurrence, isNull);
    expect(fetchedTask.endDate, isNull);
  });

  test("getAllTimeMeasurements should ignore soft-deleted tasks", () async {
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
    await db.softDeleteTask(insertedTask);

    // 3. Verify the time measurement is not returned in getAllTimeMeasurements
    final measurements = await db.getAllTimeMeasurements().get();
    expect(measurements, isEmpty);
  });
}

Future<int> _getMeasurementCount(AppDatabase db, int taskId) async {
  final count = db.timeMeasurements.count(
    where: (t) => t.taskId.equals(taskId),
  );
  return await count.getSingle();
}
