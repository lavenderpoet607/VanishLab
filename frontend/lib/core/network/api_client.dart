import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../storage/storage_service.dart';
import 'api_exceptions.dart';
import 'auth_interceptor.dart';

class ApiClient {
  late final Dio _dio;
  final StorageService _storageService;
  late String _configuredBaseUrl;

  ApiClient({required this._storageService}) {
    final customUrl = _storageService.getCustomBaseUrl();
    _configuredBaseUrl = (customUrl != null && customUrl.trim().isNotEmpty)
        ? customUrl.trim()
        : ApiConfig.defaultBaseUrl;

    final networkUrl = ApiConfig.resolveForNetwork(_configuredBaseUrl);

    _dio = Dio(
      BaseOptions(
        baseUrl: networkUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: {
          'Accept': 'application/json',
          'X-Client-Base-Url': _configuredBaseUrl,
        },
      ),
    );

    _dio.interceptors.add(AuthInterceptor(_storageService));

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
        ),
      );
    }
  }

  Dio get dio => _dio;

  void updateBaseUrl(String newUrl) {
    _configuredBaseUrl = newUrl.trim();
    _storageService.saveCustomBaseUrl(_configuredBaseUrl);

    final networkUrl = ApiConfig.resolveForNetwork(_configuredBaseUrl);
    _dio.options.baseUrl = networkUrl;
    _dio.options.headers['X-Client-Base-Url'] = _configuredBaseUrl;
  }

  String get currentBaseUrl => _configuredBaseUrl;

  String get effectiveNetworkBaseUrl => _dio.options.baseUrl;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
