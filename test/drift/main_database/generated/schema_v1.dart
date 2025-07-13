// dart format width=80
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';

class UserTasks extends Table with TableInfo<UserTasks, UserTasksData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UserTasks(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<int> reference = GeneratedColumn<int>(
      'reference', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
      'progress', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<int> updatedByUserAt = GeneratedColumn<int>(
      'updated_by_user_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<int> startDate = GeneratedColumn<int>(
      'start_date', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<int> endDate = GeneratedColumn<int>(
      'end_date', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<int> autoInsertDate = GeneratedColumn<int>(
      'auto_insert_date', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<int> activeTimeMeasurementStart =
      GeneratedColumn<int>('active_time_measurement_start', aliasedName, true,
          type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<String> recurrence = GeneratedColumn<String>(
      'recurrence', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        description,
        status,
        reference,
        progress,
        createdAt,
        updatedByUserAt,
        deletedAt,
        startDate,
        endDate,
        autoInsertDate,
        activeTimeMeasurementStart,
        recurrence
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_tasks';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserTasksData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserTasksData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      reference: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reference']),
      progress: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}progress']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedByUserAt: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}updated_by_user_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deleted_at']),
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_date']),
      endDate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_date']),
      autoInsertDate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}auto_insert_date']),
      activeTimeMeasurementStart: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}active_time_measurement_start']),
      recurrence: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recurrence']),
    );
  }

  @override
  UserTasks createAlias(String alias) {
    return UserTasks(attachedDatabase, alias);
  }
}

