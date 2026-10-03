import 'package:equatable/equatable.dart';

enum DownloaderStatus { initial, submitting, success, error }

class DownloaderState extends Equatable {
  final DownloaderStatus status;
  final String? taskId;
  final String? message;
  final String? errorMessage;

  const DownloaderState({
    this.status = DownloaderStatus.initial,
    this.taskId,
    this.message,
    this.errorMessage,
  });

  DownloaderState copyWith({
    DownloaderStatus? status,
    String? taskId,
    String? message,
    String? errorMessage,
  }) {
    return DownloaderState(
      status: status ?? this.status,
      taskId: taskId ?? this.taskId,
      message: message ?? this.message,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, taskId, message, errorMessage];
}
