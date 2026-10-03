import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/task_models.dart';
import '../../../data/repositories/task_repository.dart';
import 'task_tracker_event.dart';
import 'task_tracker_state.dart';

class TaskTrackerBloc extends Bloc<TaskTrackerEvent, TaskTrackerState> {
  final TaskRepository _taskRepository;
  StreamSubscription<TaskDetail>? _pollingSubscription;

  TaskTrackerBloc({required this._taskRepository})
      : super(const TaskTrackerState()) {
    on<StartTrackingTaskEvent>(_onStartTrackingTask);
    on<TaskUpdatedEvent>(_onTaskUpdated);
    on<TaskErrorEvent>(_onTaskError);
    on<StopTrackingTaskEvent>(_onStopTrackingTask);
  }

  void _onStartTrackingTask(
    StartTrackingTaskEvent event,
    Emitter<TaskTrackerState> emit,
  ) {
    _pollingSubscription?.cancel();
    emit(state.copyWith(
      status: TaskTrackerStatus.tracking,
      task: null,
      errorMessage: null,
    ));

    _pollingSubscription = _taskRepository.pollTask(event.taskId).listen(
      (task) {
        add(TaskUpdatedEvent(task));
      },
      onError: (error) {
        add(TaskErrorEvent(error.toString()));
      },
    );
  }

  void _onTaskUpdated(
    TaskUpdatedEvent event,
    Emitter<TaskTrackerState> emit,
  ) {
    if (event.task.status == TaskStatus.completed) {
      emit(state.copyWith(
        status: TaskTrackerStatus.completed,
        task: event.task,
      ));
    } else if (event.task.status == TaskStatus.failed) {
      emit(state.copyWith(
        status: TaskTrackerStatus.failed,
        task: event.task,
        errorMessage: event.task.errorMessage ?? 'Processing failed',
      ));
    } else {
      emit(state.copyWith(
        status: TaskTrackerStatus.tracking,
        task: event.task,
      ));
    }
  }

  void _onTaskError(
    TaskErrorEvent event,
    Emitter<TaskTrackerState> emit,
  ) {
    emit(state.copyWith(
      status: TaskTrackerStatus.failed,
      errorMessage: event.errorMessage,
    ));
  }

  void _onStopTrackingTask(
    StopTrackingTaskEvent event,
    Emitter<TaskTrackerState> emit,
  ) {
    _pollingSubscription?.cancel();
    _pollingSubscription = null;
    emit(const TaskTrackerState());
  }

  @override
  Future<void> close() {
    _pollingSubscription?.cancel();
    return super.close();
  }
}
