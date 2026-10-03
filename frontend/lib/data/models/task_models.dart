import '../../core/config/api_config.dart';

enum TaskStatus {
  queued,
  processing,
  completed,
  failed;

  static TaskStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'processing':
        return TaskStatus.processing;
      case 'completed':
      case 'success':
        return TaskStatus.completed;
      case 'failed':
      case 'failure':
        return TaskStatus.failed;
      case 'queued':
      default:
        return TaskStatus.queued;
    }
  }

  bool get isTerminal => this == TaskStatus.completed || this == TaskStatus.failed;
  bool get isSuccess => this == TaskStatus.completed;
}

enum TaskType {
  downloadMedia,
  inpaintImage,
  inpaintVideo;

  static TaskType fromString(String value) {
    final v = value.toLowerCase();
    if (v.contains('video') && v.contains('inpaint')) {
      return TaskType.inpaintVideo;
    }
    if (v.contains('inpaint')) {
      return TaskType.inpaintImage;
    }
    return TaskType.downloadMedia;
  }
}

class MediaFile {
  final String id;
  final String fileName;
  final String fileType;
  final int fileSizeBytes;
  final bool isOutput;
  final String downloadUrl;

  MediaFile({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSizeBytes,
    required this.isOutput,
    required this.downloadUrl,
  });

  static String _resolveFileType(String? type, String? contentType, String? fileName) {
    if (type != null && type.isNotEmpty && type != 'unknown') {
      return type;
    }
    if (contentType != null) {
      if (contentType.startsWith('video/')) return 'video';
      if (contentType.startsWith('audio/')) return 'audio';
      if (contentType.startsWith('image/')) return 'image';
    }
    if (fileName != null) {
      final ext = fileName.split('.').last.toLowerCase();
      if (['mp4', 'mkv', 'mov', 'webm'].contains(ext)) return 'video';
      if (['mp3', 'm4a', 'wav', 'aac'].contains(ext)) return 'audio';
      if (['png', 'jpg', 'jpeg', 'webp'].contains(ext)) return 'image';
    }
    return 'unknown';
  }

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    final fileName = json['file_name'] as String? ?? 'media_file';
    final fileType = _resolveFileType(
      json['file_type'] as String?,
      json['content_type'] as String?,
      fileName,
    );
    final rawUrl = json['download_url'] as String? ?? '';
    final resolvedUrl = ApiConfig.resolveForNetwork(rawUrl);

    return MediaFile(
      id: json['id'] as String? ?? '',
      fileName: fileName,
      fileType: fileType,
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      isOutput: json['is_output'] as bool? ?? true,
      downloadUrl: resolvedUrl,
    );
  }

  String get humanReadableSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class TaskDetail {
  final String taskId;
  final TaskType taskType;
  final TaskStatus status;
  final int progress;
  final String? errorMessage;
  final Map<String, dynamic> inputParams;
  final Map<String, dynamic>? resultMetadata;
  final List<MediaFile> outputFiles;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskDetail({
    required this.taskId,
    required this.taskType,
    required this.status,
    required this.progress,
    this.errorMessage,
    this.inputParams = const {},
    this.resultMetadata,
    required this.outputFiles,
    this.createdAt,
    this.updatedAt,
  });

  factory TaskDetail.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['output_files'] as List<dynamic>? ?? [];
    final files = rawFiles.map((e) => MediaFile.fromJson(e as Map<String, dynamic>)).toList();

    return TaskDetail(
      taskId: json['task_id'] as String,
      taskType: TaskType.fromString(json['task_type'] as String? ?? 'download_media'),
      status: TaskStatus.fromString(json['status'] as String? ?? 'queued'),
      progress: json['progress'] as int? ?? 0,
      errorMessage: json['error_message'] as String?,
      inputParams: json['input_params'] as Map<String, dynamic>? ?? const {},
      resultMetadata: json['result_metadata'] as Map<String, dynamic>?,
      outputFiles: files,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  MediaFile? get primaryOutput => outputFiles.isNotEmpty ? outputFiles.first : null;
}

class SubmitTaskResponse {
  final String taskId;
  final TaskStatus status;
  final String message;
  final TaskType taskType;

  SubmitTaskResponse({
    required this.taskId,
    required this.status,
    required this.message,
    required this.taskType,
  });

  factory SubmitTaskResponse.fromJson(Map<String, dynamic> json) {
    return SubmitTaskResponse(
      taskId: json['task_id'] as String,
      status: TaskStatus.fromString(json['status'] as String? ?? 'queued'),
      message: json['message'] as String? ?? '',
      taskType: TaskType.fromString(json['task_type'] as String? ?? 'download_media'),
    );
  }
}
