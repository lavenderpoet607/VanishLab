import 'package:equatable/equatable.dart';
import '../../../data/models/task_models.dart';

enum TaskTrackerStatus { idle, tracking, completed, failed }

class TaskTrackerState extends Equatable {
  final TaskTrackerStatus status;
  final TaskDetail? task;
  final String? errorMessage;

  const TaskTrackerState({
    this.status = TaskTrackerStatus.idle,
    this.task,
    this.errorMessage,
  });

  bool get isProcessing => status == TaskTrackerStatus.tracking;
  bool get isCompleted => status == TaskTrackerStatus.completed;
  bool get isFailed => status == TaskTrackerStatus.failed;

  TaskTrackerState copyWith({
    TaskTrackerStatus? status,
    TaskDetail? task,
    String? errorMessage,
  }) {
    return TaskTrackerState(
      status: status ?? this.status,
      task: task ?? this.task,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, task, errorMessage];
}
