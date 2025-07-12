import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:round_task/db/db.dart' as db;
import 'package:round_task/models/task.dart';
import 'package:round_task/models/time_measurement.dart';
import 'package:sqlite3/sqlite3.dart';

final databasePod = NotifierProvider<DatabaseNotifier, db.AppDatabase>(
  DatabaseNotifier.new,
);

// no need to dispose, since they are used in the main screen of the app
final _innerQueuedTasksPod = StreamProvider((ref) async* {
  final database = ref.watch(databasePod);

  yield* database.getQueuedTasksStream();
});

final queuedTasksPod = Provider.family.autoDispose((ref, TaskSorting? sorting) {
  final tasks = ref.watch(_innerQueuedTasksPod);

  // tasks already come sorted by reference
  if (sorting == null) return tasks;

  if (tasks case AsyncData()) {
    return tasks.applySorting(sorting);
  }

  return tasks;
});

final _innerPendingTasksPod = StreamProvider((ref) async* {
  final database = ref.watch(databasePod);

  yield* database.getPendingTasksStream();
});

final pendingTasksPod = Provider.family.autoDispose((
  ref,
  TaskSorting sorting,
) {
  final tasks = ref.watch(_innerPendingTasksPod);

  // tasks already come sorted by creation date
  if (sorting == TaskSorting.creationDate) return tasks;

  if (tasks case AsyncData()) {
    return tasks.applySorting(sorting);
  }

  return tasks;
});

final archivedTasksPod = StreamProvider.autoDispose((ref) async* {
  final database = ref.watch(databasePod);

  yield* database.getArchivedTasksStream();
});

final currentlyTrackedTaskPod = StreamProvider.autoDispose((ref) async* {
  final database = ref.watch(databasePod);

  yield* database.getCurrentlyTrackedTaskStream();
});

final taskByIdPod =
    StreamProvider.autoDispose.family<db.UserTask?, int>((ref, taskId) {
  final db = ref.watch(databasePod);
  return db.getTaskByIdStream(taskId);
});

final taskSubTasksPod =
    StreamProvider.autoDispose.family<List<db.SubTask>, int>((ref, taskId) {
  final database = ref.watch(databasePod);
  return database.getSubTasksStream(taskId);
});

final taskTimeMeasurementsPod = StreamProvider.autoDispose
    .family<List<db.TimeMeasurement>, int>((ref, taskId) {
  final database = ref.watch(databasePod);

  return database.getTimeMeasurementsStream(taskId);
});

enum TaskSorting {
  creationDate,
  autoInsertDate,
  endDate;

  DateTime? Function(db.UserTask task) get _keyOf {
    return switch (this) {
      TaskSorting.creationDate => (task) => task.createdAt,
      TaskSorting.autoInsertDate => (task) => task.autoInsertDate,
      TaskSorting.endDate => (task) => task.endDate,
    };
  }
}