class UserTasksData extends DataClass implements Insertable<UserTasksData> {
  final int id;
  final String title;
  final String description;
  final int status;
  final int? reference;
  final double? progress;
  final int createdAt;
  final int updatedByUserAt;
  final int? deletedAt;
  final int? startDate;
  final int? endDate;
  final int? autoInsertDate;
  final int? activeTimeMeasurementStart;
  final String? recurrence;
  const UserTasksData(
      {required this.id,
      required this.title,
      required this.description,
      required this.status,
      this.reference,
      this.progress,
      required this.createdAt,
      required this.updatedByUserAt,
      this.deletedAt,
      this.startDate,
      this.endDate,
      this.autoInsertDate,
      this.activeTimeMeasurementStart,
      this.recurrence});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || reference != null) {
      map['reference'] = Variable<int>(reference);
    }
    if (!nullToAbsent || progress != null) {
      map['progress'] = Variable<double>(progress);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_by_user_at'] = Variable<int>(updatedByUserAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<int>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<int>(endDate);
    }
    if (!nullToAbsent || autoInsertDate != null) {
      map['auto_insert_date'] = Variable<int>(autoInsertDate);
    }
    if (!nullToAbsent || activeTimeMeasurementStart != null) {
      map['active_time_measurement_start'] =
          Variable<int>(activeTimeMeasurementStart);
    }
    if (!nullToAbsent || recurrence != null) {
      map['recurrence'] = Variable<String>(recurrence);
    }
    return map;
  }

  UserTasksCompanion toCompanion(bool nullToAbsent) {
    return UserTasksCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      status: Value(status),
      reference: reference == null && nullToAbsent
          ? const Value.absent()
          : Value(reference),
      progress: progress == null && nullToAbsent
          ? const Value.absent()
          : Value(progress),
      createdAt: Value(createdAt),
      updatedByUserAt: Value(updatedByUserAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      autoInsertDate: autoInsertDate == null && nullToAbsent
          ? const Value.absent()
          : Value(autoInsertDate),
      activeTimeMeasurementStart:
          activeTimeMeasurementStart == null && nullToAbsent
              ? const Value.absent()
              : Value(activeTimeMeasurementStart),
      recurrence: recurrence == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrence),
    );
  }

  factory UserTasksData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserTasksData(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      status: serializer.fromJson<int>(json['status']),
      reference: serializer.fromJson<int?>(json['reference']),
      progress: serializer.fromJson<double?>(json['progress']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedByUserAt: serializer.fromJson<int>(json['updatedByUserAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      startDate: serializer.fromJson<int?>(json['startDate']),
      endDate: serializer.fromJson<int?>(json['endDate']),
      autoInsertDate: serializer.fromJson<int?>(json['autoInsertDate']),
      activeTimeMeasurementStart:
          serializer.fromJson<int?>(json['activeTimeMeasurementStart']),
      recurrence: serializer.fromJson<String?>(json['recurrence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'status': serializer.toJson<int>(status),
      'reference': serializer.toJson<int?>(reference),
      'progress': serializer.toJson<double?>(progress),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedByUserAt': serializer.toJson<int>(updatedByUserAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'startDate': serializer.toJson<int?>(startDate),
      'endDate': serializer.toJson<int?>(endDate),
      'autoInsertDate': serializer.toJson<int?>(autoInsertDate),
      'activeTimeMeasurementStart':
          serializer.toJson<int?>(activeTimeMeasurementStart),
      'recurrence': serializer.toJson<String?>(recurrence),
    };
  }

  UserTasksData copyWith(
          {int? id,
          String? title,
          String? description,
          int? status,
          Value<int?> reference = const Value.absent(),
          Value<double?> progress = const Value.absent(),
          int? createdAt,
          int? updatedByUserAt,
          Value<int?> deletedAt = const Value.absent(),
          Value<int?> startDate = const Value.absent(),
          Value<int?> endDate = const Value.absent(),
          Value<int?> autoInsertDate = const Value.absent(),
          Value<int?> activeTimeMeasurementStart = const Value.absent(),
          Value<String?> recurrence = const Value.absent()}) =>
      UserTasksData(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        reference: reference.present ? reference.value : this.reference,
        progress: progress.present ? progress.value : this.progress,
        createdAt: createdAt ?? this.createdAt,
        updatedByUserAt: updatedByUserAt ?? this.updatedByUserAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        startDate: startDate.present ? startDate.value : this.startDate,
        endDate: endDate.present ? endDate.value : this.endDate,
        autoInsertDate:
            autoInsertDate.present ? autoInsertDate.value : this.autoInsertDate,
        activeTimeMeasurementStart: activeTimeMeasurementStart.present
            ? activeTimeMeasurementStart.value
            : this.activeTimeMeasurementStart,
        recurrence: recurrence.present ? recurrence.value : this.recurrence,
      );
  UserTasksData copyWithCompanion(UserTasksCompanion data) {
    return UserTasksData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      status: data.status.present ? data.status.value : this.status,
      reference: data.reference.present ? data.reference.value : this.reference,
      progress: data.progress.present ? data.progress.value : this.progress,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedByUserAt: data.updatedByUserAt.present
          ? data.updatedByUserAt.value
          : this.updatedByUserAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      autoInsertDate: data.autoInsertDate.present
          ? data.autoInsertDate.value
          : this.autoInsertDate,
      activeTimeMeasurementStart: data.activeTimeMeasurementStart.present
          ? data.activeTimeMeasurementStart.value
          : this.activeTimeMeasurementStart,
      recurrence:
          data.recurrence.present ? data.recurrence.value : this.recurrence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserTasksData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('reference: $reference, ')
          ..write('progress: $progress, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedByUserAt: $updatedByUserAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('autoInsertDate: $autoInsertDate, ')
          ..write('activeTimeMeasurementStart: $activeTimeMeasurementStart, ')
          ..write('recurrence: $recurrence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      description,
      status,
      reference,
      progress,
      createdAt,
      updatedByUserAt,
      deletedAt,
      startDate,
      endDate,
      autoInsertDate,
      activeTimeMeasurementStart,
      recurrence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserTasksData &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.status == this.status &&
          other.reference == this.reference &&
          other.progress == this.progress &&
          other.createdAt == this.createdAt &&
          other.updatedByUserAt == this.updatedByUserAt &&
          other.deletedAt == this.deletedAt &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.autoInsertDate == this.autoInsertDate &&
          other.activeTimeMeasurementStart == this.activeTimeMeasurementStart &&
          other.recurrence == this.recurrence);
}

class UserTasksCompanion extends UpdateCompanion<UserTasksData> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> description;
  final Value<int> status;
  final Value<int?> reference;
  final Value<double?> progress;
  final Value<int> createdAt;
  final Value<int> updatedByUserAt;
  final Value<int?> deletedAt;
  final Value<int?> startDate;
  final Value<int?> endDate;
  final Value<int?> autoInsertDate;
  final Value<int?> activeTimeMeasurementStart;
  final Value<String?> recurrence;
  const UserTasksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.reference = const Value.absent(),
    this.progress = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedByUserAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.autoInsertDate = const Value.absent(),
    this.activeTimeMeasurementStart = const Value.absent(),
    this.recurrence = const Value.absent(),
  });
  UserTasksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String description,
    required int status,
    this.reference = const Value.absent(),
    this.progress = const Value.absent(),
    required int createdAt,
    required int updatedByUserAt,
    this.deletedAt = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.autoInsertDate = const Value.absent(),
    this.activeTimeMeasurementStart = const Value.absent(),
    this.recurrence = const Value.absent(),
  })  : title = Value(title),
        description = Value(description),
        status = Value(status),
        createdAt = Value(createdAt),
        updatedByUserAt = Value(updatedByUserAt);
  static Insertable<UserTasksData> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? status,
    Expression<int>? reference,
    Expression<double>? progress,
    Expression<int>? createdAt,
    Expression<int>? updatedByUserAt,
    Expression<int>? deletedAt,
    Expression<int>? startDate,
    Expression<int>? endDate,
    Expression<int>? autoInsertDate,
    Expression<int>? activeTimeMeasurementStart,
    Expression<String>? recurrence,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (reference != null) 'reference': reference,
      if (progress != null) 'progress': progress,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedByUserAt != null) 'updated_by_user_at': updatedByUserAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (autoInsertDate != null) 'auto_insert_date': autoInsertDate,
      if (activeTimeMeasurementStart != null)
        'active_time_measurement_start': activeTimeMeasurementStart,
      if (recurrence != null) 'recurrence': recurrence,
    });
  }

  UserTasksCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<String>? description,
      Value<int>? status,
      Value<int?>? reference,
      Value<double?>? progress,
      Value<int>? createdAt,
      Value<int>? updatedByUserAt,
      Value<int?>? deletedAt,
      Value<int?>? startDate,
      Value<int?>? endDate,
      Value<int?>? autoInsertDate,
      Value<int?>? activeTimeMeasurementStart,
      Value<String?>? recurrence}) {
    return UserTasksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      reference: reference ?? this.reference,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      updatedByUserAt: updatedByUserAt ?? this.updatedByUserAt,
      deletedAt: deletedAt ?? this.deletedAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      autoInsertDate: autoInsertDate ?? this.autoInsertDate,
      activeTimeMeasurementStart:
          activeTimeMeasurementStart ?? this.activeTimeMeasurementStart,
      recurrence: recurrence ?? this.recurrence,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (reference.present) {
      map['reference'] = Variable<int>(reference.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedByUserAt.present) {
      map['updated_by_user_at'] = Variable<int>(updatedByUserAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<int>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<int>(endDate.value);
    }
    if (autoInsertDate.present) {
      map['auto_insert_date'] = Variable<int>(autoInsertDate.value);
    }
    if (activeTimeMeasurementStart.present) {
      map['active_time_measurement_start'] =
          Variable<int>(activeTimeMeasurementStart.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(recurrence.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserTasksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('reference: $reference, ')
          ..write('progress: $progress, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedByUserAt: $updatedByUserAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('autoInsertDate: $autoInsertDate, ')
          ..write('activeTimeMeasurementStart: $activeTimeMeasurementStart, ')
          ..write('recurrence: $recurrence')
          ..write(')'))
        .toString();
  }
}

class SubTasks extends Table with TableInfo<SubTasks, SubTasksData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SubTasks(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
      'task_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES user_tasks (id) ON DELETE CASCADE'));
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
      'done', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("done" IN (0, 1))'));
  late final GeneratedColumn<int> reference = GeneratedColumn<int>(
      'reference', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, taskId, title, done, reference];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sub_tasks';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubTasksData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubTasksData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}task_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      done: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}done'])!,
      reference: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reference'])!,
    );
  }

  @override
  SubTasks createAlias(String alias) {
    return SubTasks(attachedDatabase, alias);
  }
}

