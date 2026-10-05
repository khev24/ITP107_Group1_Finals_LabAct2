import 'package:hive/hive.dart';

part 'task.g.dart';

@HiveType(typeId: 1)
class Task {
  Task({
    required this.studentName,
    required this.taskName,
    required this.description,
    required this.category,
    required this.startDate,
    required this.deadlineDate,
    required this.location,
  });
  @HiveField(0)
  String studentName;

  @HiveField(1)
  String taskName;

  @HiveField(2)
  String description;

  @HiveField(3)
  String category;

  @HiveField(4)
  DateTime startDate;

  @HiveField(5)
  DateTime deadlineDate;

  @HiveField(6)
  String location;
}
