import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/di/injection.dart';
import '../../core/network/api_client.dart';

String resolveDownloadUrl(String url, {bool forExternalDevice = false}) {
  try {
    final configured = sl<ApiClient>().currentBaseUrl;
    final baseUri = Uri.parse(configured);
    final downloadUri = Uri.parse(url);

    String targetScheme = baseUri.scheme.isNotEmpty ? baseUri.scheme : 'http';
    String targetHost = baseUri.host.isNotEmpty ? baseUri.host : 'localhost';
    int? targetPort = baseUri.hasPort ? baseUri.port : null;

    if (forExternalDevice && (targetHost == '10.0.2.2' || targetHost == '127.0.0.1')) {
      targetHost = 'localhost';
    }

    final isLocalBackend = downloadUri.host.isEmpty ||
        downloadUri.host == 'localhost' ||
        downloadUri.host == '127.0.0.1' ||
        downloadUri.host == '10.0.2.2' ||
        downloadUri.path.startsWith('/media');

    if (isLocalBackend) {
      return Uri(
        scheme: targetScheme,
        host: targetHost,
        port: targetPort,
        path: downloadUri.path,
        query: downloadUri.hasQuery ? downloadUri.query : null,
      ).toString();
    }
    return url;
  } catch (_) {
    return url;
  }
}

String resolveLaunchUrl(String url) {
  try {
    final resolved = resolveDownloadUrl(url);
    final downloadUri = Uri.parse(resolved);
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid && (downloadUri.host == 'localhost' || downloadUri.host == '127.0.0.1')) {
          return downloadUri.replace(host: '10.0.2.2').toString();
        }
      } catch (_) {}
    }
    return downloadUri.toString();
  } catch (_) {
    return url;
  }
}

Future<void> copyDownloadLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final copyUrl = resolveDownloadUrl(url, forExternalDevice: true);
  await Clipboard.setData(ClipboardData(text: copyUrl));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('Download link copied: $copyUrl'),
      duration: const Duration(seconds: 3),
    ));
}

Future<void> openDownloadUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final launchTarget = resolveLaunchUrl(url);
  final copyTarget = resolveDownloadUrl(url, forExternalDevice: true);
  final uri = Uri.tryParse(launchTarget);

  var launched = false;
  if (uri != null) {
    for (final mode in [LaunchMode.externalApplication, LaunchMode.platformDefault]) {
      try {
        launched = await launchUrl(uri, mode: mode);
      } catch (_) {
        launched = false;
      }
      if (launched) break;
    }
  }

  if (!launched) {
    await Clipboard.setData(ClipboardData(text: copyTarget));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Could not open browser. Link copied: $copyTarget'),
        duration: const Duration(seconds: 3),
      ));
  }
}
