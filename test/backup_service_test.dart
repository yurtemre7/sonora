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
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();

  late Directory docsDir;
  var tempDirs = <Directory>[];
  var prefs = SharedPreferencesAsync();
  var scanner = MusicScanner();
  var stats = StatsService();

  /// Simulates a fresh install: empty prefs, empty documents directory.
  Future<void> newDevice() async {
    docsDir = Directory.systemTemp.createTempSync('sonora_backup_test_');
    tempDirs.add(docsDir);
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
}

/// A minimal valid backup built from the current state, for tests that only
/// need to tamper with the header.
Future<String> exportFromDeviceAKeepingState() =>
    BackupService().exportToJson(appVersion: 'test');
