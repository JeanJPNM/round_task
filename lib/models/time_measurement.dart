import 'package:isar/isar.dart';
import 'package:round_task/models/task.dart';

part 'time_measurement.g.dart';

@collection
class TimeMeasurement {
  TimeMeasurement({
    this.id = Isar.autoIncrement,
    required this.startTime,
    required this.endTime,
  });

  Id id;

  @Index()
  DateTime startTime;
  @Index()
  DateTime endTime;

  @ignore
  Duration get duration => endTime.difference(startTime);

  @Backlink(to: "timeMeasurements")
  final task = IsarLink<UserTask>();
}
