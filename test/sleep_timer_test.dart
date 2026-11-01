import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/services/audio_handler.dart';

class _SlowPauseHandler extends SonoraAudioHandler {
  @override
  Future<void> pause({bool immediate = false}) =>
      Future<void>.delayed(const Duration(milliseconds: 400));
}

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
    test('Timer started while the previous one is stopping survives', () async {
      var playerProvider = PlayerProvider(
        audioHandler: _SlowPauseHandler(),
        settingsProvider: SettingsProvider(),
      );
      await playerProvider.loadSettings();
      playerProvider.queue = [
        createDummySong(
          id: 1,
          title: 'Song 1',
          duration: const Duration(minutes: 3),
        ),
      ];
      playerProvider.currentIndex = 0;

      playerProvider.startSleepTimer(
        const Duration(seconds: 1),
        finishSong: false,
        fadeOutSecs: 0,
      );
      // The first timer has expired and its stop is waiting on pause().
      await Future<void>.delayed(const Duration(milliseconds: 1150));
      playerProvider.startSleepTimer(
        const Duration(seconds: 30),
        finishSong: false,
        fadeOutSecs: 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(
        playerProvider.sleepTimerDuration,
        greaterThan(const Duration(seconds: 20)),
      );

      playerProvider.stopSleepTimer();
    });

    test('Fade-out restores the user volume, not a mid-fade value', () async {
      var audioHandler = SonoraAudioHandler();
      var playerProvider = PlayerProvider(
        audioHandler: audioHandler,
        settingsProvider: SettingsProvider(),
      );
      await playerProvider.loadSettings();
      playerProvider.queue = [
        createDummySong(
          id: 1,
          title: 'Song 1',
          duration: const Duration(minutes: 3),
        ),
      ];
      playerProvider.currentIndex = 0;

      await playerProvider.setVolume(0.8);
      // A transport fade-in is still low when the sleep-timer fade begins.
      await audioHandler.applyVolume(0.1);

      playerProvider.startSleepTimer(
        const Duration(seconds: 3),
        finishSong: false,
        fadeOutSecs: 3,
      );
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      playerProvider.stopSleepTimer();

      expect(audioHandler.volume, 0.8);
    });

    test('Countdown ticks do not notify provider listeners', () async {
      var playerProvider = PlayerProvider(
        audioHandler: SonoraAudioHandler(),
        settingsProvider: SettingsProvider(),
      );
      await playerProvider.loadSettings();
      playerProvider.queue = [
        createDummySong(
          id: 1,
          title: 'Song 1',
          duration: const Duration(minutes: 3),
        ),
      ];
      playerProvider.currentIndex = 0;

      playerProvider.startSleepTimer(
        const Duration(seconds: 30),
        finishSong: false,
        fadeOutSecs: 0,
      );
      var providerNotifications = 0;
      var countdownUpdates = 0;
      playerProvider.addListener(() => providerNotifications++);
      playerProvider.sleepTimerRemaining.addListener(() => countdownUpdates++);

      await Future<void>.delayed(const Duration(milliseconds: 2300));

      expect(countdownUpdates, greaterThanOrEqualTo(2));
      expect(providerNotifications, 0);

      playerProvider.stopSleepTimer();
    });

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

      expect(
        playerProvider.sleepTimerDuration,
        equals(const Duration(seconds: 1)),
      );
      expect(playerProvider.sleepTimerFinishSongActive, isFalse);

      // Wait for timer completion
      await Future<void>.delayed(const Duration(milliseconds: 1300));

      expect(playerProvider.sleepTimerDuration, isNull);
      // Verify queue is preserved (player does not vanish)
      expect(playerProvider.queue.length, equals(1));
      expect(playerProvider.currentIndex, equals(0));

      playerProvider.stopSleepTimer();
    });

    test(
      'Sleep timer with finishSong does not fade early during countdown',
      () async {
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
      },
    );

    test(
      'Extend and stop sleep timer resets volume and timer duration',
      () async {
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
        expect(
          playerProvider.sleepTimerDuration,
          equals(const Duration(minutes: 5)),
        );

        playerProvider.extendSleepTimer(const Duration(minutes: 2));
        expect(playerProvider.sleepTimerDuration?.inMinutes, equals(7));

        playerProvider.stopSleepTimer();
        expect(playerProvider.sleepTimerDuration, isNull);
      },
    );

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
