import 'package:flutter/services.dart';

class AppPackageInfo {
  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;

  const AppPackageInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });
}

/// Native platform bridge communicating with Sonora's native Android implementation.
class NativeBridge {
  NativeBridge._();

  static const _volumeChannel = MethodChannel('de.yurtemre.sonora/volume');

  /// Opens an external URL in the system browser.
  static Future<bool> openUrl(String url) async {
    if (url.isEmpty) return false;
    try {
      var success = await _volumeChannel.invokeMethod<bool>('openUrl', {
        'url': url,
      });
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves application metadata (version name, build number, package name).
  static Future<AppPackageInfo> getPackageInfo() async {
    try {
      var info = await _volumeChannel.invokeMapMethod<String, dynamic>(
        'getPackageInfo',
      );
      if (info != null) {
        return AppPackageInfo(
          appName: info['appName'] as String? ?? 'Sonora',
          packageName: info['packageName'] as String? ?? 'de.yurtemre.sonora',
          version: info['version'] as String? ?? '1.18.4',
          buildNumber: info['buildNumber'] as String? ?? '1',
        );
      }
    } catch (_) {}

    return const AppPackageInfo(
      appName: 'Sonora',
      packageName: 'de.yurtemre.sonora',
      version: '1.18.4',
      buildNumber: '1',
    );
  }

  /// Shares one or multiple files via Android system share sheet.
  static Future<bool> shareFiles(
    List<String> filePaths, {
    String? text,
    String? title,
  }) async {
    if (filePaths.isEmpty) return false;
    try {
      var params = <String, dynamic>{'filePaths': filePaths};
      if (text != null) params['text'] = text;
      if (title != null) params['title'] = title;

      var success = await _volumeChannel.invokeMethod<bool>(
        'shareFiles',
        params,
      );
      return success ?? false;
    } catch (_) {
      return false;
    }
  }
}
