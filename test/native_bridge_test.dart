import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/services/native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeBridge Tests', () {
    test('getPackageInfo returns mock data when channel responds', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('de.yurtemre.sonora/volume'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'getPackageInfo') {
                return <String, dynamic>{
                  'appName': 'Sonora',
                  'packageName': 'de.yurtemre.sonora',
                  'version': '1.18.4',
                  'buildNumber': '10',
                };
              }
              return null;
            },
          );

      var info = await NativeBridge.getPackageInfo();
      expect(info.appName, equals('Sonora'));
      expect(info.packageName, equals('de.yurtemre.sonora'));
      expect(info.version, equals('1.18.4'));
      expect(info.buildNumber, equals('10'));
    });

    test('openUrl sends url over MethodChannel', () async {
      String? invokedUrl;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('de.yurtemre.sonora/volume'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'openUrl') {
                invokedUrl = methodCall.arguments['url'] as String?;
                return true;
              }
              return null;
            },
          );

      // ignore: avoid_redundant_argument_values
      var opened = await NativeBridge.openUrl(
        'https://github.com/yurtemre7/sonora',
      );
      expect(opened, isTrue);
      expect(invokedUrl, equals('https://github.com/yurtemre7/sonora'));

      var emptyResult = await NativeBridge.openUrl('');
      expect(emptyResult, isFalse);
    });

    test('shareFiles invokes shareFiles method on channel with list of paths', () async {
      List<dynamic>? sharedPaths;
      String? sharedText;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('de.yurtemre.sonora/volume'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'shareFiles') {
                sharedPaths = methodCall.arguments['filePaths'] as List<dynamic>?;
                sharedText = methodCall.arguments['text'] as String?;
                return true;
              }
              return null;
            },
          );

      var success = await NativeBridge.shareFiles(
        ['/path/song1.mp3', '/path/song2.flac'],
        text: 'Listen to these songs',
      );

      expect(success, isTrue);
      expect(sharedPaths, equals(['/path/song1.mp3', '/path/song2.flac']));
      expect(sharedText, equals('Listen to these songs'));

      var emptySuccess = await NativeBridge.shareFiles([]);
      expect(emptySuccess, isFalse);
    });
  });
}
