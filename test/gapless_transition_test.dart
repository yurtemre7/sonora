import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/models/replay_gain.dart';
import 'package:sonora/services/audio_handler.dart';

/// Track changes that happen while the handler edits the native playlist
/// (sliding the window, queue edits) must still reach [mediaItem] and the
/// ReplayGain level, otherwise the notification, widget, stats and loudness
/// stay on the previous song after a gapless transition.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeJustAudioPlatform platform;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (call) async => null,
        );
    platform = _FakeJustAudioPlatform();
    JustAudioPlatform.instance = platform;
  });

  List<MediaItem> songs(int count, {double? gainOf13}) => List.generate(
    count,
    (i) => MediaItem(
      id: 'file:///music/song$i.mp3',
      title: 'song$i',
      extras: i == 13 && gainOf13 != null
          ? ReplayGainExtras.build(trackGain: gainOf13)
          : null,
    ),
  );

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'a track change during a window slide updates the current item',
    () async {
      var handler = SonoraAudioHandler();
      await settle();
      await handler.loadPlaylist(songs(60));
      await settle();
      var fake = platform.player!;

      // Reaching native index 21 leaves 8 tracks ahead, so the handler appends
      // the next chunk. The next track starts while that append is in flight.
      fake.onInsertAll = () => fake.emitIndex(22);
      fake.emitIndex(21);
      await settle();

      expect(fake.insertAllCalls, 1);
      expect(handler.mediaItem.value?.title, 'song22');
    },
  );

  test(
    'a track change during a queue edit applies the new track gain',
    () async {
      var handler = SonoraAudioHandler();
      await settle();
      await handler.setReplayGainMode(ReplayGainMode.track);
      await handler.loadPlaylist(songs(20, gainOf13: -6));
      await settle();
      var fake = platform.player!;
      fake.emitIndex(12);
      await settle();

      // Removing a later track edits the native playlist; song 13 starts
      // during that edit.
      fake.onRemoveRange = () => fake.emitIndex(13);
      await handler.removeQueueItemAt(18);
      await settle();

      expect(handler.mediaItem.value?.title, 'song13');
      expect(handler.currentReplayGainMultiplier, lessThan(1.0));
    },
  );
}

class _FakeJustAudioPlatform extends JustAudioPlatform {
  _FakeAudioPlayer? player;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async =>
      player = _FakeAudioPlayer(request.id);

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async => DisposePlayerResponse();

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async => DisposeAllPlayersResponse();
}

/// Minimal native player: records playlist edits and lets the test announce
/// track changes, optionally from inside an edit.
class _FakeAudioPlayer extends AudioPlayerPlatform {
  _FakeAudioPlayer(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();
  int? _index;
  var insertAllCalls = 0;
  void Function()? onInsertAll;
  void Function()? onRemoveRange;

  void emitIndex(int index) {
    _index = index;
    _events.add(
      PlaybackEventMessage(
        processingState: ProcessingStateMessage.ready,
        updateTime: DateTime.now(),
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: const Duration(minutes: 3),
        icyMetadata: null,
        currentIndex: _index,
        androidAudioSessionId: null,
      ),
    );
  }

  /// Runs [hook] and lets its event reach the Dart player before the
  /// native call returns, the way a real transition can race an edit.
  Future<void> _during(void Function()? hook) async {
    if (hook == null) return;
    hook();
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    emitIndex(request.initialIndex ?? 0);
    return LoadResponse(duration: const Duration(minutes: 3));
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
    ConcatenatingInsertAllRequest request,
  ) async {
    insertAllCalls++;
    var hook = onInsertAll;
    onInsertAll = null;
    await _during(hook);
    return ConcatenatingInsertAllResponse();
  }

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
    ConcatenatingRemoveRangeRequest request,
  ) async {
    var hook = onRemoveRange;
    onRemoveRange = null;
    await _during(hook);
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
    ConcatenatingMoveRequest request,
  ) async => ConcatenatingMoveResponse();

  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    if (request.index != null) emitIndex(request.index!);
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async => SetShuffleOrderResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
  setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async => SetAutomaticallyWaitsToMinimizeStallingResponse();

  @override
  Future<AudioEffectSetEnabledResponse> audioEffectSetEnabled(
    AudioEffectSetEnabledRequest request,
  ) async => AudioEffectSetEnabledResponse();

  @override
  Future<AndroidEqualizerGetParametersResponse> androidEqualizerGetParameters(
    AndroidEqualizerGetParametersRequest request,
  ) async => AndroidEqualizerGetParametersResponse(
    parameters: AndroidEqualizerParametersMessage(
      minDecibels: -15,
      maxDecibels: 15,
      bands: const [],
    ),
  );

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async =>
      DisposeResponse();
}
