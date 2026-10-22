import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/backup_service.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/services/stats_service.dart';

Map<String, dynamic> _song(
  int id,
  String path,
  String title, {
  String artist = 'Artist',
  String album = 'Album',
  int durationMs = 200000,
  bool favorite = false,
  int? favoriteDateMs,
}) => {
  'id': id,
  'title': title,
  'artist': artist,
  'album': album,
  'duration_ms': durationMs,
  'file_path': path,
  'is_favorite': favorite,
  'favorite_date_ms': favoriteDateMs,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Set before any SharedPreferencesAsync is created: instances capture it.
  var platform = _FlakyPrefs();
  SharedPreferencesAsyncPlatform.instance = platform;

  late Directory docsDir;
  var tempDirs = <Directory>[];
  var prefs = SharedPreferencesAsync();
  var scanner = MusicScanner();
  var stats = StatsService();

  /// Simulates a fresh install: empty prefs, empty documents directory.
  Future<void> newDevice() async {
    docsDir = Directory.systemTemp.createTempSync('sonora_backup_test_');
    tempDirs.add(docsDir);
    platform.failingKeys.clear();
    await prefs.clear();
    await stats.reset();
  }

  Future<void> writeLibrary(List<Map<String, dynamic>> songs) async {
    await File('${docsDir.path}/imported_songs.json')
        .writeAsString(jsonEncode(songs));
  }

  Future<Map<String, dynamic>> snapshotState() async => {
    'prefs': await prefs.getAll(),
    'library': [
      for (var s in await scanner.readLibrarySongs())
        [s.id, s.filePath, s.isFavorite, s.favoriteDateMs],
    ],
    'stats': await stats.exportSnapshot(),
  };

  Future<void> expectRejected(String content, BackupErrorKind kind) async {
    var before = await snapshotState();
    var playlistsBefore = (await scanner.getPlaylists())
        .map((p) => p.toJson())
        .toList();

    await expectLater(
      BackupService().restore(content),
      throwsA(isA<BackupException>().having((e) => e.kind, 'kind', kind)),
    );

    expect(await snapshotState(), before);
    expect(
      (await scanner.getPlaylists()).map((p) => p.toJson()).toList(),
      playlistsBefore,
    );
  }

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => call.method == 'getApplicationDocumentsDirectory'
              ? docsDir.path
              : null,
        );
  });

  tearDownAll(() {
    for (var dir in tempDirs) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  /// Device A: three songs, a playlist, favorites, stats and settings.
  Future<String> exportFromDeviceA() async {
    await newDevice();
    await writeLibrary([
      _song(
        1,
        '/storage/emulated/0/Music/one.mp3',
        'One',
        favorite: true,
        favoriteDateMs: 1000,
      ),
      _song(2, '/storage/emulated/0/Music/two.mp3', 'Two'),
      _song(
        3,
        '/storage/emulated/0/Music/three.mp3',
        'Three',
        favorite: true,
        favoriteDateMs: 3000,
      ),
    ]);
    await scanner.savePlaylists([
      Playlist(id: 'p1', name: 'Mix', songIds: [3, 1, 2], description: 'd'),
    ]);
    await prefs.setString('now_playing_style', 'vinyl');
    await prefs.setBool('amoled_dark', true);
    await prefs.setDouble('speed', 1.25);
    await prefs.setStringList('mfx_customEqGains', ['1.0', '2.0']);
    await prefs.setString('theme_mode', 'dark');
    await prefs.setString('favorite_albums_map', jsonEncode({'a|||b': 5}));
    // Skipped keys must not travel.
    await prefs.setString('scan_folder_path', '/storage/emulated/0/Music');
    await prefs.setInt('last_played_song_id', 2);

    stats.recordCompleteListen(1, playlistId: 'p1');
    stats.recordCompleteListen(1);
    stats.recordCompleteListen(3);
    stats.recordSongSkip(2);
    stats.recordSongPlayed(3, at: DateTime.fromMillisecondsSinceEpoch(9000));

    return BackupService().exportToJson(appVersion: '1.25.1+1');
  }

  group('BackupService', () {
    test('export writes a versioned document without skipped keys', () async {
      var json = await exportFromDeviceA();
      var doc = jsonDecode(json) as Map<String, dynamic>;

      expect(doc['format'], 'sonora-backup');
      expect(doc['version'], 1);
      expect(doc['appVersion'], '1.25.1+1');
      expect(DateTime.tryParse(doc['createdAt'] as String), isNotNull);
      var settings = doc['settings'] as Map<String, dynamic>;
      expect(settings['now_playing_style'], 'vinyl');
      expect(settings.containsKey('scan_folder_path'), isFalse);
      expect(settings.containsKey('last_played_song_id'), isFalse);
      expect((doc['songs'] as List).length, 3);
      expect(
        BackupService.defaultFileName(DateTime(2026, 3, 7)),
        'sonora-backup-2026-03-07.json',
      );
    });

    test('round trip remaps changed ids and drops unmatched songs', () async {
      var json = await exportFromDeviceA();

      // Device B: ids differ, "two" moved to another root, "three" is gone,
      // "one" kept its path.
      await newDevice();
      await writeLibrary([
        _song(101, '/storage/emulated/0/Music/one.mp3', 'One'),
        _song(102, '/sdcard/Music/two.mp3', 'Two (renamed tag)'),
        _song(200, '/storage/emulated/0/Music/other.mp3', 'Other'),
      ]);

      var result = await BackupService().restore(json);

      expect(result.playlistsRestored, 1);
      expect(result.favoriteSongsRestored, 1);
      expect(result.unmatchedSongs, 1);
      expect(result.statsRestored, isTrue);

      var playlists = await scanner.getPlaylists();
      expect(playlists.single.id, 'p1');
      expect(playlists.single.name, 'Mix');
      expect(playlists.single.description, 'd');
      expect(playlists.single.songIds, [101, 102]);

      var songs = {for (var s in await scanner.readLibrarySongs()) s.id: s};
      expect(songs[101]!.isFavorite, isTrue);
      expect(songs[101]!.favoriteDateMs, 1000);
      expect(songs[102]!.isFavorite, isFalse);
      expect(songs[200]!.isFavorite, isFalse);

      expect(stats.songPlayCount(101), 2);
      expect(stats.songSkipCount(102), 1);
      expect(stats.completeSongListens, 3);
      expect(stats.songLastPlayedAt(101), isNull);
      var snapshot = await stats.exportSnapshot();
      expect(snapshot['first_played_song_id'], 101);
      expect((snapshot['song_play_counts'] as Map).keys, ['101']);
      expect(snapshot['playlist_play_counts'], {'p1': 1});

      expect(await prefs.getString('now_playing_style'), 'vinyl');
      expect(await prefs.getBool('amoled_dark'), isTrue);
      expect(await prefs.getDouble('speed'), 1.25);
      expect(await prefs.getStringList('mfx_customEqGains'), ['1.0', '2.0']);
      expect(await prefs.getString('theme_mode'), 'dark');
      expect(await prefs.getString('scan_folder_path'), isNull);
      expect(await prefs.getInt('last_played_song_id'), isNull);
      expect(jsonDecode((await prefs.getString('favorite_albums_map'))!), {
        'a|||b': 5,
      });
    });

    test('matches by tags and duration when the path changed', () {
      var refs = [
        const BackupSongRef(
          id: 7,
          path: '/old/a.mp3',
          title: 'Song',
          artist: 'X',
          album: 'Y',
          durationMs: 100000,
        ),
      ];
      Song lib(int id, int durationMs) => Song(
        id: id,
        title: 'song',
        artist: 'x',
        album: 'y',
        duration: Duration(milliseconds: durationMs),
        filePath: '/new/$id.flac',
      );
      var library = [lib(1, 150000), lib(2, 101000)];
      expect(BackupService.matchSongs(refs, library), {7: 2});
      expect(BackupService.matchSongs(refs, [library.first]), isEmpty);
    });

    test('merges into existing data instead of wiping it', () async {
      var json = await exportFromDeviceA();

      await newDevice();
      await writeLibrary([
        _song(101, '/storage/emulated/0/Music/one.mp3', 'One'),
        _song(
          150,
          '/storage/emulated/0/Music/local.mp3',
          'Local',
          favorite: true,
          favoriteDateMs: 42,
        ),
      ]);
      await scanner.savePlaylists([
        Playlist(id: 'p1', name: 'Old name', songIds: [150]),
        Playlist(id: 'local', name: 'Local only', songIds: [150]),
      ]);
      await prefs.setString('user_name', 'Kept');
      await prefs.setString('now_playing_style', 'modern');

      await BackupService().restore(json);

      var playlists = await scanner.getPlaylists();
      expect(playlists.map((p) => p.id), ['p1', 'local']);
      expect(playlists.first.name, 'Mix');
      expect(playlists.first.songIds, [101]);
      expect(playlists.last.songIds, [150]);

      var songs = {for (var s in await scanner.readLibrarySongs()) s.id: s};
      expect(songs[150]!.isFavorite, isTrue);
      expect(songs[150]!.favoriteDateMs, 42);
      expect(songs[101]!.isFavorite, isTrue);

      expect(await prefs.getString('user_name'), 'Kept');
      expect(await prefs.getString('now_playing_style'), 'vinyl');
    });

    test('restoring twice yields the same state', () async {
      var json = await exportFromDeviceA();
      await newDevice();
      await writeLibrary([
        _song(101, '/storage/emulated/0/Music/one.mp3', 'One'),
        _song(103, '/storage/emulated/0/Music/three.mp3', 'Three'),
      ]);
      await scanner.savePlaylists([
        Playlist(id: 'local', name: 'Local', songIds: [103]),
      ]);

      await BackupService().restore(json);
      var first = await snapshotState();
      var firstPlaylists = (await scanner.getPlaylists())
          .map((p) => p.toJson())
          .toList();

      await BackupService().restore(json);
      expect(await snapshotState(), first);
      expect(
        (await scanner.getPlaylists()).map((p) => p.toJson()).toList(),
        firstPlaylists,
      );
    });

    group('rejects bad files without writing anything', () {
      setUp(() async {
        await newDevice();
        await writeLibrary([_song(1, '/m/one.mp3', 'One')]);
        await scanner.savePlaylists([
          Playlist(id: 'keep', name: 'Keep', songIds: [1]),
        ]);
        await prefs.setString('now_playing_style', 'modern');
        stats.recordCompleteListen(1);
      });

      test('invalid JSON', () async {
        await expectRejected('{not json', BackupErrorKind.invalidJson);
      });

      test('not a backup', () async {
        await expectRejected('{"hello": 1}', BackupErrorKind.notABackup);
        await expectRejected('[]', BackupErrorKind.notABackup);
      });

      test('unknown version', () async {
        var json = jsonDecode(await exportFromDeviceAKeepingState());
        json['version'] = 2;
        await expectRejected(
          jsonEncode(json),
          BackupErrorKind.unsupportedVersion,
        );
      });

      test('malformed section after valid settings', () async {
        var doc = {
          'format': 'sonora-backup',
          'version': 1,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'appVersion': '1.0.0',
          'songs': <Object>[],
          'settings': {'now_playing_style': 'vinyl'},
          'playlists': [
            {
              'id': 'x',
              'name': 'X',
              'songIds': ['not an id'],
            },
          ],
        };
        await expectRejected(jsonEncode(doc), BackupErrorKind.malformed);

        doc['playlists'] = <Object>[];
        doc['settings'] = {'now_playing_style': 42};
        await expectRejected(jsonEncode(doc), BackupErrorKind.malformed);

        doc['settings'] = <String, Object>{};
        doc['stats'] = {
          'song_play_counts': {'abc': 1},
        };
        await expectRejected(jsonEncode(doc), BackupErrorKind.malformed);
      });
    });
  });

  group('BackupService safety', () {
    test('refuses to restore into an empty library', () async {
      var json = await exportFromDeviceA();
      await newDevice();
      await prefs.setString('now_playing_style', 'modern');
      stats.recordCompleteListen(5);

      await expectRejected(json, BackupErrorKind.libraryEmpty);
      expect(stats.songPlayCount(5), 1);
    });

    test('refuses when no backed-up song is in the library', () async {
      var json = await exportFromDeviceA();
      await newDevice();
      await writeLibrary([_song(9, '/elsewhere/x.mp3', 'Unrelated')]);
      await scanner.savePlaylists([
        Playlist(id: 'p1', name: 'Mine', songIds: [9]),
      ]);

      await expectRejected(json, BackupErrorKind.noMatchingSongs);
      expect((await scanner.getPlaylists()).single.songIds, [9]);
    });

    test('aborts when current playlists cannot be read', () async {
      var json = await exportFromDeviceA();
      await newDevice();
      await writeLibrary([
        _song(101, '/storage/emulated/0/Music/one.mp3', 'One'),
      ]);
      await prefs.setString('playlists_json', '{broken');

      await expectRejected(json, BackupErrorKind.readFailed);
      expect(await prefs.getString('playlists_json'), '{broken');
    });

    test('rolls back everything when the library write fails', () async {
      var json = await exportFromDeviceA();
      await newDevice();
      await writeLibrary([
        _song(101, '/storage/emulated/0/Music/one.mp3', 'One'),
      ]);
      await scanner.savePlaylists([
        Playlist(id: 'p1', name: 'Mine', songIds: [101]),
      ]);
      await prefs.setString('now_playing_style', 'modern');
      // The library is written via a temp file; a directory in its place
      // makes that write fail after settings and playlists were written.
      Directory('${docsDir.path}/imported_songs.json.tmp').createSync();

      await expectRejected(json, BackupErrorKind.writeFailed);
      expect(await prefs.getString('now_playing_style'), 'modern');
      expect(await prefs.getBool('amoled_dark'), isNull);
      expect((await scanner.getPlaylists()).single.name, 'Mine');
    });

    test('rolls back everything when the stats write fails', () async {
      var json = await exportFromDeviceA();
      await newDevice();
      await writeLibrary([
        _song(101, '/storage/emulated/0/Music/one.mp3', 'One'),
      ]);
      stats.recordCompleteListen(101);
      File('${docsDir.path}/listening_stats.json').deleteSync();
      Directory('${docsDir.path}/listening_stats.json').createSync();

      await expectRejected(json, BackupErrorKind.writeFailed);
      expect(stats.songPlayCount(101), 1);
      var songs = await scanner.readLibrarySongs();
      expect(songs.single.isFavorite, isFalse);
      expect(await scanner.getPlaylists(), isEmpty);
    });

    test('rolls back settings when a prefs write fails', () async {
      var json = await exportFromDeviceA();
      await newDevice();
      await writeLibrary([
        _song(101, '/storage/emulated/0/Music/one.mp3', 'One'),
      ]);
      await prefs.setString('theme_mode', 'light');
      platform.failingKeys.add('playlists_json');

      await expectRejected(json, BackupErrorKind.writeFailed);
      expect(await prefs.getString('theme_mode'), 'light');
      expect(await prefs.getDouble('speed'), isNull);
    });

    test('pauses stats recording only while restoring', () {
      stats.pauseRecording();
      stats.recordCompleteListen(77);
      stats.resumeRecording();
      expect(stats.songPlayCount(77), 0);
      stats.recordCompleteListen(77);
      expect(stats.songPlayCount(77), 1);
    });

    test('export refuses an empty library', () async {
      await newDevice();
      await expectLater(
        BackupService().exportToJson(appVersion: 'x'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.kind,
            'kind',
            BackupErrorKind.libraryEmpty,
          ),
        ),
      );
    });

    test('legacy favorite lists are exported and not shadowed', () async {
      await newDevice();
      await writeLibrary([_song(1, '/m/one.mp3', 'One')]);
      await prefs.setStringList('favorite_albums', ['al|||ar']);
      var doc = jsonDecode(await BackupService().exportToJson(appVersion: 'x'));
      expect((doc['favorites']['albums'] as Map).keys, ['al|||ar']);

      await newDevice();
      await writeLibrary([_song(1, '/m/one.mp3', 'One')]);
      await prefs.setStringList('favorite_artists', ['old']);
      doc['favorites']['artists'] = {'new': 5};
      await BackupService().restore(jsonEncode(doc));

      var artists =
          jsonDecode((await prefs.getString('favorite_artists_map'))!) as Map;
      expect(artists.keys.toSet(), {'old', 'new'});
      expect(artists['new'], 5);
      var albums = jsonDecode((await prefs.getString('favorite_albums_map'))!);
      expect((albums as Map).keys, ['al|||ar']);
    });

    test('restores "no effects" by removing preset keys', () async {
      await newDevice();
      await writeLibrary([_song(1, '/m/one.mp3', 'One')]);
      var json = await BackupService().exportToJson(appVersion: 'x');

      await prefs.setString('mfx_preset_name', 'slowed');
      await prefs.setDouble('mfx_preset', 0.8);
      await prefs.setStringList('mfx_customEqGains', ['1.0']);
      await prefs.setDouble('volume', 0.5);
      await BackupService().restore(json);

      expect(await prefs.getString('mfx_preset_name'), isNull);
      expect(await prefs.getDouble('mfx_preset'), isNull);
      expect(await prefs.getStringList('mfx_customEqGains'), isNull);
      expect(await prefs.getDouble('volume'), 0.5);
    });

    test('accepts a file with a UTF-8 byte order mark', () async {
      await newDevice();
      await writeLibrary([_song(1, '/m/one.mp3', 'One')]);
      var json = await BackupService().exportToJson(appVersion: 'x');
      expect(BackupService.parse('﻿$json').appVersion, 'x');
      var bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(json)];
      expect(
        BackupService.parse(BackupService.decodeFile(bytes)).appVersion,
        'x',
      );
    });
  });

  group('matchSongs', () {
    BackupSongRef ref(
      int id,
      String path,
      String title, {
      String artist = 'A',
    }) => BackupSongRef(
      id: id,
      path: path,
      title: title,
      artist: artist,
      album: 'Al',
      durationMs: 100000,
    );
    Song song(int id, String path, String title, {String artist = 'A'}) => Song(
      id: id,
      title: title,
      artist: artist,
      album: 'Al',
      duration: const Duration(milliseconds: 100000),
      filePath: path,
    );

    test('is one to one; a colliding song stays unmatched', () {
      var refs = [ref(2, '/a/x.mp3', 'T'), ref(1, '/b/y.mp3', 'T')];
      var library = [song(10, '/c/z.mp3', 'T')];
      expect(BackupService.matchSongs(refs, library), {1: 10});
    });

    test('exact path wins over an earlier tag match', () {
      var refs = [ref(1, '/a/x.mp3', 'T'), ref(2, '/lib/t.mp3', 'T')];
      var library = [song(10, '/lib/t.mp3', 'T')];
      expect(BackupService.matchSongs(refs, library), {2: 10});
    });

    test('ties go to the lowest library id', () {
      var library = [song(20, '/c/a.mp3', 'T'), song(11, '/c/b.mp3', 'T')];
      expect(BackupService.matchSongs([ref(1, '/x/q.mp3', 'T')], library), {
        1: 11,
      });
    });

    test('path tail needs the title or artist to agree', () {
      var r = ref(1, '/old/Music/x.mp3', 'Title', artist: 'Band');
      expect(
        BackupService.matchSongs(
          [r],
          [song(5, '/new/Music/x.mp3', 'Other', artist: 'Someone')],
        ),
        isEmpty,
      );
      expect(
        BackupService.matchSongs(
          [r],
          [song(5, '/new/Music/x.mp3', 'Other', artist: 'band')],
        ),
        {1: 5},
      );
    });
  });
}

/// A minimal valid backup built from the current state, for tests that only
/// need to tamper with the header.
Future<String> exportFromDeviceAKeepingState() =>
    BackupService().exportToJson(appVersion: 'test');

/// In-memory prefs whose string writes fail for [failingKeys].
final class _FlakyPrefs extends InMemorySharedPreferencesAsync {
  _FlakyPrefs() : super.empty();

  final failingKeys = <String>{};

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) {
    if (failingKeys.contains(key)) throw StateError('simulated failure');
    return super.setString(key, value, options);
  }
}
