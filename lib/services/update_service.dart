import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateInfo {
  final String version;
  final String changelog;
  final String downloadUrl;

  UpdateInfo({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
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
  static const _lastCheckKey = 'last_update_check_time';

  /// Checks for an update. If [manual] is true, ignores the 12-hour throttle.
  static Future<UpdateResult> checkForUpdate({bool manual = false}) async {
    try {
      var prefs = SharedPreferencesAsync();

      if (!manual) {
        var lastCheckStr = await prefs.getString(_lastCheckKey);
        if (lastCheckStr != null) {
          var lastCheck = DateTime.tryParse(lastCheckStr);
          if (lastCheck != null &&
              DateTime.now().difference(lastCheck).inHours < 12) {
            // Checked recently, silently return no update
            return UpdateResult();
          }
        }
      }

      var response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (!manual) {
        // Record the check time if it's an automatic check
        await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
      }

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
            return UpdateResult(
              update: UpdateInfo(
                version: tagName,
                changelog: body,
                downloadUrl: htmlUrl,
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
    var packageInfo = await PackageInfo.fromPlatform();

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
}
