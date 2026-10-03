import 'package:equatable/equatable.dart';
import '../../../data/models/task_models.dart';

abstract class TaskTrackerEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class StartTrackingTaskEvent extends TaskTrackerEvent {
  final String taskId;

  StartTrackingTaskEvent(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class TaskUpdatedEvent extends TaskTrackerEvent {
  final TaskDetail task;

  TaskUpdatedEvent(this.task);

  @override
  List<Object?> get props => [task.taskId, task.status, task.progress];
}

class TaskErrorEvent extends TaskTrackerEvent {
  final String errorMessage;

  TaskErrorEvent(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

class StopTrackingTaskEvent extends TaskTrackerEvent {}
