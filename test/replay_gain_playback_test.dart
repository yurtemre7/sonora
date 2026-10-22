import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/models/replay_gain.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/services/audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    var messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (call) async => call.method == 'init' ? {'id': 'test_player'} : {},
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.events'),
      (call) async => null,
    );
  });

  MediaItem item(String id, {double? trackGain, double? albumGain}) =>
      MediaItem(
        id: id,
        title: id,
        extras: ReplayGainExtras.build(
          trackGain: trackGain,
          albumGain: albumGain,
        ),
      );

  test('applies the current track gain on top of the user volume', () async {
    var handler = SonoraAudioHandler();
    await Future<void>.delayed(Duration.zero);
    var half = math.pow(10, -6 / 20).toDouble();

    handler.mediaItem.add(item('a', trackGain: -6));
    await handler.setReplayGainMode(ReplayGainMode.track);
    expect(handler.player.volume, closeTo(half, 1e-9));
    expect(handler.volume, 1.0);

    await handler.applyVolume(0.5);
    expect(handler.player.volume, closeTo(0.5 * half, 1e-9));

    // Album mode without album gain falls back to the track gain.
    await handler.setReplayGainMode(ReplayGainMode.album);
    expect(handler.player.volume, closeTo(0.5 * half, 1e-9));

    // An untagged track plays unchanged.
    handler.mediaItem.add(item('b'));
    await Future<void>.delayed(Duration.zero);
    expect(handler.player.volume, 0.5);

    await handler.setReplayGainMode(ReplayGainMode.off);
    handler.mediaItem.add(item('a', trackGain: -6));
    await Future<void>.delayed(Duration.zero);
    expect(handler.player.volume, 0.5);
  });

  test('a library resync refreshes gains of already queued songs', () async {
    var handler = SonoraAudioHandler();
    var provider = PlayerProvider(
      audioHandler: handler,
      settingsProvider: SettingsProvider(),
    );
    await provider.loadSettings();
    await handler.setReplayGainMode(ReplayGainMode.track);

    var untagged = Song(
      id: 1,
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      filePath: '/test/music/song.mp3',
    );
    var queued = MediaItem(
      id: Uri.file(untagged.filePath).toString(),
      title: 'Song',
    );
    handler.mediaItem.add(queued);
    provider.queue = [untagged];
    provider.currentIndex = 0;
    await Future<void>.delayed(Duration.zero);
    expect(handler.player.volume, 1.0);

    // The first sync after upgrading reads the song's tags.
    var tagged = untagged.withReplayGain(const ReplayGainInfo(trackGain: -6));
    provider.updateSongs([tagged]);
    await Future<void>.delayed(Duration.zero);

    expect(provider.queue.single.replayGainTrack, -6);
    expect(
      handler.player.volume,
      closeTo(math.pow(10, -6 / 20).toDouble(), 1e-9),
    );
  });
}
