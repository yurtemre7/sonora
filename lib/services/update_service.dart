import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/services/native_bridge.dart';

class UpdateInfo {
  final String version;
  final String changelog;
  final String downloadUrl;
  final Map<String, String> apkAssets;
  final String? recommendedAbi;
  final String recommendedUrl;

  UpdateInfo({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    required this.apkAssets,
    this.recommendedAbi,
    required this.recommendedUrl,
  });
}

class UpdateResult {
  final bool isRateLimited;
  final bool hasError;
  final UpdateInfo? update;

  UpdateResult({
    this.isRateLimited = false,
    this.hasError = false,
    this.update,
  });
}

class UpdateService {
  static const _githubApiUrl =
      'https://api.github.com/repos/yurtemre7/sonora/releases/latest';

  /// Queries the native platform to get the device CPU ABI.
  static Future<String?> getDeviceAbi() async {
    try {
      const channel = MethodChannel('de.yurtemre.sonora/volume');
      var abi = await channel.invokeMethod<String>('getDeviceAbi');
      return abi;
    } catch (_) {
      return null;
    }
  }

  /// Downloads an APK from [url] with progress updates to the app temporary directory.
  static Future<String> downloadApk(
    String url, {
    required Function(int receivedBytes, int totalBytes) onProgress,
  }) async {
    var tempDir = await getTemporaryDirectory();
    var savePath = '${tempDir.path}/sonora_update.apk';
    var file = File(savePath);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    var client = http.Client();
    var request = http.Request('GET', Uri.parse(url));
    var response = await client.send(request);

    if (response.statusCode != 200) {
      throw Exception('HTTP error ${response.statusCode}');
    }

    var contentLength = response.contentLength ?? 0;
    var sink = file.openWrite();
    var received = 0;

    await for (var chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress(received, contentLength);
    }

    await sink.flush();
    await sink.close();
    client.close();

    return file.path;
  }

  /// Triggers Android system package installation for the given APK file path.
  static Future<bool> installApk(String filePath) async {
    try {
      const channel = MethodChannel('de.yurtemre.sonora/volume');
      var success = await channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Checks for an update via GitHub API releases.
  static Future<UpdateResult> checkForUpdate() async {
    try {
      var response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 403 || response.statusCode == 429) {
        return UpdateResult(isRateLimited: true);
      }

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        var tagName = data['tag_name'] as String?;
        var body = data['body'] as String? ?? 'No changelog provided.';
        var htmlUrl = data['html_url'] as String?;

        if (tagName != null && htmlUrl != null) {
          var isNewer = await _isVersionNewer(tagName);
          if (isNewer) {
            // Fetch latest changelog from main repository as well
            await fetchChangelog(forceRefresh: true);

            var assets = data['assets'] as List<dynamic>? ?? [];
            var apkAssets = <String, String>{};

            for (var asset in assets) {
              if (asset is! Map<String, dynamic>) continue;
              var name = (asset['name'] as String? ?? '').toLowerCase();
              var url = asset['browser_download_url'] as String?;
              if (url == null) continue;

              if (name.contains('arm64-v8a')) {
                apkAssets['arm64-v8a'] = url;
              } else if (name.contains('armeabi-v7a')) {
                apkAssets['armeabi-v7a'] = url;
              } else if (name.contains('x86_64')) {
                apkAssets['x86_64'] = url;
              } else if (name.contains('x86')) {
                apkAssets['x86'] = url;
              }
            }

            var detectedAbi = await getDeviceAbi();
            String? matchedAbi;
            String chosenUrl;

            if (detectedAbi != null && apkAssets.containsKey(detectedAbi)) {
              matchedAbi = detectedAbi;
              chosenUrl = apkAssets[detectedAbi]!;
            } else if (apkAssets.containsKey('arm64-v8a')) {
              matchedAbi = 'arm64-v8a';
              chosenUrl = apkAssets['arm64-v8a']!;
            } else if (apkAssets.isNotEmpty) {
              matchedAbi = apkAssets.keys.first;
              chosenUrl = apkAssets.values.first;
            } else {
              chosenUrl = htmlUrl;
            }

            return UpdateResult(
              update: UpdateInfo(
                version: tagName,
                changelog: body,
                downloadUrl: htmlUrl,
                apkAssets: apkAssets,
                recommendedAbi: matchedAbi,
                recommendedUrl: chosenUrl,
              ),
            );
          } else {
            return UpdateResult(); // up to date
          }
        }
      }

      return UpdateResult(hasError: true);
    } catch (e) {
      return UpdateResult(hasError: true);
    }
  }

  /// Compares the given GitHub tag (e.g., 'v1.7.0') against the local app version
  /// (e.g., '1.6.2+1'). Ignores build numbers.
  static Future<bool> _isVersionNewer(String remoteTag) async {
    var packageInfo = await NativeBridge.getPackageInfo();

    // e.g., '1.7.0+2' -> '1.7.0'
    var localVerString = packageInfo.version.split('+')[0].trim();
    // e.g., 'v1.7.0' -> '1.7.0'
    var remoteVerString = remoteTag.trim();
    if (remoteVerString.toLowerCase().startsWith('v')) {
      remoteVerString = remoteVerString.substring(1);
    }
    // Also ignore build number on remote if accidentally present
    remoteVerString = remoteVerString.split('+')[0].trim();

    return _compareSemanticVersions(remoteVerString, localVerString) > 0;
  }

  /// Returns > 0 if v1 > v2, 0 if v1 == v2, < 0 if v1 < v2
  static int _compareSemanticVersions(String v1, String v2) {
    var parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    var parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      var p1 = i < parts1.length ? parts1[i] : 0;
      var p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  /// Fetches the full CHANGELOG.md from the main branch.
  /// Caches the result in SharedPreferencesAsync for 12 hours unless [forceRefresh] is true.
  static Future<String?> fetchChangelog({bool forceRefresh = false}) async {
    try {
      var prefs = SharedPreferencesAsync();
      const cachedChangelogKey = 'cached_changelog_content';
      const lastChangelogCheckKey = 'last_changelog_check_time';

      if (!forceRefresh) {
        var lastCheckStr = await prefs.getString(lastChangelogCheckKey);
        if (lastCheckStr != null) {
          var lastCheck = DateTime.tryParse(lastCheckStr);
          if (lastCheck != null &&
              DateTime.now().difference(lastCheck).inHours < 12) {
            var cachedContent = await prefs.getString(cachedChangelogKey);
            if (cachedContent != null) {
              return cachedContent;
            }
          }
        }
      }

      var response = await http.get(
        Uri.parse(
          'https://raw.githubusercontent.com/yurtemre7/sonora/main/CHANGELOG.md',
        ),
      );

      if (response.statusCode == 200) {
        var content = response.body;
        await prefs.setString(cachedChangelogKey, content);
        await prefs.setString(
          lastChangelogCheckKey,
          DateTime.now().toIso8601String(),
        );
        return content;
      }
    } catch (_) {}
    return null;
  }
}