class SubTasksData extends DataClass implements Insertable<SubTasksData> {
  final int id;
  final int taskId;
  final String title;
  final bool done;
  final int reference;
  const SubTasksData(
      {required this.id,
      required this.taskId,
      required this.title,
      required this.done,
      required this.reference});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['task_id'] = Variable<int>(taskId);
    map['title'] = Variable<String>(title);
    map['done'] = Variable<bool>(done);
    map['reference'] = Variable<int>(reference);
    return map;
  }

  SubTasksCompanion toCompanion(bool nullToAbsent) {
    return SubTasksCompanion(
      id: Value(id),
      taskId: Value(taskId),
      title: Value(title),
      done: Value(done),
      reference: Value(reference),
    );
  }

  factory SubTasksData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubTasksData(
      id: serializer.fromJson<int>(json['id']),
      taskId: serializer.fromJson<int>(json['taskId']),
      title: serializer.fromJson<String>(json['title']),
      done: serializer.fromJson<bool>(json['done']),
      reference: serializer.fromJson<int>(json['reference']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'taskId': serializer.toJson<int>(taskId),
      'title': serializer.toJson<String>(title),
      'done': serializer.toJson<bool>(done),
      'reference': serializer.toJson<int>(reference),
    };
  }

  SubTasksData copyWith(
          {int? id, int? taskId, String? title, bool? done, int? reference}) =>
      SubTasksData(
        id: id ?? this.id,
        taskId: taskId ?? this.taskId,
        title: title ?? this.title,
        done: done ?? this.done,
        reference: reference ?? this.reference,
      );
  SubTasksData copyWithCompanion(SubTasksCompanion data) {
    return SubTasksData(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      title: data.title.present ? data.title.value : this.title,
      done: data.done.present ? data.done.value : this.done,
      reference: data.reference.present ? data.reference.value : this.reference,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubTasksData(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('done: $done, ')
          ..write('reference: $reference')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, taskId, title, done, reference);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubTasksData &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.title == this.title &&
          other.done == this.done &&
          other.reference == this.reference);
}

