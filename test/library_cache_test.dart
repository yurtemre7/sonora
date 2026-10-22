import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/models/replay_gain.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/services/replay_gain_reader.dart';

import 'helpers/replay_gain_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocsDir;

  File libraryFile() => File('${tempDocsDir.path}/imported_songs.json');

  Map<String, Object?> songJson(int id, {bool isFavorite = false}) => {
    'id': id,
    'title': 'Song $id',
    'artist': 'Artist',
    'album': 'Album',
    'duration_ms': 180000,
    'file_path': '/mock/$id.mp3',
    'is_favorite': isFavorite,
  };

  setUp(() {
    tempDocsDir = Directory.systemTemp.createTempSync('sonora_cache_test_');
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return tempDocsDir.path;
            }
            return null;
          },
        );
  });

  tearDown(() {
    if (tempDocsDir.existsSync()) {
      tempDocsDir.deleteSync(recursive: true);
    }
  });

  group('Library cache', () {
    test('migrates the legacy prefs copy to the file and removes it', () async {
      var prefs = SharedPreferencesAsync();
      await prefs.setString(
        'imported_songs_json',
        jsonEncode([songJson(1), songJson(2)]),
      );
      // An older, stale file must lose to the prefs copy.
      await libraryFile().writeAsString(jsonEncode([songJson(9)]));

      var songs = await MusicScanner().scanAllSongs();

      expect(songs.map((s) => s.id), unorderedEquals([1, 2]));
      expect(await prefs.getString('imported_songs_json'), isNull);
      var onDisk = jsonDecode(libraryFile().readAsStringSync()) as List;
      expect(onDisk.map((e) => e['id']), unorderedEquals([1, 2]));
    });

    test('reads the file when no legacy prefs copy exists', () async {
      await libraryFile().writeAsString(jsonEncode([songJson(3)]));

      var songs = await MusicScanner().scanAllSongs();

      expect(songs.single.id, 3);
    });

    test('a read right after a write sees the new data', () async {
      await libraryFile().writeAsString(jsonEncode([songJson(1), songJson(2)]));
      var scanner = MusicScanner();

      // setFavoriteSongs writes, then each later read must observe it.
      await scanner.setFavoriteSongs([1], true);
      var songs = await scanner.scanAllSongs();

      expect(songs.firstWhere((s) => s.id == 1).isFavorite, isTrue);
      expect(songs.firstWhere((s) => s.id == 2).isFavorite, isFalse);
    });

    test('writes leave no temp file behind and keep valid JSON', () async {
      await libraryFile().writeAsString(jsonEncode([songJson(1)]));
      var scanner = MusicScanner();

      await scanner.setFavoriteSongs([1], true);
      await scanner.scanAllSongs();
      var afterFirst = jsonDecode(libraryFile().readAsStringSync()) as List;
      expect(afterFirst.single['is_favorite'], isTrue);

      await scanner.setFavoriteSongs([1], false);
      await scanner.scanAllSongs();

      expect(File('${libraryFile().path}.tmp').existsSync(), isFalse);
      var onDisk = jsonDecode(libraryFile().readAsStringSync()) as List;
      expect(onDisk.single['is_favorite'], isFalse);
    });
  });

  group('Library cache ReplayGain', () {
    Song song(int id, String path) => Song(
      id: id,
      title: 'Song $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      filePath: path,
    );

    test('round-trips ReplayGain fields', () async {
      var scanner = MusicScanner();
      await scanner.saveAllSongsMetadata([
        song(1, '/mock/1.mp3').withReplayGain(
          const ReplayGainInfo(
            trackGain: -7.25,
            albumGain: -6.5,
            trackPeak: 0.98,
            albumPeak: 1.01,
          ),
        ),
        song(2, '/mock/2.mp3').withReplayGain(null),
        song(3, '/mock/3.mp3'),
      ]);

      var songs = await scanner.scanAllSongs();
      var byId = {for (var s in songs) s.id: s};

      expect(byId[1]!.replayGainTrack, -7.25);
      expect(byId[1]!.replayGainAlbum, -6.5);
      expect(byId[1]!.replayGainTrackPeak, 0.98);
      expect(byId[1]!.replayGainAlbumPeak, 1.01);
      expect(byId[1]!.replayGainScanned, isTrue);
      expect(byId[2]!.replayGain, isNull);
      expect(byId[2]!.replayGainScanned, isTrue);
      expect(byId[3]!.replayGainScanned, isFalse);
    });

    test('loads caches written before ReplayGain support', () async {
      await libraryFile().writeAsString(jsonEncode([songJson(4)]));

      var loaded = (await MusicScanner().scanAllSongs()).single;

      expect(loaded.replayGain, isNull);
      expect(loaded.replayGainScanned, isFalse);
    });

    test('sync reads tags once for songs cached without them', () async {
      var audio = File('${tempDocsDir.path}/tagged.mp3')
        ..writeAsBytesSync(
          id3Tag([
            id3Frame('TXXX', txxxPayload('REPLAYGAIN_TRACK_GAIN', '-4.5 dB')),
          ]),
        );
      var cached = songJson(5)..['file_path'] = audio.path;
      await libraryFile().writeAsString(jsonEncode([cached]));

      var synced = (await MusicScanner().syncLibrary()).single;

      expect(synced.replayGainTrack, -4.5);
      expect(synced.replayGainScanned, isTrue);
      // Reading waits for the pending cache write.
      var reloaded = (await MusicScanner().scanAllSongs()).single;
      expect(reloaded.replayGainTrack, -4.5);
      var onDisk = jsonDecode(libraryFile().readAsStringSync()) as List;
      expect(onDisk.single['replaygain_track_gain'], -4.5);
      expect(onDisk.single['replaygain_scanned'], isTrue);
    });

    test(
      'a failed read leaves the song unmarked so the next sync retries',
      () async {
        var audio = File('${tempDocsDir.path}/locked.mp3')
          ..writeAsBytesSync(
            id3Tag([
              id3Frame('TXXX', txxxPayload('REPLAYGAIN_TRACK_GAIN', '-2 dB')),
            ]),
          );
        var cached = songJson(6)..['file_path'] = audio.path;
        await libraryFile().writeAsString(jsonEncode([cached]));

        Process.runSync('chmod', ['000', audio.path]);
        var failed = (await MusicScanner().syncLibrary()).single;
        Process.runSync('chmod', ['644', audio.path]);

        expect(failed.replayGainScanned, isFalse);
        expect(failed.replayGain, isNull);

        var retried = (await MusicScanner().syncLibrary()).single;
        expect(retried.replayGainScanned, isTrue);
        expect(retried.replayGainTrack, -2);
      },
      skip: Platform.isWindows ? 'needs chmod' : false,
    );

    test('tryReadFile tells failed reads from untagged files', () {
      var missing = ReplayGainReader.tryReadFile(
        '${tempDocsDir.path}/nope.mp3',
      );
      expect(missing.failed, isTrue);

      var plain = File('${tempDocsDir.path}/plain.mp3')
        ..writeAsBytesSync(List.filled(64, 7));
      var untagged = ReplayGainReader.tryReadFile(plain.path);
      expect(untagged.failed, isFalse);
      expect(untagged.info, isNull);
    });
  });
}
