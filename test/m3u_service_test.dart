import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/services/music_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocsDir;

  setUp(() {
    tempDocsDir = Directory.systemTemp.createTempSync('sonora_m3u_test_');
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

  group('M3U Playlist Export and Import Tests', () {
    test('exportPlaylistToM3u and importM3u full roundtrip', () async {
      var scanner = MusicScanner();

      var testSongsJson = [
        {
          'id': 10,
          'title': 'Synth Echoes',
          'artist': 'Neon Wave',
          'album': 'Cyber City',
          'duration_ms': 210000,
          'file_path': '/storage/music/synth_echoes.mp3',
        },
        {
          'id': 20,
          'title': 'Midnight Drift',
          'artist': 'Retro Dream',
          'album': 'Highway 80',
          'duration_ms': 185000,
          'file_path': '/storage/music/midnight_drift.flac',
        },
      ];

      var jsonFile = File('${tempDocsDir.path}/imported_songs.json');
      var jsonString = jsonEncode(testSongsJson);
      await jsonFile.writeAsString(jsonString);

      var prefs = SharedPreferencesAsync();
      await prefs.setString('imported_songs_json', jsonString);

      // 1. Export playlist
      var playlist = Playlist(
        id: 'pl_synth',
        name: 'Synthwave_Classics',
        songIds: [10, 20],
      );

      var exportedFile = await scanner.exportPlaylistToM3u(playlist);
      expect(exportedFile, isNotNull);
      expect(exportedFile!.existsSync(), isTrue);

      var lines = await exportedFile.readAsLines();
      expect(lines.first, equals('#EXTM3U'));
      expect(lines[1], equals('#EXTINF:210,Neon Wave - Synth Echoes'));
      expect(lines[2], equals('/storage/music/synth_echoes.mp3'));
      expect(lines[3], equals('#EXTINF:185,Retro Dream - Midnight Drift'));
      expect(lines[4], equals('/storage/music/midnight_drift.flac'));

      // 2. Import a new M3U file referencing library songs
      var customM3uFile = File('${tempDocsDir.path}/Imported_Hits.m3u');
      var m3uContent = '''
#EXTM3U
#EXTINF:210,Neon Wave - Synth Echoes
/different/path/synth_echoes.mp3
#EXTINF:185,Retro Dream - Midnight Drift
/another/path/midnight_drift.flac
''';
      await customM3uFile.writeAsString(m3uContent);

      await scanner.importM3u(customM3uFile);

      var playlists = await scanner.getPlaylists();
      expect(playlists.any((p) => p.name == 'Imported_Hits'), isTrue);

      var importedPlaylist = playlists.firstWhere(
        (p) => p.name == 'Imported_Hits',
      );
      expect(importedPlaylist.songIds, equals([10, 20]));
      expect(importedPlaylist.description, equals('Imported from M3U'));
    });
  });
}
