import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/services/home_widget_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(HomeWidgetSync.channelName);
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
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
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  MediaItem song(String id, {Uri? artUri}) => MediaItem(
    id: '/music/$id.mp3',
    title: 'Title $id',
    artist: 'Artist $id',
    artUri: artUri,
  );

  test('maps media item fields to the widget state', () {
    var state = HomeWidgetState.from(
      song('a', artUri: Uri.file('/cache/art/a.jpg')),
      playing: true,
    );
    expect(state!.toMap(), {
      'title': 'Title a',
      'artist': 'Artist a',
      'artPath': '/cache/art/a.jpg',
      'isPlaying': true,
    });

    var remote = HomeWidgetState.from(
      song('b', artUri: Uri.parse('https://example.com/b.jpg')),
      playing: false,
    );
    expect(remote!.artPath, isNull);
    expect(remote.isPlaying, isFalse);

    expect(HomeWidgetState.from(null, playing: true), isNull);
  });

  test('handler pushes widget state only when it changes', () async {
    var handler = SonoraAudioHandler(homeWidget: HomeWidgetSync(enabled: true));
    await settle();
    // Nothing loaded yet: the widget keeps what it shows.
    expect(calls, isEmpty);

    var a = song('a', artUri: Uri.file('/cache/art/a.jpg'));
    handler.mediaItem.add(a);
    await settle();
    expect(calls, hasLength(1));
    expect(calls.single.method, 'update');
    expect(calls.single.arguments, {
      'title': 'Title a',
      'artist': 'Artist a',
      'artPath': '/cache/art/a.jpg',
      'isPlaying': false,
    });

    // Position ticks and repeated items change nothing on the widget.
    handler.playbackState.add(
      handler.playbackState.value.copyWith(
        updatePosition: const Duration(seconds: 5),
      ),
    );
    handler.mediaItem.add(a);
    await settle();
    expect(calls, hasLength(1));

    handler.playbackState.add(
      handler.playbackState.value.copyWith(playing: true),
    );
    await settle();
    expect(calls, hasLength(2));
    expect((calls.last.arguments as Map)['isPlaying'], isTrue);

    handler.playbackState.add(
      handler.playbackState.value.copyWith(
        updatePosition: const Duration(seconds: 6),
        bufferedPosition: const Duration(seconds: 30),
      ),
    );
    await settle();
    expect(calls, hasLength(2));

    handler.mediaItem.add(song('b'));
    await settle();
    expect(calls, hasLength(3));
    expect(calls.last.arguments, {
      'title': 'Title b',
      'artist': 'Artist b',
      'artPath': null,
      'isPlaying': true,
    });

    // Stopping clears the widget once.
    await handler.stop();
    await settle();
    expect(calls, hasLength(4));
    expect(calls.last.arguments, isNull);
  });

  test('retries after a failed push', () async {
    var fail = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (fail) throw MissingPluginException();
          return null;
        });
    var sync = HomeWidgetSync(enabled: true);
    var state = const HomeWidgetState(title: 'x');

    await sync.update(state);
    fail = false;
    await sync.update(state);
    await sync.update(state);
    expect(calls, hasLength(2));
  });

  test('does nothing when disabled', () async {
    var sync = HomeWidgetSync(enabled: false);
    await sync.update(const HomeWidgetState(title: 'x'));
    expect(calls, isEmpty);
  });
}
