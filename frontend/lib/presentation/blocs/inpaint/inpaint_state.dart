import 'dart:typed_data';
import 'package:equatable/equatable.dart';

enum InpaintStatus { initial, imageLoaded, submitting, success, error }

class InpaintState extends Equatable {
  final InpaintStatus status;
  final Uint8List? imageBytes;
  final String? filename;
  final double originalWidth;
  final double originalHeight;
  final String? taskId;
  final String? message;
  final String? errorMessage;

  const InpaintState({
    this.status = InpaintStatus.initial,
    this.imageBytes,
    this.filename,
    this.originalWidth = 0.0,
    this.originalHeight = 0.0,
    this.taskId,
    this.message,
    this.errorMessage,
  });

  bool get hasImage => imageBytes != null && originalWidth > 0 && originalHeight > 0;

  InpaintState copyWith({
    InpaintStatus? status,
    Uint8List? imageBytes,
    String? filename,
    double? originalWidth,
    double? originalHeight,
    String? taskId,
    String? message,
    String? errorMessage,
  }) {
    return InpaintState(
      status: status ?? this.status,
      imageBytes: imageBytes ?? this.imageBytes,
      filename: filename ?? this.filename,
      originalWidth: originalWidth ?? this.originalWidth,
      originalHeight: originalHeight ?? this.originalHeight,
      taskId: taskId ?? this.taskId,
      message: message ?? this.message,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        filename,
        originalWidth,
        originalHeight,
        taskId,
        message,
        errorMessage,
      ];
}
