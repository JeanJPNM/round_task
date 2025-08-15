import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:round_task/db/db.dart' as db;
import 'package:sqlite3/sqlite3.dart';

final databasePod = NotifierProvider<DatabaseNotifier, db.AppDatabase>(
  DatabaseNotifier.new,
);

// no need to dispose, since they are used in the main screen of the app
final _innerQueuedTasksPod = StreamProvider((ref) {
  final database = ref.watch(databasePod);

  return database.getQueuedTasksStream();
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

final _innerPendingTasksPod = StreamProvider((ref) {
  final database = ref.watch(databasePod);

  return database.getPendingTasksStream();
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

final archivedTasksPod = StreamProvider.autoDispose((ref) {
  final database = ref.watch(databasePod);

  return database.getArchivedTasksStream();
});

final currentlyTrackedTaskPod = StreamProvider.autoDispose((ref) {
  final database = ref.watch(databasePod);

  return database.getCurrentlyTrackedTaskStream();
});

final filteredTasksPod = StreamProvider.family.autoDispose((
  ref,
  TaskFilter filter,
) {
  final database = ref.watch(databasePod);

  return database.searchTasks(filter.status, filter.searchQuery).watch();
});

final taskByIdPod =
    StreamProvider.autoDispose.family<db.UserTask?, int>((ref, taskId) {
  final db = ref.watch(databasePod);
  return db.getTaskById(taskId).watchSingleOrNull();
});

final taskSubTasksPod =
    StreamProvider.autoDispose.family<List<db.SubTask>, int>((ref, taskId) {
  final database = ref.watch(databasePod);
  return database.getSubTasks(taskId).watch();
});

final taskTimeMeasurementsPod = StreamProvider.autoDispose
    .family<List<db.TimeMeasurement>, int>((ref, taskId) {
  final database = ref.watch(databasePod);

  return database.getTimeMeasurements(taskId).watch();
});

final appSettingsPod = StreamProvider.autoDispose((ref) {
  final database = ref.watch(databasePod);

  return database.getAppSettingsStream();
});

@immutable
class TaskFilter {
  const TaskFilter({
    required this.status,
    required this.searchQuery,
  });

  final db.TaskStatus status;
  final String searchQuery;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TaskFilter &&
        other.status == status &&
        other.searchQuery == searchQuery;
  }

  @override
  int get hashCode => Object.hash(status, searchQuery);
}

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

class DatabaseNotifier extends Notifier<db.AppDatabase> {
  late final String databasePath;

  @override
  db.AppDatabase build() {
    final executor = LazyDatabase(() async {
      final dir = Platform.isAndroid || Platform.isIOS
          ? await getApplicationDocumentsDirectory()
          : await getApplicationSupportDirectory();

      databasePath = join(dir.path, "round_task.sqlite");
      final file = File(databasePath);

      return NativeDatabase.createInBackground(file);
    });

    final database = db.AppDatabase(executor);
    ref.onDispose(() => state.close());

    database.init();

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
