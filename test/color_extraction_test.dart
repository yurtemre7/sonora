import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/services/audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sonora_color_test_');
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    var messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (MethodCall methodCall) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'init') return {'id': 'test_player'};
        return {};
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.events'),
      (MethodCall methodCall) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<String> writePng(String name, Color color) async {
    var recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
        .drawRect(const Rect.fromLTWH(0, 0, 8, 8), ui.Paint()..color = color);
    var image = await recorder.endRecording().toImage(8, 8);
    var bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    var file = File('${tempDir.path}/$name.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file.path;
  }

  Song song(int id, String artworkPath) => Song(
    id: id,
    title: 'Song $id',
    artist: 'Artist',
    album: 'Album $id',
    duration: const Duration(minutes: 3),
    filePath: '/test/music/$id.mp3',
    artworkPath: artworkPath,
  );

  test(
    'background extraction colors songs and remembers colorless covers',
    () async {
      var red = await writePng('red', const Color(0xFFFF0000));
      var clear = await writePng('clear', const Color(0x00000000));

      var provider = PlayerProvider(
        audioHandler: SonoraAudioHandler(),
        settingsProvider: SettingsProvider(),
      );
      provider.updateSongs([song(1, red), song(2, red), song(3, clear)]);

      // The run is deferred 3s, then yields 100ms between covers.
      var deadline = DateTime.now().add(const Duration(seconds: 10));
      while (provider.isExtractingColors && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      var byId = {for (var s in provider.allSongs) s.id: s};
      expect(byId[1]!.dominantColor, const Color(0xFFFF0000).toARGB32());
      expect(byId[2]!.dominantColor, const Color(0xFFFF0000).toARGB32());
      expect(byId[3]!.dominantColor, isNull);

      var colorless = await SharedPreferencesAsync().getStringList(
        'colorless_artwork_paths',
      );
      expect(colorless, [clear]);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
