import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/services/music_scanner.dart';

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
}
