import 'package:flutter/services.dart';

/// Communicates with native Android code to manage media volume.
///
/// Uses a [MethodChannel] to invoke platform-specific volume logic that
/// checks whether the device's media volume is at zero and raises it to
/// a reasonable default if so.
class VolumeService {
  static const _channel = MethodChannel('com.sonora/volume');

  /// Ensures the device media volume is not zero.
  ///
  /// Returns `true` if the volume was raised (it was previously at zero),
  /// `false` if the volume was already non-zero or if the call failed.
  Future<bool> ensureMediaVolume() async {
    try {
      var result = await _channel.invokeMethod<bool>('ensureMediaVolume');
      return result ?? false;
    } on PlatformException catch (_) {
      // Native side failed — nothing we can do; return false gracefully.
      return false;
    } on MissingPluginException catch (_) {
      // Channel not implemented on this platform (e.g. during testing).
      return false;
    }
  }

}