class SubTasksCompanion extends UpdateCompanion<SubTasksData> {
  final Value<int> id;
  final Value<int> taskId;
  final Value<String> title;
  final Value<bool> done;
  final Value<int> reference;
  const SubTasksCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.title = const Value.absent(),
    this.done = const Value.absent(),
    this.reference = const Value.absent(),
  });
  SubTasksCompanion.insert({
    this.id = const Value.absent(),
    required int taskId,
    required String title,
    required bool done,
    required int reference,
  })  : taskId = Value(taskId),
        title = Value(title),
        done = Value(done),
        reference = Value(reference);
  static Insertable<SubTasksData> custom({
    Expression<int>? id,
    Expression<int>? taskId,
    Expression<String>? title,
    Expression<bool>? done,
    Expression<int>? reference,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (title != null) 'title': title,
      if (done != null) 'done': done,
      if (reference != null) 'reference': reference,
    });
  }

  SubTasksCompanion copyWith(
      {Value<int>? id,
      Value<int>? taskId,
      Value<String>? title,
      Value<bool>? done,
      Value<int>? reference}) {
    return SubTasksCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      done: done ?? this.done,
      reference: reference ?? this.reference,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (reference.present) {
      map['reference'] = Variable<int>(reference.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubTasksCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('done: $done, ')
          ..write('reference: $reference')
          ..write(')'))
        .toString();
  }
}

class TimeMeasurements extends Table
    with TableInfo<TimeMeasurements, TimeMeasurementsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TimeMeasurements(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
      'task_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES user_tasks (id) ON DELETE CASCADE'));
  late final GeneratedColumn<int> start = GeneratedColumn<int>(
      'start', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<int> end = GeneratedColumn<int>(
      'end', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, taskId, start, end];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'time_measurements';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimeMeasurementsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimeMeasurementsData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}task_id'])!,
      start: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start'])!,
      end: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end'])!,
    );
  }

  @override
  TimeMeasurements createAlias(String alias) {
    return TimeMeasurements(attachedDatabase, alias);
  }
}

