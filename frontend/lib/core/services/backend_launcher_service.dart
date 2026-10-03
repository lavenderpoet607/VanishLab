import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class BackendLauncherService {
  static Future<bool> isBackendHealthy() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 1500);
      final rawUrl = ApiConfig.sanitizeBaseUrl('http://localhost:8000/');
      final request = await client.getUrl(Uri.parse(rawUrl));
      final response = await request.close().timeout(
            const Duration(milliseconds: 2000),
            onTimeout: () => throw TimeoutException('API probe timeout'),
          );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<void> ensureBackendRunning() async {
    if (kIsWeb) return;

    try {
      if (await isBackendHealthy()) {
        return;
      }

      if (Platform.isWindows) {
        final currentDir = Directory.current.path;
        final possiblePaths = [
          r'c:\Users\user\Documents\project\VanishLab\.venv\Scripts\pythonw.exe',
          '$currentDir\\..\\.venv\\Scripts\\pythonw.exe',
          '$currentDir\\.venv\\Scripts\\pythonw.exe',
        ];

        String? pythonPath;
        for (final p in possiblePaths) {
          if (File(p).existsSync()) {
            pythonPath = p;
            break;
          }
        }

        if (pythonPath != null) {
          final scriptPath =
              r'c:\Users\user\Documents\project\VanishLab\backend\scripts\start_daemon.py';
          if (File(scriptPath).existsSync()) {
            await Process.start(
              pythonPath,
              [scriptPath],
              mode: ProcessStartMode.detached,
              runInShell: true,
            );
          }
        }
      }
    } catch (_) {}
  }
}
