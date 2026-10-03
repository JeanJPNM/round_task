import 'dart:ui' show Color;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_task/db/db.dart';
import 'package:rrule/rrule.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_better_trigram/sqlite_better_trigram.dart';
import '../../test_helpers.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    sqlite3.ensureExtensionLoaded(BetterTrigram.load());
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  group('data integrity migrations', () {
    test('migration from v1 to v2 preserves data'
        ' and creates indexes and table', () async {
      final baseDate = DateTime.utc(2023, 11, 14, 22, 13, 20);
      final dailyRule = RecurrenceRule(frequency: Frequency.daily, interval: 1);

      final oldUserTasksData = <v1.UserTasksData>[
        v1.UserTasksData(
          id: 1,
          title: 'Task 1',
          description: 'Description 1',
          status: TaskStatus.active.toSql(),
          reference: 100,
          progress: 0.5,
          createdAt: baseDate.toSql(),
          updatedByUserAt: baseDate.toSql(),
          startDate: baseDate.toSql(),
          endDate: baseDate.add(const Duration(days: 1)).toSql(),
          autoInsertDate: baseDate.toSql(),
          recurrence: dailyRule.toSql(),
        ),
        v1.UserTasksData(
          id: 2,
          title: 'Task 2',
          description: 'Description 2',
          status: TaskStatus.pending.toSql(),
          createdAt: baseDate.add(const Duration(seconds: 1)).toSql(),
          updatedByUserAt: baseDate.add(const Duration(seconds: 1)).toSql(),
          deletedAt: baseDate.add(const Duration(seconds: 2)).toSql(),
        ),
      ];
      final expectedNewUserTasksData = <v2.UserTasksData>[
        v2.UserTasksData(
          id: 1,
          title: 'Task 1',
          description: 'Description 1',
          status: TaskStatus.active.toSql(),
          reference: 100,
          progress: 0.5,
          createdAt: baseDate.toSql(),
          updatedByUserAt: baseDate.toSql(),
          startDate: baseDate.toSql(),
          endDate: baseDate.add(const Duration(days: 1)).toSql(),
          autoInsertDate: baseDate.toSql(),
          recurrence: dailyRule.toSql(),
        ),
        v2.UserTasksData(
          id: 2,
          title: 'Task 2',
          description: 'Description 2',
          status: TaskStatus.pending.toSql(),
          createdAt: baseDate.add(const Duration(seconds: 1)).toSql(),
          updatedByUserAt: baseDate.add(const Duration(seconds: 1)).toSql(),
          deletedAt: baseDate.add(const Duration(seconds: 2)).toSql(),
        ),
      ];

      const oldSubTasksData = <v1.SubTasksData>[
        v1.SubTasksData(
          id: 1,
          taskId: 1,
          title: 'Sub Task 1',
          done: false,
          reference: 0,
        ),
        v1.SubTasksData(
          id: 2,
          taskId: 1,
          title: 'Sub Task 2',
          done: true,
          reference: 1,
        ),
        v1.SubTasksData(
          id: 3,
          taskId: 2,
          title: 'Sub Task 3',
          done: false,
          reference: 0,
        ),
      ];
      const expectedNewSubTasksData = <v2.SubTasksData>[
        v2.SubTasksData(
          id: 1,
          taskId: 1,
          title: 'Sub Task 1',
          done: false,
          reference: 0,
        ),
        v2.SubTasksData(
          id: 2,
          taskId: 1,
          title: 'Sub Task 2',
          done: true,
          reference: 1,
        ),
        v2.SubTasksData(
          id: 3,
          taskId: 2,
          title: 'Sub Task 3',
          done: false,
          reference: 0,
        ),
      ];

      final oldTimeMeasurementsData = <v1.TimeMeasurementsData>[
        v1.TimeMeasurementsData(
          id: 1,
          taskId: 1,
          start: baseDate.toSql(),
          end: baseDate.add(const Duration(minutes: 30)).toSql(),
        ),
        v1.TimeMeasurementsData(
          id: 2,
          taskId: 1,
          start: baseDate.add(const Duration(seconds: 2000)).toSql(),
          end: baseDate.add(const Duration(hours: 1)).toSql(),
        ),
        v1.TimeMeasurementsData(
          id: 3,
          taskId: 2,
          start: baseDate.add(const Duration(seconds: 4000)).toSql(),
          end: baseDate.add(const Duration(minutes: 90)).toSql(),
        ),
      ];
      final expectedNewTimeMeasurementsData = <v2.TimeMeasurementsData>[
        v2.TimeMeasurementsData(
          id: 1,
          taskId: 1,
          start: baseDate.toSql(),
          end: baseDate.add(const Duration(minutes: 30)).toSql(),
        ),
        v2.TimeMeasurementsData(
          id: 2,
          taskId: 1,
          start: baseDate.add(const Duration(seconds: 2000)).toSql(),
          end: baseDate.add(const Duration(hours: 1)).toSql(),
        ),
        v2.TimeMeasurementsData(
          id: 3,
          taskId: 2,
          start: baseDate.add(const Duration(seconds: 4000)).toSql(),
          end: baseDate.add(const Duration(minutes: 90)).toSql(),
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 2,
        createOld: v1.DatabaseAtV1.new,
        createNew: v2.DatabaseAtV2.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.userTasks, oldUserTasksData);
          batch.insertAll(oldDb.subTasks, oldSubTasksData);
          batch.insertAll(oldDb.timeMeasurements, oldTimeMeasurementsData);
        },
        validateItems: (newDb) async {
          expect(
            await newDb.select(newDb.userTasks).get(),
            expectedNewUserTasksData,
          );
          expect(
            await newDb.select(newDb.subTasks).get(),
            expectedNewSubTasksData,
          );
          expect(
            await newDb.select(newDb.timeMeasurements).get(),
            expectedNewTimeMeasurementsData,
          );

          // Verify appSettingsTable was created and is empty
          final settings = await newDb.select(newDb.appSettingsTable).get();
          expect(settings, isEmpty);

          // Verify time_measurements indexes were created
          final indexRows = await newDb
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'index'"
                " AND tbl_name = 'time_measurements'",
              )
              .get();
          final indexNames = indexRows
              .map((r) => r.read<String>('name'))
              .toSet();
          expect(indexNames, contains('idx_time_measurements_start'));
          expect(indexNames, contains('idx_time_measurements_end'));

          // Verify settings can be written and read back
          await newDb
              .into(newDb.appSettingsTable)
              .insert(
                v2.AppSettingsTableCompanion(
                  brightness: Value(AppBrightness.dark.toSql()),
                  seedColor: Value(const Color(0xFF112233).toSql()),
                ),
              );
          final savedSettings = await newDb
              .select(newDb.appSettingsTable)
              .getSingle();
          expect(savedSettings.brightness, equals(AppBrightness.dark.toSql()));
          expect(
            savedSettings.seedColor,
            equals(const Color(0xFF112233).toSql()),
          );
        },
      );
    });

    test('migration from v2 to v3 preserves data'
        ' and assigns default priority', () async {
      final baseDate = DateTime.utc(2023, 11, 14, 22, 13, 20);

      final oldUserTasksData = <v2.UserTasksData>[
        v2.UserTasksData(
          id: 1,
          title: 'Task with startDate',
          description: 'Has start date',
          status: TaskStatus.active.toSql(),
          createdAt: baseDate.toSql(),
          updatedByUserAt: baseDate.toSql(),
          startDate: baseDate.toSql(),
          endDate: baseDate.add(const Duration(days: 1)).toSql(),
          autoInsertDate: baseDate.toSql(),
        ),
        v2.UserTasksData(
          id: 2,
          title: 'Task with endDate only',
          description: 'Derives autoInsertDate from endDate minus 1 day',
          status: TaskStatus.active.toSql(),
          createdAt: baseDate.toSql(),
          updatedByUserAt: baseDate.toSql(),
          endDate: baseDate.add(const Duration(days: 1)).toSql(),
        ),
        v2.UserTasksData(
          id: 3,
          title: 'Task without dates',
          description: 'Has null autoInsertDate',
          status: TaskStatus.pending.toSql(),
          createdAt: baseDate.toSql(),
          updatedByUserAt: baseDate.toSql(),
        ),
      ];

      const oldSubTasksData = <v2.SubTasksData>[
        v2.SubTasksData(
          id: 1,
          taskId: 1,
          title: 'Subtask for Task 1',
          done: false,
          reference: 0,
        ),
      ];

      final oldTimeMeasurementsData = <v2.TimeMeasurementsData>[
        v2.TimeMeasurementsData(
          id: 1,
          taskId: 1,
          start: baseDate.toSql(),
          end: baseDate.add(const Duration(minutes: 30)).toSql(),
        ),
      ];

      final oldSettingsData = <v2.AppSettingsTableData>[
        v2.AppSettingsTableData(
          id: 1,
          brightness: AppBrightness.dark.toSql(),
          seedColor: const Color(0xFF123456).toSql(),
        ),
      ];
      final expectedSettingsData = <v3.AppSettingsTableData>[
        v3.AppSettingsTableData(
          id: 1,
          brightness: AppBrightness.dark.toSql(),
          seedColor: const Color(0xFF123456).toSql(),
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.userTasks, oldUserTasksData);
          batch.insertAll(oldDb.subTasks, oldSubTasksData);
          batch.insertAll(oldDb.timeMeasurements, oldTimeMeasurementsData);
          batch.insertAll(oldDb.appSettingsTable, oldSettingsData);
        },
        validateItems: (newDb) async {
          final tasks = await newDb.select(newDb.userTasks).get();
          expect(tasks, hasLength(3));

          // Verify all existing tasks were assigned default priority (3)
          for (final task in tasks) {
            expect(
              task.priority,
              equals(
                const TaskPriority(important: false, urgent: false).toSql(),
              ),
            );
          }

          // Verify generated autoInsertDate values
          final task1 = tasks.firstWhere((t) => t.id == 1);
          expect(task1.autoInsertDate, equals(baseDate.toSql()));

          final task2 = tasks.firstWhere((t) => t.id == 2);
          expect(task2.autoInsertDate, equals(baseDate.toSql()));

          final task3 = tasks.firstWhere((t) => t.id == 3);
          expect(task3.autoInsertDate, isNull);

          // Verify subtasks and time measurements survived table migration
          final subtasks = await newDb.select(newDb.subTasks).get();
          expect(subtasks, hasLength(1));
          expect(subtasks.first.taskId, equals(1));

          final measurements = await newDb.select(newDb.timeMeasurements).get();
          expect(measurements, hasLength(1));
          expect(measurements.first.taskId, equals(1));

          // Verify settings survived migration
          expect(
            await newDb.select(newDb.appSettingsTable).get(),
            expectedSettingsData,
          );

          // Verify new task can be inserted with explicit priority
          final newId = await newDb
              .into(newDb.userTasks)
              .insert(
                v3.UserTasksCompanion(
                  title: const Value('High Priority Task'),
                  description: const Value('New in v3'),
                  status: Value(TaskStatus.active.toSql()),
                  createdAt: Value(
                    baseDate.add(const Duration(seconds: 5)).toSql(),
                  ),
                  updatedByUserAt: Value(
                    baseDate.add(const Duration(seconds: 5)).toSql(),
                  ),
                  priority: Value(
                    const TaskPriority(important: true, urgent: false).toSql(),
                  ),
                ),
              );
          final inserted = await (newDb.select(
            newDb.userTasks,
          )..where((t) => t.id.equals(newId))).getSingle();
          expect(
            inserted.priority,
            equals(const TaskPriority(important: true, urgent: false).toSql()),
          );
        },
      );
    });

    test('migration from v3 to v4 populates task_fts'
        ' and keeps triggers working', () async {
      final baseDate = DateTime.utc(2023, 11, 14, 22, 13, 20);

      final oldUserTasksData = <v3.UserTasksData>[
        v3.UserTasksData(
          id: 1,
          title: 'Café da manhã',
          description: 'Comprar pão e café moído',
          status: TaskStatus.active.toSql(),
          createdAt: baseDate.toSql(),
          updatedByUserAt: baseDate.toSql(),
          priority: const TaskPriority(important: true, urgent: false).toSql(),
        ),
        v3.UserTasksData(
          id: 2,
          title: 'Quarterly Review',
          description: 'Analyze quarterly performance metrics',
          status: TaskStatus.active.toSql(),
          createdAt: baseDate.toSql(),
          updatedByUserAt: baseDate.toSql(),
          priority: const TaskPriority(important: false, urgent: true).toSql(),
        ),
        v3.UserTasksData(
          id: 3,
          title: 'Archived Notes',
          description: 'Old blueprints and schematics',
          status: TaskStatus.archived.toSql(),
          createdAt: baseDate.toSql(),
          updatedByUserAt: baseDate.toSql(),
          priority: const TaskPriority(important: false, urgent: false).toSql(),
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 4,
        createOld: v3.DatabaseAtV3.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.userTasks, oldUserTasksData);
        },
        validateItems: (newDb) async {
          final tasks = await newDb.select(newDb.userTasks).get();
          expect(tasks, hasLength(3));

          // Verify diacritics removal and trigram search on rebuilt index
          final cafeMatch = await newDb
              .customSelect(
                'SELECT "rowid" FROM task_fts WHERE task_fts MATCH ?',
                variables: [Variable.withString('cafe')],
              )
              .get();
          expect(cafeMatch, hasLength(1));
          expect(cafeMatch.first.read<int>('rowid'), equals(1));

          final metricsMatch = await newDb
              .customSelect(
                'SELECT "rowid" FROM task_fts WHERE task_fts MATCH ?',
                variables: [Variable.withString('metrics')],
              )
              .get();
          expect(metricsMatch, hasLength(1));
          expect(metricsMatch.first.read<int>('rowid'), equals(2));

          // Verify task_fts_on_task_insert trigger
          final newTaskId = await newDb
              .into(newDb.userTasks)
              .insert(
                v4.UserTasksCompanion(
                  title: const Value('Deploy Telescope'),
                  description: const Value('Launch rocket to orbit'),
                  status: Value(TaskStatus.active.toSql()),
                  createdAt: Value(
                    baseDate.add(const Duration(seconds: 10)).toSql(),
                  ),
                  updatedByUserAt: Value(
                    baseDate.add(const Duration(seconds: 10)).toSql(),
                  ),
                ),
              );
          final insertMatch = await newDb
              .customSelect(
                'SELECT "rowid" FROM task_fts WHERE task_fts MATCH ?',
                variables: [Variable.withString('rocket')],
              )
              .get();
          expect(insertMatch, hasLength(1));
          expect(insertMatch.first.read<int>('rowid'), equals(newTaskId));

          // Verify task_fts_on_task_update trigger
          await (newDb.update(
            newDb.userTasks,
          )..where((t) => t.id.equals(2))).write(
            const v4.UserTasksCompanion(
              description: Value('Audit cybersecurity vulnerabilities'),
            ),
          );
          final updatedMatch = await newDb
              .customSelect(
                'SELECT "rowid" FROM task_fts WHERE task_fts MATCH ?',
                variables: [Variable.withString('cybersecurity')],
              )
              .get();
          expect(updatedMatch, hasLength(1));
          expect(updatedMatch.first.read<int>('rowid'), equals(2));

          final oldMatch = await newDb
              .customSelect(
                'SELECT "rowid" FROM task_fts WHERE task_fts MATCH ?',
                variables: [Variable.withString('metrics')],
              )
              .get();
          expect(oldMatch, isEmpty);

          // Verify task_fts_on_task_delete trigger
          await (newDb.delete(
            newDb.userTasks,
          )..where((t) => t.id.equals(newTaskId))).go();
          final deleteMatch = await newDb
              .customSelect(
                'SELECT "rowid" FROM task_fts WHERE task_fts MATCH ?',
                variables: [Variable.withString('rocket')],
              )
              .get();
          expect(deleteMatch, isEmpty);
        },
      );
    });
  });
}
