import 'dart:async';
import '../models/task_models.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';

class TaskRepository {
  final ApiClient _apiClient;

  TaskRepository({required this._apiClient});

  Future<TaskDetail> getTaskStatus(String taskId) async {
    final response = await _apiClient.get('${ApiConfig.taskStatusEndpoint}/$taskId');
    return TaskDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Stream<TaskDetail> pollTask(
    String taskId, {
    Duration interval = const Duration(milliseconds: 1800),
    Duration timeout = const Duration(minutes: 5),
  }) async* {
    final startTime = DateTime.now();

    while (true) {
      if (DateTime.now().difference(startTime) > timeout) {
        throw TimeoutException('Task monitoring timed out after ${timeout.inMinutes} minutes.');
      }

      final task = await getTaskStatus(taskId);
      yield task;

      if (task.status.isTerminal) {
        break;
      }

      await Future.delayed(interval);
    }
  }
}
