import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _defaultPort = '8000';

  static String resolveForNetwork(String url) {
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          if (url.contains('localhost')) {
            return url.replaceAll('localhost', '10.0.2.2');
          }
          if (url.contains('127.0.0.1')) {
            return url.replaceAll('127.0.0.1', '10.0.2.2');
          }
        }
      } catch (_) {}
    }
    return url;
  }

  static String sanitizeBaseUrl(String url) => resolveForNetwork(url);

  static String get defaultBaseUrl {
    return 'http://localhost:$_defaultPort/api/v1';
  }

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 120);

  static const String registerEndpoint = '/auth/register';
  static const String loginEndpoint = '/auth/login';
  static const String meEndpoint = '/auth/me';
  static const String quotaEndpoint = '/auth/quota';
  static const String quotaResetEndpoint = '/auth/quota/reset';

  static const String downloaderProcessEndpoint = '/downloader/process';
  static const String inpaintImageEndpoint = '/inpaint/image';
  static const String inpaintVideoPreviewEndpoint = '/inpaint/video/preview';
  static const String inpaintVideoEndpoint = '/inpaint/video';
  static const String taskStatusEndpoint = '/tasks';
}
