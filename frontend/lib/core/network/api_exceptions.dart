import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final String? errorCode;
  final int? statusCode;
  final dynamic details;

  ApiException({
    required this.message,
    this.errorCode,
    this.statusCode,
    this.details,
  });

  factory ApiException.fromDioException(DioException error) {
    if (error.response != null && error.response?.data is Map) {
      final data = error.response!.data as Map<String, dynamic>;
      final msg = data['message'] ?? data['detail'] ?? 'An error occurred';
      final code = data['error_code'] as String?;
      final details = data['details'];

      switch (code) {
        case 'QUOTA_EXCEEDED':
          return QuotaExceededException(
            message: msg.toString(),
            details: details,
            statusCode: error.response?.statusCode,
          );
        case 'EXTRACTION_FAILED':
          return ExtractionFailedException(
            message: msg.toString(),
            details: details,
            statusCode: error.response?.statusCode,
          );
        case 'INVALID_FILE':
          return InvalidFileException(
            message: msg.toString(),
            details: details,
            statusCode: error.response?.statusCode,
          );
        case 'TASK_NOT_FOUND':
          return TaskNotFoundException(
            message: msg.toString(),
            statusCode: error.response?.statusCode,
          );
        case 'UNAUTHORIZED':
          return UnauthorizedException(
            message: msg.toString(),
            statusCode: error.response?.statusCode,
          );
        default:
          return ApiException(
            message: msg.toString(),
            errorCode: code,
            statusCode: error.response?.statusCode,
            details: details,
          );
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkTimeoutException(
          message: 'Connection timed out. Please check your network or server status.',
        );
      case DioExceptionType.connectionError:
        return NetworkConnectionException(
          message: 'Cannot connect to backend server. Make sure VanishLab backend is running.',
        );
      default:
        return ApiException(
          message: error.message ?? 'Unexpected network error occurred.',
          statusCode: error.response?.statusCode,
        );
    }
  }

  @override
  String toString() => message;
}

class QuotaExceededException extends ApiException {
  QuotaExceededException({required super.message, super.details, super.statusCode})
      : super(errorCode: 'QUOTA_EXCEEDED');
}

class ExtractionFailedException extends ApiException {
  ExtractionFailedException({required super.message, super.details, super.statusCode})
      : super(errorCode: 'EXTRACTION_FAILED');
}

class InvalidFileException extends ApiException {
  InvalidFileException({required super.message, super.details, super.statusCode})
      : super(errorCode: 'INVALID_FILE');
}

class TaskNotFoundException extends ApiException {
  TaskNotFoundException({required super.message, super.statusCode})
      : super(errorCode: 'TASK_NOT_FOUND');
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({required super.message, super.statusCode})
      : super(errorCode: 'UNAUTHORIZED');
}

class NetworkTimeoutException extends ApiException {
  NetworkTimeoutException({required super.message}) : super(errorCode: 'TIMEOUT');
}

class NetworkConnectionException extends ApiException {
  NetworkConnectionException({required super.message}) : super(errorCode: 'NO_CONNECTION');
}