int _compareNullableDatetime(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

extension on AsyncData<List<db.UserTask>> {
  AsyncData<List<db.UserTask>> applySorting(TaskSorting sorting) {
    return AsyncData(value.sortedByCompare(
      sorting._keyOf,
      _compareNullableDatetime,
    ));
  }
}

typedef _IsarMigrationData = ({
  List<db.UserTasksCompanion> tasks,
  List<db.SubTasksCompanion> subTasks,
  List<db.TimeMeasurementsCompanion> timeMeasurements,
});

class DatabaseNotifier extends Notifier<db.AppDatabase> {
  late final String databasePath;

  @override
  db.AppDatabase build() {
    final completer = Completer<_IsarMigrationData?>();
    final executor = LazyDatabase(() async {
      final dir = Platform.isAndroid || Platform.isIOS
          ? await getApplicationDocumentsDirectory()
          : await getApplicationSupportDirectory();

      databasePath = join(dir.path, "round_task.sqlite");
      final file = File(databasePath);
      final isarFile = File(join(dir.path, '${Isar.defaultName}.isar'));

      if (await isarFile.exists()) {
        final isar = await Isar.open(
          [UserTaskSchema, SubTaskSchema, TaskDirSchema, TimeMeasurementSchema],
          directory: dir.path,
        );
        final companions = await _getIsarCompanions(isar);
        completer.complete(companions);
        await isar.close(deleteFromDisk: true);
        final lockFile = File(join(dir.path, '${Isar.defaultName}.isar-lck'));

        if (await lockFile.exists()) {
          await lockFile.delete();
        }
      } else {
        completer.complete(null);
      }

      return NativeDatabase.createInBackground(file);
    });

    final database = db.AppDatabase(executor);
    ref.onDispose(() => state.close());

    database.init(runIsarMigration: (database) async {
      final data = await completer.future;
      if (data == null) return;

      await _runIsarMigration(database, data);
    });

    return database;
  }

  Future<void> exportData(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    if (await file.exists()) {
      await file.delete();
    }

    await state.customStatement("VACUUM INTO ?", [path]);
  }

  Future<void> importData(String path) async {
    await state.close();

    try {
      final importedDb = sqlite3.open(path);
      final tempDir = await getTemporaryDirectory();
      final tempDbPath = join(tempDir.path, "temp_round_task.sqlite");
      final tempDbFile = File(tempDbPath);

      if (await tempDbFile.exists()) {
        await tempDbFile.delete();
      }

      try {
        importedDb.execute("VACUUM INTO ?", [tempDbPath]);
      } finally {
        importedDb.dispose();
      }

      await tempDbFile.copy(databasePath);
      await tempDbFile.delete();
    } finally {
      state = db.AppDatabase(
        NativeDatabase.createInBackground(File(databasePath)),
      );
      await state.init();
    }
  }
}

Future<_IsarMigrationData> _getIsarCompanions(Isar isar) async {
  final tasks = await isar.userTasks.where().anyId().findAll();

  final taskCompanions = <db.UserTasksCompanion>[];
  final subTaskCompanions = <db.SubTasksCompanion>[];
  final timeMeasurementCompanions = <db.TimeMeasurementsCompanion>[];
  for (final (index, task) in tasks.indexed) {
    final taskId = index + 1;
    final taskCompanion = db.UserTasksCompanion.insert(
      id: Value(taskId),
      title: task.title,
      description: task.description,
      reference: Value(task.reference),
      activeTimeMeasurementStart: Value(task.activeTimeMeasurementStart),
      startDate: Value(task.startDate),
      endDate: Value(task.endDate),
      progress: Value(task.progress),
      recurrence: Value(task.recurrence),
      status: switch (task) {
        UserTask(reference: _?) => db.TaskStatus.active,
        UserTask(archived: true) => db.TaskStatus.archived,
        _ => db.TaskStatus.pending,
      },
      createdAt: task.creationDate,
      updatedByUserAt: task.lastTouched,
    );

    await task.subTasks.load();
    await task.timeMeasurements.load();

    taskCompanions.add(taskCompanion);
    subTaskCompanions.addAll(task.subTasks.map((subTask) {
      return db.SubTasksCompanion.insert(
        taskId: taskId,
        title: subTask.name,
        done: subTask.done,
        reference: subTask.reference,
      );
    }));
    timeMeasurementCompanions
        .addAll(task.timeMeasurements.map((timeMeasurement) {
      return db.TimeMeasurementsCompanion.insert(
        taskId: taskId,
        start: timeMeasurement.startTime,
        end: timeMeasurement.endTime,
      );
    }));
  }

  return (
    tasks: taskCompanions,
    subTasks: subTaskCompanions,
    timeMeasurements: timeMeasurementCompanions,
  );
}

Future<void> _runIsarMigration(
  db.AppDatabase database,
  _IsarMigrationData data,
) async {
  final (:tasks, :subTasks, :timeMeasurements) = data;

  await database.batch((batch) {
    batch.insertAll(database.userTasks, tasks);
    batch.insertAll(database.subTasks, subTasks);
    batch.insertAll(database.timeMeasurements, timeMeasurements);
  });
}
