import 'package:isar/isar.dart';
import 'package:rrule/rrule.dart';
part 'task.g.dart';

@collection
class UserTask {
  UserTask({
    this.id = Isar.autoIncrement,
    required this.title,
    required this.description,
    required this.lastTouched,
    this.startDate,
    this.endDate,
    int? statusId,
    this.archived = false,
    this.reference,
    this.recurrence,
    required this.creationDate,
    this.progress,
  });

  Id id;
  String title;
  String description;

  bool archived;
  double? progress;
  DateTime creationDate;
  DateTime lastTouched;

  @Index()
  DateTime? startDate;
  DateTime? endDate;

  @Index()
  DateTime? get autoInsertDate =>
      startDate ?? endDate?.subtract(const Duration(days: 1));

  @ignore
  RecurrenceRule? recurrence;

  String? get recurrenceString => recurrence?.toString();

  set recurrenceString(String? value) {
    if (value == null) {
      recurrence = null;
      return;
    }

    try {
      recurrence = RecurrenceRule.fromString(value);
    } catch (e) {
      recurrence = null;
    }
  }

  /// Used to order the queue
  @Index(unique: false)
  int? reference;

  final subTasks = IsarLinks<SubTask>();
  final directory = IsarLink<TaskDir>();
}

@collection
class SubTask {
  SubTask({
    this.id = Isar.autoIncrement,
    required this.name,
    required this.done,
    required this.reference,
  });

  Id id;
  String name;
  bool done;
  int reference;

  @Backlink(to: "subTasks")
  final task = IsarLink<UserTask>();
}

@collection
class TaskDir {
  TaskDir({
    this.id = Isar.autoIncrement,
    required this.name,
    this.isRoot = false,
  });

  Id id;
  String name;
  bool isRoot;

  @Backlink(to: "directory")
  final tasks = IsarLinks<UserTask>();

  final children = IsarLinks<TaskDir>();
}

@embedded
class StoredRecurrence {
  StoredRecurrence({
    this.rule,
  });
  @ignore
  RecurrenceRule? rule;
}
