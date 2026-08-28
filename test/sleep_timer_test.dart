import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/services/audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (MethodCall methodCall) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.just_audio.methods'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'init') {
              return {'id': 'test_player'};
            }
            return {};
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.just_audio.events'),
          (MethodCall methodCall) async => null,
        );
  });

  Song createDummySong({
    required int id,
    required String title,
    required Duration duration,
  }) {
    return Song(
      id: id,
      title: title,
      artist: 'Test Artist',
      album: 'Test Album',
      duration: duration,
      filePath: '/test/music/$title.mp3',
    );
  }

  group('Sleep Timer Logic Tests', () {
    test('Standard sleep timer pauses without clearing queue', () async {
      var audioHandler = SonoraAudioHandler();
      var settingsProvider = SettingsProvider();
      var playerProvider = PlayerProvider(
        audioHandler: audioHandler,
        settingsProvider: settingsProvider,
      );
      await playerProvider.loadSettings();

      var song = createDummySong(
        id: 1,
        title: 'Song 1',
        duration: const Duration(minutes: 3),
      );
      playerProvider.queue = [song];
      playerProvider.currentIndex = 0;

      playerProvider.startSleepTimer(
        const Duration(seconds: 1),
        finishSong: false,
        fadeOutSecs: 0,
      );

      expect(playerProvider.sleepTimerDuration, equals(const Duration(seconds: 1)));
      expect(playerProvider.sleepTimerFinishSongActive, isFalse);

      // Wait for timer completion
      await Future<void>.delayed(const Duration(milliseconds: 1300));

      expect(playerProvider.sleepTimerDuration, isNull);
      // Verify queue is preserved (player does not vanish)
      expect(playerProvider.queue.length, equals(1));
      expect(playerProvider.currentIndex, equals(0));

      playerProvider.stopSleepTimer();
    });

    test('Sleep timer with finishSong does not fade early during countdown', () async {
      var audioHandler = SonoraAudioHandler();
      var settingsProvider = SettingsProvider();
      var playerProvider = PlayerProvider(
        audioHandler: audioHandler,
        settingsProvider: settingsProvider,
      );
      await playerProvider.loadSettings();

      var song = createDummySong(
        id: 1,
        title: 'Song 1',
        duration: const Duration(seconds: 60),
      );
      playerProvider.queue = [song];
      playerProvider.currentIndex = 0;

      playerProvider.startSleepTimer(
        const Duration(seconds: 2),
        finishSong: true,
        fadeOutSecs: 10,
      );

      expect(playerProvider.sleepTimerFinishSongActive, isTrue);

      // 1 second into countdown: volume remains 1.0 (no early fade-out)
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(audioHandler.player.volume, equals(1.0));

      playerProvider.stopSleepTimer();
    });

    test('Extend and stop sleep timer resets volume and timer duration', () async {
      var audioHandler = SonoraAudioHandler();
      var settingsProvider = SettingsProvider();
      var playerProvider = PlayerProvider(
        audioHandler: audioHandler,
        settingsProvider: settingsProvider,
      );
      await playerProvider.loadSettings();

      playerProvider.startSleepTimer(
        const Duration(minutes: 5),
        finishSong: false,
      );
      expect(playerProvider.sleepTimerDuration, equals(const Duration(minutes: 5)));

      playerProvider.extendSleepTimer(const Duration(minutes: 2));
      expect(playerProvider.sleepTimerDuration?.inMinutes, equals(7));

      playerProvider.stopSleepTimer();
      expect(playerProvider.sleepTimerDuration, isNull);
    });

    test('Finishing song flag is properly set and cleared on stop', () async {
      var audioHandler = SonoraAudioHandler();
      var settingsProvider = SettingsProvider();
      var playerProvider = PlayerProvider(
        audioHandler: audioHandler,
        settingsProvider: settingsProvider,
      );
      await playerProvider.loadSettings();

      playerProvider.isFinishingCurrentSong = true;
      expect(playerProvider.isFinishingCurrentSong, isTrue);

      playerProvider.stopSleepTimer();
      expect(playerProvider.isFinishingCurrentSong, isFalse);
      expect(playerProvider.sleepTimerDuration, isNull);
    });
  });
}
