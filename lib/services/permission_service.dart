import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Handles runtime permissions for audio file access and notifications.
class PermissionService {
  static const _channel = MethodChannel('com.sonora/volume');

  /// Requests all required permissions for the app to function.
  ///
  /// Returns `true` if all critical permissions (audio/storage) were granted,
  /// `false` otherwise. Notification permission is best-effort.
  Future<bool> requestAllPermissions() async {
    if (!Platform.isAndroid) return true;

    var audioGranted = false;

    try {
      var sdkInt = await _getAndroidSdk();
      if (sdkInt >= 33) {
        // Android 13+ uses granular media permission
        var status = await Permission.audio.request();
        audioGranted = status.isGranted;
      } else {
        // Legacy storage permission for Android 12 and below
        var status = await Permission.storage.request();
        audioGranted = status.isGranted;
      }
    } catch (_) {
      // Fallback
      var status = await Permission.storage.request();
      audioGranted = status.isGranted;
    }

    // Request notification permission separately (non-critical)
    try {
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Ignore notification exceptions
    }

    return audioGranted;
  }

  Future<int> _getAndroidSdk() async {
    try {
      var sdk = await _channel.invokeMethod<int>('getAndroidSdk');
      return sdk ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