class TimeMeasurementsData extends DataClass
    implements Insertable<TimeMeasurementsData> {
  final int id;
  final int taskId;
  final int start;
  final int end;
  const TimeMeasurementsData(
      {required this.id,
      required this.taskId,
      required this.start,
      required this.end});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['task_id'] = Variable<int>(taskId);
    map['start'] = Variable<int>(start);
    map['end'] = Variable<int>(end);
    return map;
  }

  TimeMeasurementsCompanion toCompanion(bool nullToAbsent) {
    return TimeMeasurementsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      start: Value(start),
      end: Value(end),
    );
  }

  factory TimeMeasurementsData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimeMeasurementsData(
      id: serializer.fromJson<int>(json['id']),
      taskId: serializer.fromJson<int>(json['taskId']),
      start: serializer.fromJson<int>(json['start']),
      end: serializer.fromJson<int>(json['end']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'taskId': serializer.toJson<int>(taskId),
      'start': serializer.toJson<int>(start),
      'end': serializer.toJson<int>(end),
    };
  }

  TimeMeasurementsData copyWith({int? id, int? taskId, int? start, int? end}) =>
      TimeMeasurementsData(
        id: id ?? this.id,
        taskId: taskId ?? this.taskId,
        start: start ?? this.start,
        end: end ?? this.end,
      );
  TimeMeasurementsData copyWithCompanion(TimeMeasurementsCompanion data) {
    return TimeMeasurementsData(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      start: data.start.present ? data.start.value : this.start,
      end: data.end.present ? data.end.value : this.end,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimeMeasurementsData(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('start: $start, ')
          ..write('end: $end')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, taskId, start, end);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimeMeasurementsData &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.start == this.start &&
          other.end == this.end);
}

class TimeMeasurementsCompanion extends UpdateCompanion<TimeMeasurementsData> {
  final Value<int> id;
  final Value<int> taskId;
  final Value<int> start;
  final Value<int> end;
  const TimeMeasurementsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.start = const Value.absent(),
    this.end = const Value.absent(),
  });
  TimeMeasurementsCompanion.insert({
    this.id = const Value.absent(),
    required int taskId,
    required int start,
    required int end,
  })  : taskId = Value(taskId),
        start = Value(start),
        end = Value(end);
  static Insertable<TimeMeasurementsData> custom({
    Expression<int>? id,
    Expression<int>? taskId,
    Expression<int>? start,
    Expression<int>? end,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
    });
  }

  TimeMeasurementsCompanion copyWith(
      {Value<int>? id,
      Value<int>? taskId,
      Value<int>? start,
      Value<int>? end}) {
    return TimeMeasurementsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (start.present) {
      map['start'] = Variable<int>(start.value);
    }
    if (end.present) {
      map['end'] = Variable<int>(end.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimeMeasurementsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('start: $start, ')
          ..write('end: $end')
          ..write(')'))
        .toString();
  }
}

class DatabaseAtV1 extends GeneratedDatabase {
  DatabaseAtV1(QueryExecutor e) : super(e);
  late final UserTasks userTasks = UserTasks(this);
  late final SubTasks subTasks = SubTasks(this);
  late final TimeMeasurements timeMeasurements = TimeMeasurements(this);
  late final Index idxUserTasksStatus = Index('idx_user_tasks_status',
      'CREATE INDEX idx_user_tasks_status ON user_tasks (status)');
  late final Index idxUserTasksAutoInsertDate = Index(
      'idx_user_tasks_auto_insert_date',
      'CREATE INDEX idx_user_tasks_auto_insert_date ON user_tasks (auto_insert_date)');
  late final Index idxUserTasksDeletedAt = Index('idx_user_tasks_deleted_at',
      'CREATE INDEX idx_user_tasks_deleted_at ON user_tasks (deleted_at)');
  late final Index idxUserTasksActiveTimeMeasurementStart = Index(
      'idx_user_tasks_active_time_measurement_start',
      'CREATE INDEX idx_user_tasks_active_time_measurement_start ON user_tasks (active_time_measurement_start)');
  late final Index idxSubTasksTaskId = Index('idx_sub_tasks_task_id',
      'CREATE INDEX idx_sub_tasks_task_id ON sub_tasks (task_id)');
  late final Index idxTimeMeasurementsTaskId = Index(
      'idx_time_measurements_task_id',
      'CREATE INDEX idx_time_measurements_task_id ON time_measurements (task_id)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        userTasks,
        subTasks,
        timeMeasurements,
        idxUserTasksStatus,
        idxUserTasksAutoInsertDate,
        idxUserTasksDeletedAt,
        idxUserTasksActiveTimeMeasurementStart,
        idxSubTasksTaskId,
        idxTimeMeasurementsTaskId
      ];
  @override
  int get schemaVersion => 1;
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}
